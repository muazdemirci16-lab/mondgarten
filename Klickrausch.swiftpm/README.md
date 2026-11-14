# Klickrausch ⚡️

Natives SwiftUI-Klickspiel für iPhone und iPad.

## So geht's
1. Name und Land eingeben (beim ersten Start).
2. Dauer wählen: **5, 10, 15 … bis 100 Sekunden**.
3. Der erste Tipp auf den großen Knopf zählt als **1** und startet die Zeit.
4. So schnell wie möglich tippen, bis die Zeit abläuft.
5. Dein Ergebnis landet auf der Rangliste:
   - oben umschalten zwischen **🇩🇪 Deutschland** und **🌍 Weltweit**
   - darunter die Reihe **5 s · 10 s · 15 s … 100 s** – jede Zeit hat ihre eigene Liste
   - pro Spieler zählt das beste Ergebnis, dein Eintrag ist orange markiert

## Starten
`Klickrausch.swiftpm` in **Swift Playgrounds** (iPad/Mac) oder **Xcode** öffnen und ▶︎ drücken.

## Online-Rangliste (Deutschland / Weltweit über alle Geräte)
Ohne Einrichtung speichert die App die Rangliste auf dem Gerät. Für eine echte
Online-Liste nutzt die App Apples **CloudKit** (öffentliche Datenbank):

1. In Xcode ein Team wählen, Capability **iCloud → CloudKit** hinzufügen und einen
   Container anlegen (z. B. `iCloud.com.example.klickrausch`).
2. In `ScoreService.swift` bei `OnlineConfig.containerIdentifier` den Container eintragen.
3. Im CloudKit-Dashboard für den Record-Typ `Score` Indizes anlegen:
   `duration` und `country` → *Queryable*, `clicks` → *Sortable*.

Fällt die Verbindung aus, zeigt die App die lokalen Ergebnisse an. Unrealistische
Werte (mehr als 25 Klicks pro Sekunde) werden nicht gewertet.
