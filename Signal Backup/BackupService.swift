import MultipeerConnectivity
import Crypto
import SwiftASN1
import X509
import os
import CoreImage
import SwiftUI


import Foundation

let cancelMessage = "App backgrounded".data(using: .utf8)!

class BackupService: NSObject, ObservableObject, MCSessionDelegate,
    MCNearbyServiceAdvertiserDelegate
{
    var mcSession: MCSession?
    var advertiser: MCNearbyServiceAdvertiser

    var identity: SecIdentity
    var tmpFolder: URL?
    var manifest: DeviceTransferProtoManifest?
    var qrCode: Image
    var connectdedPeer: MCPeerID?
    
    @Published
    var transferring = false
    
    @Published
    var needsSaving = false
    
    override init() {
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: ourID,
            discoveryInfo: nil,
            serviceType: serviceType)

        do { self.identity = try newIdentity() } catch { fatalError("Failed to create new identity") }
        self.qrCode = try! generateQRCode(peerId: ourID, identity: self.identity)
        super.init()
    }
    
    func startAdvertising() {
        logger.log("Starting advertising")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer();
        
        logger.log("Starting Advertising")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.log("Failed to start advertising: \(error.localizedDescription)")
    }
    
    // TODO: is this mutexed?
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger.log("Received invitation from \(peerID.displayName)")
        
        if transferring, let connected = self.connectdedPeer {
            logger.log("Rejected invitation from \(peerID.displayName). Already connected to \(connected.displayName)")
        } else {
            connectdedPeer = peerID
            transferring = true
            
            self.mcSession = MCSession(peer:ourID, securityIdentity: [self.identity], encryptionPreference: .required)
            self.mcSession?.delegate = self
            
            self.tmpFolder = try! FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: FileManager.default.temporaryDirectory, create: true)
            invitationHandler(true, self.mcSession)
            logger.log("Accepted invitation from \(peerID.displayName)")
        }
    }
    
    // Implement the required MCSessionDelegate methods here
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // Handle peer state changes
        logger.log("State Change: Peer \(peerID.displayName), state: \(state.rawValue)")
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle receiving data
        logger.log("Data Receive: Peer \(peerID.displayName), data: \(data.base64EncodedString())")

        guard peerID == self.connectdedPeer
        else {
            return
        }
        if data == "Transfer Complete".data(using: .utf8)! {
           // do {
            //    try session.send(cancelMessage, toPeers: [peerID], with: .unreliable)
           // } catch {}
            self.needsSaving = true
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle receiving a stream
        logger.log("Stream Receive: Peer \(peerID.displayName)")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Handle the start of receiving a resource
        logger.log("Resource Receive: Peer \(peerID.displayName), resource: \(resourceName)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        if resourceName == "manifest" {
            handleManifest(localURL!)
        } else {
            
            let nameComponents = resourceName.components(separatedBy: " ")
            guard let fileIdentifier = nameComponents.first, let fileHash = nameComponents.last, nameComponents.count == 2 else {
                fatalError()
            }
            
            guard let file: DeviceTransferProtoFile = {
                switch fileIdentifier {
                case "database":
                    return manifest?.database?.database
                case "database-wal":
                    return manifest?.database?.wal
                default:
                    return manifest?.files.first(where: { $0.identifier == fileIdentifier })
                }
            }() else {
                fatalError()
            }
            // Handle finishing receiving a resource
            logger.log("Finish resource Receive: Peer \(peerID.displayName), resource: \(resourceName) at \(localURL?.absoluteString)")
            
            // TODO: validate hash
            
            let dest = tmpFolder!.appending(component: file.identifier)
            do {
                if let localURL = localURL {
                    logger.log("moving \(localURL) to \(dest)")
                }
                try FileManager.default.moveItem(at: localURL!, to: dest)
            } catch {fatalError()}
        }
    }
    
    func handleManifest(_ localURL: URL) {
        guard let data = try? Data(contentsOf: localURL) else {
            logger.log("Failed to read file \(localURL.absoluteString)")
            return
        }
        guard let manifest = try? DeviceTransferProtoManifest(serializedData: data) else {
            logger.log("Failed to parse manifest proto \(localURL.absoluteString)")
            return
        }
        self.manifest = manifest
        do {
            let dest = tmpFolder!.appending(component: "manifest")
            try FileManager.default.moveItem(at: localURL, to: dest)
        }
        catch {
            logger.log("File move failed \(error)")
            fatalError()
        }
    }
    
    func cancelTransfer() {
        if transferring, let connectdedPeer = self.connectdedPeer, let session = self.mcSession {
            try? session.send(cancelMessage, toPeers: [connectdedPeer], with: .unreliable)
            session.disconnect()
            transferring = false
            try? FileManager.default.removeItem(at: self.tmpFolder!)
        }
    }
    
    func stopAdvertising() {
        cancelTransfer()
        advertiser.stopAdvertisingPeer()
        logger.log("Stopped Adevrtising")
    }
}

