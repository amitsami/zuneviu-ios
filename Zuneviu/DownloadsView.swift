import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var playback: PlaybackStore
    @State private var pendingRemoval: Track?
    @AppStorage("downloadedMusicSort") private var sort = "newest"
    private var sortedDownloads: [Track] { TrackOrdering.sorted(library.downloads, by: sort, downloads: true) }
    var body: some View {
        List {
            Section {
                Text("Downloads become available offline only after the complete file passes native audio validation. This queue needs a working source. Manifest-only streams are not offline-packaged yet.").font(.footnote).foregroundStyle(.secondary)
                if let failure = downloads.persistenceError { Text(failure).foregroundStyle(.red) }
            }
            if !downloads.jobs.isEmpty {
                Section("Queue") {
                    ForEach(downloads.jobs) { job in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(job.track.title).font(.headline)
                            Text(job.message ?? job.state.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                            if job.state == .downloading {
                                if let progress = job.progress { ProgressView(value: progress) } else { ProgressView() }
                                Text(ByteCountFormatter.string(fromByteCount: job.receivedBytes, countStyle: .file)).font(.caption).monospacedDigit()
                            }
                            HStack {
                                if [.failed, .cancelled, .interrupted].contains(job.state) { Button("Retry") { downloads.retry(job.id) }.buttonStyle(.bordered) }
                                if [.queued, .waitingForWifi, .resolving, .downloading, .verifying].contains(job.state) { Button("Cancel", role: .cancel) { downloads.cancel(job.id) }.buttonStyle(.bordered) }
                            }
                        }.padding(.vertical, 5)
                    }
                }
            }
            Section("Available offline") {
                if library.downloads.isEmpty { Text("No source downloads yet. Imported Files audio is listed under On Device.").foregroundStyle(.secondary) }
                ForEach(sortedDownloads) { track in TrackRow(track: track, context: library.downloads) }
                    .onDelete { offsets in
                        let songs = sortedDownloads
                        for index in offsets where songs.indices.contains(index) {
                            pendingRemoval = songs[index]
                        }
                    }
            }
        }.navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu { TrackSortPicker(selection: $sort) } label: { Image(systemName: "arrow.up.arrow.down") }.accessibilityLabel("Sort downloads")
                }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Clear finished") { downloads.clearFinished() }.disabled(downloads.jobs.isEmpty) }
            }
            .confirmationDialog("Remove downloaded audio?", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible) {
                Button("Remove offline copy", role: .destructive) {
                    if let track = pendingRemoval {
                        if playback.current?.id == track.id { playback.stop() }
                        downloads.removeOfflineCopy(track.id)
                    }
                    pendingRemoval = nil
                }
            } message: { Text("Likes, playlists and history are kept. Playing this song again will need its online source.") }
    }
}
