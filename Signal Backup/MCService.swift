import MultipeerConnectivity
import Crypto
import SwiftASN1
import X509
import os
import CoreImage
import SwiftUI


import Foundation

class MultipeerConnectivityService: NSObject, ObservableObject, MCSessionDelegate,
    MCNearbyServiceAdvertiserDelegate
{
    var peerID: MCPeerID
    var mcSession: MCSession
    var advertiser: MCNearbyServiceAdvertiser?
    var identity: SecIdentity?
    var destFolder: URL?
    var manifest: DeviceTransferProtoManifest?
    
    override init() {
        do { self.identity = try newIdentity() } catch { logger.error("Failed to create new identity") }
        self.peerID = MCPeerID(displayName: "Desktop App")
        self.mcSession = MCSession(peer: peerID, securityIdentity: [self.identity!], encryptionPreference: .required)
        super.init()
        self.mcSession.delegate = self
    }
    
    func startAdvertising() -> Image? {
        advertiser = MCNearbyServiceAdvertiser(
            peer: self.peerID,
            discoveryInfo: nil,
            serviceType: "sgnl-new-device")
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer();
        
        logger.log("Starting Advertising")
        
        var components = URLComponents()
        components.scheme = "sgnl"
        components.host = "transfer"
        do {
            guard let base64CertificateHash = try self.identity!.computeCertificateHash().base64EncodedString().encodeURIComponent else {
                throw "failed to get base64 certificate hash"
            }
            
            guard let base64PeerId = try NSKeyedArchiver.archivedData(withRootObject: self.peerID, requiringSecureCoding: true).base64EncodedString().encodeURIComponent else {
                throw "failed to get base64 peerId"
            }

        let queryItems = [
            "version": String(1),
            "transferMode": "primary",
            "certificateHash": base64CertificateHash,
            "peerId": base64PeerId
        ]

        components.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }

        logger.debug("URL: \(components.url!.absoluteString)")
        
        return generateQRCode(from: components.url!.absoluteString)
        }
        catch {return nil }
        //components.url!
        
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.log("Failed to start advertising: \(error.localizedDescription)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger.log("Received invitation from \(peerID.displayName)")
        invitationHandler(true, self.mcSession)
    }
    
    // Implement the required MCSessionDelegate methods here
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // Handle peer state changes
        logger.log("State Change: Peer \(peerID.displayName), state: \(state.rawValue)")
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle receiving data
        logger.log("Data Receive: Peer \(peerID.displayName), data: \(data.base64EncodedString())")
        if data == "Transfer Complete".data(using: .utf8)! {
            let response = "App backgrounded".data(using: .utf8)!
            do {
                try session.send(response, toPeers: [peerID], with: .unreliable)
            } catch {}
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
            
            let dest = destFolder!.appending(component: file.identifier)
            do {
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
            let dest = destFolder!.appending(component: "manifest")
            try FileManager.default.moveItem(at: localURL, to: dest)
        }
        catch {
            logger.log("File move failed \(error)")
            fatalError()
        }
        
    }
}

