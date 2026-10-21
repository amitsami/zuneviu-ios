# Runtime acceptance plan — current and historical scope

The 13 unit/integration and 2 UI test methods passed in GitHub Actions run 39458769222. Every physical-device row below remains **PENDING**. Automated tests are implementation checks, not a universal device or service compatibility guarantee.

## Version 0.2 results

Run 39467391958 built both Simulator and unsigned device binaries. All 24 offline
regression methods passed. Live catalog/home and real search UI methods passed.
The actual online audio method FAILED before playback began (4 failed assertions).
Online pause/seek/next were not reached. Total: 26 methods passed, 1 failed.
No new IPA was delivered because the live gate failed. See VALIDATION_0_2.json.

## Version 0.2 online acceptance

- 9 added offline tests cover real catalog renderer shapes, metadata, order/deduplication, stable identities, invalid IDs, browse-vs-track classification, shelves/continuation, dynamic shell configuration, and old-library/remote-favorites persistence.
- Separate real-provider tests request actual catalog/home data and actual native streams. Playback must advance, pause, seek and move to the next real song.
- A real UI test searches the live online catalog and attaches the actual search screenshot.
- Test tones, mocks and local fixture tests CANNOT satisfy any real online playback acceptance.
- Any provider restriction, sign-in requirement or extraction failure remains a failing gate until legitimately resolved. Do not treat a restricted runner as proof of success on an iPhone.
- Physical iPhone verification is still pending for every device row below.

## Historical/local automated tests

Use `./scripts/test_on_mac.sh` or Xcode Product → Test.

| Area | Written tests | What they do not prove |
| --- | --- | --- |
| LRC/time models | Timestamp sorting, fractions, repeated tags, plain/malformed input, blank timed line, clock and JSON | All lyric formats, downloaded provider lyrics |
| Library | Playlists, duplicate add prevention, favorite persistence, corrupt-manifest preservation | Every filesystem/iCloud failure mode |
| File import | Real WAV import, duration, lyrics import, deletion preserving original; invalid audio rejection | All codecs, tags, DRM and large imports |
| Playback | Native AVPlayer clock advances; pause/seek; sleep timer setup/cancel; missing-file error | Audible device output, full timer expiration, background/route behavior |
| UI | Debug-fixture playback/favorite, local search | File picker automation, all routes, appearance/accessibility |

## Physical iPhone acceptance

| Scenario | Expected result | Status |
| --- | --- | --- |
| Fresh launch | Development notice; no fake connected accounts/catalog | PENDING |
| Import MP3/M4A/WAV/FLAC from local Files and iCloud | Supported non-DRM formats import; failures are actionable; originals intact | PENDING |
| Metadata | Title/artist/album/artwork visible; graceful missing-art fallback | PENDING |
| Playback | Audible output, pause/resume, position slider, next/previous | PENDING |
| Queue | Shuffle/repeat, enqueue/next, remove imported song, end-of-queue behavior | PENDING |
| Background and locked screen | Audio continues where permitted; metadata/transport controls are correct | PENDING |
| Phone/Siri interruption | Pauses; resumes only when iOS indicates and prior state allowed | PENDING |
| Disconnect headphones | Pauses rather than exposing audio on speaker | PENDING |
| Bluetooth/AirPlay | Correct route picker and output; system volume operates | PENDING |
| Sleep timer | Playback pauses after full selected interval; cancellation prevents old timer firing | PENDING |
| Lyrics | Import, plain display, timed follow, tapping line seeks, offset applies | PENDING |
| Persistence | Favorites/playlists/history survive relaunch; failed writes surfaced | PENDING |
| Deletion | App copy removed, original Files document preserved, queue remains valid | PENDING |
| Theme and speed | Settings persist and actually affect display/playback | PENDING |
| Accessibility/layout | VoiceOver, large text, small/large iPhones, no clipping | PENDING |
| Offline/privacy | Local library works without network; no sign-in/analytics requests | PENDING |
| Unsupported features | Account/video/download/streaming limitations remain explicit, no false success | PENDING |
| Long listening/import session | Memory, energy, responsiveness and disk behavior acceptable | PENDING |

## Android parity work

Guest catalog/search/shelves, native extraction, radio and plain lyric requests are now implemented in source, but live streaming acceptance is not yet passed. iOS authentication/sync, provider downloads, music video, effects, smart transitions, party features, migrations and localization remain unimplemented. They cannot pass an acceptance gate by testing only the local-player subset.

## Evidence needed before calling it tested

Record commit/hash, Xcode version, simulator/device model and OS, test command, full `.xcresult`, failures/fixes/retest logs, and device acceptance outcomes. A screenshot or static syntax report is insufficient.

## Version 0.3: glass dock / minimum iOS 15

- Compile with `IPHONEOS_DEPLOYMENT_TARGET=15.0` in both the Xcode 16.4
  fallback and Xcode 26.2 native-glass toolchains. Build an arm64 device Release
  and inspect `MinimumOSVersion` independently of Simulator results.
- iOS 26.2 / iPhone 16 Pro: native `.glassEffect(.clear)` surfaces.
- iOS 18.5 / iPhone SE 3: material fallback, small screen, no home indicator.
- Footer UI tests check every tab/search action, minimum 44pt controls, separate
  search surface, low safe-area position, mini-player separation and opening.
- DEBUG-only custom environment keys exercise reduced motion, solid fallback
  and accessibility text size without mutating read-only system preferences.
- Regression tests verify actual local AVPlayer clock movement does not publish
  playback/library changes every tick, batched listening time persists exactly,
  and 1600px artwork is decoded at 128px then reused from cache.
- Scroll wall-time/CPU/memory are measured without asserting an invented FPS or
  percentage speedup. No before/after performance baseline has been collected.
- Export and visually inspect actual Simulator attachments, not HTML mockups.
- iOS 15 actual runtime/device execution is still REQUIRED. Compiling a target
  of 15.0 and executing on 18.5 do not establish iOS 15 runtime coverage.
- Native live-provider audio acceptance remains a separate release gate. Offline
  footer/optimization success cannot override the version 0.2 streaming failure.
