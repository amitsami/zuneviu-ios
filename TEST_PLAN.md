# Runtime acceptance plan — not yet executed

The 13 unit/integration and 2 UI test methods passed in GitHub Actions run 39458769222. Every physical-device row below remains **PENDING**. Automated tests are implementation checks, not a universal device or service compatibility guarantee.

## Automated tests

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

Streaming providers and their iOS-compatible authentication/stream resolution, provider search and recommendations, online downloads, music video, effects, smart transitions, party features, migrations and localization remain separate unimplemented work. They cannot pass an acceptance gate by testing only the local-player subset.

## Evidence needed before calling it tested

Record commit/hash, Xcode version, simulator/device model and OS, test command, full `.xcresult`, failures/fixes/retest logs, and device acceptance outcomes. A screenshot or static syntax report is insufficient.
