import Foundation
import SwiftUI

/// Alle wählbaren Spieldauern: 5, 10, 15 … 100 Sekunden.
enum GameDurations {
    static let all: [Int] = Array(stride(from: 5, through: 100, by: 5))
}

/// Ein Eintrag auf der Rangliste (bestes Ergebnis eines Spielers für eine Dauer).
struct ScoreEntry: Identifiable, Codable, Hashable {
    var playerID: String
    var name: String
    var country: String      // ISO-Ländercode, z. B. "DE"
    var duration: Int        // Sekunden
    var clicks: Int
    var date: Date = Date()

    var id: String { "\(playerID)-\(duration)" }

    var clicksPerSecond: Double {
        Double(clicks) / Double(max(duration, 1))
    }
}

/// Welche Liste angezeigt wird.
enum LeaderboardScope: String, CaseIterable, Identifiable {
    case germany
    case world

    var id: String { rawValue }

    var title: String {
        switch self {
        case .germany: return "🇩🇪 Deutschland"
        case .world:   return "🌍 Weltweit"
        }
    }

    /// Ländercode-Filter für die Abfrage (nil = alle Länder).
    var countryFilter: String? {
        switch self {
        case .germany: return "DE"
        case .world:   return nil
        }
    }
}

/// Wandelt einen Ländercode ("DE") in eine Flagge ("🇩🇪") um.
func flagEmoji(for countryCode: String) -> String {
    let base: UInt32 = 127397
    var flag = ""
    for scalar in countryCode.uppercased().unicodeScalars {
        guard let s = UnicodeScalar(base + scalar.value) else { return "🏳️" }
        flag.unicodeScalars.append(s)
    }
    return flag.isEmpty ? "🏳️" : flag
}

/// Name, Land und eine feste Spieler-ID – dauerhaft auf dem Gerät gespeichert.
@MainActor
final class PlayerProfile: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var name: String {
        didSet { defaults.set(name, forKey: "player.name") }
    }
    @Published var country: String {
        didSet { defaults.set(country, forKey: "player.country") }
    }
    let playerID: String

    var hasName: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    init() {
        if let id = defaults.string(forKey: "player.id") {
            playerID = id
        } else {
            let id = UUID().uuidString
            defaults.set(id, forKey: "player.id")
            playerID = id
        }
        name = defaults.string(forKey: "player.name") ?? ""
        country = defaults.string(forKey: "player.country")
            ?? Locale.current.region?.identifier
            ?? "DE"
    }

    // MARK: Persönliche Bestwerte (immer lokal)

    func personalBest(for duration: Int) -> Int {
        defaults.integer(forKey: "best.\(duration)")
    }

    /// Speichert den Wert, falls er besser ist. Gibt `true` zurück bei neuem Rekord.
    @discardableResult
    func recordIfBest(_ clicks: Int, duration: Int) -> Bool {
        guard clicks > personalBest(for: duration) else { return false }
        defaults.set(clicks, forKey: "best.\(duration)")
        objectWillChange.send()
        return true
    }
}

/// Länderliste für die Auswahl – Deutschland, Österreich, Schweiz zuerst.
enum CountryList {
    static let pinned = ["DE", "AT", "CH"]

    static let all: [String] = {
        let others = Locale.isoRegionCodes
            .filter { !pinned.contains($0) && $0.count == 2 }
            .sorted { localizedName($0) < localizedName($1) }
        return pinned + others
    }()

    static func localizedName(_ code: String) -> String {
        Locale(identifier: "de_DE").localizedString(forRegionCode: code) ?? code
    }
}
