import SwiftUI
import SwiftData
import Charts

/// Dual chart card with flip animation.
/// Tap to switch between "Bekannt im Zeitverlauf" and "Aktivität pro Tag".
struct ProgressChartView: View {
    let deck: LanguageDeck

    @Query private var allEvents: [MasteryEvent]
    @Query(sort: \SessionRecord.date, order: .forward) private var allSessions: [SessionRecord]

    @State private var isFlipped = false

    private let daysWindow = 30

    // MARK: - Data Points

    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Int
    }

    /// Events filtered to the current deck.
    private var deckEvents: [MasteryEvent] {
        allEvents.filter { $0.deck?.id == deck.id }
    }

    /// Chart A: cumulative "Bekannt" count over the last 30 days.
    private var masteryOverTime: [DataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(daysWindow - 1), to: today) else { return [] }

        // Initial count: events BEFORE startDate that reached .bekannt state
        var currentCount = 0
        for event in deckEvents where event.date < startDate {
            if event.toCategory == .bekannt { currentCount += 1 }
            if event.fromCategory == .bekannt { currentCount -= 1 }
        }

        // Walk through days, applying events per day
        var points: [DataPoint] = []
        for dayOffset in 0..<daysWindow {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let todaysEvents = deckEvents.filter { $0.date >= day && $0.date < nextDay }
            for event in todaysEvents {
                if event.toCategory == .bekannt { currentCount += 1 }
                if event.fromCategory == .bekannt { currentCount -= 1 }
            }
            points.append(DataPoint(date: day, value: max(0, currentCount)))
        }
        return points
    }

    /// Chart B: learned ("Gewusst!") cards per day over the last 30 days.
    private var activityPerDay: [DataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(daysWindow - 1), to: today) else { return [] }

        var points: [DataPoint] = []
        for dayOffset in 0..<daysWindow {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayGood = allSessions
                .filter { $0.date >= day && $0.date < nextDay }
                .reduce(0) { $0 + $1.goodCount }
            points.append(DataPoint(date: day, value: dayGood))
        }
        return points
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            frontChart
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            backChart
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .animation(.spring(duration: 0.6), value: isFlipped)
        .onTapGesture {
            HapticService.light()
            isFlipped.toggle()
        }
    }

    // MARK: - Front: Mastery Over Time

    private var frontChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Bekannt im Verlauf", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.green)
                Spacer()
                Text("30 Tage")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.2.squarepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Chart(masteryOverTime) { point in
                AreaMark(
                    x: .value("Tag", point.date),
                    y: .value("Bekannt", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green.opacity(0.4), .green.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Tag", point.date),
                    y: .value("Bekannt", point.value)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: false)
                }
            }
            .frame(height: 140)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Back: Activity Per Day

    private var backChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Gelernt pro Tag", systemImage: "flame.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.orange)
                Spacer()
                Text("30 Tage")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.2.squarepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Chart(activityPerDay) { point in
                BarMark(
                    x: .value("Tag", point.date, unit: .day),
                    y: .value("Gewusst", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: false)
                }
            }
            .frame(height: 140)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
