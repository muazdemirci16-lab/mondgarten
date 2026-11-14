import SwiftUI
import UIKit

/// Spiellogik: erster Klick = 1 und startet die Zeit.
@MainActor
final class ClickGame: ObservableObject {
    enum Phase { case ready, running, finished }

    let duration: Int
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var clicks = 0
    @Published private(set) var remaining: Double

    private var endDate: Date?
    private var timer: Timer?

    nonisolated init(duration: Int) {
        self.duration = duration
        self.remaining = Double(duration)
    }

    var clicksPerSecond: Double {
        let elapsed = Double(duration) - remaining
        guard elapsed > 0.2 else { return 0 }
        return Double(clicks) / elapsed
    }

    func tap() {
        switch phase {
        case .ready:
            start()
            clicks = 1
        case .running:
            // Klicks nach Ablauf zählen nicht – auch wenn der Timer noch nicht getickt hat.
            if let endDate, Date() < endDate {
                clicks += 1
            } else {
                finish()
            }
        case .finished:
            break
        }
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        clicks = 0
        remaining = Double(duration)
        phase = .ready
    }

    private func start() {
        phase = .running
        endDate = Date().addingTimeInterval(Double(duration))
        let t = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard let endDate, phase == .running else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 { finish() }
    }

    private func finish() {
        guard phase == .running else { return }
        timer?.invalidate()
        timer = nil
        remaining = 0
        phase = .finished
    }

    deinit { timer?.invalidate() }
}

/// Der Spielbildschirm mit großem Klick-Knopf.
struct GameView: View {
    let duration: Int
    @Binding var path: NavigationPath

    @EnvironmentObject private var profile: PlayerProfile
    @EnvironmentObject private var scores: ScoreService
    @StateObject private var game: ClickGame

    @State private var isNewRecord = false
    @State private var submitNote: String?
    @State private var showResult = false

    private let haptics = UIImpactFeedbackGenerator(style: .light)

    init(duration: Int, path: Binding<NavigationPath>) {
        self.duration = duration
        self._path = path
        self._game = StateObject(wrappedValue: ClickGame(duration: duration))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 16) {
                stats
                clickButton
                Text(hint)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .padding()

            if showResult {
                resultOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationTitle("\(duration) Sekunden")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(game.phase == .running)
        .onAppear { haptics.prepare() }
        .onChange(of: game.phase) { phase in
            if phase == .finished { finishGame() }
        }
    }

    // MARK: Teile

    private var stats: some View {
        HStack {
            statBox(title: "Zeit", value: String(format: "%.1f", game.remaining), unit: "s",
                    color: game.remaining < 3 && game.phase == .running ? .red : .primary)
            statBox(title: "Klicks", value: "\(game.clicks)", unit: "", color: .orange)
            statBox(title: "Tempo", value: String(format: "%.1f", game.clicksPerSecond), unit: "/s",
                    color: .primary)
        }
    }

    private func statBox(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var clickButton: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.9
            Button {
                guard game.phase != .finished else { return }
                game.tap()
                haptics.impactOccurred()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(colors: [.yellow, .orange, .red],
                                           center: .center, startRadius: 10, endRadius: size / 1.6)
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 20)
                    Text(game.phase == .ready ? "TIPP!" : "\(game.clicks)")
                        .font(.system(size: size / 4, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                        .padding(size / 8)
                }
                .frame(width: size, height: size)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(game.phase == .finished)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var hint: String {
        switch game.phase {
        case .ready:    return "Erster Tipp startet die Zeit"
        case .running:  return "Schneller! Schneller!"
        case .finished: return "Zeit vorbei!"
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(isNewRecord ? "🏆 Neuer Rekord!" : "Zeit vorbei!")
                    .font(.title.bold())
                Text("\(game.clicks)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(.orange)
                Text("Klicks in \(duration) Sekunden")
                    .font(.headline)
                Text(String(format: "%.2f Klicks pro Sekunde", Double(game.clicks) / Double(duration)))
                    .foregroundStyle(.secondary)
                if let submitNote {
                    Text(submitNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button {
                        withAnimation { showResult = false }
                        game.reset()
                    } label: {
                        Label("Nochmal", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        path.removeLast()
                        path.append(Route.leaderboard(duration))
                    } label: {
                        Label("Rangliste ansehen", systemImage: "trophy")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)

                    Button("Andere Zeit wählen") {
                        path.removeLast()
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding()
        }
    }

    // MARK: Ende

    private func finishGame() {
        let clicks = game.clicks
        isNewRecord = profile.recordIfBest(clicks, duration: duration)
        submitNote = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Kurze Pause, damit ein letzter schneller Tipp nicht aus Versehen einen Knopf trifft.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showResult = true }
        }

        let entry = ScoreEntry(
            playerID: profile.playerID,
            name: profile.name.trimmingCharacters(in: .whitespaces),
            country: profile.country,
            duration: duration,
            clicks: clicks
        )
        Task {
            submitNote = await scores.submit(entry)
        }
    }
}

/// Knopf schrumpft kurz beim Drücken.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
    }
}
