import Foundation
import AVFoundation
import CryptoKit

/// Calls OpenAI TTS for French pronunciation.
/// Caches audio files locally so repeated cards don't cost extra API calls.
@MainActor
class TTSService: ObservableObject {

    static let shared = TTSService()

    /// User-configured key (Settings) takes priority, falls back to build-time config (development).
    private var apiKey: String {
        if let userKey = UserDefaults.standard.string(forKey: "openai_api_key"), !userKey.isEmpty {
            return userKey
        }
        return Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String ?? ""
    }

    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tts_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var player: AVAudioPlayer?

    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Whether the API key is configured and TTS can work.
    var isAvailable: Bool { !apiKey.isEmpty }

    /// Speak text in the given language. Uses cache if available.
    func speak(_ text: String, language: String = "French") async {
        guard isAvailable else { return }

        errorMessage = nil

        // Deterministic cache key using SHA256 (stable across app launches)
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: Data(normalized.utf8))
        let hashString = hash.prefix(12).map { String(format: "%02x", $0) }.joined()
        let cacheFile = cacheDir.appendingPathComponent("\(hashString).mp3")

        // Check cache first
        if FileManager.default.fileExists(atPath: cacheFile.path) {
            await playAudio(from: cacheFile)
            return
        }

        // Fetch from OpenAI
        isLoading = true
        defer { isLoading = false }

        do {
            let audioData = try await fetchTTS(text: text, language: language)
            try audioData.write(to: cacheFile)
            await playAudio(from: cacheFile)
        } catch is CancellationError {
            // Task was cancelled, ignore silently
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost || urlError.code == .timedOut {
            errorMessage = "Keine Internetverbindung"
        } catch {
            errorMessage = "Aussprache nicht verfügbar"
        }
    }

    /// Stop any playing audio immediately.
    func stop() {
        player?.stop()
        isPlaying = false
        isLoading = false
    }

    private func fetchTTS(text: String, language: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini-tts",
            "input": text,
            "voice": "coral",
            "response_format": "mp3",
            "instructions": "Speak in natural, clear \(language). Pronounce slowly and clearly \u{2014} this is for a language learner."
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("⚠️ TTS API error (\(status)): \(errorBody)")
            throw TTSError.apiError
        }
        return data
    }

    private func playAudio(from url: URL) async {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            isPlaying = true
            player?.play()
            if let duration = player?.duration, duration > 0 {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            }
            isPlaying = false
        } catch is CancellationError {
            isPlaying = false
        } catch {
            isPlaying = false
        }
    }

    enum TTSError: Error {
        case apiError
    }
}
