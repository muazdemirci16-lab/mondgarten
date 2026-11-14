import SwiftUI

@main
struct KlickrauschApp: App {
    @StateObject private var profile = PlayerProfile()
    @StateObject private var scores = ScoreService()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(profile)
                .environmentObject(scores)
                .tint(.orange)
        }
    }
}
