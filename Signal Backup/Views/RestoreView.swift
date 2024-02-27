//
//  RestoreView.swift
//  Signal Backup
//
//  Created by Tjaden Hess on 2/26/24.
//

import SwiftUI

struct RestoreView: View {
    @Binding var backupURL: URL?
    @State private var filePickerPresented = true;
    @State private var restoreURL: URL?
    @State private var cameraDisplayed = false
    @State private var peerQR: URL?;
    //@State private var transferring = false
    @Environment(\.dismiss) var dismiss
    @StateObject private var restoreService = RestoreService();
    
    var body: some View {
        VStack {
            if (cameraDisplayed){
                QRCodeScannerView(peerQR: $peerQR, transferReady: $restoreService.transferring)
            }
        }.fileImporter(isPresented: $filePickerPresented, allowedContentTypes: [.directory], allowsMultipleSelection: false)
        { result in
            switch result{
                case .success(let url):
                    restoreURL = url[0]
                    cameraDisplayed = true
                guard restoreURL!.startAccessingSecurityScopedResource() else {fatalError("Failed to get directory access")}
                case .failure:
                    dismiss()
            }
        } onCancellation: {
            dismiss()
        }
        .fileDialogDefaultDirectory(backupURL)
        .sheet(isPresented: $restoreService.transferring, content: {
            Text("Transferring...").frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 100).onAppear(){
                restoreService.srcFolder = restoreURL!
                restoreService.startBrowsing(url: peerQR!)
            }
        })
    }
}

#Preview {
    RestoreView(backupURL: .constant(nil))}
