import Foundation

@MainActor
class StreakManager: ObservableObject {

    static let shared = StreakManager()

    private let defaults = UserDefaults.standard
    private let streakKey = "currentStreak"
    private let lastDateKey = "lastLearningDate"
    private let longestStreakKey = "longestStreak"

    @Published var currentStreak: Int
    @Published var longestStreak: Int

    private init() {
        currentStreak = defaults.integer(forKey: streakKey)
        longestStreak = defaults.integer(forKey: longestStreakKey)
    }

    /// Call when a learning session is completed.
    func recordSession() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = defaults.object(forKey: lastDateKey) as? Date {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 0 {
                return // already learned today
            } else if daysDiff == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        defaults.set(today, forKey: lastDateKey)
        defaults.set(currentStreak, forKey: streakKey)
        defaults.set(longestStreak, forKey: longestStreakKey)
    }

    /// Call on view appear to detect broken streaks (more than 1 day since last session).
    func refreshStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastDate = defaults.object(forKey: lastDateKey) as? Date else {
            currentStreak = 0
            return
        }

        let lastDay = calendar.startOfDay(for: lastDate)
        let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if daysDiff > 1 {
            currentStreak = 0
            defaults.set(0, forKey: streakKey)
        }
    }
}
