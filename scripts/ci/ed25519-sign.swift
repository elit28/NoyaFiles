// Signs a file with Ed25519, the way Sparkle checks updates before installing them.
//
// Usage:
//   SPARKLE_PRIVATE_KEY=<key> xcrun swift scripts/ci/ed25519-sign.swift <file> <SUPublicEDKey>
//       Prints the base64 signature of the file. The key is the base64 encoding of a
//       32-byte Ed25519 seed, the format Sparkle's generate_keys exports. It must match
//       the public key built into the app, or installed apps would refuse the update.
//   xcrun swift scripts/ci/ed25519-sign.swift --generate
//       Prints a throwaway "private public" key pair, for tests.
import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments == ["--generate"] {
    let key = Curve25519.Signing.PrivateKey()
    print(key.rawRepresentation.base64EncodedString(), key.publicKey.rawRepresentation.base64EncodedString())
    exit(0)
}

guard arguments.count == 2 else {
    fail("usage: ed25519-sign.swift <file> <public key>, with SPARKLE_PRIVATE_KEY set")
}

let secret = (ProcessInfo.processInfo.environment["SPARKLE_PRIVATE_KEY"] ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
guard let seed = Data(base64Encoded: secret), seed.count == 32 else {
    fail("SPARKLE_PRIVATE_KEY must be the base64 encoding of a 32-byte Ed25519 key.")
}

let key: Curve25519.Signing.PrivateKey
do {
    key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
} catch {
    fail("SPARKLE_PRIVATE_KEY is not a valid Ed25519 key: \(error)")
}

let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
guard publicKey == arguments[1] else {
    fail("SPARKLE_PRIVATE_KEY does not match the app's SUPublicEDKey (\(arguments[1])); its public key is \(publicKey). Installed apps would refuse this update.")
}

let data: Data
do {
    data = try Data(contentsOf: URL(fileURLWithPath: arguments[0]), options: .mappedIfSafe)
} catch {
    fail("cannot read \(arguments[0]): \(error.localizedDescription)")
}

let signature: Data
do {
    signature = try key.signature(for: data)
} catch {
    fail("signing failed: \(error)")
}
guard key.publicKey.isValidSignature(signature, for: data) else {
    fail("the signature does not verify.")
}
print(signature.base64EncodedString())
