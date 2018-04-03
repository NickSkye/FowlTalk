//
//  ViewController.swift
//  FowlTalk
//
//  Created by Nick Hoyt on 3/3/18.
//  Copyright © 2018 IntelliSkye. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import FirebaseDatabase
import GeoFire
import CoreLocation
import MapKit
import FirebaseAuth
import Firebase

class ChatViewController: JSQMessagesViewController, CLLocationManagerDelegate {

    
    var latitude = ""
    var longitude = ""
    let locationManager = CLLocationManager()
    
    var lat: CLLocationDegrees = 0.0
    var long: CLLocationDegrees = 0.0
    var currentLatitude = 0.0
    var currentLongitude = 0.0
    var messages = [JSQMessage]()
    var geoFire : GeoFire!
    var radiusInMeters = 100.00
    var geofireRef : DatabaseReference!
    var nearbyUsers = [String]()
//    var myLocation = Optional(CLLocation(latitude: 0, longitude: 0))
    lazy var outgoingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }()
    
    lazy var incomingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }()
    
   
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        self.locationManager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestAlwaysAuthorization()
            locationManager.requestWhenInUseAuthorization()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            //mapView.showsUserLocation = true
            
        }
    
        var location = locationManager.location!
//        location =
        lat = location.coordinate.latitude
        long = location.coordinate.longitude
        // For use in foreground
        
        let defaults = UserDefaults.standard
        
        geofireRef = Database.database().reference()
        let geoFire = GeoFire(firebaseRef: geofireRef)
        
        
        if  let id = defaults.string(forKey: "jsq_id"),
            let name = defaults.string(forKey: "jsq_name")
        {
            senderId = id
            senderDisplayName = name
            
        }
        else
        {
            senderId = String(arc4random_uniform(999999))
            senderDisplayName = ""
            
            defaults.set(senderId, forKey: "jsq_id")
            defaults.synchronize()
            
            showDisplayNameDialog()
        }
        
        title = "Chat: \(senderDisplayName!)"
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showDisplayNameDialog))
        tapGesture.numberOfTapsRequired = 1
        
        navigationController?.navigationBar.addGestureRecognizer(tapGesture)
        
        inputToolbar.contentView.leftBarButtonItem = nil
        collectionView.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
       
        let query = Constants.refs.databaseChats.queryLimited(toLast: 100)
        
        _ = query.observe(.childAdded, with: { [weak self] snapshot in
            
            if  let data        = snapshot.value as? [String: String],
                let id          = data["sender_id"],
                let name        = data["name"],
                let text        = data["text"],
                !text.isEmpty
            {
                if let message = JSQMessage(senderId: id, displayName: name, text: text)
                {
                    self?.messages.append(message)
                    
                    self?.finishReceivingMessage()
                }
            }
        })
        findNearbyUsers()
       
    }
    
    
 
    
    func updateUserLocation() {
        
       
            
            let userID = senderId
        geoFire!.setLocation(locationManager.location!, forKey: userID!) { (error) in
                if (error != nil) {
                    debugPrint("An error occured: \(error)")
                } else {
                    print("Saved location successfully!")
                }
            }
            
        
    }
    
    func findNearbyUsers() {
        
      var myLoc = CLLocation(latitude: 0, longitude: 0)
        if(locationManager.location != nil){
            myLoc = locationManager.location!
        }
        else{
            myLoc = CLLocation(latitude: 0, longitude: 0)
        }
        print("geofireRef \(geofireRef!)")
        
        let circleQuery = GeoFire(firebaseRef: geofireRef!).query(at: myLoc, withRadius: 1000/1000)
            
            _ = circleQuery.observe(.keyEntered, with: { (key, location) in

                if !self.nearbyUsers.contains(key) && key != Auth.auth().currentUser!.uid {
                    self.nearbyUsers.append(key)
//                    print("key \(key)")
                }

            })
        
        
            //Execute this code once GeoFire completes the query!
            circleQuery.observeReady({
                
                for user in self.nearbyUsers {
                    
                   Constants.refs.databaseLocs.childByAutoId().observe(.value, with: { snapshot in
                        let value = snapshot.value as? NSDictionary
                        print("value \(value)")
                    })
                }
                
            })
            
       
        
    }
    
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            print(location.coordinate)
        }
    }
    
    // If we have been deined access give the user the option to change it
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if(status == CLAuthorizationStatus.denied) {
            showLocationDisabledPopUp()
        }
    }
    
    // Show the popup to the user if we have been deined access
    func showLocationDisabledPopUp() {
        let alertController = UIAlertController(title: "Background Location Access Disabled",
                                                message: "In order to deliver pizza we need your location",
                                                preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        let openAction = UIAlertAction(title: "Open Settings", style: .default) { (action) in
            if let url = URL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        alertController.addAction(openAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func showDisplayNameDialog()
    {
        let defaults = UserDefaults.standard
        
        let alert = UIAlertController(title: "Your Display Name", message: "Before you can chat, please choose a display name. Others will see this name when you send chat messages. You can change your display name again by tapping the navigation bar.", preferredStyle: .alert)
        
        alert.addTextField { textField in
            
            if let name = defaults.string(forKey: "jsq_name")
            {
                textField.text = name
            }
            else
            {
                let names = ["Anakin", "Obi Wan Kenobi", "Luke", "R2-D2", "BB-8", "Sheev Palpatine", "Darth Vader"]
                textField.text = names[Int(arc4random_uniform(UInt32(names.count)))]
            }
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self, weak alert] _ in
            
            if let textField = alert?.textFields?[0], !textField.text!.isEmpty {
                
                self?.senderDisplayName = textField.text
                
                self?.title = "Chat: \(self!.senderDisplayName!)"
                
                defaults.set(textField.text, forKey: "jsq_name")
                defaults.synchronize()
            }
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData!
    {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource!
    {
        return messages[indexPath.item].senderId == senderId ? outgoingBubble : incomingBubble
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource!
    {
        return nil
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString!
    {
        return messages[indexPath.item].senderId == senderId ? nil : NSAttributedString(string: messages[indexPath.item].senderDisplayName)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat
    {
        return messages[indexPath.item].senderId == senderId ? 0 : 15
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!)
    {
        
        let ref = Constants.refs.databaseChats.childByAutoId()
        let refLoc = Constants.refs.databaseLocs.childByAutoId()
        
        
        let message = ["sender_id": senderId, "name": senderDisplayName, "text": text] as [String : Any]
        
        let locs = ["sender_id": senderId, "name": senderDisplayName, "text": text, "lat": lat, "long": long] as [String : Any]
       
        
        ref.setValue(message)
        refLoc.setValue(locs)
        findNearbyUsers()
        finishSendingMessage()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
   


}

