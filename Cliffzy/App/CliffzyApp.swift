import AVFoundation
import SwiftUI

@main
struct CliffzyApp: App {
    @State private var model = AppModel()

    init() {
        // Play sound even when the silent switch is on, like every video app.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(model)
                .preferredColorScheme(.dark)
                .task { await model.purchases.loadProducts() }
        }
    }
}
