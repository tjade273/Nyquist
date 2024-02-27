//
//  ContentView.swift
//  Signal Backup
//
//  Created by Tjaden Hess on 2/7/24.
//

import SwiftUI
import os
import CoreImage.CIFilterBuiltins
import CoreImage


extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

let tmpKeyLabel = "tempKey"
let teamID = "XV8FX9AS7N"
//let teamID = "V42B9WH5ZS"
let bundleIdentifier = teamID + "." +
    "signal-backup"

let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")

func deleteSelfSignedIdentityFromKeychain() throws {
    let _deleteQuery: [CFString: Any] = [
        kSecClass: kSecClassIdentity,
        //kSecAttrAccessGroup: bundleIdentifier,
        kSecAttrLabel: tmpKeyLabel
    ]
    
    //let status = SecItemDelete(deleteQuery as CFDictionary)
    //guard [errSecSuccess, errSecItemNotFound].contains(status) else {
       // logger.error("Delete failed: \(SecCopyErrorMessageString(status, nil))")
     //   throw "delete failed"
   // }
}



struct ContentView: View {
    var backupService = BackupService()
    //@ObservedObject var restoreService = RestoreService()
    @State private var backupURL: URL?
    @State private var restoreIsShowing = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                NavigationLink(destination: BackupView(backupURL: $backupURL)) {
                    Text("Backup")
                }
                Spacer()
                NavigationLink(destination: RestoreView(backupURL: $backupURL)) {
                    Text("Restore")
                }
                Spacer()
            }
        }
    }
}


#Preview {
    ContentView()
}

@objc
public extension NSString {
    var encodeURIComponent: String? {
        // Match behavior of encodeURIComponent used by desktop.
        //
        // Removes any "/" in the base64. All other base64 chars are URL safe.
        // Apple's built-in `stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URL*]]`
        // doesn't offer a flavor for encoding "/".
        var characterSet = CharacterSet.alphanumerics
        characterSet.insert(charactersIn: "-_.!~*'()")
        return addingPercentEncoding(withAllowedCharacters: characterSet)
    }
}

func selectDestFolder() -> URL {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    let res = panel.runModal()
    if res != NSApplication.ModalResponse.OK {
        fatalError("TODO: handle cancel")
    }
    return panel.directoryURL!
}
