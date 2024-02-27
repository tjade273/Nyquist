//
//  Signal_BackupApp.swift
//  Signal Backup
//
//  Created by Tjaden Hess on 2/7/24.
//

import SwiftUI
import MultipeerConnectivity

let ourID = MCPeerID(displayName: "Desktop App")
let serviceType = "sgnl-new-device"
let qrScheme = "sgnl"
let qrHost = "transfer"
let qrVersion = String(1)
let transferMode = "primary"


@main
struct Signal_BackupApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
