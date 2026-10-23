import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Make yourself at home") {
                    Toggle("Sound", isOn: Binding(get: { !store.muted }, set: { store.muted = !$0 }))
                    Toggle("Haptics", isOn: $store.haptics)
                    Button("Your records") { store.sheet = .records }
                }
                Section("The breakfast brief") {
                    Label("Choose a difficulty. Harder modes earn more points.", systemImage: "dial.low")
                    Label("Drag the toaster lever down, or tap Pull to Start.", systemImage: "arrow.down")
                    Label("Listen to the ticks and watch the heat. Tap the toaster or Stop Toaster just before it pops.", systemImage: "hand.tap")
                    Label("A perfect save is less than 0.15 seconds before the pop. Burnt toast ends your run.", systemImage: "sparkles")
                    Label("Every attempt earns XP. Unlock eight toast finishes, then equip your favorite in the collection.", systemImage: "square.grid.2x2")
                }.font(.subheadline)
                Section {
                    Text("Your progress is saved on this device. Rounds pause when the app leaves the foreground. Sound follows your iPhone’s silent switch.")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
            }
            .scrollContentBackground(.hidden).background(Palette.cream)
            .navigationTitle("A little setup").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(Palette.copper)
    }
}

struct RecordsView: View {
    @ObservedObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Best run", value: "\(store.game.records.best)")
                LabeledContent("Longest streak", value: "\(store.game.records.bestStreak)")
                LabeledContent("Perfect saves", value: "\(store.game.records.perfects)")
                LabeledContent("Slices saved", value: "\(store.game.progression.saves)")
                LabeledContent("Total XP", value: "\(store.game.progression.xp)")
            }
            .scrollContentBackground(.hidden).background(Palette.cream)
            .navigationTitle("Breakfast bests").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(Palette.copper)
    }
}
