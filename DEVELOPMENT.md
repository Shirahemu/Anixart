# Anixart PORT Development Checklist

## Stage 2 Manual Test Plan

1. Launch the app.
2. Open Settings.
3. Set Mock Mode OFF.
4. Set Base URL to Primary.
5. Set Header profile to Exact Android 8.5.2 or Android compatibility.
6. Turn Send Sign ON if needed; keep OFF if the live API works without it.
7. Sign in manually.
8. Confirm Profile loads.
9. Relaunch the app.
10. Confirm settings and session restore.
11. Open Home and refresh schedule.
12. Open Search and run a release search manually.
13. Open Release Details from Home or Search.
14. Open Profile.

## Regression Checks

- Mock Mode ON works without network.
- Developer Tools remain available under Settings.
- Login Debug, Profile lookup Debug, Release lookup Debug, Endpoint tester, and Runtime settings Debug still open.
- Debug output redacts token, password, Sign, Authorization, Cookie, and Set-Cookie values.
- No screen performs registration, vote, favorite, comment, report, or scraping automation.

## Stage 3 Data Binding Checks

1. Launch app in live mode with the known working configuration.
2. Confirm session persists after relaunch.
3. Open Home and confirm cards show real Russian titles, not `Release <id>` fallback text.
4. Open Search, search for a known anime, and confirm titles/posters/year/episodes show where available.
5. Open Release Details for ID `20205`.
6. Confirm the release shows `Даже копия способна влюбиться`, `Replica datte, Koi wo Suru`, country/year/season, `12 из 13 эп.`, status `Выходит`, studio `Voil`, source `ранобэ`, genres and description.
7. Confirm episode type/source/episode selectors still load without player actions.
8. Open Profile and confirm login/avatar plus favorite/watching/planned/completed/hold/dropped counts.
9. Confirm watched episodes and watched time display, with `52992` minutes shown as approximately `~883 часа` when present.
10. Confirm votes/history/friends previews render when arrays are present.
11. Confirm Developer Tools still work.
12. Confirm Mock Mode still works.
13. Confirm no token/password/Sign appears in logs or visible debug output.

## Stage 3.5 Profile Diagnostics Checks

1. Launch app.
2. Open Settings and use the known working live configuration:
   - Mock Mode OFF
   - Base URL Primary
   - Header Profile Android compatibility or Exact Android 8.5.2
   - Send Sign ON when required by the live API
3. Open Settings -> Developer Tools -> Diagnostics.
4. Enable verbose diagnostics.
5. Sign in or confirm restored session.
6. Open Profile.
7. Confirm login/avatar/status/counters/statistics render and the screen does not go blank.
8. Open Developer Tools -> Diagnostics again.
9. Confirm network/profile/decoding/uiState events are visible.
10. Confirm latest ProfileDecodeAudit shows raw profile key count, DTO non-nil field count and hidden sections.
11. Tap events to inspect redacted metadata.
12. Generate export text and confirm it does not contain token, password, Sign, Authorization, Cookie or Set-Cookie values.
13. Relaunch app and confirm settings/session restore, then open Profile again.
