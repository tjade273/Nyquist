//
//  RestoreService.swift
//  Signal Backup
//
//  Created by Tjaden Hess on 2/25/24.
//
/*
import Foundation
import MultipeerConnectivity

class RestoreService: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate
{
    var mcSession: MCSession
    var browser: MCNearbyServiceBrowser
    var identity: SecIdentity // TODO: do we even need this? TODO: var vs let?
    var srcFolder: URL
    var manifest: DeviceTransferProtoManifest?
    
    override init() {
        do { self.identity = try newIdentity() } catch { logger.error("Failed to create new identity") }
        browser = MCNearbyServiceBrowser(peer: ourID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }
    
    func transferData(url: URL) {
        let components = url.pathComponents;
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        <#code#>
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        <#code#>
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        <#code#>
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        <#code#>
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        <#code#>
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        logger.log("Invite from peer \(foundPeer)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer: MCPeerID) {
        logger.log("Lost peer \(lostPeer)")
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
*/
