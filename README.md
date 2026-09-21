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

Aerium is a Chromium browser for Android that leaves you alone. Nothing phones home. There is no ad platform wired into the settings page.

Extensions install from the Chrome Web Store, Manifest V2 included. Hardly any Android browser can do that. Kiwi Browser could, until it stopped getting updates in January 2026. Aerium picks that up again, on a Chromium base GrapheneOS has already hardened.

[**Download for Android**](https://github.com/aerium-browser/aerium-browser-android/releases/latest)

## Installing and staying updated

That link gives you an arm64 APK. It is the right one for almost any phone or tablet from the last several years. Other ways to get it and keep it current:

- **[Obtainium](https://github.com/ImranR98/Obtainium)**. Add this repository (`aerium-browser/aerium-browser-android`) as an app source. Obtainium then watches for releases and offers you the update, so you never have to check GitHub. You sideload Obtainium itself, from F-Droid or its own releases page, which suits a de-googled phone better than an app store does.
- **x86_64**, for emulators, x86 tablets and Chromebooks running Android apps. This one is deliberately kept off the main release feed, so the in-app updater never hands an arm64 phone an APK it cannot install. Look on the [releases page](https://github.com/aerium-browser/aerium-browser-android/releases) for a tag with `-x64-` in it. These are built on request rather than every version, so open an issue if the newest is too old.
- Aerium checks for a new release once a day by itself and tells you when there is one. You open **Settings** to start the update. Nothing else is needed.

## What you get

- **Extensions that actually work.** Manifest V2 and the Chrome Web Store, plus the Opera and Microsoft Edge add-on stores. You can also load a `.crx` from a GitHub release, which is usually where an extension lives if it is on no store at all. You still get the permissions prompt before anything installs.
- **Your password manager, working properly.** Android's autofill framework is on by default. Bitwarden and the rest fill forms natively instead of falling back on flaky accessibility tricks.
- **Search that works from the first keystroke.** DuckDuckGo is the default. Startpage, Brave Search, Mojeek, Qwant, Ecosia, degoog and the two DuckDuckGo no-JS variants are all there in Settings, and you can add your own.
- **Its own look, and a true black dark mode.** Aerium ships a palette of its own rather than pulling colours off your wallpaper. Dark mode goes fully black if you want it, and on an OLED screen a black pixel is simply off and costs nothing. The browser and web pages have separate switches, under **Settings → Appearance → Theme**.
- **Media that keeps playing.** Switch apps or turn the screen off and the audio carries on. Chromium suspends media in a hidden page on Android. Aerium does not. Some sites pause themselves the moment they are told they have gone to the background, YouTube among them, so a page making sound is allowed to go on believing it is still on screen. This only holds while sound is actually playing. A silent background tab still gets throttled and put to sleep exactly as before.
- **Safe Browsing off by default.** It is the one Android feature that reports to Google on every page you open. Turn it back on in Settings if you want it.
- **Lighter by default.** Background chatter is off out of the box: hint prefetching, the Discover feed's background refresh, domain reliability pings. The name comes from aerogel, the lightest solid there is.
- **Per-site rules for when your data goes.** Under **Settings → Privacy and security → Site rules** you can keep a site, keep it only until you close Aerium, or clear it the moment its last tab closes. A switch inverts the whole thing: clear *every* site on tab close and treat your list as the exceptions, the way Cookie AutoDelete does it. Clearing waits a moment first, so a sign-in that redirects through a self-closing tab does not lose the cookie it was about to use.
- **Downloads on your terms.** Hand a download off to ADM, 1DM or another manager instead of fetching it here, under **Settings → Downloads**. You can copy any finished download's source link from its ⋮ menu.
- **HTTPS by default.** Balanced Mode upgrades navigations to HTTPS on its own, without the full-site warnings that make strict HTTPS-only so disruptive.
- **Global Privacy Control sent by default.** The `Sec-GPC` opt-out signal and `navigator.globalPrivacyControl` go out on every page, with no toggle to find. CCPA recognises them. Stock Chromium still does not implement them.
- **Canvas, text measurement and WebGL fingerprinting resistance on by default.** Canvas readbacks, `getClientRects()` and `measureText()` all get noise you will never notice. WebGL reports generic renderer and vendor strings rather than your actual GPU. Nothing to switch on.
- **DRM off by default, your call either way.** Widevine is not registered until you turn it on in **Settings → Media**, and nothing is fetched from Google until you do.

## Using extensions

Open the [Chrome Web Store](https://chromewebstore.google.com/), turn on **Desktop site** from the <kbd>⋮</kbd> menu, and install as you normally would. A few worth knowing about, all free and open source:

- **[uBlock Origin](https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm) (recommended)**, or its [latest release straight from GitHub](https://github.com/gorhill/uBlock/releases/latest) if you'd rather sideload it. Content blocking that doesn't get in your way. Install this one first.
- [**uBlock Origin Lite**](https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh), from the same author with the same filter lists, a lighter footprint if that's what you'd rather trade for.
- [**floccus**](https://chromewebstore.google.com/detail/floccus-bookmarks-sync/fnaicdffflnofjppbagibeoednhnbjhg), for bookmark sync across browsers using storage you control.
- [**TablissNG**](https://chromewebstore.google.com/detail/tablissng/dlaogejjiafeobgofajdlkkhjlignalk), a new tab page worth looking at twice, actively maintained. Android ships no new tab page of its own: install one of these and Chromium's own `chrome_url_overrides.newtab` mechanism hands the page over to it, which upstream gates behind a flag that assumes extensions are desktop-only and this build turns on. With none installed, a new tab is the search box and nothing else, and the history-derived Most Visited tiles stay suppressed either way.
- [**Cookie AutoDelete V3**](https://chromewebstore.google.com/detail/cookie-autodelete-v3/jofioghmpdcgiiobkhmdojhjbjiejfbd), which clears a site's cookies once you close its tabs, with a whitelist for the ones you want to keep.
- [**Decentraleyes**](https://chromewebstore.google.com/detail/decentraleyes/ldpochfccmkkmhdbclfhpagapcfdljkj), which serves common libraries locally instead of fetching them from a CDN, cutting a quiet tracking channel most blockers miss.

Opera and Microsoft Edge add-on stores work too. To load an unpacked extension, open **Manage extensions** (`chrome://extensions`), enable **Developer mode**, and choose **Load unpacked**.

Pin an extension's icon to the toolbar from the <kbd>⋮</kbd> menu next to it in the extensions list to reach its popup directly. To allow one in Incognito, go to **Manage extensions → Details** and enable **Allow in Incognito**.

## Why the download is large

The APK runs to about 300 MB, well above most browsers. There are two reasons for it, and neither is an accident.

**Extensions.** Running Chrome Web Store extensions on Android means building Chromium's *desktop* browser for Android instead of its phone build. That drags in the entire extension system and the desktop UI layer. The engine alone accounts for roughly 218 MB. Almost no other Android browser offers extensions at all, and this is the price of it.

**The engine is not compressed inside the package.** Android can map an uncompressed library straight out of the APK. It starts faster that way, and your phone does not end up storing a second unpacked copy. Compressing it would roughly halve the download and cost you both of those. It also keeps the installed size close to the download size instead of nearly doubling it.

What Aerium does strip out is anything it never touches, including about 20 MB of Android XR and ARCore libraries that Chromium packs in by default for features this build disables anyway.

## Other things worth knowing

- `chrome://chrome-urls` lists every internal page; `chrome://flags` has the full set of experiments.
- WebRTC IP handling lives under **Settings → Privacy and security**. If a voice service misbehaves because your IP is shielded by default, switch it to **Default public interface only** or **Default**.

## Privacy protections and flags

Most of what other builds hide behind a flag is simply on here. There is no switch to hunt for because there is nothing to turn on:

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

Earlier versions of this file listed a dozen flags under *More privacy flags to consider*. That list came straight from the desktop builds, and most of it was never true here. Those builds are based on ungoogled-chromium and inherit its flag entries. This one is based on GrapheneOS's Vanadium and inherits none of them. Search `chrome://flags` for those names and you find nothing, which is why `#enable-parallel-downloading` was the only one anyone could ever locate: it came from upstream Chromium, not from ungoogled.

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

The four marked *ported* carry ungoogled-chromium's own flag names, and are off by default. The rest of ungoogled-chromium's flag set is either desktop-only UI or still to come; open an issue naming one if you want it next.

## Building

Every push to `main` kicks off a build on GitHub Actions. It is split across sequential jobs so a full compile fits inside the free tier's per-job time limit. Whatever finishes gets published as a release.

Want your own signed build?

1. Fork this repository.
2. Generate a signing keystore and add it as two base64-encoded repository secrets, `STORE_TEST_JKS` and `LOCAL_TEST_JKS` (see `common.sh` for the expected format).
3. Run the `Build` workflow from the Actions tab.

## Contributing

Issues and pull requests are welcome. [UPDATING.md](UPDATING.md) covers how the build keeps up with upstream releases.

## Credits

Aerium is a thin layer over other people's work. Full attribution and licence terms live in [NOTICE](NOTICE).

- **[Chromium](https://www.chromium.org/)** is the browser. Everything here is a modification of its source, under its **BSD-3-Clause** licence.
- **[Vanadium](https://github.com/GrapheneOS/Vanadium)**, by GrapheneOS, is the hardened base. Its 312 patches go on before any of Aerium's own. They are **GPL-2.0-only**, and that is why Aerium is GPLv2. The licence was inherited, not picked.
- **[ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium)** is where several of the `chrome://flags` entries get their names and their behaviour.
- **[Cromite](https://github.com/uazo/cromite)**, by uazo, is where two DNS-over-HTTPS fixes come from: minimal DoH request headers, per RFC 8484, and building a DoH config when the system DNS configuration cannot be read. On Android, behind a VPN or Private DNS, that happens all the time.
- **[Bromite](https://github.com/bromite/bromite)** wrote the canvas fingerprinting shuffler.
- **[Titanium Browser](https://github.com/jqssun/android-titanium-browser)**, by jqssun, formerly Helium. Aerium's whole premise, a Vanadium base carrying desktop extensions on Android, is Titanium's. So are `patch.sh`, `common.sh` and `args.gn`, which began as its scripts and are still synced against it by hand. `theme.sh`, `build.sh`, the icons and the CI are Aerium's own.

The Aerium name, logo and application id are not covered by the GPLv2 grant. See the trademarks section of [NOTICE](NOTICE). The code is yours to take. The identity is not. Fork it under your own name.

## About

Aerium is built on [GrapheneOS's Vanadium](https://github.com/GrapheneOS/Vanadium), starting from [Titanium Browser](https://github.com/jqssun/android-titanium-browser)'s scripts for putting desktop extensions on Android, with its own branding, defaults and privacy flags on top. Licensed under [GPLv2](LICENSE).
