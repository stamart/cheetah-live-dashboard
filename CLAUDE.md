# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter Android app that acts as the GT7-side relay for the `livetiming` domain in `Softtail_racing`. It runs on a driver's phone, on the same local Wi-Fi as their PS5, and:

1. Sends the GT7 UDP heartbeat and decrypts/decodes the console's telemetry stream (own car only — GT7 exposes no data about other cars).
2. Shows a live on-screen HUD (speed/RPM/lap/best lap/fuel) — the phone itself is the "counter on screen".
3. Pairs with a league event via a short-lived pairing code (issued from the PANEL's Live Timing admin page) and pushes throttled telemetry snapshots to the backend, which broadcasts them to an OBS overlay.

See `docs/superpowers/plans/2026-09-07-gt7-live-timing.md` in the main `simbot` monorepo for the full design (this app is Tasks 6-7 of that plan; the backend and PANEL admin/overlay pages are Tasks 1-5, already shipped in `Softtail_racing`/`softtail-PANEL`).

## Commands

```bash
flutter pub get
flutter run                # on a connected Android device (must be on the PS5's Wi-Fi to test the GT7 socket for real)
flutter build apk --debug  # or --release
```

Requires a JDK whose `cacerts` trust store actually validates Google's certificate chain — on a locked-down Windows machine you may need to set (session-only, not persisted):
```
$env:JAVA_OPTS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT"
$env:GRADLE_OPTS = "-Djavax.net.ssl.trustStoreType=Windows-ROOT"
```
This tells the JVM to trust whatever Windows itself trusts, instead of the JDK's bundled `cacerts` — needed here because `sdkmanager`/Gradle otherwise fail with `PKIX path building failed` reaching `dl.google.com`/Google's Maven repo even though the OS and Dart's own HTTP stack have no problem with the same certs.

## Architecture

```
lib/
  gt7/
    gt7_socket.dart           UDP heartbeat + RawDatagramSocket listener
    gt7_packet_decoder.dart   Salsa20 decrypt + field extraction (offsets verified against
                               snipem/gt7dashboard's gt7communication.py)
    gt7_telemetry.dart        Typed telemetry model
  backend/
    pairing_client.dart       Exchanges a pairing code for a scoped ingest token
    telemetry_uplink.dart     Throttles 60Hz telemetry down to ~6-7Hz before POSTing to the backend
  ui/
    hud_screen.dart           Single screen: PS5 IP + backend URL + pairing code entry, then live HUD
  main.dart
```

No state management library, no navigation — this is a one-screen utility app, not a general-purpose app.

## GT7 protocol notes

- Heartbeat: single byte `0x41` ('A') sent to `<ps5Ip>:33739`, resent every second (packets stop if it lapses).
- The PS5 replies to whatever local port the heartbeat was *sent from* — telemetry is read from that same bound socket, not a fixed port on the phone.
- Packet: 296 bytes, Salsa20-encrypted, fixed key `"Simulator Interface Packet GT7 ver 0.0"`, nonce derived from 4 bytes at offset `0x40` XORed with `0xDEADBEAF` (not `0xDEADBEEF` — that's the correct constant per the reverse-engineered protocol, easy to typo).
- Decrypted packet header must equal magic `0x47375330` or the packet is garbage/out-of-sync and should be dropped, not parsed.
- This app only speaks the base `'A'` packet type. The extended `'B'`/`'~'`/`'C'` variants (surface type, sway/heave/surge) aren't decoded — out of scope, not needed for the HUD/overlay fields in use.
- **Own car only.** There is no way to get other cars' data from this packet. Don't build anything here that implies a real multi-car leaderboard — that's the backend's job (and even there, it's lap-time ranking, not live track position — see the plan doc).

## Backend integration

Talks to the same `domain/livetiming` endpoints documented in `Softtail_racing/CLAUDE.md`:
- `POST /api/livetiming/sessions/exchange` — pairing code → ingest token (public, code is single-use/short-lived).
- `POST /api/livetiming/ingest` — telemetry snapshot, `X-Ingest-Token` header (public, token-scoped).

Both are deliberately unauthenticated (no OAuth2 session, no API key) since this app has neither.
