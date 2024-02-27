//
//  QRGenerator.swift
//  Signal Backup
//
//  Created by Tjaden Hess on 2/25/24.
//

import Foundation
import MultipeerConnectivity
import SwiftUI

func generateQRCode(peerId: MCPeerID, identity: SecIdentity) throws -> Image {
    var components = URLComponents()
    components.scheme = qrScheme
    components.host = qrHost
    guard let base64CertificateHash = try identity.computeCertificateHash().base64EncodedString().encodeURIComponent else {
        throw "failed to get base64 certificate hash"
    }
    
    guard let base64PeerId = try NSKeyedArchiver.archivedData(withRootObject: ourID, requiringSecureCoding: true).base64EncodedString().encodeURIComponent else {
        throw "failed to get base64 peerId"
    }

    let queryItems = [
        "version": qrVersion,
        "transferMode": transferMode,
        "certificateHash": base64CertificateHash,
        "peerId": base64PeerId
    ]

    components.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }

    logger.debug("URL: \(components.url!.absoluteString)")

    return qrImage(from: components.url!.absoluteString)
}

func qrImage(from string: String) -> Image {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    
    let outputImage = filter.outputImage!
    let cgimg = context.createCGImage(outputImage, from: outputImage.extent)
   
    return Image(cgimg!, scale: 1, label: Text("QR Image"))
}
