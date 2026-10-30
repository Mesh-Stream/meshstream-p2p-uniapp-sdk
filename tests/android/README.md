# Android device acceptance

Run only in a private staging project, never in a published plugin/example.

1. Prepare a controlled HLS fixture: `index.m3u8` with at least 10 relative TS segment URLs (no master playlist).
2. Start `python3 tests/android/media-server.py --media /absolute/fixture --output /absolute/private-results` on the Mac. It listens on loopback port 18116, throttles each TS request to 256 KiB/s and independently verifies received segment bytes and SHA-256.
3. Run `adb reverse tcp:18116 tcp:18116` for the test device.
4. Create a fresh staging app with `scripts/prepare-marketplace.py`, replace its index page with `acceptance-page.vue`, and supply an authorized Android SDK Key **only in that private copy**.
5. Import the staging project into HBuilderX. Use an official Android custom base containing the exact public native dependency and the plugin network configuration. Force-stop the test app before each run; hot reload can retain old native clients.
6. Run the staging app. Inspect `acceptance-events.jsonl` for the final `summary`; every check must pass. Preserve failed checks and logs. Always distinguish independent clients on one device from cross-device testing.

The harness covers preload, segment integrity, real P2P counters, removal of the seeder with CDN fallback, independent clients, explicit P2P disable/toggle, diagnostics, position/buffer updates, event unsubscribe, idempotent close, closed-session rejection and proxy release. Configuration readiness is checked after creating the session (client creation intentionally makes no HTTP request) with a 12.5s observation window; a failure remains a failed check even if later media requests succeed. Individual calls have bounded timeouts. The fixture is synthetic network traffic, not a rendered-video/first-frame or battery benchmark.

Restore the original page, remove test-only reverse mappings, and stop the fixture server after testing. Credentials, media and raw device logs are not plugin package contents.
