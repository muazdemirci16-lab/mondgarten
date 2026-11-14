import Foundation
import CloudKit

// MARK: - Einstellungen für die Online-Rangliste

/// Online-Rangliste über Apples CloudKit (öffentliche Datenbank).
///
/// Damit Deutschland- und Weltliste über alle Geräte hinweg funktionieren:
/// 1. Projekt in Xcode öffnen, Team auswählen.
/// 2. Capability „iCloud“ → „CloudKit“ aktivieren und einen Container anlegen,
///    z. B. `iCloud.com.example.klickrausch`.
/// 3. Den Container-Namen unten bei `containerIdentifier` eintragen.
/// 4. Im CloudKit-Dashboard für den Record-Typ `Score` die Felder
///    `duration` und `country` als „Queryable“ und `clicks` als „Sortable“ indizieren.
///
/// Solange `containerIdentifier` `nil` ist, läuft die Rangliste lokal auf diesem Gerät
/// (alle, die auf diesem iPhone/iPad spielen, erscheinen darauf).
enum OnlineConfig {
    static let containerIdentifier: String? = nil
}

/// Schutz gegen unrealistische Werte (Menschen schaffen kaum mehr als ~20 Klicks/s).
enum AntiCheat {
    static let maxClicksPerSecond = 25

    static func isPlausible(clicks: Int, duration: Int) -> Bool {
        clicks > 0 && clicks <= duration * maxClicksPerSecond
    }
}

// MARK: - Backend-Schnittstelle

protocol ScoreBackend {
    /// Speichert das Ergebnis, falls es besser ist als der bisherige Eintrag des Spielers.
    func submit(_ entry: ScoreEntry) async throws
    /// Die besten Einträge für eine Dauer, optional gefiltert nach Land.
    func top(duration: Int, country: String?, limit: Int) async throws -> [ScoreEntry]
}

// MARK: - Lokale Rangliste (UserDefaults)

final class LocalScoreBackend: ScoreBackend {
    private let key = "local.leaderboard.v1"
    private let defaults = UserDefaults.standard

    private func load() -> [ScoreEntry] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([ScoreEntry].self, from: data) else { return [] }
        return list
    }

    private func save(_ list: [ScoreEntry]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
    }

    func submit(_ entry: ScoreEntry) async throws {
        var list = load()
        if let index = list.firstIndex(where: { $0.id == entry.id }) {
            // Name/Land immer aktualisieren, Klicks nur wenn besser.
            list[index].name = entry.name
            list[index].country = entry.country
            if entry.clicks > list[index].clicks {
                list[index].clicks = entry.clicks
                list[index].date = entry.date
            }
        } else {
            list.append(entry)
        }
        save(list)
    }

    func top(duration: Int, country: String?, limit: Int) async throws -> [ScoreEntry] {
        load()
            .filter { $0.duration == duration && (country == nil || $0.country == country) }
            .sorted { $0.clicks != $1.clicks ? $0.clicks > $1.clicks : $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Online-Rangliste (CloudKit, öffentliche Datenbank)

final class CloudKitScoreBackend: ScoreBackend {
    private let database: CKDatabase
    private let recordType = "Score"

    init(containerIdentifier: String) {
        database = CKContainer(identifier: containerIdentifier).publicCloudDatabase
    }

    func submit(_ entry: ScoreEntry) async throws {
        // Ein Datensatz pro Spieler und Dauer → automatisch „bestes Ergebnis“.
        let recordID = CKRecord.ID(recordName: entry.id)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
            let old = (record["clicks"] as? Int) ?? 0
            if entry.clicks <= old {
                // Nur Name/Land auffrischen, wenn sie sich geändert haben.
                if (record["name"] as? String) == entry.name,
                   (record["country"] as? String) == entry.country { return }
            } else {
                record["clicks"] = entry.clicks as CKRecordValue
                record["date"] = entry.date as CKRecordValue
            }
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
            record["playerID"] = entry.playerID as CKRecordValue
            record["duration"] = entry.duration as CKRecordValue
            record["clicks"] = entry.clicks as CKRecordValue
            record["date"] = entry.date as CKRecordValue
        }
        record["name"] = entry.name as CKRecordValue
        record["country"] = entry.country as CKRecordValue
        _ = try await database.save(record)
    }

    func top(duration: Int, country: String?, limit: Int) async throws -> [ScoreEntry] {
        let predicate: NSPredicate
        if let country {
            predicate = NSPredicate(format: "duration == %d AND country == %@", duration, country)
        } else {
            predicate = NSPredicate(format: "duration == %d", duration)
        }
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "clicks", ascending: false)]

        let (results, _) = try await database.records(matching: query, resultsLimit: limit)
        return results.compactMap { _, result -> ScoreEntry? in
            guard let record = try? result.get(),
                  let playerID = record["playerID"] as? String,
                  let clicks = record["clicks"] as? Int else { return nil }
            return ScoreEntry(
                playerID: playerID,
                name: (record["name"] as? String) ?? "?",
                country: (record["country"] as? String) ?? "",
                duration: (record["duration"] as? Int) ?? duration,
                clicks: clicks,
                date: (record["date"] as? Date) ?? Date()
            )
        }
    }
}

// MARK: - Service, den die Oberfläche benutzt

@MainActor
final class ScoreService: ObservableObject {
    private let local = LocalScoreBackend()
    private let online: ScoreBackend?

    /// `true`, wenn eine Online-Rangliste konfiguriert ist.
    var isOnline: Bool { online != nil }

    init() {
        if let id = OnlineConfig.containerIdentifier {
            online = CloudKitScoreBackend(containerIdentifier: id)
        } else {
            online = nil
        }
    }

    /// Speichert lokal und – falls eingerichtet – online. Gibt eine Fehlermeldung zurück, wenn online fehlschlug.
    func submit(_ entry: ScoreEntry) async -> String? {
        guard AntiCheat.isPlausible(clicks: entry.clicks, duration: entry.duration) else {
            return "Ergebnis nicht gewertet."
        }
        try? await local.submit(entry)
        guard let online else { return nil }
        do {
            try await online.submit(entry)
            return nil
        } catch {
            return "Online-Rangliste nicht erreichbar – lokal gespeichert."
        }
    }

    /// Lädt eine Liste. Fällt bei Online-Fehlern auf die lokale Liste zurück.
    func top(duration: Int, scope: LeaderboardScope, limit: Int = 100) async -> (entries: [ScoreEntry], note: String?) {
        if let online {
            do {
                let list = try await online.top(duration: duration, country: scope.countryFilter, limit: limit)
                return (list, nil)
            } catch {
                let list = (try? await local.top(duration: duration, country: scope.countryFilter, limit: limit)) ?? []
                return (list, "Offline – zeige Ergebnisse dieses Geräts.")
            }
        }
        let list = (try? await local.top(duration: duration, country: scope.countryFilter, limit: limit)) ?? []
        return (list, nil)
    }
}
