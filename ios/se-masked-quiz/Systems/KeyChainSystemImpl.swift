import KeychainAccess

public final class KeyChainSystemImpl: KeyChainSystem {

    private let keychain: Keychain
    // Removed accessTokenKey and refreshTokenKey private constants

    public convenience init() {
        self.init(keychain: Keychain(service: "com.example.se-masked-quiz"))
    }

    init(keychain: Keychain) {
        self.keychain = keychain
    }

    public func save(value: String, forKey key: String) async throws {
        do {
            try keychain.set(value, key: key)
        } catch {
            throw KeychainError.unknown(error)
        }
    }

    public func getString(forKey key: String) async throws -> String? {
        do {
            return try keychain.get(key)
        } catch {
            throw KeychainError.unknown(error)
        }
    }

    public func delete(key: String) async throws {
        do {
            try keychain.remove(key)
        } catch {
            throw KeychainError.unknown(error)
        }
    }

    public func deleteAll() async throws {
        do {
            // KeychainAccess provides `removeAll()` to clear items for the service.
            try keychain.removeAll()
        } catch {
            throw KeychainError.unknown(error)
        }
    }
}
