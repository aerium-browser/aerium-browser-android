# Changelog

Written for people using Aerium rather than for people building it. Each
release on GitHub also links the full commit history if you want the detail
behind any of this.

## 152.0.7977.82 (next release)

**Search**

- DuckDuckGo is now the default engine, with Startpage second. Existing
  installs keep whichever engine they are already using.
- degoog (degoog.org) replaces the SearXNG entry, and Brave Search, Mojeek,
  Qwant and Ecosia join the list.

**Secure DNS**

- **Settings › Privacy and security › Use secure DNS** gains Mullvad and
  Mullvad's ad-blocking resolver, and finally shows Quad9 and NextDNS - the
  first was hidden behind a disabled feature flag, the second was restricted to
  the United States.
- Google Public DNS is gone from that menu. It was the one place in a
  de-googled browser still offering it.

**Fixes**

- Fixed a crash that took the whole browser down when you closed the last
  incognito tab using the overview button's "close tab" shortcut.
- The bottom bar now follows the pure black switch in incognito. It was the one
  surface still showing Chromium's dark grey.
- The search widget shows the Aerium logo rather than the launcher icon, so it
  no longer sits on a white tile.
- **Access payment methods** is gone from Privacy and security. Aerium ships no
  payment methods, so the switch offered to let sites check a store that cannot
  exist - and it was a live switch, not a display.

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

**Deleting what you leave behind**

- New: **Settings › Privacy and security › Delete browsing data on exit**. Pick
  which of the eight data types go when you close the browser — history,
  downloads, cookies, cache, form data, passwords, site settings, hosted app
  data. Off by default; passwords and site settings stay unticked even once it
  is on, because a switch that promises a clean slate should not quietly throw
  away your sign-ins unless you asked it to.
- If Android closes the browser without warning, the deletion happens the next
  time it starts instead, before you do anything with it. Closing it yourself
  deletes straight away.

**Seeing what you are running**

- New: **chrome://aerium** lists every change this build makes on top of
  upstream Chromium — GrapheneOS's Vanadium patches first, then Aerium's own,
  with the number of files each one edits. The list is generated while the
  build runs from the patches and scripts themselves, so it describes what was
  actually applied rather than what someone remembered to write down.
- The About screen now links to it, and to the project's own site.

**Dark mode fix**

- **Blacken dark sites** is greyed out while **Darken websites** is off, with a
  line saying which box to tick first. It only changes how darkened pages are
  painted, so with darkening off it did nothing at all and said so nowhere.

**Media keeps playing**

- Video and audio no longer stop when you leave the browser or the screen turns
  off. Chromium suspends media in a hidden page on Android; Aerium doesn't.
  Anything with sound keeps going — a muted video still pauses, since nobody is
  listening to it and running it would cost battery for a picture you can't see.
- Sites that stop their own video when you look away now keep playing as well.
  YouTube is the one everyone runs into: the page is told it went to the
  background and pauses itself, which no browser setting could undo. Aerium
  lets a page that is making sound go on believing it is still on screen, so
  it never reaches for the pause button. This only applies while sound is
  actually playing — a silent background tab is told the plain truth and is
  slowed down and put to sleep exactly as before, so nothing here costs you
  battery. No extension to install, and nothing a site can see.

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
