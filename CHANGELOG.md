# Changelog

Written for people using Aerium rather than for people building it. Each
release on GitHub also links the full commit history if you want the detail
behind any of this.

## 152.0.7977.64

**Security**

- Updated to Chromium 152.0.7977.64, which brings upstream's latest security
  fixes.

**A look of its own**

- Aerium now uses its own colours instead of picking them up from your phone's
  wallpaper, so it looks like Aerium on every device.
- Dark mode reaches two places it was missing before: Incognito, and the
  toolbar on the fast "warm start" path. Both used to stay grey while the rest
  of the browser went black.

**Dark mode on web pages**

- **Settings → Appearance → Theme → Darken websites** now gives true black on
  every page. Pages with a plain white background already went black; pages
  with any tint kept a grey cast, and no longer do.
- A new switch beside it, off by default: **Blacken dark sites** extends the
  same treatment to sites that ship their own dark theme. YouTube and Reddit
  are the obvious ones — their dark grey still lights every pixel on an OLED
  screen.
- Changing either switch now offers to restart the browser. They only take
  effect on a restart, and previously nothing said so, which made them look
  broken.

**Smaller download**

- About 20 MB lighter. Chromium packs in Android XR and ARCore libraries by
  default; Aerium has those features switched off and now leaves the libraries
  out too.

## 152.0.7977.54

**Appearance**

- New pure-black dark mode for OLED screens, under **Settings → Appearance →
  Theme**. A black pixel on an OLED panel is switched off and draws no power.
- Launcher icon reworked: no more white corners, and the monochrome and colour
  versions are now sized to match the rest of your home screen.

**First run**

- The welcome page now links straight to Bitwarden, Proton Pass and KeePassDX
  rather than only naming them.

**Elsewhere**

- Legal information credits Aerium and Dioide instead of carrying Chromium's
  original notice.
