# Validation status

## Android-reference UI restyle — validation pending

- Read-only reference: Android repository source `1e590ed2e5f7bb5f170ec353443490970020c574`, shared UI/Common/Theme/Settings and owner-supplied Discover/Listen/Settings gallery.
- Reworked feed headings, 70%-width hero cards, 150-point shelves, Library listening card and collection tiles, grouped Settings with a persistent dock, and immersive player artwork with three primary transport actions.
- No invented account state, membership history, fake provider playback or cosmetic-only DSP switches were added. Shuffle/repeat remain available in player options and Playback settings.
- New layout changes require fresh Apple compilation, both compact/native UI regressions and real-source UI acceptance; prior passes do not certify the restyle. Android-identical screen/feature parity is not yet claimed.

## Current version 0.4 — optional-source audio verified; full Android parity incomplete

- Real-source acceptance run [39563210602](https://github.com/amitsami/zuneviu-ios/actions/runs/39563210602), source `7b0eada8`, passed 49 offline unit/integration methods and one real JioSaavn acceptance method, then built an unsigned arm64 iPhone app targeting iOS 15.0.
- Real acceptance verified exact full Tum Hi Ho recording search, native playback clock advancement, pause, seek/resume, actual listening qualification, source-specific suggestion candidates, complete progressive-file download, library reload and native playback from the persisted file URL with the online source disabled. This is not an all-song/region/codec guarantee or physical audible-output test.
- Earlier full compatibility run [39565266711](https://github.com/amitsami/zuneviu-ios/actions/runs/39565266711), source `22479004`, passed **49 offline + 10 fixture UI + 1 real JioSaavn method in each environment**: iOS 18.5 / iPhone SE 3 / Xcode 16.4 and iOS 26.2 / iPhone 16 Pro / Xcode 26.2.
- Real-source UI run [39571506930](https://github.com/amitsami/zuneviu-ios/actions/runs/39571506930), source `0dff2329`, PASSED: explicit source opt-in, real search, native playback clock in Now Playing, on-screen transport bounds and Pause-to-Play state change.
- Visual QA caught remote artwork expanding the player beyond the screen; explicit background/content width constraints fixed it. UI selectors now distinguish the presented player from the underlying dock.
- Compatibility run [39571509421](https://github.com/amitsami/zuneviu-ios/actions/runs/39571509421) PASSED its native-glass job but FAILED the small-screen fixture UI test: the transport required vertical scrolling below oversized artwork. The failure is retained; it is not a full-suite pass.
- Latest source `5da51a8a` adapts artwork size/spacing for compact-height iPhones. Its final [compatibility/build run](https://github.com/amitsami/zuneviu-ios/actions/runs/39599408895) PASSED both environments (49 offline + 10 fixture UI + 1 real-source method each, unsigned iPhone Release build), and [real-source UI run](https://github.com/amitsami/zuneviu-ios/actions/runs/39599406029) PASSED. These results predate the Android-reference restyle below.
- Earlier failed UI runs remain visible: source switch tap (`39563212734`), active-search dismissal (`39565268727`), ambiguous Pause (`39567030806`) and duplicate dock Next selectors (`39568853762`). A passed subset never changes a failed overall run into a pass.
- Extensionless progressive downloads are validated using typed app-owned staging files; failed copies are removed without deleting the caller's original. Removing a downloaded copy retains favorites/playlists/history/lyrics. Independent stable library/download title/date sorting is implemented.
- **Not full Android parity:** YouTube native extraction remains blocked in its previous acceptance. JioSaavn success does not fix or substitute for YouTube. Google/Spotify login-sync, video, DSP/EQ/smart transitions, advanced integrations/private modules, migration and full Settings parity remain missing. Background-restorable downloads and HLS/DASH offline packaging are not implemented.
- **Unsigned development builds require Apple signing/provisioning.** Physical iPhone and actual iOS 15 runtime acceptance have NOT run. See `docs/ANDROID_PARITY.md` for declaration-level scope and `VALIDATION_0_4.json` for gate references.

## Historical version 0.3 — glass/compatibility regression passed; streaming NOT fixed

- Final application source: `23ca6ad`; final run: https://github.com/amitsami/zuneviu-ios/actions/runs/39554273435
- Both Simulator environments passed **28 offline unit/integration + 7 fixture UI methods** each, zero failures (35 unique methods, 70 executions).
- Native Glass: Xcode 26.2 (17C52), iPhone 16 Pro, iOS 26.2.
- Material fallback: Xcode 16.4 (16F6), iPhone SE 3, iOS 18.5.
- Unsigned iPhone Release build passed; built app `MinimumOSVersion` is **15.0**.
- Direct iOS 15 runtime execution and physical iPhone tests: NOT RUN. The deployment target alone is not runtime certification.
- UI: separate search circle, three-tab pill, low safe-area placement, mini-player above, complete untruncated branding. No full-width opaque footer surface.
- Accessibility: system reduce-motion/transparency are respected; DEBUG overrides exercise solid fallback and large type without mutating read-only system settings.
- Regression assertions: local AVPlayer clock advances without publishing player/library state every tick; listening seconds batch and persist correctly; decoded artwork downsamples and cache identity is reused.
- Scroll metrics target the app process; no before baseline or FPS claim.
- Visual QA exported actual screenshots, caught the native toolbar's clipped brand and retested the correction. The Home guest catalog screenshot is not provider-playback proof.
- Known previous online audio acceptance failure remains UNRESOLVED; live tests are deliberately separate and skipped in the footer workflow. No new IPA was delivered as a working-equivalent release.
- See `VALIDATION_0_3.json` for exact method names and evidence hashes.

## Version 0.2 — build passed, online playback FAILED

- Completed iOS build/regression/live gate run: https://github.com/amitsami/zuneviu-ios/actions/runs/39467391958
- Source under test: `5f020b9`.
- Standalone pinned native extractor compiled but FAILED actual media extraction in run https://github.com/amitsami/zuneviu-ios/actions/runs/39466288757 (`YouTubeKitError.extractError`).
- Real provider catalog search and guest home calls returned HTTP 200 in the development environment. This does not prove native audio playback.
- Google/Spotify sign-in and sync, provider downloads, video and Android effects are still missing.
- Simulator compilation and unsigned iPhone device compilation: PASSED.
- Offline regression: 22 unit/integration + 2 fixture UI tests PASSED.
- Live catalog/search/home integration: PASSED.
- Real online search UI test: PASSED (actual result screenshot attached to xcresult).
- Actual native online audio: FAILED before playback advanced. Pause/seek/next were therefore not reached for online audio.
- Total: 26 test methods passed; 1 failed (4 failed assertions in that method).
- Real guest Home screenshot was captured; it is UI evidence, NOT streaming proof.
- Overall workflow: FAILURE. The IPA delivery step was correctly skipped.
- See `VALIDATION_0_2.json` for exact result scope. No new working-equivalent app is claimed.

## Historical version 0.1 verified result

GitHub Actions runs **39458769222** and **39459965095** successfully compiled the app and executed the iOS Simulator test suites using Xcode 16.4. The second run also successfully built the unsigned iPhone device IPA and captured an actual Simulator screenshot.

- Historical local-player application source commit: `efd987efbc07103cb9b024d97b071177c7f78083`.
- Environment: Xcode 16.4 (16F6), iPhone 16 Pro Simulator, iOS 18.5.
- 13 XCTest unit/integration methods: passed, zero failures.
- 2 XCUITest UI methods: passed, zero failures.
- Native AVPlayer playback clock advance, pause and seek were tested with a generated WAV fixture.
- Real audio import/lyrics import/deletion, original-file preservation, favorites/playlists persistence and corrupt-manifest protection passed.
- UI fixture playback/favorite and local search passed.
- Latest evidence: https://github.com/amitsami/zuneviu-ios/actions/runs/39459965095
- First successful test run: https://github.com/amitsami/zuneviu-ios/actions/runs/39458769222

**This is not full Android parity or physical iPhone certification.** Audible output, lock-screen/background behavior, AirPlay, interruptions, every codec, accessibility, provider services and full sleep-timer expiration still require manual/device testing. At this historical commit, streaming providers and Google/Spotify login were not implemented. Version 0.2 is documented separately above.

## Historical version 0.1 package status

The historical version 0.1 run produced `Zuneviu-unsigned.ipa` and a real Simulator screenshot. The downloaded IPA was integrity-checked against its SHA-256 and its Mach-O load commands confirmed arm64 **iOS device** platform (not Simulator), minimum iOS 17.0. See `BUILD_EVIDENCE.json` for checksum and provenance. An unsigned IPA requires signing before installation; it is not an App Store/TestFlight release. GitHub artifacts use one-day retention.

## Static checks

`STATIC_VALIDATION.json` records earlier syntax/project/reference/asset checks and Swift source hashes. It is separate from the above Xcode runtime evidence. AVFoundation is imported with pre-concurrency compatibility for its legacy non-Sendable metadata objects; the expanded workflow reruns the complete test suite.

## Remaining release gates

- Complete the physical iPhone acceptance matrix in TEST_PLAN.md.
- Implement and validate the missing Android features before claiming parity.
- Sign and provision any device installation using the owner's chosen installation method.
- Review license, provider-policy and distribution requirements before a public app release.

The Android release repository has not been modified.
