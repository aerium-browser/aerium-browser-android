# Security Policy

Aerium is maintained by a small, independent team on top of [Vanadium](https://github.com/GrapheneOS/Vanadium) and Chromium, syncing with upstream on a best-effort basis (see [UPDATING.md](UPDATING.md)) rather than on the schedule of a vendor with a dedicated security team. Keep that in mind if you're weighing Aerium against a browser with that kind of backing.

## Reporting a vulnerability

If you find a security issue in code specific to Aerium — the changes in `theme.sh`/`patch.sh`, the signing/build pipeline, or the branding pass — please don't open a public issue. Instead, use [GitHub Security Advisories](https://github.com/aerium-browser/aerium-browser-android/security/advisories/new) for this repo.

Include the affected version, a description of the issue, and reproduction steps if you have them. This is maintained in spare time, so please allow a reasonable window for a response.

## Out of scope

Vulnerabilities in Chromium itself or in Vanadium's own patches aren't Aerium-specific — report those upstream instead:

- Chromium: the [Chromium Security page](https://www.chromium.org/Home/chromium-security/reporting-security-bugs/)
- Vanadium / GrapheneOS: [their issue tracker](https://github.com/GrapheneOS/Vanadium/issues)

Aerium pulls in upstream fixes on the cadence described in [UPDATING.md](UPDATING.md), not immediately on disclosure.
