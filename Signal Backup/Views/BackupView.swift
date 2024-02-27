//
//  BackupView.swift
//  Signal Backup
//
//  Created by Tjaden Hess on 2/25/24.
//

import SwiftUI

struct BackupView: View {
    @StateObject private var backupService = BackupService()
    
    @Binding var backupURL: URL?
    
    var body: some View {
        VStack {
            backupService.qrCode.resizable().padding(200).scaledToFit()
                .onAppear(){
                    backupService.startAdvertising()
                }
                .onDisappear {
                    backupService.stopAdvertising()
                }
        }.sheet(isPresented: $backupService.transferring, content: {
            TransferringView().environmentObject(backupService)
        }).fileMover(isPresented: $backupService.needsSaving, file: backupService.tmpFolder) {result in
               // TODO
            switch result {
            case .success(let url):
                backupURL = url
            
            case .failure:
                logger.error("Failed to move files!")
            }
        } onCancellation: {
            backupURL = backupService.tmpFolder
        }
    }
}

struct TransferringView: View {
    @EnvironmentObject
    private var backupService: BackupService
    
    var body: some View {
        VStack {
            Text("Transferring, please wait...")
                .frame(height:30)
            
            Button("Cancel") {
                backupService.cancelTransfer()
            }
        }
        .scaledToFill()
        .backgroundStyle(.gray)
        .opacity(1)
    }
}

#Preview {
    BackupView(backupURL: .constant(nil))
}
