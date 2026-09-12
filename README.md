<p align="center">
  <img src="res/aerium.svg" width="96" height="96" alt="Aerium logo">
</p>

<h1 align="center">Aerium</h1>

<p align="center"><i>by Dioide</i></p>

[![release](https://img.shields.io/github/v/release/aerium-browser/aerium-browser-android)](https://github.com/aerium-browser/aerium-browser-android/releases/latest)
[![released](https://img.shields.io/github/release-date/aerium-browser/aerium-browser-android?label=released)](https://github.com/aerium-browser/aerium-browser-android/releases/latest)
[![downloads](https://img.shields.io/github/downloads/aerium-browser/aerium-browser-android/total?label=downloads)](https://github.com/aerium-browser/aerium-browser-android/releases)
[![license](https://img.shields.io/badge/License-GPLv2-blue.svg)](LICENSE)
[![Donate XMR](https://img.shields.io/badge/XMR-Donate-FF6600?logo=monero&logoColor=white)](https://aerium-browser.github.io/donate/xmr)
[![Donate LTC](https://img.shields.io/badge/LTC-Donate-345D9D?logo=litecoin&logoColor=white)](https://aerium-browser.github.io/donate/ltc)

### Support Aerium

Aerium runs on donations and spare time: no ads, no data sales. Scan or copy an address to help keep it going.

<p align="center">
<a href="https://aerium-browser.github.io/donate/xmr">
<img src="donate/xmr-qr.png" width="120" height="120" alt="Monero donation QR code">
<br><b>Monero (XMR)</b>
</a>
<br><a href="https://aerium-browser.github.io/donate/xmr"><code>49TPHGjCk52cr6f8LWwDrwAvCWmXWfVPy5DUt7KTEnLBfsm6xa9bUgaAVV5xYU6LH5WcoRNYZZSBuAjHFuVHFUDpRm6tKFA</code></a>
</p>

<p align="center">
<a href="https://aerium-browser.github.io/donate/ltc">
<img src="donate/ltc-qr.png" width="120" height="120" alt="Litecoin donation QR code">
<br><b>Litecoin (LTC)</b>
</a>
<br><a href="https://aerium-browser.github.io/donate/ltc"><code>ltc1q8cpevsanzlmuc0ja8d0eltj72qk55nu7dty59v</code></a>
</p>

Aerium is a browser for people who'd rather their browser stayed out of the way. No telemetry calling home, no ad platform baked into the settings page. Extensions, including Manifest V2, install straight from the Chrome Web Store, something most Android browsers still can't do.

[**Download for Android**](https://github.com/aerium-browser/aerium-browser-android/releases/latest)

## What you get

- **Extensions that actually work.** Manifest V2 support and Chrome Web Store access, plus Opera and Microsoft Edge add-on stores, and `.crx` files straight from a GitHub release, which is where an extension that is on no store usually lives. You still see the permissions prompt before anything installs.
- **Your password manager, working properly.** Android's own autofill framework is on by default, so Bitwarden and similar apps fill forms natively instead of falling back to flaky accessibility tricks.
- **Search that works from the first keystroke.** DuckDuckGo is the default engine, with Startpage, Brave Search, Mojeek, Qwant, Ecosia, degoog and the two DuckDuckGo no-JS variants ready to pick in Settings, plus any other engine addable by hand.
- **Its own look, and a true-black dark mode.** Aerium ships its own palette instead of taking colours from your wallpaper. Dark mode can go fully black: on an OLED screen a black pixel is switched off and draws no power. There are separate switches for the browser itself and for web pages under **Settings → Appearance → Theme**.
- **Media that keeps playing.** Leave the browser or turn the screen off and video and audio carry on. Chromium suspends media in a hidden page on Android, and Aerium doesn't. For sites that pause themselves the moment they're told they've gone to the background, YouTube included, a page that's making sound goes on believing it's still on screen. This only applies while sound is actually playing: a silent background tab is slowed down and put to sleep exactly as before.
- **Safe Browsing off by default.** It's the one Android feature that phones home to Google on every page you visit. Turn it back on in Settings if you want it.
- **Lighter by default.** Background network chatter, including hint prefetching, the Discover feed's background refresh, and domain reliability pings, is off out of the box. The name comes from aerogel, the lightest solid there is.
- **Per-site rules for when your data goes.** Under **Settings → Privacy and security → Site rules**, each site can be kept, kept only until you close Aerium, or cleared the moment its last tab closes. There's a switch to invert it: clear *every* site on tab close and treat the list as your exceptions, which is how Cookie AutoDelete works. A short delay before clearing means a sign-in redirect through a self-closing tab doesn't lose the cookie it was about to use.
- **Downloads on your terms.** Hand a download to ADM, 1DM or another download manager instead of fetching it here (**Settings → Downloads**), and copy any finished download's source link from its ⋮ menu.
- **HTTPS by default.** Balanced Mode upgrades navigations to HTTPS automatically, without the disruptive full-site warnings of strict HTTPS-only enforcement.
- **Global Privacy Control sent by default.** The `Sec-GPC` opt-out signal and `navigator.globalPrivacyControl`, recognized under CCPA but still not implemented in stock Chromium, are on for every page, no toggle needed.
- **Canvas, text-measurement, and WebGL fingerprinting resistance on by default.** Canvas readbacks and `getClientRects()`/`measureText()` get a barely-perceptible noise; WebGL's renderer/vendor strings return generic values instead of your actual GPU. Same protections Windows Aerium ships, no toggle needed.
- **DRM off by default, your call either way.** Widevine isn't registered until you turn it on in **Settings → Media**. Nothing is fetched from Google until you flip that switch.

## Using extensions

Open the [Chrome Web Store](https://chromewebstore.google.com/), switch on **Desktop site** from the <kbd>⋮</kbd> menu, and install as normal. A few worth knowing about, all free and open-source:

- **[uBlock Origin](https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm) (recommended)**, or its [latest release straight from GitHub](https://github.com/gorhill/uBlock/releases/latest) if you'd rather sideload it. Content blocking that doesn't get in your way. Install this one first.
- [**uBlock Origin Lite**](https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh), from the same author with the same filter lists, a lighter footprint if that's what you'd rather trade for.
- [**floccus**](https://chromewebstore.google.com/detail/floccus-bookmarks-sync/fnaicdffflnofjppbagibeoednhnbjhg), for bookmark sync across browsers using storage you control.
- [**TablissNG**](https://chromewebstore.google.com/detail/tablissng/dlaogejjiafeobgofajdlkkhjlignalk), a new tab page worth looking at twice, actively maintained. This is also the answer to "can I set my own New Tab background?" Aerium ships no setting for it, because an extension owning the whole page does the job better than a wallpaper picker would.
- [**Cookie AutoDelete V3**](https://chromewebstore.google.com/detail/cookie-autodelete-v3/jofioghmpdcgiiobkhmdojhjbjiejfbd), which clears a site's cookies once you close its tabs, with a whitelist for the ones you want to keep.
- [**Decentraleyes**](https://chromewebstore.google.com/detail/decentraleyes/ldpochfccmkkmhdbclfhpagapcfdljkj), which serves common libraries locally instead of fetching them from a CDN, cutting a quiet tracking channel most blockers miss.

Opera and Microsoft Edge add-on stores work too. To load an unpacked extension, open **Manage extensions** (`chrome://extensions`), enable **Developer mode**, and choose **Load unpacked**.

Pin an extension's icon to the toolbar from the <kbd>⋮</kbd> menu next to it in the extensions list to reach its popup directly. To allow one in Incognito, go to **Manage extensions → Details** and enable **Allow in Incognito**.

## Why the download is large

The APK is around 300 MB, which is bigger than most browsers. Two reasons, both deliberate.

**Extensions.** Supporting Chrome Web Store extensions on Android means building Chromium's *desktop* browser for Android rather than its phone build, and that carries the whole extension system and desktop UI layer with it. The browser engine alone is roughly 218 MB of the APK. Almost no other Android browser offers extensions; this is what it costs.

**The engine isn't compressed inside the package.** Android can map an uncompressed library straight out of the APK, which starts faster and avoids keeping a second unpacked copy on your device. Compressing it would roughly halve the download and give up both benefits, and it also means the installed size stays close to the download size rather than doubling it.

What Aerium does cut is anything it isn't using: around 20 MB of Android XR and ARCore libraries that Chromium packs in by default for features Aerium disables.

## Other things worth knowing

- `chrome://chrome-urls` lists every internal page; `chrome://flags` has the full set of experiments.
- WebRTC IP handling lives under **Settings → Privacy and security**. If a voice service misbehaves because your IP is shielded by default, switch it to **Default public interface only** or **Default**.

## Privacy protections and flags

Most of what other builds put behind a flag, Aerium applies on Android by default. There is no switch to find because there is nothing to turn on:

- **Canvas fingerprinting**: image-data readback and `measureText()` are both perturbed.
- **`getClientRects()` / `getBoundingClientRect()`**: perturbed by a factor drawn once per document.
- **WebGL renderer and vendor**: reported as generic strings rather than your real GPU.
- **CPU core count**: reported as 2 whatever the real number is, with the User-Agent client hints reduced to match.

The flags Aerium adds, at `chrome://flags`:

- `chrome://flags/#aerium-audio-noise`: audio fingerprint deception, on by default. This is where you turn it off.
- `chrome://flags/#aerium-time-zone`: tell sites a time zone other than the one your phone is set to. Off by default.
- `chrome://flags/#aerium-local-font-access`: the Local Font Access API, which hands a site your installed font list. Off by default.

Ported from the desktop builds, same names, all off by default:

- `chrome://flags/#disable-search-engine-collection`: stop Aerium adding a search engine for every site that offers one.
- `chrome://flags/#force-punycode-hostnames`: show an internationalized domain as its punycode, so a lookalike name cannot pass for another site. Costs readability on every legitimate non-Latin domain.
- `chrome://flags/#increase-incognito-storage-quota`: work out the incognito storage quota the way a normal profile does, which is one of the numbers a site reads to detect incognito.
- `chrome://flags/#remove-client-hints`: stop sending client hints, and hand `navigator.userAgentData` nothing to report.
- `chrome://flags/#disable-grease-tls`: stop sending GREASE, the deliberately unknown values Chromium puts in the TLS handshake.
- `chrome://flags/#keep-old-history`: stop deleting history older than 90 days. There is no setting for that anywhere else.
- `chrome://flags/#http-accept-header`: replace the `Accept` header sent with every navigation. Empty means the default.
- `chrome://flags/#enforce-certificate-transparency`: already **on** here; this is how you turn it off if a certificate you trust has no SCTs.
- `chrome://flags/#enable-low-end-device-mode`: treat this device as low-end whatever its memory, with smaller caches and fewer renderer processes.
- `chrome://flags/#disable-beforeunload`: stop pages putting up a *Leave site?* dialog when you navigate away.
- `chrome://flags/#set-ipv6-probe-false`: tell the resolver IPv6 is unreachable without probing for it, putting IPv4 first.
- `chrome://flags/#max-connections-per-host`: raise the six simultaneous connections per host Chromium allows to fifteen, which is what Firefox uses.

Some things the desktop builds put behind a flag are **settings** here, because Vanadium built them that way and a setting is the better surface:

- **Cross-origin referrers**, under Settings → Privacy and security. Default, *Reduce* (cross-origin referrers capped to the origin), or *Disable* (none at all). This is what the desktop `#remove-cross-origin-referrers` and `#minimal-referrers` flags do.
- **JavaScript JIT**, a per-site setting with a page-info toggle, rather than the desktop `#disable-jit` flag's single global switch.
- **Delete browsing data when you close Aerium**, under Settings → Privacy and security, with eight data types, in place of the desktop `#clear-data-on-exit` flag.

And one upstream Chromium flag worth knowing:

- `chrome://flags/#enable-parallel-downloading`: split downloads into simultaneous requests for faster large files.

### The list this README used to carry

Earlier versions of this file listed a dozen flags under *More privacy flags to consider*. That list was copied from the desktop builds, and most of it was never true here: the desktop builds are based on ungoogled-chromium and inherit its flag entries, while this one is based on GrapheneOS's Vanadium and has none of them. Searching `chrome://flags` for those names finds nothing, which is why `#enable-parallel-downloading`, the only entry that came from upstream Chromium rather than from ungoogled, was the only one anybody could find.

What actually happened to each:

| Old entry | On Android |
| --- | --- |
| `#enable-parallel-downloading` | Real. Upstream Chromium, still there. |
| `#fingerprinting-canvas-image-data-noise` | No flag. Compiled in and always on. |
| `#fingerprinting-canvas-measuretext-noise` | No flag. Compiled in and always on. |
| `#fingerprinting-client-rects-noise` | No flag. Compiled in and always on. |
| `#spoof-webgl-info` | No flag. Compiled in and always on. |
| `#reduced-system-info` | No flag. Two of its three effects are compiled in: two CPU cores whatever the real count, and client hints reduced to match the reduced User-Agent. |
| `#remove-client-hints` | **Ported.** Not the same as the line above: that derives the hints from the reduced User-Agent, this stops sending them. |
| `#remove-tabsearch-button` | Desktop-only UI. Android has no tab strip. |
| `#show-avatar-button` | Desktop-only UI. Android has no avatar button. |
| `#disable-search-engine-collection` | **Ported.** |
| `#force-punycode-hostnames` | **Ported.** |
| `#increase-incognito-storage-quota` | **Ported.** |
| `#popups-to-tabs` | Nothing to port. Chrome on Android has no popup windows; `window.open` with features already lands in a tab. |

The four marked *ported* now carry the same flag name they have on Windows and Linux, and are off by default there and here. The rest of ungoogled-chromium's flag set is either desktop-only UI or still to come; open an issue naming one if you want it next.

## Building

Every push to `main` builds automatically on GitHub Actions, split across sequential jobs to fit a full compile inside the free tier's per-job time limit. Every finished build is published as a release.

Want your own signed build?

1. Fork this repository.
2. Generate a signing keystore and add it as two base64-encoded repository secrets, `STORE_TEST_JKS` and `LOCAL_TEST_JKS` (see `common.sh` for the expected format).
3. Run the `Build` workflow from the Actions tab.

## Contributing

Issues and pull requests are welcome. See [UPDATING.md](UPDATING.md) for how the build stays in sync with upstream releases.

## About

Aerium is built on [GrapheneOS's Vanadium](https://github.com/GrapheneOS/Vanadium), following the desktop-extensions approach pioneered by [Titanium Browser](https://github.com/jqssun/android-titanium-browser), with Aerium's own branding, defaults, and privacy-parity flags layered on top. Licensed under [GPLv2](LICENSE).
