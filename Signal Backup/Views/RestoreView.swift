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
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            QRCodeScannerView(peerQR: $peerQR)
        }.fileImporter(isPresented: $filePickerPresented, allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result{
                case .success(let url):
                    restoreURL = url[0]
                    cameraDisplayed = true
                case .failure:
                    filePickerPresented = true
            }
        } onCancellation: {
            dismiss()
        }
        .fileDialogDefaultDirectory(backupURL)
        if let url = backupURL {
            Text(url.absoluteString)
        }
    }
}

#Preview {
    RestoreView(backupURL: .constant(nil))}
