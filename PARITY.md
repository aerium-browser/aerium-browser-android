# Feature parity

Aerium is three builds of one browser. This file is the answer to "do all three
have this?", so that the answer is a diff rather than an investigation.

**Update it in the same commit that lands a feature.** A row that is wrong here
is worse than no row, because the next person will trust it.

Windows and Linux are listed separately only because they are separate
repositories. In practice they never differ: the two patch sets are identical
except for the release URL on the first-run page, and a change to one is
expected to land in the other in the same session.

Legend: ✅ shipped · 🟡 partial · ❌ gap · — not applicable on this platform.

## Data and cleanup

| | Win | Linux | Android |
|---|:--:|:--:|:--:|
| Delete browsing data when the browser closes | ✅ | ✅ | ✅ |
| Per-site rules: keep this site | ✅ | ✅ | ✅ |
| Per-site rules: clear when the last tab closes | ✅ | ✅ | ✅ |
| Per-site rules: keep until the browser closes (greylist) | ✅ | ✅ | ✅ |
| Clear every site on tab close, table as exceptions | ✅ | ✅ | ✅ |
| Delay before clearing | ✅ | ✅ | ✅ |
| Automatic-cleanup grouped behind one row | ✅ | ✅ | 🟡 one dedicated screen already |

## Privacy defaults

| | Win | Linux | Android |
|---|:--:|:--:|:--:|
| HTTPS-First Balanced Mode on by default | ✅ | ✅ | ✅ |
| Global Privacy Control on every request | ✅ | ✅ | ✅ |
| Canvas / clientRects / measureText noise, WebGL spoof | ✅ | ✅ | ✅ |
| ...on by default, not only after a first-run choice | ✅ | ✅ | ✅ |
| navigator.hardwareConcurrency reports 2 | ✅ | ✅ | ✅ |
| High-entropy client hints not populated | ✅ | ✅ | ✅ |
| Time zone override (off by default, chrome://flags) | ✅ | ✅ | ✅ |
| Audio fingerprint noise (analyser reads, offline render) | ✅ | ✅ | ✅ |
| AudioContext.baseLatency quantised to 1ms | ✅ | ✅ | ✅ |
| navigator.connection.type reports unknown | — | — | ✅ |
| window.queryLocalFonts() off (Local Font Access) | ✅ | ✅ | ✅ |
| Font enumeration by text measurement | ❌ | ❌ | ❌ |
| Safe Browsing off by default | ✅ | ✅ | ✅ |
| Widevine off, toggleable | ✅ | ✅ | ✅ |
| Passwords and autofill out of the menus and settings | ✅ | ✅ | ✅ |
| Payment probing off by default | ✅ | ✅ | ✅ |
| Preloading, optimization guide, domain reliability off | ✅ | ✅ | ✅ |

Font enumeration by measurement is an open gap on every platform, and is listed
as one rather than left off the table. A page can render text in a candidate
family and compare widths; nothing here stops that. Cromite answers it with an
allowlist of permitted family names, and that patch is not portable here as
written: its list is the Windows 11 font set with an Android section and no
Linux section at all, so on Linux it would reject nearly every real family and
break text rather than harden anything; its Windows half reads private Skia
internals (`src/ports/SkTypeface_win_dw.h`, `DWriteFontTypeface::fDWriteFont`);
and its Android counterpart is 3300 lines. It wants its own pass with a list
built for the platforms this project ships.

navigator.connection: the row above is marked not-applicable on desktop rather
than missing. `type` and `downlinkMax` are exposed only where
`NetInfoDownlinkMax` is stable, which upstream sets for Android and ChromeOS
only, so there is nothing on desktop for the mitigation to hide — the switch is
turned on there too, for the day that changes. The rest of that interface is
deliberately untouched on every platform: `RoundRtt()` and `RoundMbps()` already
bucket `rtt` and `downlink` and multiply by a per-host random factor first, so
two sites already read different values.

Fingerprinting defaults: desktop reaches these through flags seeded in
`default-flags.patch`, so they are listed in `chrome://flags` and one click to
undo; Android compiles them in, because Vanadium has no flags-seeding mechanism
and an unreachable switch would be worse than none. The time zone override is
the exception on both — it is registered but not seeded, because its breakage
is silent (a wrong meeting time reads as a wrong meeting time, not as a browser
setting) where the rest announce themselves.

Payment probing: `payments.can_make_payment_enabled` is registered false by
ungoogled-chromium's `extra/inox-patchset/0006-modify-default-prefs.patch` on
desktop and by Vanadium's patch 0079 on Android. Neither is an Aerium patch —
check there before concluding it is missing.

## Appearance

| | Win | Linux | Android |
|---|:--:|:--:|:--:|
| Aerium's own palette instead of the platform's | ✅ | ✅ | ✅ |
| Pure black (AMOLED) browser surfaces | ❌ | ❌ | ✅ |
| Incognito follows the pure-black switch | ❌ | ❌ | ✅ |
| Darken web content, as a setting | ❌ | ❌ | ✅ |
| Darkened pages get a true-black background | ❌ | ❌ | ✅ |
| Blacken sites that ship their own dark theme | ❌ | ❌ | ✅ |

The five desktop gaps are a decision, not a backlog: AMOLED is a power argument
about OLED phone panels and does not carry to a desktop monitor.

## Extensions

| | Win | Linux | Android |
|---|:--:|:--:|:--:|
| Extensions at all | ✅ | ✅ | ✅ |
| An extension can own the New Tab page | ✅ | ✅ | ✅ |
| Web store bundled with the package | ✅ | ✅ | 🟡 points at the Chrome, Opera and Edge stores |
| Install a .crx from an allowed off-store host | ✅ | ✅ | ✅ |
| Install a .crx already on the device | ❌ | ❌ | ❌ |
| MV2 support | ✅ | ✅ | ✅ |

## Identity and internal pages

| | Win | Linux | Android |
|---|:--:|:--:|:--:|
| `chrome://aerium` — every change this build makes | ✅ | ✅ | ✅ |
| `chrome://aerium-first-run` | ✅ | ✅ | ✅ |
| `aerium://` as an alias for every internal page | ✅ | ✅ | ✅ |
| About page points at the project | ✅ | ✅ | ✅ |
| Startpage default, nine privacy-first engines offered | ✅ | ✅ | ✅ |
| Secure DNS menu: Mullvad, Quad9, NextDNS, no Google | ✅ | ✅ | ✅ |
| Aerogel: a tab with its own throwaway cookie jar | ✅ | ✅ | ❌ |
| Search widget shows the logo, not the launcher tile | — | — | ✅ |
| "You and Google" renamed, Google-services block removed | ✅ | ✅ | — |

## Updates

| | Win | Linux | Android |
|---|:--:|:--:|:--:|
| Daily release check, result on the About screen | ✅ | ✅ | ✅ |
| Told about a release without opening Settings | ✅ app-menu row | ✅ app-menu row | ✅ notification |

## Platform behaviour

| | Win | Linux | Android |
|---|:--:|:--:|:--:|
| Media keeps playing in the background | — | — | ✅ |
| System autofill service used by default | — | — | ✅ |
| Downloads can be handed to another app | — | — | ✅ |
| A download's source URL is recoverable from the UI | 🟡 | 🟡 | ✅ |
| View page source in the menu | ✅ | ✅ | ✅ |
| New tab groups not auto-pinned to the bookmarks bar | ✅ | ✅ | — |
| arm64 build | — | ✅ | ✅ |
| x86_64 build | ✅ | ✅ | ✅ prerelease, dispatch only |

`chrome://downloads` shows the initiator origin and links the filename to the
full URL, so on desktop the address is reachable by copying that link target but
is never displayed. Android's ⋮ menu shows it and copies it in one tap. Worth
evening up; not a hole.

## Onboarding and presets — deliberately desktop-only

| | Win | Linux | Android |
|---|:--:|:--:|:--:|
| First-run preset chooser with an Apply button | ✅ | ✅ | ❌ |
| Aerium Guard section in Settings | ✅ | ✅ | ❌ |
| Aerium Guard shield in the address bar | ✅ | ✅ | ❌ |

The presets exist on desktop because the browser ships with Chromium's defaults
and needs a way off them. The Android build already *is* the decided set, so
`theme.sh` documents the choice not to offer them. Revisit the Settings half if
that reasoning stops holding; do not port the first-run chooser without one.
