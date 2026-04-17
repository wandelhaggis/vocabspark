import Foundation
import AVFoundation
import CryptoKit

/// Calls OpenAI TTS for pronunciation.
/// Caches audio files locally so repeated cards don't cost extra API calls.
@MainActor
class TTSService: ObservableObject {

    static let shared = TTSService()

    /// User-configured key (Keychain) takes priority, falls back to build-time config (development).
    private var apiKey: String {
        if let keychainKey = KeychainService.load(), !keychainKey.isEmpty {
            return keychainKey
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

    /// Fix #14: Rate-limit debounce — ignore taps closer than 300ms apart.
    private var lastSpeakTime: Date = .distantPast

    /// Background prefetch queue — serialized so we never fire parallel TTS requests.
    /// Independent from user-initiated `speak()` calls.
    private var prefetchChain: Task<Void, Never>?

    /// Whether the API key is configured and TTS can work.
    var isAvailable: Bool { !apiKey.isEmpty }

    /// Compute the deterministic cache file URL for a given text + language.
    private func cacheFile(for text: String, language: String) -> URL {
        let normalized = "\(language):\(text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
        let hash = SHA256.hash(data: Data(normalized.utf8))
        let hashString = hash.prefix(12).map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent("\(hashString).mp3")
    }

    /// Silent background download — caches the audio so a later `speak()` is instant.
    /// No playback, no debounce, no UI state. Fire-and-forget.
    func prefetch(_ text: String, language: String) {
        guard isAvailable else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let target = cacheFile(for: trimmed, language: language)
        // Skip if already cached — check synchronously, no need to queue
        if FileManager.default.fileExists(atPath: target.path) { return }

        let previous = prefetchChain
        prefetchChain = Task { [weak self] in
            _ = await previous?.result
            guard let self else { return }
            // Re-check in case another prefetch just finished the same file
            if FileManager.default.fileExists(atPath: target.path) { return }
            do {
                let data = try await self.fetchTTS(text: trimmed, language: language)
                try data.write(to: target)
            } catch {
                // Silent — user will see error when they tap play
            }
        }
    }

    /// Speak text in the given language. Uses cache if available.
    func speak(_ text: String, language: String = "French") async {
        guard isAvailable else { return }

        // Fix #14: Debounce rapid taps
        let now = Date()
        guard now.timeIntervalSince(lastSpeakTime) >= 0.3 else { return }
        lastSpeakTime = now

        errorMessage = nil

        let cacheFile = cacheFile(for: text, language: language)

        if FileManager.default.fileExists(atPath: cacheFile.path) {
            await playAudio(from: cacheFile)
            return
        }

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

    /// Fix #13: Cleanup oldest cache files if cache grows beyond 100 MB.
    /// Call on app launch.
    static func cleanupCacheIfNeeded() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tts_cache", isDirectory: true)
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .contentAccessDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: Array(keys)
        ) else { return }

        // Compute total size
        var totalSize: Int64 = 0
        var fileInfo: [(url: URL, size: Int64, accessed: Date)] = []
        for url in files {
            guard let values = try? url.resourceValues(forKeys: keys),
                  let size = values.totalFileAllocatedSize,
                  let accessed = values.contentAccessDate else { continue }
            totalSize += Int64(size)
            fileInfo.append((url, Int64(size), accessed))
        }

        let maxSize: Int64 = 100 * 1024 * 1024  // 100 MB
        let targetSize: Int64 = 50 * 1024 * 1024  // cleanup down to 50 MB
        guard totalSize > maxSize else { return }

        // Sort by access date ascending (oldest first)
        let sorted = fileInfo.sorted { $0.accessed < $1.accessed }
        var remaining = totalSize
        for item in sorted {
            if remaining <= targetSize { break }
            try? FileManager.default.removeItem(at: item.url)
            remaining -= item.size
        }
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
            print("\u{26A0}\u{FE0F} TTS API error (\(status)): \(errorBody)")
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
            // Fix #10: release audio session so other apps' audio resumes
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch is CancellationError {
            isPlaying = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            isPlaying = false
        }
    }

    enum TTSError: Error {
        case apiError
    }
}
