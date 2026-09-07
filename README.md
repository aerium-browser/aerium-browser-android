<p align="center">
  <img src="res/aerium.svg" width="96" height="96" alt="Aerium logo">
</p>

<h1 align="center">Aerium</h1>

<p align="center"><i>by Dioide</i></p>

[![release](https://img.shields.io/github/v/release/aerium-browser/aerium-browser-android)](https://github.com/aerium-browser/aerium-browser-android/releases/latest)
[![released](https://img.shields.io/github/release-date/aerium-browser/aerium-browser-android?label=released)](https://github.com/aerium-browser/aerium-browser-android/releases/latest)
[![downloads](https://img.shields.io/github/downloads/aerium-browser/aerium-browser-android/total?label=downloads)](https://github.com/aerium-browser/aerium-browser-android/releases)
[![license](https://img.shields.io/badge/License-GPLv2-blue.svg)](LICENSE)

Aerium is a browser for people who'd rather their browser stayed out of the way. No telemetry calling home, no ad platform baked into the settings page. Extensions — including Manifest V2 — install straight from the Chrome Web Store, something most Android browsers still can't do.

[**Download for Android**](https://github.com/aerium-browser/aerium-browser-android/releases/latest)

## What you get

- **Extensions that actually work.** Manifest V2 support and Chrome Web Store access, plus Opera and Microsoft Edge add-on stores, and `.crx` files straight from a GitHub release — which is where an extension that is on no store usually lives. You still see the permissions prompt before anything installs.
- **Your password manager, working properly.** Android's own autofill framework is on by default, so Bitwarden and similar apps fill forms natively instead of falling back to flaky accessibility tricks.
- **Search that works from the first keystroke.** DuckDuckGo is the default engine, with Startpage, Brave Search, Mojeek, Qwant, Ecosia, degoog and the two DuckDuckGo no-JS variants ready to pick in Settings — and any other engine addable by hand.
- **Its own look, and a true-black dark mode.** Aerium ships its own palette instead of taking colours from your wallpaper. Dark mode can go fully black — on an OLED screen a black pixel is switched off and draws no power — with separate switches for the browser itself and for web pages under **Settings → Appearance → Theme**.
- **Media that keeps playing.** Leave the browser or turn the screen off and video and audio carry on. Chromium suspends media in a hidden page on Android and Aerium doesn't — and for sites that pause themselves the moment they're told they've gone to the background, YouTube included, a page that's making sound goes on believing it's still on screen. Only while sound is actually playing: a silent background tab is slowed down and put to sleep exactly as before.
- **Safe Browsing off by default.** It's the one Android feature that phones home to Google on every page you visit. Turn it back on in Settings if you want it.
- **Lighter by default.** Background network chatter — hint prefetching, the Discover feed's background refresh, domain reliability pings — is off out of the box. The name comes from aerogel, the lightest solid there is.
- **Per-site rules for when your data goes.** Under **Settings → Privacy and security → Site rules**, each site can be kept, kept only until you close Aerium, or cleared the moment its last tab closes. There's a switch to invert it — clear *every* site on tab close and treat the list as your exceptions — which is how Cookie AutoDelete works, and a short delay before clearing so a sign-in redirect through a self-closing tab doesn't lose the cookie it was about to use.
- **Downloads on your terms.** Hand a download to ADM, 1DM or another download manager instead of fetching it here (**Settings → Downloads**), and copy any finished download's source link from its ⋮ menu.
- **HTTPS by default.** Balanced Mode upgrades navigations to HTTPS automatically, without the disruptive full-site warnings of strict HTTPS-only enforcement.
- **Global Privacy Control sent by default.** The `Sec-GPC` opt-out signal and `navigator.globalPrivacyControl` — recognized under CCPA, but still not implemented in stock Chromium — are on for every page, no toggle needed.
- **Canvas, text-measurement, and WebGL fingerprinting resistance on by default.** Canvas readbacks and `getClientRects()`/`measureText()` get a barely-perceptible noise; WebGL's renderer/vendor strings return generic values instead of your actual GPU. Same protections Windows Aerium ships, no toggle needed.
- **DRM off by default, your call either way.** Widevine isn't registered unless you turn it on at `chrome://flags/#enable-widevine`.

## Using extensions

Open the [Chrome Web Store](https://chromewebstore.google.com/), switch on **Desktop site** from the <kbd>⋮</kbd> menu, and install as normal. A few worth knowing about, all free and open-source:

- **[uBlock Origin](https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm) (recommended)** — content blocking that doesn't get in your way. Install this one first.
- [**uBlock Origin Lite**](https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh) — same author, same filter lists, a lighter footprint if that's what you'd rather trade for.
- [**floccus**](https://chromewebstore.google.com/detail/floccus-bookmarks-sync/fnaicdffflnofjppbagibeoednhnbjhg) — bookmark sync across browsers, using storage you control.
- [**TablissNG**](https://chromewebstore.google.com/detail/tablissng/dlaogejjiafeobgofajdlkkhjlignalk) — a new tab page worth looking at twice, actively maintained. This is also the answer to "can I set my own New Tab background?" — Aerium ships no setting for it because an extension owning the whole page does the job better than a wallpaper picker would.
- [**Cookie AutoDelete V3**](https://chromewebstore.google.com/detail/cookie-autodelete-v3/jofioghmpdcgiiobkhmdojhjbjiejfbd) — clears a site's cookies once you close its tabs, with a whitelist for the ones you want to keep.
- [**Decentraleyes**](https://chromewebstore.google.com/detail/decentraleyes/ldpochfccmkkmhdbclfhpagapcfdljkj) — serves common libraries locally instead of fetching them from a CDN, cutting a quiet tracking channel most blockers miss.

Opera and Microsoft Edge add-on stores work too. To load an unpacked extension, open **Manage extensions** (`chrome://extensions`), enable **Developer mode**, and choose **Load unpacked**.

Pin an extension's icon to the toolbar from the <kbd>⋮</kbd> menu next to it in the extensions list to reach its popup directly. To allow one in Incognito, go to **Manage extensions → Details** and enable **Allow in Incognito**.

## Why the download is large

The APK is around 300 MB, which is bigger than most browsers. Two reasons, both deliberate.

**Extensions.** Supporting Chrome Web Store extensions on Android means building Chromium's *desktop* browser for Android rather than its phone build, and that carries the whole extension system and desktop UI layer with it. The browser engine alone is roughly 218 MB of the APK. Almost no other Android browser offers extensions; this is what it costs.

**The engine isn't compressed inside the package.** Android can map an uncompressed library straight out of the APK, which starts faster and avoids keeping a second unpacked copy on your device. Compressing it would roughly halve the download and give up both. It also means the installed size is close to the download size rather than double it.

What Aerium does cut is anything it isn't using — around 20 MB of Android XR and ARCore libraries that Chromium packs in by default for features Aerium disables.

## Other things worth knowing

- `chrome://chrome-urls` lists every internal page; `chrome://flags` has the full set of experiments.
- WebRTC IP handling lives under **Settings → Privacy and security**. If a voice service misbehaves because your IP is shielded by default, switch it to **Default public interface only** or **Default**.

## Privacy protections and flags

Most of what other builds put behind a flag, Aerium applies on Android by default. There is no switch to find because there is nothing to turn on:

- **Canvas fingerprinting** — image-data readback and `measureText()` are both perturbed.
- **`getClientRects()` / `getBoundingClientRect()`** — perturbed by a factor drawn once per document.
- **WebGL renderer and vendor** — reported as generic strings rather than your real GPU.
- **CPU core count** — reported as 2 whatever the real number is, with the User-Agent client hints reduced to match.

The flags Aerium adds, at `chrome://flags`:

- `chrome://flags/#aerium-audio-noise` — audio fingerprint deception. **On by default**; this is where you turn it off.
- `chrome://flags/#aerium-time-zone` — tell sites a time zone other than the one your phone is set to. Off by default.
- `chrome://flags/#aerium-local-font-access` — the Local Font Access API, which hands a site your installed font list. Off by default.

And one upstream Chromium flag worth knowing:

- `chrome://flags/#enable-parallel-downloading` — split downloads into simultaneous requests for faster large files.

**If you have read the Windows or Linux README**, its longer list of `#fingerprinting-*`, `#spoof-webgl-info`, `#reduced-system-info`, `#remove-client-hints`, `#force-punycode-hostnames` and similar flags does not apply here, and searching `chrome://flags` for them will find nothing. Those builds are based on ungoogled-chromium and inherit its flag entries; the Android build is based on GrapheneOS's Vanadium, which has no equivalent mechanism. The same protections are compiled in and always on instead. A few of those flags also govern desktop-only UI — the tab-search button, the profile avatar button — which Android does not have.

## Building

Every push to `main` builds automatically on GitHub Actions, split across sequential jobs to fit a full compile inside the free tier's per-job time limit. Every finished build is published as a release.

Want your own signed build?

1. Fork this repository.
2. Generate a signing keystore and add it as two base64-encoded repository secrets, `STORE_TEST_JKS` and `LOCAL_TEST_JKS` (see `common.sh` for the expected format).
3. Run the `Build` workflow from the Actions tab.

## Contributing

Issues and pull requests are welcome. See [UPDATING.md](UPDATING.md) for how the build stays in sync with upstream releases.

## About

Aerium is a fork of [Titanium Browser for Android](https://github.com/jqssun/android-titanium-browser). Licensed under [GPLv2](LICENSE).
