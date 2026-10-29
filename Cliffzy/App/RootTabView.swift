import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("For You", systemImage: "play.rectangle.fill") }
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "square.grid.2x2.fill") }
            MyListView()
                .tabItem { Label("My List", systemImage: "bookmark.fill") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(.pink)
    }
}
