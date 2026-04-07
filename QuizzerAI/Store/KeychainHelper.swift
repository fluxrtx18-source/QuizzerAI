import Foundation
import Security

/// Lightweight Keychain wrapper for small integer/string values.
/// Used for the free-card counter so it survives app reinstalls and
/// resists casual manipulation via UserDefaults editors.
enum KeychainHelper {

    // MARK: - Integer

    /// Stores as fixed-width Int32 (4 bytes) regardless of platform pointer size.
    /// Ensures Keychain data is portable if Apple ever ships a new architecture.
    static func getInt(forKey key: String) -> Int? {
        guard let data = getData(forKey: key) else { return nil }
        guard data.count == MemoryLayout<Int32>.size else { return nil }
        let i32 = data.withUnsafeBytes { $0.load(as: Int32.self) }
        return Int(i32)
    }

    static func setInt(_ value: Int, forKey key: String) {
        var v = Int32(clamping: value)
        let data = Data(bytes: &v, count: MemoryLayout<Int32>.size)
        setData(data, forKey: key)
    }

    // MARK: - Raw Data (private)

    private static func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func setData(_ data: Data, forKey key: String) {
        // Try update first — faster than delete+add when the item exists.
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
