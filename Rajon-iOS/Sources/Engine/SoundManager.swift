import AVFoundation
import SwiftUI

/// Basit ses efekti çalar. WAV'lar Sources/Sounds altında bundle'a girer.
@MainActor
final class SoundManager: ObservableObject {
    static let shared = SoundManager()

    @Published var acik: Bool {
        didSet { UserDefaults.standard.set(acik, forKey: "rajon_ses") }
    }

    private var players: [String: AVAudioPlayer] = [:]

    enum SFX: String { case punch, gun, coin, win }

    init() {
        // Varsayılan açık
        if UserDefaults.standard.object(forKey: "rajon_ses") == nil {
            UserDefaults.standard.set(true, forKey: "rajon_ses")
        }
        acik = UserDefaults.standard.bool(forKey: "rajon_ses")
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for s in ["punch", "gun", "coin", "win"] { preload(s) }
    }

    private func preload(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        if let p = try? AVAudioPlayer(contentsOf: url) {
            p.prepareToPlay()
            players[name] = p
        }
    }

    func cal(_ sfx: SFX, volume: Float = 0.7) {
        guard acik, let p = players[sfx.rawValue] else { return }
        p.volume = volume
        p.currentTime = 0
        p.play()
    }
}
