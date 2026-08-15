#!/usr/bin/env swift
import Foundation
import CryptoKit

let args = CommandLine.arguments
guard args.count > 1 else {
    print("Usage: ./scripts/generate_key.swift <customer_email>")
    print("Example: ./scripts/generate_key.swift customer@gmail.com")
    exit(1)
}

let email = args[1].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
let secretSalt = "IvorsProMac2026#SecureHMACKey"

let keyData = Data(secretSalt.utf8)
let msgData = Data(email.utf8)

let hmac = HMAC<SHA256>.authenticationCode(for: msgData, using: SymmetricKey(data: keyData))
let hex = hmac.map { String(format: "%02X", $0) }.joined()

let p1 = String(hex.prefix(4))
let p2 = String(hex.dropFirst(4).prefix(4))
let p3 = String(hex.dropFirst(8).prefix(4))

let licenseKey = "IVORS-PRO-\(p1)-\(p2)-\(p3)"

print("🔑 Ivors Pro License Generator")
print("Customer Email : \(email)")
print("License Key    : \(licenseKey)")
