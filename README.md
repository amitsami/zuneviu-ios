# Zunéviu for iOS — development source, not a tested release

**Status: partial native port. The initial Xcode Simulator build and 15 automated tests passed on GitHub macOS. This is not full Android parity, not physically iPhone-tested, and not production-certified. Device IPA output is unsigned and requires signing.**

The owner requested an iOS version retaining the Android app's design. This archive contains an initial SwiftUI/AVPlayer implementation and an Xcode project, with test code and a macOS CI workflow. Xcode Simulator runtime evidence is linked in `BUILD_STATUS.md`; the earlier static checks remain in `STATIC_VALIDATION.json`.

## Reference

- Original repository: https://github.com/amitsami/zunevio-releases
- Source inspected at commit `4ba49d58de1b2699b9c948ec0d0c911e05ea0ab0`.
- Reference gallery: `assets/gallery/discover.png`, `listen.png`, `settings.png` in that repository.
- The original shared network/UI implementation uses JVM/Android dependencies, not an existing iOS target. This is a separate native implementation, not a claim that Android code now builds unchanged for iOS.
- Original monochrome music-mark branding was reused. Actual artist covers are not shipped; imported audio supplies its own embedded artwork. Empty-library UI is intentional.

## Implemented in source — selected behavior verified by Simulator tests

- Native Listen Now, Explore, Library, Search and Settings navigation.
- Files import, app-sandbox copies, embedded title/artist/album/artwork extraction.
- Local AVPlayer playback, scrubbing, previous/next, shuffle, repeat and queue.
- Background audio declaration, Now Playing metadata and remote transport handlers.
- System volume and AirPlay route controls.
- Favorites, playlists, recent history, locally measured listening time and JSON persistence.
- Remove an imported copy without deleting the original Files document.
- UTF-8 `.lrc`/`.txt` import, timed lyrics, lyric seeking and timing offset.
- Sleep timer, playback speed and dark/light/system theme settings.
- An explicit first-run development/feature-limit notice, rather than a fake connected streaming library.

## Not implemented / not equivalent to Android

- Google/YouTube Music and Spotify authentication, sessions, library sync and acceptance flows.
- Online streaming catalog, recommendations, stream extraction/resolution and provider downloads.
- Music video, radio, provider search, Genius/live lyric fetch and automatic album-art lookup.
- Android equalizer/DSP, PCM output controls, smart transitions/crossfade, stem separation.
- Listen-together/party, WebDAV, provider integrations and Android APK update machinery.
- Full settings parity, localization, Android library migration and pixel-identical visual certification.

Unavailable features are identified as such in Settings. No decorative switches pretend to implement them.

## Open and run on a Mac

Requirements: full Xcode 16 or newer, installed iOS Simulator runtime, iOS 17+ deployment target. No CocoaPods, Swift packages, service credentials or XcodeGen are required.

1. Open `Zuneviu.xcodeproj`.
2. Choose the shared **Zuneviu** scheme and an installed iPhone simulator.
3. Build/run. On first launch, read the development notice, then import an audio file from Files.
4. For a physical iPhone, set **Signing & Capabilities → Team** and choose an available bundle identifier. Apple signing/provisioning is required; this archive supplies no signing secrets.

The iOS code is kept separately in `amitsami/zuneviu-ios`; the Android release repository is not modified. GitHub authorization is used only outside the source tree. No credential is included in this repository.

## Run the actual iOS tests

```sh
./scripts/test_on_mac.sh
```

Or use Xcode's **Product → Test**. The project includes 13 unit/integration test methods and 2 UI test methods. **All 15 tests passed in initial run 39458769222. This does not replace the physical-device acceptance matrix.** See `TEST_PLAN.md` for coverage and limitations.

The script writes a timestamped `.xcresult` and log into `TestResults/`. It exits unsuccessfully if Xcode tests fail. No report in this archive substitutes for those runtime results.

### GitHub Actions

The included `.github/workflows/ios.yml` is manual-only (`workflow_dispatch`), runs on `macos-15` with a 20-minute job timeout, builds the app, executes the tests on an available iPhone simulator, and uploads `.xcresult`/logs with one-day retention. Pushing code does not automatically start a billable run. The simulator app is uploaded only after test success. A simulator `.app` is **not** an installable iPhone IPA. The initial Simulator workflow successfully ran in this repository. The expanded workflow also attempts an unsigned iPhone build and captures a real Simulator screenshot after successful tests.

Place the archive contents at the root of a new repository, or adapt paths and workflow triggers if placing it under a subfolder in an existing repository. GitHub-hosted macOS runners require account/repository access and may incur charges; only standard public-repository runners are used; no paid/larger runner is selected.

## Re-run static checks

```sh
python3 -m pip install -r scripts/requirements-static.txt
python3 scripts/verify_project.py
bash -n scripts/test_on_mac.sh
```

The verifier parses Swift syntax with Tree-sitter, not Apple's Swift compiler. It also parses the Xcode project, checks references, plists, scheme, assets and fixture WAV. A static pass cannot establish API availability, Swift type checking, linker correctness, UI behavior or audio behavior.

After adding/removing Swift files, regenerate the explicit Xcode project with:

```sh
python3 scripts/generate_project.py
```

## Storage and privacy

Audio imports copy into `Library/Application Support/Zuneviu/`. Originals are not modified. Metadata and playlists are in `library.json`; imported artwork and lyrics sit beside the copied music. Corrupt manifests are not overwritten by a scene-save. The app has no analytics, embedded login or online music endpoint. System Files/iCloud, sharing, device backup and AirPlay retain their own platform behavior. Deleting the app deletes this sandbox.

`TestTone.wav` is an original generated 8-second 440 Hz tone for tests. The debug-only `--ui-testing` launch flag creates an isolated test library, not the user's normal library. It is not a demo of provider streaming.

## License

GPL-3.0; see `LICENSE`. Original branding and source references retain attribution in `UPSTREAM-NOTICE.md`. `UPSTREAM-THIRD-PARTY-NOTICES.md` is retained historical context for the Android app, not a declaration that all Android dependencies are linked into this SwiftUI target. No Android Kotlin implementation, AGPL smart-transition code or external music-provider credentials are included in this archive.
