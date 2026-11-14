import SwiftUI

/// Startbildschirm: Spieler, Dauer wählen, Los!
struct HomeView: View {
    @EnvironmentObject private var profile: PlayerProfile
    @EnvironmentObject private var scores: ScoreService

    @AppStorage("selectedDuration") private var selectedDuration = 10
    @State private var path = NavigationPath()
    @State private var showProfile = false

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 10)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    playerCard
                    durationPicker
                    startButton
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Klickrausch")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.append(Route.leaderboard(selectedDuration))
                    } label: {
                        Label("Rangliste", systemImage: "trophy.fill")
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .game(let seconds):
                    GameView(duration: seconds, path: $path)
                case .leaderboard(let seconds):
                    LeaderboardView(duration: seconds)
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView(isFirstLaunch: !profile.hasName)
                    .interactiveDismissDisabled(!profile.hasName)
            }
            .onAppear {
                if !profile.hasName { showProfile = true }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 54))
                .foregroundStyle(.orange)
            Text("Klicke so schnell du kannst!")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var playerCard: some View {
        Button {
            showProfile = true
        } label: {
            HStack(spacing: 12) {
                Text(flagEmoji(for: profile.country))
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.hasName ? profile.name : "Name eingeben")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text(CountryList.localizedName(profile.country))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wie viele Sekunden?")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(GameDurations.all, id: \.self) { seconds in
                    let selected = seconds == selectedDuration
                    Button {
                        selectedDuration = seconds
                    } label: {
                        Text("\(seconds) s")
                            .font(.body.monospacedDigit().weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                selected ? Color.orange : Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            let best = profile.personalBest(for: selectedDuration)
            Text(best > 0
                 ? "Dein Rekord bei \(selectedDuration) s: \(best) Klicks"
                 : "Noch kein Rekord bei \(selectedDuration) s")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var startButton: some View {
        Button {
            if profile.hasName {
                path.append(Route.game(selectedDuration))
            } else {
                showProfile = true
            }
        } label: {
            Label("Los – \(selectedDuration) Sekunden", systemImage: "play.fill")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 18))
    }
}

enum Route: Hashable {
    case game(Int)
    case leaderboard(Int)
}
