import SwiftUI

struct MyListView: View {
    @Environment(AppModel.self) private var app

    @State private var selection: SeriesSelection?

    var body: some View {
        NavigationStack {
            Group {
                if saved.isEmpty && history.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                            if !history.isEmpty {
                                continueWatching
                            }
                            savedGrid
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.bgBase)
            .navigationTitle("My List")
            .toolbar {
                if !history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Clear history", role: .destructive) { app.library.clearHistory() }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("More")
                    }
                }
            }
        }
        .fullScreenCover(item: $selection) { selection in
            SeriesPlayerView(series: selection.series, startEpisode: selection.episode)
        }
    }

    private var saved: [Series] {
        app.library.favoriteSeriesIDs.compactMap(app.series(id:))
    }

    private var history: [Series] {
        app.library.recentSeriesIDs.compactMap(app.series(id:))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing saved yet", systemImage: "bookmark")
        } description: {
            Text("Tap the bookmark on any series to save it here.")
        } actions: {
            Button("Browse Discover") { app.selectedTab = .discover }
                .buttonStyle(CapsuleButtonStyle())
        }
    }

    private var continueWatching: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.inCard) {
            SectionHeader(title: "Continue watching")
            VStack(spacing: 10) {
                ForEach(history) { series in
                    continueRow(series)
                }
            }
            .padding(.horizontal, Theme.Spacing.margin)
        }
    }

    private func continueRow(_ series: Series) -> some View {
        let episode = app.resumeEpisode(for: series)
        return Button {
            selection = SeriesSelection(series: series, episode: episode)
        } label: {
            HStack(spacing: 12) {
                PosterView(series: series, showsTitle: false, showsBadge: false)
                    .frame(width: 56, height: 80)
                VStack(alignment: .leading, spacing: 6) {
                    Text(series.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("Episode \(episode) of \(series.episodeCount)")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    ProgressLine(value: Double(episode) / Double(max(series.episodeCount, 1)), track: Theme.Colors.bgElevated)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.Colors.accent, in: Circle())
            }
            .padding(10)
            .background(Theme.Colors.bgSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.row))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue \(series.title), episode \(episode) of \(series.episodeCount)")
    }

    private var savedGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.inCard) {
            SectionHeader(title: "Saved")
            if saved.isEmpty {
                Text("Tap the bookmark on any series to save it here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.margin)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 16) {
                    ForEach(saved) { series in
                        let watched = app.library.lastEpisode[series.id]
                        Button {
                            selection = SeriesSelection(series: series, episode: watched ?? 1)
                        } label: {
                            PosterCard(
                                series: series,
                                meta: watched.map { "Ep \($0) of \(series.episodeCount)" } ?? "Not started",
                                width: nil
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Remove from My List", systemImage: "bookmark.slash") {
                                app.library.toggleFavorite(series.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.margin)
            }
        }
    }
}
