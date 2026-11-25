import SwiftUI

/// Episode picker (screen 04): range tabs of 30 and a 6-column grid. Loads the episode list
/// (with locks) when it opens from the feed, where only the series card is known.
struct EpisodesSheet: View {
    @Environment(AppModel.self) private var app
    let series: Series
    let current: Int?
    let onSelect: (Int) -> Void

    @State private var rangeIndex = 0
    @State private var loaded: Series?

    private var shown: Series { loaded ?? series }

    private let pageSize = 30
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    private var ranges: [ClosedRange<Int>] {
        stride(from: 1, through: shown.episodeCount, by: pageSize).map { start in
            start...min(start + pageSize - 1, shown.episodeCount)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    if ranges.count > 1 {
                        rangeTabs
                    }

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(episodesInRange) { episode in
                            cell(episode)
                        }
                    }

                    legend
                }
                .padding(Theme.Spacing.margin)
            }
            .background(Theme.Colors.bgSurface)
            .navigationTitle(shown.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SheetCloseButton() }
            }
            .onAppear {
                if let current { rangeIndex = (current - 1) / pageSize }
            }
            .task {
                if !series.hasEpisodes { loaded = try? await app.detailedSeries(series) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.bgSurface)
    }

    private var summary: String {
        let count = "\(shown.episodeCount) episodes"
        if app.account.isVIP { return count + " · all open with VIP" }
        guard let free = shown.freeEpisodes else { return count }
        return count + " · first \(free) free · VIP opens the rest"
    }

    /// Before the list loads, plain numbered cells (locks appear once the server answered).
    private var episodesInRange: [Episode] {
        let all = shown.hasEpisodes ? shown.episodes : (1...max(shown.episodeCount, 1)).map {
            Episode(seriesID: shown.id, number: $0, duration: 0, access: .free)
        }
        guard ranges.indices.contains(rangeIndex) else { return all }
        let range = ranges[rangeIndex]
        return all.filter { range.contains($0.number) }
    }

    private var rangeTabs: some View {
        HStack(spacing: 20) {
            ForEach(Array(ranges.enumerated()), id: \.offset) { index, range in
                Button {
                    rangeIndex = index
                } label: {
                    VStack(spacing: 6) {
                        Text("\(range.lowerBound)–\(range.upperBound)")
                            .font(.subheadline.weight(index == rangeIndex ? .semibold : .regular))
                            .foregroundStyle(index == rangeIndex ? .white : Theme.Colors.textTertiary)
                        Capsule()
                            .fill(index == rangeIndex ? Theme.Colors.accent : .clear)
                            .frame(height: 3)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cell(_ episode: Episode) -> some View {
        let isCurrent = episode.number == current
        let playable = app.access(for: episode).isPlayable
        let watched = (app.library.lastEpisode[series.id] ?? 0) > episode.number
        return Button {
            onSelect(episode.number)
        } label: {
            Text("\(episode.number)")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(isCurrent ? .white : (watched ? Theme.Colors.textTertiary : .white))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isCurrent ? Theme.Colors.accent : Theme.Colors.bgElevated, in: RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    if !playable {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Episode \(episode.number)\(playable ? "" : ", locked")")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Theme.Colors.accent, text: "Playing")
            legendItem(color: Theme.Colors.bgElevated, text: "Free or open")
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 11))
                Text("VIP")
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.top, 4)
    }

    private func legendItem(color: Color, text: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text)
        }
    }
}
