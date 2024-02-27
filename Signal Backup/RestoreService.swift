//
//  RestoreService.swift
//  Signal Backup
//
//  Created by Tjaden Hess on 2/25/24.
//

import Foundation
import MultipeerConnectivity
import Crypto

class RestoreService: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate
{
    var mcSession: MCSession?
    var browser: MCNearbyServiceBrowser
    var identity: SecIdentity // TODO: do we even need this? TODO: var vs let?
    var srcFolder: URL?
    var manifest: DeviceTransferProtoManifest?
    var newDeviceId: MCPeerID?
    var certHash: Data?
    var started = false
    var pending_transfers: [SendFile] = [];
    var in_progress_transfers = Set<SendFile>()
    var all_scheduled = false
        
    @Published var success = false
    @Published var transferring = false
    
    override init() {
        self.identity = try! newIdentity()
        browser = MCNearbyServiceBrowser(peer: ourID, serviceType: serviceType)
        super.init()
        browser.delegate = self
    }
    
    func startBrowsing(url: URL) {
        browser.startBrowsingForPeers()
        let (peerID, certHash) = try! parseTransferURL(url)
        self.newDeviceId = peerID
        self.certHash = certHash
        self.mcSession = MCSession(peer: ourID, securityIdentity: [self.identity], encryptionPreference: .required)
        self.mcSession?.delegate = self
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        logger.debug("Connection to \(peerID) did change: \(state.rawValue)")

        DispatchQueue.main.async {
            // We only care about state changes for the device we're sending to.
            guard peerID == self.newDeviceId else { return }
            logger.info("Connection to new device did change: \(state.rawValue)")

            switch state {
            case .connected:
                // Only send the files if we haven't yet sent the manifest.
                guard !self.started else { return }
                self.started = true
                do {
                    try self.sendManifest()
                } catch {
                    //TODO: Handle
                    //self.failTransfer(.assertion, "Failed to send manifest to new device \(error)")
                }
            case .connecting:
                break
            case .notConnected:
                // TODO: handle
                logger.error("Lost connection to new device")
                //self.failTransfer(.assertion, "Lost connection to new device")
            @unknown default:
                logger.error("Unexpected connection state: \(state.rawValue)")
             //   self.failTransfer(.assertion, "Unexpected connection state: \(state.rawValue)")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        logger.log("Recieved \(data) from \(peerID)")
        guard peerID == self.newDeviceId else {return}
        
        if data == "Transfer Complete".data(using: .utf8)! {
            
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        logger.error("Recieved unexpected stream \(streamName) from \(peerID)")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        logger.error("Recieved unexpected resource \(resourceName) from \(peerID)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        logger.error("Finished recieving unexpected resource \(resourceName) from \(peerID)")
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificates: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        var trusted = false
        defer {
            certificateHandler(trusted)
            if trusted {
                logger.info("Accepted certificate from \(peerID.displayName)")
            } else {
                logger.error("Rejected certificate from \(peerID.displayName)")
            }
        }
        guard peerID == self.newDeviceId else {return}
        
        guard let certificate = certificates?.first else {logger.error("Received no certificates"); return}
        
        let certificateData = SecCertificateCopyData(certificate as! SecCertificate) as Data
        
        let certificateHash = Data(SHA256.hash(data: certificateData))
        
        guard let expected = self.certHash else { return }
        trusted = certificateHash == expected
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        logger.log("Invite from peer \(foundPeer)")
        if foundPeer == self.newDeviceId {
            logger.log("Inviting peer \(foundPeer) to session")
            browser.invitePeer(self.newDeviceId!, to: self.mcSession!, withContext: nil, timeout: 30)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer: MCPeerID) {
        logger.log("Lost peer \(lostPeer)")
    }
    
    // TODO EXTENSION
    func sendManifest() throws {
        logger.info("Sending manifest to new device.")

        guard self.started else {
            throw ("attempted to send manifest while no active outgoing transfer")
        }

        guard let session = mcSession else {
            throw ("attempted to send manifest without an available session")
        }
        
        guard let srcFolder = srcFolder else {
            throw "source folder is not set"
        }
        
        let manifestFileURL = srcFolder.appending(path: "manifest")
        
        // Parse the manifest ourselves to extract file list for future transfers
        guard let data = try? Data(contentsOf: manifestFileURL) else {
            logger.log("Failed to read file \(manifestFileURL.absoluteString)") // TODO - user selected something that is not a backup folder. Alert them
            return
        }
        guard let manifest = try? DeviceTransferProtoManifest(serializedData: data) else {
            logger.log("Failed to parse manifest proto \(manifestFileURL.absoluteString)")
            return
        }
        self.manifest = manifest

        
        session.sendResource(at: manifestFileURL, withName: "manifest", toPeer: self.newDeviceId!) { error in
            if error != nil {
                logger.error("Failed to send manifest: \(error)")
            } else {
                logger.info("Successfully sent manifest to new device.")
                do {
                    try self.sendAllFiles()
                } catch {
                    logger.log("Failed to send all files \(error)")
                }
            }
        }
    }

    
    func sendAllFiles() throws {
        guard let manifest = self.manifest else {
            throw "Manifest file not set"
        }
        guard let database = manifest.database else {
                throw ("Manifest unexpectedly missing database")
            }
        
        guard let srcFolder = self.srcFolder else {
            throw ("Source folder unset")
        }
        
        let dbFile = try! SendFile(fileURL: URL(fileURLWithPath: database.database.relativePath, relativeTo: srcFolder), fileIdentifier: "database")
        //let dbFile = try! SendFile(fileURL: URL(fileURLWithPath: database.database.identifier, relativeTo: srcFolder), fileIdentifier: "database")
        try scheduleSendFile(dbFile)
        let walFile = try! SendFile(fileURL: URL(fileURLWithPath: database.wal.relativePath, relativeTo: srcFolder), fileIdentifier: "database-wal")
        //let walFile = try! SendFile(fileURL: URL(fileURLWithPath: database.wal.identifier, relativeTo: srcFolder), fileIdentifier: "database-wal")
        try scheduleSendFile(walFile)
        
        var errs: [Error] = []
        for file in manifest.files {
            do {
                try scheduleSendFile(SendFile(file, srcFolder: srcFolder))
            } catch {
                errs.append(error)
                logger.error("Failed scheduling sending \(file.identifier): \(error)")
            }
        }
        all_scheduled = true
        if !errs.isEmpty {
            throw errs[0]
        }
    }
    
    func sendComplete(_ file: SendFile, _ error: Error?) {
        self.in_progress_transfers.remove(file)
        updateQueue()
        
        if self.pending_transfers.isEmpty && self.in_progress_transfers.isEmpty && self.all_scheduled {
            completeTransfer()
        }
    }
    
    func updateQueue(){
        if self.in_progress_transfers.count < 10 {
            if let sendFile = pending_transfers.popLast() {
                self.in_progress_transfers.insert(sendFile)
                sendFile.send(mcSession: self.mcSession!, toPeer: self.newDeviceId!)
            }
        }
        // logger.log("\(self.in_progress_transfers.count) transfers in progress, \(self.pending_transfers.count) waiting")
    }
        
    func scheduleSendFile(_ sendFile: SendFile) throws {
        var sendFile = sendFile
        sendFile.onComplete = self.sendComplete
        self.pending_transfers.append(sendFile)
        updateQueue()
    }
    
    func completeTransfer() {
        guard pending_transfers.isEmpty else {
            logger.error("Tried to complete transfer with pending files")
            return
        }
        
        logger.log("File transfer complete, sending done message")
        
        try? mcSession?.send("Transfer Complete".data(using: .utf8)! , toPeers: [self.newDeviceId!], with: .reliable)
        DispatchQueue.main.async {
            self.transferring = false
            self.success = true
        }
    }
    
    struct SendFile: Hashable {
        
        var fileURL: URL
        var fileIdentifier: String
        
        var onComplete: ((SendFile, Error?) -> Void)?;
        
        
        init(_ file: DeviceTransferProtoFile, srcFolder: URL) throws {
            let url = URL(filePath: file.relativePath, relativeTo: srcFolder)
            //let url = URL(filePath: file.identifier, relativeTo: srcFolder)
            try self.init(fileURL: url, fileIdentifier: file.identifier)
        }
        
        init(fileURL: URL, fileIdentifier: String) throws {
            self.fileURL = fileURL
            let fileContents = try Data(contentsOf: fileURL)
            let fileHash = Data(SHA256.hash(data: fileContents)).hexEncodedString()

            self.fileIdentifier = fileIdentifier + " " + fileHash
        }
        
        func send(mcSession: MCSession, toPeer: MCPeerID) {
            mcSession.sendResource(at: fileURL, withName: fileIdentifier, toPeer: toPeer) {
                err in
                if err != nil {
                    logger.error("Failed to send \(fileIdentifier): \(err)")
                } else {
                    logger.info("Successfully sent \(fileIdentifier)")
                }
                if let onComplete = self.onComplete {
                    onComplete(self, err)
                }
            }
        }
        
        static func == (lhs: RestoreService.SendFile, rhs: RestoreService.SendFile) -> Bool {
            return lhs.fileURL == rhs.fileURL && lhs.fileIdentifier == rhs.fileIdentifier
        }
        
        func hash(into hasher: inout Hasher) {
                hasher.combine(fileURL)
                hasher.combine(fileIdentifier)
            }
    }
}

func parseTransferURL(_ url: URL) throws -> (peerId: MCPeerID, certificateHash: Data) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let queryItems = components.queryItems else {
        throw "Invalid url \(url)"
    }

    let queryItemsDictionary = [String: String](uniqueKeysWithValues: queryItems.compactMap { item in
        guard let value = item.value else { return nil }
        return (item.name, value)
    })

    guard let version = queryItemsDictionary["version"], qrVersion == version else {
        throw "unsupported version"
    }

    guard let mode = queryItemsDictionary["transferMode"], mode == transferMode else {
        throw "expected transfer mode to be 'primary'"
    }

    guard let base64CertificateHash = queryItemsDictionary["certificateHash"],
        let uriDecodedHash = base64CertificateHash.removingPercentEncoding,
        let certificateHash = Data(base64Encoded: uriDecodedHash) else {
            throw "failed to decode certificate hash"
    }

    guard let base64PeerId = queryItemsDictionary["peerId"],
        let uriDecodedPeerId = base64PeerId.removingPercentEncoding,
        let peerIdData = Data(base64Encoded: uriDecodedPeerId),
        let peerId = try NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: peerIdData) else {
            throw "failed to decode MCPeerId"
    }

    return (peerId, certificateHash)
}

