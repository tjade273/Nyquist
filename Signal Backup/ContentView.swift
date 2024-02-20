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
    //Bundle.main.bundleIdentifier!


let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")

func deleteSelfSignedIdentityFromKeychain() throws {
    let deleteQuery: [CFString: Any] = [
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
    @ObservedObject var mcService = MultipeerConnectivityService()
    @State private var image: Image?

    var body: some View {
        VStack {
            Button("Choose Destination Directory") {
                mcService.destFolder = selectDestFolder()
                image = mcService.startAdvertising()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
        
            image?.resizable().frame(width: 300.0, height: 300.0)
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


func generateQRCode(from string: String) -> Image? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    
    if let outputImage = filter.outputImage {
        if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            return Image(cgimg, scale: 10, label: Text("QR Image"))
        }
    }
    return nil
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
