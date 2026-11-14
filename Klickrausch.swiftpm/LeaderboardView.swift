import SwiftUI

/// Rangliste: oben Deutschland / Weltweit, darunter eine Reihe mit 5 s, 10 s, 15 s … 100 s.
struct LeaderboardView: View {
    @EnvironmentObject private var profile: PlayerProfile
    @EnvironmentObject private var scores: ScoreService

    @State private var duration: Int
    @AppStorage("leaderboardScope") private var scopeRaw = LeaderboardScope.germany.rawValue
    @State private var entries: [ScoreEntry] = []
    @State private var note: String?
    @State private var isLoading = false

    init(duration: Int) {
        _duration = State(initialValue: duration)
    }

    private var scope: LeaderboardScope {
        LeaderboardScope(rawValue: scopeRaw) ?? .germany
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Picker("Liste", selection: $scopeRaw) {
                    ForEach(LeaderboardScope.allCases) { s in
                        Text(s.title).tag(s.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                durationRow
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)

            list
        }
        .navigationTitle("Rangliste \(duration) s")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(scopeRaw)-\(duration)") { await load() }
    }

    /// Die Reihe mit allen Zeit-Listen.
    private var durationRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GameDurations.all, id: \.self) { seconds in
                        let selected = seconds == duration
                        Button {
                            withAnimation { duration = seconds }
                        } label: {
                            Text("\(seconds) s")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selected ? Color.orange : Color(.tertiarySystemFill),
                                    in: Capsule()
                                )
                                .foregroundStyle(selected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .id(seconds)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear { proxy.scrollTo(duration, anchor: .center) }
            .onChange(of: duration) { new in
                withAnimation { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        List {
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if !scores.isOnline {
                Text("Ergebnisse von diesem Gerät")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if entries.isEmpty && !isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Noch niemand auf der \(duration)-Sekunden-Liste.")
                        .multilineTextAlignment(.center)
                    Text("Sei der Erste!")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .listRowBackground(Color.clear)
            }

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                row(rank: index + 1, entry: entry)
                    .listRowBackground(
                        entry.playerID == profile.playerID ? Color.orange.opacity(0.15) : nil
                    )
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if isLoading && entries.isEmpty { ProgressView() }
        }
        .refreshable { await load() }
    }

    private func row(rank: Int, entry: ScoreEntry) -> some View {
        HStack(spacing: 12) {
            Group {
                switch rank {
                case 1: Text("🥇")
                case 2: Text("🥈")
                case 3: Text("🥉")
                default:
                    Text("\(rank).")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .font(.title2)
            .frame(width: 40)

            Text(flagEmoji(for: entry.country))
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(String(format: "%.2f Klicks/s", entry.clicksPerSecond))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.clicks)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true
        let result = await scores.top(duration: duration, scope: scope)
        entries = result.entries
        note = result.note
        isLoading = false
    }
}
