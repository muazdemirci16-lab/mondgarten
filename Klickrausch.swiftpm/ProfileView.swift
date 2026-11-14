import SwiftUI

/// Name und Land festlegen – erscheint so auf der Rangliste.
struct ProfileView: View {
    let isFirstLaunch: Bool

    @EnvironmentObject private var profile: PlayerProfile
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var country = "DE"

    private let maxNameLength = 16

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Dein Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: name) { new in
                            if new.count > maxNameLength { name = String(new.prefix(maxNameLength)) }
                        }
                } header: {
                    Text("Name")
                } footer: {
                    Text("So erscheinst du auf der Rangliste.")
                }

                Section {
                    Picker("Land", selection: $country) {
                        ForEach(CountryList.all, id: \.self) { code in
                            Text("\(flagEmoji(for: code))  \(CountryList.localizedName(code))")
                                .tag(code)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Land")
                } footer: {
                    Text("Mit Deutschland stehst du auf der Deutschland-Liste und auf der weltweiten Liste.")
                }
            }
            .navigationTitle(isFirstLaunch ? "Willkommen!" : "Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFirstLaunch {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        profile.name = trimmed
                        profile.country = country
                        dismiss()
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
            .onAppear {
                name = profile.name
                country = profile.country
            }
        }
    }
}
