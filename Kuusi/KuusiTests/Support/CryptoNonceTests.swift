import Testing
@testable import Kuusi

struct CryptoNonceTests {
    private let allowedCharacters = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    @Test
    func randomNonceUsesRequestedLength() {
        let nonce = CryptoNonce.randomNonceString(length: 32)

        #expect(nonce.count == 32)
    }

    @Test
    func randomNonceUsesOnlyAllowedCharacters() {
        let nonce = CryptoNonce.randomNonceString(length: 128)

        #expect(Set(nonce).isSubset(of: allowedCharacters))
    }

    @Test
    func randomNonceReturnsEmptyStringForZeroLength() {
        let nonce = CryptoNonce.randomNonceString(length: 0)

        #expect(nonce.isEmpty)
    }

    @Test
    func sha256ReturnsKnownDigest() {
        let digest = CryptoNonce.sha256("hello")

        #expect(digest == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }
}
