import SwiftUI

struct ContentView: View {
    let deck: LanguageDeck
    let onSwitchLanguage: () -> Void

    @State private var selectedTab = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    private var isKeyConfigured: Bool {
        if let keychainKey = KeychainService.load(), !keychainKey.isEmpty { return true }
        if let plistKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String, !plistKey.isEmpty { return true }
        return false
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionSetupView(deck: deck)
                .tabItem {
                    Label("Lernen", systemImage: "brain.head.profile")
                }
                .tag(0)

            VocabListView(deck: deck, onSwitchLanguage: onSwitchLanguage)
                .tabItem {
                    Label("Vokabeln", systemImage: "list.bullet")
                }
                .tag(1)

            SettingsView(deck: deck)
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(.indigo)
        .onAppear {
            if !hasSeenOnboarding && !isKeyConfigured {
                showOnboarding = true
            }
        }
        .alert("Willkommen bei VocabSpark!", isPresented: $showOnboarding) {
            Button("Zu den Einstellungen") {
                hasSeenOnboarding = true
                selectedTab = 2
            }
            Button("Sp\u{E4}ter") {
                hasSeenOnboarding = true
            }
        } message: {
            Text("F\u{FC}r Aussprache und Beispiels\u{E4}tze brauchst du einen OpenAI API-Key. Du kannst ihn in den Einstellungen eingeben.")
        }
    }
}
