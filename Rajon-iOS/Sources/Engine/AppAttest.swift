import Foundation
import DeviceCheck
import CryptoKit

/// Apple App Attest sarmalayıcı — yalnızca GERÇEK Apple cihazındaki GERÇEK (değiştirilmemiş)
/// uygulama örneği API'ye erişebilsin. Secure Enclave anahtarı + Apple imzalı attestation.
/// Entitlement GEREKMEZ; TestFlight/App Store buildleri "production" ortamıyla attest eder.
enum AppAttest {
    private static var svc: DCAppAttestService { DCAppAttestService.shared }
    private static let kKeyId = "rajon_attest_keyid"
    private static let kDone = "rajon_attest_done"

    static var destekli: Bool { svc.isSupported }

    static var keyId: String? {
        get { UserDefaults.standard.string(forKey: kKeyId) }
        set { UserDefaults.standard.setValue(newValue, forKey: kKeyId) }
    }
    /// Bu anahtar bir kez attest edildi mi (sonrası assertion ile yenilenir).
    static var attestEdildi: Bool {
        get { UserDefaults.standard.bool(forKey: kDone) }
        set { UserDefaults.standard.set(newValue, forKey: kDone) }
    }

    /// keyId üret (yoksa) — Secure Enclave.
    static func anahtarSagla() async throws -> String {
        if let k = keyId { return k }
        let k = try await svc.generateKey()
        keyId = k
        return k
    }

    /// İlk attestation (sunucu challenge'ı ile).
    static func attest(challenge: Data) async throws -> (keyId: String, attestation: Data) {
        let k = try await anahtarSagla()
        let hash = Data(SHA256.hash(data: challenge))
        let att = try await svc.attestKey(k, clientDataHash: hash)
        return (k, att)
    }

    /// Yenileme: attest edilmiş anahtarla assertion.
    static func assert(challenge: Data) async throws -> (keyId: String, assertion: Data) {
        let k = try await anahtarSagla()
        let hash = Data(SHA256.hash(data: challenge))
        let a = try await svc.generateAssertion(k, clientDataHash: hash)
        return (k, a)
    }

    /// Anahtar geçersizleşirse (uygulama silinip yüklenince) sıfırla → yeniden attest.
    static func sifirla() {
        UserDefaults.standard.removeObject(forKey: kKeyId)
        UserDefaults.standard.set(false, forKey: kDone)
    }
}
