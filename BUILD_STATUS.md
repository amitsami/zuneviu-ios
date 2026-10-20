# Validation status

## Current version 0.2 — build passed, online playback FAILED

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
