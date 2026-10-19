# Security

Aerium is a spare time project built on Chromium, not a company with its own security team. Keep that in mind when you compare it with a browser that has one.

## Reporting a vulnerability

Please don't open a public issue for a security problem. Report it privately instead:

**[Report a vulnerability](https://github.com/aerium-browser/aerium-browser-core/security/advisories/new)**

That opens an advisory only you and the maintainers can see. Tell us the Aerium version from Settings → About Aerium, your phone and Android version, and the steps to reproduce it. A small test page that shows the problem helps a lot.

Expect an answer within a week, often sooner. Once a fix is out, the advisory is published and you are credited, unless you'd rather stay anonymous.

## What to report here

Anything Aerium adds or changes on top of Chromium. For example:

- Aerogel tabs, site rules or clear on exit leaving data behind
- a way around Aerium Guard, fingerprinting resistance or Global Privacy Control
- the extension installer, backup and restore, or the update check
- the release APKs or the build workflows in this repository

## What to report upstream

If it also happens in Chrome or another Chromium browser, it's a Chromium bug. Report it through [Chromium's security page](https://www.chromium.org/Home/chromium-security/reporting-security-bugs/).

Aerium follows Chromium's stable releases, so upstream security fixes arrive with each new Chromium version.

## Supported versions

Only the latest release gets fixes. Aerium follows Chromium's stable channel, so an older build is missing security fixes no matter what. Please update before reporting.

## Checking a download

Every Aerium APK is signed with the same certificate. Its SHA-256 fingerprint is:

```
CE:1E:D2:FD:85:72:EA:D4:B5:D1:3B:9A:FE:85:DC:89:8C:61:9F:33:E5:D0:E1:9F:18:94:11:54:D1:F3:34:B2
```

[AppVerifier](https://github.com/soupslurpr/AppVerifier) checks it for you, or run `apksigner verify --print-certs` on the file. If an APK calls itself Aerium and shows a different fingerprint, don't install it, and please tell us where you found it.

Newer releases also carry a signed record of how they were made. It proves the APK came from this repository's public build workflow and not from someone's own computer. With the GitHub command line tool installed:

```
gh attestation verify aerium-*.apk --repo aerium-browser/aerium-browser-core
```
