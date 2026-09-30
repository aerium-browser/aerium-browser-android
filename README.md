<p align="center">
  <img src="res/aerium.svg" width="96" height="96" alt="Aerium logo">
</p>

<h1 align="center">Aerium</h1>

<p align="center">
  <b>The browser that stays out of the way.</b><br>
  Desktop extensions on Android. No big tech inside.
</p>

<p align="center">
  <a href="https://github.com/aerium-browser/aerium-browser-android/releases/latest"><b>Download for Android</b></a>
  &nbsp;·&nbsp;
  <a href="https://aerium-browser.github.io">Website</a>
  &nbsp;·&nbsp;
  <a href="CHANGELOG.md">Changelog</a>
</p>

<p align="center">
  <a href="https://github.com/aerium-browser/aerium-browser-android/releases/latest"><img src="https://img.shields.io/github/v/release/aerium-browser/aerium-browser-android?color=1b2c5e&label=release" alt="Latest release"></a>
  <a href="https://github.com/aerium-browser/aerium-browser-android/releases"><img src="https://img.shields.io/github/downloads/aerium-browser/aerium-browser-android/total?color=1b2c5e&label=downloads" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--2.0-1b2c5e" alt="License GPL-2.0"></a>
</p>

<p align="center">
  <img src="https://aerium-browser.github.io/shots/new-tab.webp" width="200" alt="Aerium new tab page in true black">
  <img src="https://aerium-browser.github.io/shots/extensions.webp" width="200" alt="Aerium extensions menu with uBlock Origin and floccus">
  <img src="https://aerium-browser.github.io/shots/settings-guard.webp" width="200" alt="Aerium settings with Aerium Guard">
  <img src="https://aerium-browser.github.io/shots/settings-backup.webp" width="200" alt="Aerium settings with backup and restore">
</p>

## Extensions, finally.

uBlock Origin, floccus and other open-source extensions. Manifest V2 included.

Open the [extension store](https://chromewebstore.google.com/), turn on **Desktop site** from the <kbd>⋮</kbd> menu, and install as usual. The Opera and Edge add-on stores work too, and so does a `.crx` from a release page. You still get the permissions prompt before anything installs.

Worth installing, all free and open source:

- **[uBlock Origin](https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm)**, or [straight from its releases](https://github.com/gorhill/uBlock/releases/latest). Install this one first.
- **[uBlock Origin Lite](https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh)**, same author and filter lists, lighter footprint.
- **[floccus](https://chromewebstore.google.com/detail/floccus-bookmarks-sync/fnaicdffflnofjppbagibeoednhnbjhg)**, bookmark sync on storage you control.
- **[TablissNG](https://chromewebstore.google.com/detail/tablissng/dlaogejjiafeobgofajdlkkhjlignalk)**, a new tab page that takes over the default one.
- **[Cookie AutoDelete V3](https://chromewebstore.google.com/detail/cookie-autodelete-v3/jofioghmpdcgiiobkhmdojhjbjiejfbd)**, clears a site's cookies once its tabs close.
- **[Decentraleyes](https://chromewebstore.google.com/detail/decentraleyes/ldpochfccmkkmhdbclfhpagapcfdljkj)**, serves common libraries locally instead of from a CDN.

Pin an extension to the toolbar from its <kbd>⋮</kbd> menu in the extensions list. To allow one in Incognito, open **Manage extensions → Details → Allow in Incognito**.

## Private by default.

- **Nothing phones home.** No telemetry, no background chatter.
- **Aerium Guard** sets privacy, security and speed options in one place.
- **Safe Browsing and DRM stay off** until you turn them on.
- **Global Privacy Control** is sent on every page.
- **Fingerprinting resistance** for canvas, text measurement and WebGL, always on.
- **HTTPS by default** through Balanced Mode, without full-page warnings.
- **Site rules**: keep a site, keep it until you close Aerium, or clear it when its last tab closes.

## Made for every day.

- **True black dark mode.** On OLED, a black pixel is simply off.
- **Media keeps playing** when you switch apps or turn the screen off.
- **Password managers fill natively** through Android autofill.
- **Take it with you.** Back up open tabs, site permissions, settings and flags, and restore them on any phone.
- **Downloads on your terms.** Hand them off to your download manager.
- **Your search engine.** A privacy-respecting default, more in Settings, or add your own.

## Named after aerogel.

The lightest solid there is, up to 99% air. Aerium keeps only what matters.

## Install and update

- **[Download the arm64 APK](https://github.com/aerium-browser/aerium-browser-android/releases/latest)**. It fits almost any phone or tablet from the last several years.
- **Updates**: Aerium checks once a day and tells you when a new version is ready. Or add this repository to **[Obtainium](https://github.com/ImranR98/Obtainium)** as an app source.
- **x86_64**, for emulators, x86 tablets and Chromebooks: look for a `-x64-` tag on the [releases page](https://github.com/aerium-browser/aerium-browser-android/releases). Built on request, so open an issue if the newest is too old.

## Why the download is large

The APK is about 300 MB, for two reasons.

**Extensions.** Running desktop extensions means building the desktop browser for Android instead of the phone build, which brings in the whole extension system and desktop UI layer. The engine alone is roughly 218 MB.

**The engine is stored uncompressed.** Android maps it straight out of the APK, so it starts faster and your phone never keeps a second unpacked copy. The installed size stays close to the download size.

Anything the build never touches is stripped, including about 20 MB of XR and AR libraries.

<details>
<summary><b>Privacy protections and flags</b></summary>

<br>

Always on, nothing to switch:

- **Canvas fingerprinting**: image-data readback and `measureText()` are perturbed.
- **`getClientRects()` / `getBoundingClientRect()`**: perturbed by a factor drawn once per document.
- **WebGL renderer and vendor**: reported as generic strings.
- **CPU core count**: reported as 2, with User-Agent client hints reduced to match.

Aerium's own flags:

- `chrome://flags/#aerium-audio-noise`: audio fingerprint deception, on by default.
- `chrome://flags/#aerium-time-zone`: report a different time zone to sites. Off by default.
- `chrome://flags/#aerium-local-font-access`: the Local Font Access API. Off by default.

Ported from the desktop builds, all off by default:

- `#disable-search-engine-collection`: stop adding a search engine for every site that offers one.
- `#force-punycode-hostnames`: show internationalized domains as punycode.
- `#increase-incognito-storage-quota`: hide one of the numbers sites read to detect incognito.
- `#remove-client-hints`: stop sending client hints.
- `#disable-grease-tls`: stop sending GREASE values in the TLS handshake.
- `#keep-old-history`: keep history older than 90 days.
- `#http-accept-header`: replace the `Accept` header sent with navigations.
- `#enforce-certificate-transparency`: already **on**; turn it off here if needed.
- `#enable-low-end-device-mode`: smaller caches and fewer renderer processes.
- `#disable-beforeunload`: no more *Leave site?* dialogs.
- `#set-ipv6-probe-false`: prefer IPv4 without probing IPv6.
- `#max-connections-per-host`: raise simultaneous connections per host from six to fifteen.

Settings rather than flags:

- **Cross-origin referrers** under Settings → Privacy and security: Default, *Reduce* or *Disable*.
- **JavaScript JIT** as a per-site setting with a page-info toggle.
- **Delete browsing data when you close Aerium** under Settings → Privacy and security.
- **WebRTC IP handling** under Settings → Privacy and security. If a voice service misbehaves, switch it to **Default public interface only** or **Default**.

Also useful: `chrome://flags/#enable-parallel-downloading` splits large downloads into simultaneous requests, and `chrome://chrome-urls` lists every internal page.

</details>

## Support Aerium

Aerium runs on donations and spare time. No ads, no data sales.

<table align="center">
  <tr>
    <td align="center">
      <a href="https://aerium-browser.github.io/donate/xmr/"><img src="donate/xmr-qr.png" width="140" height="140" alt="Monero donation QR code"></a><br>
      <a href="https://aerium-browser.github.io/donate/xmr/"><b>Donate Monero</b></a>
    </td>
    <td align="center">
      <a href="https://aerium-browser.github.io/donate/ltc/"><img src="donate/ltc-qr.png" width="140" height="140" alt="Litecoin donation QR code"></a><br>
      <a href="https://aerium-browser.github.io/donate/ltc/"><b>Donate Litecoin</b></a>
    </td>
  </tr>
</table>

## Building

Every push to `main` that changes the build starts one on GitHub Actions, split across sequential jobs so a full compile fits the free tier's time limit. Finished builds are published as releases.

For your own signed build: fork this repository, add a signing keystore as the base64-encoded secrets `STORE_TEST_JKS` and `LOCAL_TEST_JKS` (see `common.sh`), and run the `Build` workflow from the Actions tab.

Issues and pull requests are welcome. [UPDATING.md](UPDATING.md) covers how the build keeps up with upstream releases.

## Credits

Aerium is a thin layer over other people's open-source work. Full attribution and licence terms are in [NOTICE](NOTICE).

- **[Chromium](https://www.chromium.org/)** is the browser, under its **BSD-3-Clause** licence.
- **[Vanadium](https://github.com/GrapheneOS/Vanadium)**, by GrapheneOS, is the hardened base. Its patches are **GPL-2.0-only**, which is why Aerium is GPLv2.
- **[Titanium Browser](https://github.com/jqssun/android-titanium-browser)**, by jqssun, is where the idea of desktop extensions on a Vanadium base comes from, along with `patch.sh`, `common.sh` and `args.gn`.
- **[ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium)** is where several flag names and behaviours come from.
- **[Cromite](https://github.com/uazo/cromite)**, by uazo, contributed two DNS-over-HTTPS fixes.
- **[Bromite](https://github.com/bromite/bromite)** wrote the canvas fingerprinting shuffler.

The Aerium name, logo and application id are not covered by the GPLv2 grant; see the trademarks section of [NOTICE](NOTICE). The code is yours to take. The identity is not, so fork it under your own name.
