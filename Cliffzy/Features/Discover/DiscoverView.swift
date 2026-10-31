import SwiftUI

struct DiscoverView: View {
    @Environment(AppModel.self) private var app

    @State private var selection: SeriesSelection?
    @State private var genre: String?
    @State private var searchText = ""
    @State private var searchPresented = false
    @State private var path: [ShelfRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if searchPresented || !searchText.isEmpty {
                    SearchResultsView(query: $searchText, onOpen: open)
                } else {
                    content
                }
            }
            .background(Theme.Colors.bgBase)
            .navigationTitle("Discover")
            .searchable(text: $searchText, isPresented: $searchPresented, prompt: "Search series")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CoinBadge() }
            }
            .navigationDestination(for: ShelfRoute.self) { route in
                ShelfGridView(title: route.title, series: route.series, onOpen: open)
            }
        }
        .fullScreenCover(item: $selection) { selection in
            SeriesPlayerView(series: selection.series, startEpisode: selection.episode)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.catalogState {
        case .failed(let message):
            LoadErrorView(message: message) { Task { await app.reloadCatalog() } }
        case .loaded:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    if let top = app.shelves.first?.series.first {
                        HeroBanner(series: top) { open(top) }
                            .padding(.horizontal, Theme.Spacing.margin)
                    }
                    genreChips
                    if let genre {
                        let filtered = app.allSeries.filter { $0.genres.contains(genre) }
                        grid(filtered)
                    } else {
                        continueWatching
                        ForEach(app.shelves) { shelf in
                            shelfView(shelf)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        default:
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .fill(Theme.Colors.bgSurface)
                        .frame(height: 210)
                        .padding(.horizontal, Theme.Spacing.margin)
                    ForEach(0..<2, id: \.self) { _ in
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(MockCatalogService().all.prefix(4)) { PosterCard(series: $0) }
                            }
                            .padding(.horizontal, Theme.Spacing.margin)
                        }
                    }
                }
                .redacted(reason: .placeholder)
            }
            .disabled(true)
        }
    }

    private var genres: [String] {
        var seen: [String] = []
        for genre in app.allSeries.flatMap(\.genres) where !seen.contains(genre) {
            seen.append(genre)
        }
        return seen
    }

    private var genreChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button { genre = nil } label: { GenreChip(text: "All", selected: genre == nil) }
                ForEach(genres, id: \.self) { item in
                    Button { genre = item } label: { GenreChip(text: item, selected: genre == item) }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.margin)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: genre)
    }

    @ViewBuilder
    private var continueWatching: some View {
        let recent = app.library.recentSeriesIDs.compactMap(app.series(id:))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.inCard) {
                SectionHeader(title: "Continue watching")
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(recent) { series in
                            Button { open(series) } label: {
                                PosterCard(series: series, meta: "Ep \(app.resumeEpisode(for: series)) of \(series.episodeCount)")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.margin)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func shelfView(_ shelf: Shelf) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.inCard) {
            SectionHeader(title: LocalizedStringKey(shelf.title)) {
                path.append(ShelfRoute(title: shelf.title, series: shelf.series))
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(shelf.series.enumerated()), id: \.element.id) { index, series in
                        Button { open(series) } label: {
                            if shelf.style == .ranked {
                                RankedCard(rank: index + 1, series: series)
                            } else {
                                PosterCard(series: series, meta: "\(series.views.compactFormatted) views")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.margin)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func grid(_ series: [Series]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 16) {
            ForEach(series) { item in
                Button { open(item) } label: { PosterCard(series: item, width: nil) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
    }

    private func open(_ series: Series) {
        selection = SeriesSelection(series: series, episode: app.resumeEpisode(for: series))
    }
}

struct ShelfRoute: Hashable {
    let title: String
    let series: [Series]
}

struct SeriesSelection: Identifiable {
    let series: Series
    let episode: Int
    var showsEpisodes = false

    var id: String { "\(series.id)-\(episode)" }
}

// MARK: - Pieces

private struct HeroBanner: View {
    let series: Series
    let onWatch: () -> Void

    var body: some View {
        Button(action: onWatch) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: PosterView.colors(for: series), startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "play.fill")
                    .font(.system(size: 140, weight: .black))
                    .foregroundStyle(.white.opacity(0.07))
                    .rotationEffect(.degrees(-12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 20, y: -10)
                Theme.Gradients.scrimBottom
                VStack(alignment: .leading, spacing: 8) {
                    Text("#1 THIS WEEK")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: 4))
                    Text(series.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Watch now")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white, in: Capsule())
                }
                .padding(Theme.Spacing.margin)
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Number 1 this week: \(series.title). Watch now")
    }
}

private struct RankedCard: View {
    let rank: Int
    let series: Series

    var body: some View {
        HStack(alignment: .bottom, spacing: -14) {
            Text("\(rank)")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black, radius: 2)
                .frame(minWidth: 36)
                .zIndex(1)
                .offset(y: 10)
            PosterCard(series: series, meta: "\(series.views.compactFormatted) views")
        }
        .accessibilityElement(children: .combine)
    }
}

/// "See all" destination: a 3-column poster grid.
struct ShelfGridView: View {
    let title: String
    let series: [Series]
    let onOpen: (Series) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 16) {
                ForEach(series) { item in
                    Button { onOpen(item) } label: { PosterCard(series: item, width: nil) }
                        .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.margin)
        }
        .background(Theme.Colors.bgBase)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Search: recent searches, then a poster grid of matches.
private struct SearchResultsView: View {
    @Environment(AppModel.self) private var app
    @Binding var query: String
    let onOpen: (Series) -> Void

    private var results: [Series] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return app.allSeries.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.genres.contains { $0.localizedCaseInsensitiveContains(q) }
                || $0.synopsis.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ScrollView {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.inCard) {
                    Text("Popular searches")
                        .font(.headline)
                        .foregroundStyle(.white)
                    ForEach(["Billionaire", "Revenge", "Werewolf", "Mafia", "Secret baby"], id: \.self) { term in
                        Button {
                            query = term
                        } label: {
                            Label(term, systemImage: "magnifyingglass")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.margin)
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 16) {
                    ForEach(results) { item in
                        Button { onOpen(item) } label: { PosterCard(series: item, width: nil) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(Theme.Spacing.margin)
            }
        }
    }
}
