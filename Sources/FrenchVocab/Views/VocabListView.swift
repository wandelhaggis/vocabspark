import SwiftUI
import SwiftData

enum TimeFilter: String, CaseIterable {
    case all
    case today
    case thisWeek
    case thisMonth

    var displayName: String {
        switch self {
        case .all:       return String(localized: "Alle", comment: "Time filter: all vocab")
        case .today:     return String(localized: "Heute", comment: "Time filter: today only")
        case .thisWeek:  return String(localized: "Diese Woche", comment: "Time filter: this week")
        case .thisMonth: return String(localized: "Dieser Monat", comment: "Time filter: this month")
        }
    }
}

struct VocabListView: View {
    let deck: LanguageDeck
    let onSwitchLanguage: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabItem.createdAt, order: .reverse) private var items: [VocabItem]

    @State private var showingAdd = false
    @State private var editingItem: VocabItem?
    @State private var searchText = ""
    @State private var timeFilter: TimeFilter = .all

    // Test mode
    @State private var isTestMode = false
    @State private var selectedForTest: Set<UUID> = []
    @State private var testDirection: LearningDirection = .random
    @State private var isTestActive = false

    /// Items belonging to the current deck.
    var deckItems: [VocabItem] {
        items.filter { $0.deck?.id == deck.id }
    }

    var timeFilteredItems: [VocabItem] {
        guard timeFilter != .all else { return deckItems }
        let calendar = Calendar.current
        let now = Date()
        let cutoff: Date
        switch timeFilter {
        case .all: cutoff = .distantPast
        case .today: cutoff = calendar.startOfDay(for: now)
        case .thisWeek: cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .thisMonth: cutoff = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        }
        return deckItems.filter { $0.createdAt >= cutoff }
    }

    var filteredItems: [VocabItem] {
        let base = timeFilteredItems
        if searchText.isEmpty { return base }
        return base.filter {
            $0.term.localizedCaseInsensitiveContains(searchText) ||
            $0.translation.localizedCaseInsensitiveContains(searchText)
        }
    }

    var dueCount: Int {
        deckItems.filter { $0.isDue }.count
    }

    var selectedItems: [VocabItem] {
        deckItems.filter { selectedForTest.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if deckItems.isEmpty {
                    emptyState
                } else {
                    vocabList
                }
            }
            .navigationTitle(isTestMode
                             ? String(localized: "Vokabeltest")
                             : String(localized: "VocabSpark"))
            .toolbar {
                if isTestMode {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            withAnimation { isTestMode = false }
                            selectedForTest.removeAll()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        // Fix #21: operate on filteredItems, not deckItems, so "Alle" matches
                        // what the user actually sees (after search + time filter).
                        let visibleIDs = Set(filteredItems.map(\.id))
                        let allVisibleSelected = !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedForTest)
                        Button(LocalizedStringKey(allVisibleSelected ? "Keine" : "Alle")) {
                            if allVisibleSelected {
                                selectedForTest.subtract(visibleIDs)
                            } else {
                                selectedForTest.formUnion(visibleIDs)
                            }
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onSwitchLanguage()
                        } label: {
                            HStack(spacing: 4) {
                                Text(deck.emoji)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 16) {
                            if !deckItems.isEmpty {
                                Button {
                                    withAnimation { isTestMode = true }
                                } label: {
                                    Image(systemName: "pencil.and.list.clipboard")
                                        .font(.title3)
                                }
                            }
                            Button {
                                showingAdd = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isTestMode {
                    testBottomBar
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddVocabView(deck: deck)
            }
            .sheet(item: $editingItem) { item in
                EditVocabView(item: item, deck: deck)
            }
            .fullScreenCover(isPresented: $isTestActive) {
                VocabTestSessionView(
                    items: selectedItems.shuffled(),
                    direction: testDirection,
                    deck: deck
                )
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(deck.emoji)
                .font(.system(size: 80))
            Text("Noch keine Vokabeln")
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            Text("Tippe auf + um loszulegen!")
                .foregroundStyle(.secondary)

            Button {
                showingAdd = true
            } label: {
                Label("Erste Vokabel hinzuf\u{FC}gen", systemImage: "plus")
                    .font(.headline)
                    .fontDesign(.rounded)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.indigo.gradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Vocab List

    @ViewBuilder
    private var vocabList: some View {
        List {
            if !isTestMode && dueCount > 0 {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text("\(dueCount) Karten f\u{E4}llig")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                    }
                    .padding(.vertical, 4)
                }
            }

            if !isTestMode {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TimeFilter.allCases, id: \.self) { filter in
                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        timeFilter = filter
                                    }
                                } label: {
                                    Text(filter.displayName)
                                        .font(.subheadline)
                                        .fontWeight(timeFilter == filter ? .semibold : .regular)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(timeFilter == filter ? Color.indigo : Color(.systemGray5))
                                        .foregroundStyle(timeFilter == filter ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            Section(isTestMode
                    ? String(localized: "Vokabeln ausw\u{E4}hlen")
                    : "\(timeFilter == .all ? String(localized: "Alle Vokabeln") : timeFilter.displayName) (\(filteredItems.count))") {
                ForEach(filteredItems) { item in
                    if isTestMode {
                        testRow(item: item)
                    } else {
                        Button {
                            editingItem = item
                        } label: {
                            VocabRowView(item: item)
                        }
                        .tint(.primary)
                        // Long-press → play TTS without leaving the list
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    guard TTSService.shared.isAvailable else { return }
                                    HapticService.medium()
                                    Task { await TTSService.shared.speak(item.term, language: deck.ttsLanguage) }
                                }
                        )
                    }
                }
                .onDelete(perform: isTestMode ? nil : deleteItems)
            }
        }
        .searchable(text: $searchText, prompt: "Suchen...")
    }

    // MARK: - Test Mode Row

    @ViewBuilder
    private func testRow(item: VocabItem) -> some View {
        let isSelected = selectedForTest.contains(item.id)
        Button {
            if isSelected {
                selectedForTest.remove(item.id)
            } else {
                selectedForTest.insert(item.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .indigo : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.term)
                        .font(.body)
                        .fontWeight(.semibold)
                    Text(item.translation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .tint(.primary)
    }

    // MARK: - Test Bottom Bar

    @ViewBuilder
    private var testBottomBar: some View {
        VStack(spacing: 12) {
            Divider()

            // Direction picker
            HStack(spacing: 8) {
                ForEach(LearningDirection.allCases, id: \.self) { dir in
                    Button {
                        testDirection = dir
                    } label: {
                        Text(dir.icon)
                            .font(.caption)
                            .fontWeight(testDirection == dir ? .bold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(testDirection == dir ? Color.indigo : Color(.systemGray5))
                            .foregroundStyle(testDirection == dir ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }

            // Start button
            Button {
                isTestActive = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.list.clipboard")
                    Text("\(selectedForTest.count) Vokabeln testen")
                }
                .font(.headline)
                .fontDesign(.rounded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selectedForTest.isEmpty
                    ? AnyShapeStyle(Color.gray)
                    : AnyShapeStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selectedForTest.isEmpty)
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredItems[index])
        }
    }
}

// MARK: - Row View

struct VocabRowView: View {
    let item: VocabItem
    @ObservedObject private var exampleService = ExampleSentenceService.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.term)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(item.translation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if exampleService.loadingItemIDs.contains(item.id) {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    Text(item.statusLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.15))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())
                }
                if item.isDue {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch item.category {
        case .neu: return .indigo
        case .lernen: return .orange
        case .festigen: return .yellow
        case .bekannt: return .green
        }
    }
}
