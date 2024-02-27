//
//  SelfSigned.swift
//  Signal Backup
//
//  Created by Tjaden Hess on 2/18/24.
//

import Foundation
import Crypto
import SwiftASN1
import X509
import os

func newIdentity() throws -> SecIdentity {
    let swiftCryptoKey = P256.Signing.PrivateKey()
    let key = Certificate.PrivateKey(swiftCryptoKey)
    let subjectName = try DistinguishedName {
        CommonName("IncomingDeviceTransfer")
    }
    let issuerName = subjectName
    let now = Date()
    let extensions = try Certificate.Extensions {
        Critical(
            BasicConstraints.isCertificateAuthority(maxPathLength: nil)
        )
        Critical(
            KeyUsage(keyCertSign: true)
        )
    }
    let certificate = try Certificate(
        version: .v3,
        serialNumber: Certificate.SerialNumber(),
        publicKey: key.publicKey,
        notValidBefore: now,
        notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365),
        issuer: issuerName,
        subject: subjectName,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: extensions,
        issuerPrivateKey: key)
    
    var serializer = DER.Serializer()
    try serializer.serialize(certificate)
    let derEncodedCertificate = Data(serializer.serializedBytes)
    //let derEncodedPrivateKey = swiftCryptoKey.derRepresentation
    try deleteSelfSignedIdentityFromKeychain()
    
    let options: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                  kSecAttrKeyClass as String: kSecAttrKeyClassPrivate]
    
    var error: Unmanaged<CFError>?
    guard let secKey = SecKeyCreateWithData(swiftCryptoKey.x963Representation as CFData, options as CFDictionary, &error)
    else {throw error!.takeRetainedValue() as Error}
    
    let secCert = SecCertificateCreateWithData(nil, derEncodedCertificate as CFData)!
    do {
           let addquery: [CFString: Any] = [
               kSecClass: kSecClassCertificate,
               kSecValueRef: secCert,
               //kSecAttrAccessGroup: bundleIdentifier,
               //kSecUseDataProtectionKeychain: true,
               
               kSecAttrLabel: tmpKeyLabel
           ]
           let err = SecItemAdd(addquery as CFDictionary, nil)
           guard err == errSecSuccess else {
               logger.error("failed to add certificate to keychain: \(SecCopyErrorMessageString(err, nil))")
               throw "failed to add certificate to keychain"
           }
       }
    
    do {
        let addquery: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            //kSecUseDataProtectionKeychain: true,
            kSecValueRef: secKey,
            //kSecAttrAccessGroup: bundleIdentifier,
            kSecAttrLabel: tmpKeyLabel
        ]
        let err = SecItemAdd(addquery as CFDictionary, nil)
        guard err == errSecSuccess else {
            logger.error("failed to add private key to keychain: \(SecCopyErrorMessageString(err, nil))")
            throw "failed to add private key to keychain"
        }
    }
    
    // Fetch the composed identity from the keychain
    let identity: SecIdentity = try {
        let copyQuery: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecReturnRef: true,
            //kSecAttrAccessGroup: bundleIdentifier,
            //kSecUseDataProtectionKeychain: true,
            kSecAttrLabel: tmpKeyLabel
        ]

        var typeRef: CFTypeRef?
        let err = SecItemCopyMatching(copyQuery as CFDictionary, &typeRef)
        guard err == errSecSuccess else {
            logger.error("failed to add get identity from keychain: \(SecCopyErrorMessageString(err, nil))")
            throw "failed to fetch identity from keychain"
        }

        return (typeRef as! SecIdentity)
    }()
    
    try deleteSelfSignedIdentityFromKeychain()

    return identity
}

extension SecIdentity {
    func computeCertificateHash() throws -> Data {
        var optionalCertificate: SecCertificate?
        guard SecIdentityCopyCertificate(self, &optionalCertificate) == errSecSuccess, let certificate = optionalCertificate else {
            throw "failed to copy certificate from identity"
        }

        let certificateData = SecCertificateCopyData(certificate) as Data

        let hash = SHA256.hash(data: certificateData)
        
        return Data(hash)
    }
}


