//
//  Constants.swift
//  FowlTalk
//
//  Created by Nick Hoyt on 3/3/18.
//  Copyright © 2018 IntelliSkye. All rights reserved.
//

import Foundation
import Firebase

struct Constants
{
    struct refs
    {
        static let databaseRoot = Database.database().reference()
        static let databaseChats = databaseRoot.child("chats")
        static let databaseLocs = databaseRoot.child("locations")
    }
}
