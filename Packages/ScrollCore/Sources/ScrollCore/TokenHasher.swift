import Foundation
import Crypto

/// Stable device-local identifier for an opaque ApplicationToken.
/// The app layer encodes the token (JSONEncoder) and passes the bytes here;
/// ScrollCore never sees FamilyControls types.
public enum TokenHasher {
    /// First 8 bytes of SHA256 over the encoded token, as 16 lowercase hex chars.
    public static func hash(encodedToken: Data) -> String {
        let digest = SHA256.hash(data: encodedToken)
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
