# Android feature/settings coverage — iOS 0.4 development

**This is an implementation inventory, not a 100% parity claim or runtime pass.** See BUILD_STATUS.md for the tested commit and exact evidence. No control is presented as working solely because it appears on screen.

Reference: Android source commit `4ba49d58de1b2699b9c948ec0d0c911e05ea0ab0`, `source/app/src/main/java/com/music/bitchord/data/settings/AppSettings.kt`. The declarations below include enum descriptors and runtime state, not 130 distinct user features.

## Source and platform limits

- YouTube Music: guest catalog/search/browse; native extraction remains blocked in the previous live acceptance test. A server verification requirement is not bypassed.
- JioSaavn: separately opt-in, source-labelled search/results/streaming/download path. Never silently maps YouTube IDs to covers or alternate recordings. Real acceptance results are recorded separately.
- No spoofed geographic headers, account-cookie reuse, hosted extraction proxies or private addon execution.
- Download queue supports complete progressive files, cancel/retry and validation before offline installation. Removing a source download keeps its likes, playlists, history and lyrics; this is separate from deleting an imported library entry. No background-restorable sessions or HLS/DASH offline packaging yet.
- Local recommendations are not Google-account recommendations. JioSaavn artist-search candidates extend, rather than exactly reproduce, the Android YouTube-radio policy.
- Minimum target iOS 15.0. Actual iOS 15 runtime and physical-device acceptance remain untested.

## Cross-cutting features

| Area | Implemented scope | Still missing / unverified |
|---|---|---|
| Design | Split three-tab floating dock, separate Search, mini-player, dark branding; material fallback | Pixel-perfect full-app certification, every device/text size |
| Library | Files import, favorites/playlists/history, local metadata/artwork/lyrics, original-file preservation | Android library migration, account sync, advanced sort/view parity |
| Player | AVPlayer, seek/queue/next/previous/shuffle/repeat, speed/sleep timer, volume/AirPlay handlers | Physical lock-screen/background/interruption/AirPlay acceptance |
| Online | Guest YouTube catalog/search/browse; explicit optional JioSaavn source | Reliable YouTube native audio, Google/Spotify authentication |
| Offline | Progressive-file queue/install/validation; Files imports | Background completion, manifest packaging, all-provider download guarantees |
| Settings | Functional native controls listed below | Android DSP, video, account integrations and advanced services |

## Declaration-level audit

| Android declaration | iOS scope |
|---|---|
| `maxKbps` | Descriptor/runtime state, not a separately ported user control. |
| `label` | Descriptor/runtime state, not a separately ported user control. |
| `detail` | Descriptor/runtime state, not a separately ported user control. |
| `perTrack` | Descriptor/runtime state, not a separately ported user control. |
| `keepsLossless` | Descriptor/runtime state, not a separately ported user control. |
| `videoQualityWifi` | Not ported. No fake functional switch is supplied. |
| `videoQualityCellular` | Not ported. No fake functional switch is supplied. |
| `videoConnection` | Descriptor/runtime state, not a separately ported user control. |
| `audioQualityWifi` | Wired: Wi-Fi bitrate ceiling; source must offer a compatible native rendition. |
| `audioQualityCellular` | Wired: cellular bitrate ceiling and cellular-streaming opt-out. |
| `upgradeLengthSlackSeconds` | Descriptor/runtime state, not a separately ported user control. |
| `downloadQuality` | Wired: queue requests selected bitrate ceiling; source-dependent. |
| `wifiOnlyDownloads` | Wired: unmetered Wi-Fi/Ethernet gate and URLSession network restrictions. |
| `exportDownloads` | Partial: share an on-device audio file from Now Playing; no automatic folder export. |
| `meteredConnection` | Partial: NWPathMonitor detects cost/constraint; no manual override. |
| `crossfadeSeconds` | Not ported. No fake functional switch is supplied. |
| `smartFadeEnabled` | Not ported. No fake functional switch is supplied. |
| `automixPerformanceMode` | Not ported. No fake functional switch is supplied. |
| `skipSilence` | Not ported. No fake functional switch is supplied. |
| `outputPcmMode` | Not ported. No fake functional switch is supplied. |
| `preferUsbDac` | Not ported. No fake functional switch is supplied. |
| `loudnessNormalization` | Not ported. No fake functional switch is supplied. |
| `loudnessOffOnSpeaker` | Not ported. No fake functional switch is supplied. |
| `dolbyAtmos` | Not ported. No fake functional switch is supplied. |
| `spatialAudio` | Not ported. No fake functional switch is supplied. |
| `equalizerEnabled` | Not ported. No fake functional switch is supplied. |
| `equalizerMode` | Not ported. No fake functional switch is supplied. |
| `equalizerToneX` | Not ported. No fake functional switch is supplied. |
| `equalizerToneY` | Not ported. No fake functional switch is supplied. |
| `equalizerFocused` | Not ported. No fake functional switch is supplied. |
| `equalizerBalance` | Not ported. No fake functional switch is supplied. |
| `equalizerBands` | Not ported. No fake functional switch is supplied. |
| `equalizerPreset` | Not ported. No fake functional switch is supplied. |
| `playbackSpeed` | Wired: AVPlayer rate 0.75–2× from Settings. |
| `themeMode` | Wired: dark/light/system. |
| `autoplay` | Wired: source-specific related candidates at queue end; no cross-source substitution. |
| `shuffleEnabled` | Wired: actual queue selection, not decorative state. |
| `repeatMode` | Wired: off/all/one transport behavior. |
| `showNerdStats` | Not ported. No fake functional switch is supplied. |
| `reduceAnimation` | Wired: footer/press/lyric-scroll motion; also respects system Reduce Motion. |
| `highPerformanceMode` | Not ported. No fake functional switch is supplied. |
| `performanceRefreshRate` | Not ported. No fake functional switch is supplied. |
| `stopOnTaskRemoved` | Different platform lifecycle: no Android task-removal service. Killing iOS app can interrupt downloads. |
| `hideVolumeBar` | Wired: hide system volume slider in player. |
| `hideSongStatus` | Wired: hide source caption in player. |
| `swipeToPlayNext` | Not ported. No fake functional switch is supplied. |
| `dontRepeatSuggestions` | Wired: excludes local listening-history IDs from discovery candidates. |
| `preferMusicOnly` | Not ported. No fake functional switch is supplied. |
| `smartVersionAlignment` | Not ported. No fake functional switch is supplied. |
| `reduceDynamicBlur` | Wired: solid dock surfaces and no blurred artwork backdrop. |
| `liquidGlass` | Wired: native iOS 26 clear glass; earlier iOS material fallback; can disable. |
| `localRecommendations` | Wired: 20-second qualified listening, max eight seeds, round-robin dedup. Opt-in JioSaavn extends this to artist-search suggestions. No account personalization. |
| `lyricsBlur` | Wired: inactive timed-line blur. |
| `lyricsOffsetMs` | Partial: one iOS seconds-based offset; not all Android per-mode offsets. |
| `audioLyricsOffsetMs` | Partial: shared iOS lyric offset, not separate audio/video offsets. |
| `translationLanguage` | Not ported. No fake functional switch is supplied. |
| `animatedCanvas` | Not ported. No fake functional switch is supplied. |
| `canvasOverCellular` | Not ported. No fake functional switch is supplied. |
| `spotifyCanvasAutoHide` | Not ported. No fake functional switch is supplied. |
| `prioritizeSpotifyCanvas` | Not ported. No fake functional switch is supplied. |
| `fullBleedArtwork` | Wired: immersive artwork backdrop toggle. |
| `legacyMeshGradient` | Not ported. No fake functional switch is supplied. |
| `lastPlayerScreen` | Not ported. No fake functional switch is supplied. |
| `syncedLyrics` | Wired: imported LRC highlight/auto-scroll/tap seeking. Online timed lyrics parity is missing. |
| `lyricsSources` | Not ported. No fake functional switch is supplied. |
| `lyricsSourceOrder` | Not ported. No fake functional switch is supplied. |
| `prioritizeSyllableSync` | Not ported. No fake functional switch is supplied. |
| `paxSenixApiKey` | Not ported. No fake functional switch is supplied. |
| `audioCacheLimitBytes` | Not ported. No fake functional switch is supplied. |
| `showCacheFolder` | Not ported. No fake functional switch is supplied. |
| `replayGenres` | Not ported. No fake functional switch is supplied. |
| `filterNonMusicAudio` | Not ported. No fake functional switch is supplied. |
| `localMusicSort` | Wired: On Device title A–Z/Z–A and newest/oldest import-date ordering. Android external file modification time is not retained. |
| `downloadedMusicSort` | Wired: independent Downloads title A–Z/Z–A and newest/oldest download-date ordering. |
| `localMusicViewType` | Not ported. No fake functional switch is supplied. |
| `downloadedMusicViewType` | Not ported. No fake functional switch is supplied. |
| `homeRecentsViewType` | Not ported. No fake functional switch is supplied. |
| `librarySort` | Partial: stable on-device title/date ordering; playlist ordering is unchanged. |
| `detailSongSorts` | Not ported. No fake functional switch is supplied. |
| `localMusicFolderUri` | Partial: Files document import with app-local copies; no folder watching. |
| `webdavUrl` | Not ported. No fake functional switch is supplied. |
| `webdavUsername` | Not ported. No fake functional switch is supplied. |
| `webdavPassword` | Not ported. No fake functional switch is supplied. |
| `smbHost` | Not ported. No fake functional switch is supplied. |
| `smbShare` | Not ported. No fake functional switch is supplied. |
| `smbBasePath` | Not ported. No fake functional switch is supplied. |
| `smbUsername` | Not ported. No fake functional switch is supplied. |
| `smbPassword` | Not ported. No fake functional switch is supplied. |
| `pinnedPlaylists` | Not ported. No fake functional switch is supplied. |
| `scrobblingAvailable` | Not ported. No fake functional switch is supplied. |
| `lastfmEnabled` | Not ported. No fake functional switch is supplied. |
| `lastfmUsername` | Not ported. No fake functional switch is supplied. |
| `lastfmSessionKey` | Not ported. No fake functional switch is supplied. |
| `lastfmApiKey` | Not ported. No fake functional switch is supplied. |
| `lastfmSecret` | Not ported. No fake functional switch is supplied. |
| `lastfmEndpoint` | Not ported. No fake functional switch is supplied. |
| `lastfmScrobbleEnabled` | Not ported. No fake functional switch is supplied. |
| `lastfmNowPlaying` | Not ported. No fake functional switch is supplied. |
| `lastfmPrimaryArtistOnly` | Not ported. No fake functional switch is supplied. |
| `scrobbleMinDuration` | Not ported. No fake functional switch is supplied. |
| `scrobbleDelayPercent` | Not ported. No fake functional switch is supplied. |
| `scrobbleDelaySeconds` | Not ported. No fake functional switch is supplied. |
| `listenBrainzEnabled` | Not ported. No fake functional switch is supplied. |
| `listenBrainzToken` | Not ported. No fake functional switch is supplied. |
| `listenBrainzPrimaryArtistOnly` | Not ported. No fake functional switch is supplied. |
| `spotifySpdcToken` | Not ported. No fake functional switch is supplied. |
| `discordToken` | Not ported. No fake functional switch is supplied. |
| `discordUsername` | Not ported. No fake functional switch is supplied. |
| `discordName` | Not ported. No fake functional switch is supplied. |
| `discordAvatar` | Not ported. No fake functional switch is supplied. |
| `discordRpcEnabled` | Not ported. No fake functional switch is supplied. |
| `discordUseDetails` | Not ported. No fake functional switch is supplied. |
| `discordShowAudioQuality` | Not ported. No fake functional switch is supplied. |
| `discordAdvancedMode` | Not ported. No fake functional switch is supplied. |
| `discordStatus` | Not ported. No fake functional switch is supplied. |
| `discordActivityType` | Not ported. No fake functional switch is supplied. |
| `discordActivityName` | Not ported. No fake functional switch is supplied. |
| `discordButton1Text` | Not ported. No fake functional switch is supplied. |
| `discordButton1Visible` | Not ported. No fake functional switch is supplied. |
| `discordButton2Text` | Not ported. No fake functional switch is supplied. |
| `discordButton2Visible` | Not ported. No fake functional switch is supplied. |
| `discordInfoDismissed` | Not ported. No fake functional switch is supplied. |
| `audioSessionId` | Platform-specific runtime state: AVAudioSession, not Android session IDs. |
| `smartMixInProgress` | Descriptor/runtime state, not a separately ported user control. |
| `smartMixBlend` | Descriptor/runtime state, not a separately ported user control. |
| `versionAlignmentInProgress` | Descriptor/runtime state, not a separately ported user control. |
| `smartAnalysis` | Descriptor/runtime state, not a separately ported user control. |
| `smartTransitionWindow` | Descriptor/runtime state, not a separately ported user control. |
| `effectiveAudioQuality` | Partial: rendition selection; no complete decoder/output diagnostics UI. |
| `downloadsAllowedNow` | Partial: queue checks storage/network/source state; private module policies are unsupported. |
