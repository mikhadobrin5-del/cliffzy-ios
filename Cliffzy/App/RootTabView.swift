import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app

        TabView(selection: $app.selectedTab) {
            FeedView()
                .tag(AppTab.forYou)
                .tabItem { Label("For You", systemImage: "play.rectangle.fill") }
            DiscoverView()
                .tag(AppTab.discover)
                .tabItem { Label("Discover", systemImage: "square.grid.2x2.fill") }
            MyListView()
                .tag(AppTab.myList)
                .tabItem { Label("My List", systemImage: "bookmark.fill") }
            ProfileView()
                .tag(AppTab.profile)
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .toolbarBackground(Theme.Colors.bgSurface.opacity(0.96), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(Theme.Colors.accent)
        .sheet(isPresented: $app.paywallPresented) {
            PaywallSheet(episode: app.paywallEpisode)
        }
        .fullScreenCover(item: $app.presentedSeries) { selection in
            SeriesPlayerView(series: selection.series, startEpisode: selection.episode, showsEpisodesOnAppear: selection.showsEpisodes)
        }
        .onChange(of: app.selectedTab) {
            if app.selectedTab != .forYou { app.players.pauseAll() }
        }
        .onChange(of: app.account.isVIP) { app.vipDidChange() }
    }
}
