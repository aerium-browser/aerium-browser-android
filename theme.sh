#!/bin/bash
# Aerium identity pass (sourced from build.sh inside chromium/src, after
# patch.sh): product rename, privacy defaults, and battery efficiency.
# Visual theming is left stock so Android's own dynamic-color/dark-theme
# settings work as expected instead of being overridden.

# `sed -i` succeeds and changes nothing when its pattern stops matching, so a
# Chromium version bump that renames or reflows a targeted line silently drops
# the corresponding Aerium change - the build stays green and the feature is
# just missing from the APK. `sed_i` is a drop-in replacement that fails the
# build instead. Use it for every substitution whose absence would be a
# behaviour regression rather than a cosmetic one.
sed_i() {
    # A sed invocation can name several trailing files (theme.sh has one that
    # patches both worker fetch-context implementations at once), so the
    # targets are derived positionally: skip flags, the first non-flag
    # argument is the script, everything after it is a file.
    #
    # Splitting them by testing `-e "$arg"` instead - which this used to do -
    # is wrong twice over. A target whose path upstream renamed gets
    # reclassified as part of the script, so the failure reads "no existing
    # sed target" instead of naming the file that moved. Worse, it made every
    # sed_i invisible to devutils/verify-seds.sh: that script collects targets
    # in a first pass over an *empty* tree, so nothing existed, files[] came
    # back empty, and sed_i returned before calling sed at all. The targets
    # were never collected, never fetched, and never evaluated - leaving the
    # substitutions reserved for behaviour regressions as the only ones with
    # no version-bump safety net.
    local -a files=() expr=()
    local arg script_seen=0
    for arg in "$@"; do
        case "$arg" in
            -*) expr+=("$arg"); continue ;;
        esac
        if [ "$script_seen" = 0 ]; then
            script_seen=1
            expr+=("$arg")
            continue
        fi
        files+=("$arg")
    done
    if [ "${#files[@]}" -eq 0 ]; then
        echo "[aerium] FATAL: no sed target in: $*" >&2
        return 1
    fi

    # A missing target is reported but does not short-circuit the sed call:
    # verify-seds learns which paths a substitution wants by intercepting that
    # call, and it needs to hear about the missing ones most of all.
    local f rc=0
    local -a before_sums=()
    for f in "${files[@]}"; do
        if [ -e "$f" ]; then
            before_sums+=("$(cksum < "$f")")
        else
            echo "[aerium] FATAL: sed target does not exist: $f" >&2
            echo "[aerium]        upstream probably moved this file - see theme.sh" >&2
            before_sums+=("")
            rc=1
        fi
    done
    sed -i "$@" || rc=1
    local i=0
    for f in "${files[@]}"; do
        if [ -e "$f" ] && [ -n "${before_sums[$i]}" ] \
           && [ "${before_sums[$i]}" = "$(cksum < "$f")" ]; then
            echo "[aerium] FATAL: sed changed nothing in $f" >&2
            echo "[aerium]        expression: ${expr[*]}" >&2
            echo "[aerium]        upstream probably moved this code - see theme.sh" >&2
            rc=1
        fi
        i=$((i + 1))
    done
    return $rc
}

# --- Product name in every UI string source (.grd/.grdp/.xtb). Vanadium's
# branding patches already renamed their subset; this sweep catches the rest
# (e.g. "About Chromium" strings living inside <if expr> branches). Changed
# source texts get new grit IDs, so affected strings fall back to English in
# non-English locales.
grep -rl --include='*.grd' --include='*.grdp' --include='*.xtb' 'Chromium' \
    chrome components ui extensions content 2>/dev/null | while read -r f; do
    sed -i 's/The Chromium Authors/Dioide/g; s/Chromium/Aerium/g' "$f"
done

# --- The copyright line under Settings -> About Aerium -> Legal information.
# The sweep above rewrites "The Chromium Authors" to Dioide, but this string
# names Google LLC instead, so it survived as "Copyright 2026 Google LLC" on
# a screen where every other name had already been rebranded.
#
# sed_i rather than sed: if a Chromium bump reflows this line the build should
# stop and say so, not quietly ship Google's name in Aerium's about screen.
# The <ph> element is kept exactly as upstream writes it - grit requires the
# %1$d formatter to sit inside a <ph>, and moving it out is what broke an
# earlier build.
sed_i 's|Copyright <ph name="year">%1$d<ex>2014</ex></ph> Google LLC. All rights reserved.|Aerium. Copyright <ph name="year">%1$d<ex>2014</ex></ph> Dioide. All rights reserved.|' \
    chrome/browser/ui/android/strings/android_chrome_strings.grd

# --- Ungoogled-style privacy default: disable Safe Browsing by default. It
# is the main recurring Google phone-home on Android (URL/reputation pings);
# ungoogled-chromium removes it at build level. Left toggleable in
# Settings -> Privacy and security for users who want it.
sed -i 's/prefs::kSafeBrowsingEnabled, true,/prefs::kSafeBrowsingEnabled, false,/' \
    components/safe_browsing/core/common/safe_browsing_prefs.cc

# --- Use the Android Autofill framework by default so third-party password
# managers (Bitwarden etc.) fill web forms natively instead of relying on
# flaky accessibility-based compatibility mode. User-changeable in
# Settings -> Autofill services. This matters here because Aerium ships no
# built-in passwords/autofill UI to fall back on; Chrome still falls back to
# its own engine automatically when no non-Google third-party autofill
# service is configured system-wide - see
# AutofillClientProviderUtils.getAndroidAutofillFrameworkAvailability().
sed -i 's/registry->RegisterBooleanPref(kAutofillUsingPlatformAutofill, false);/registry->RegisterBooleanPref(kAutofillUsingPlatformAutofill, true);/' \
    components/autofill/core/common/autofill_prefs.cc

# --- Stop platform autofill switching itself off after a few launches.
#
# The pref flipped above is not only read, it is written back. On every
# profile construction AutofillClientProvider computes the current
# availability and stores the result in the same pref, while the Java side
# treats that pref as one of its two routes to AVAILABLE. That makes it a
# latch. One launch where the autofill service does not resolve - the
# AutofillManager not ready yet, or getAutofillServiceComponentName()
# momentarily null - writes false, and the only automatic way back is the
# saved-package route, which needs the package to have been recorded on an
# earlier run and to still match the current service.
#
# This is a known upstream behaviour, not a theory: Chromium counts how often
# it happens, in the Autofill.ResetAutofillPrefToChrome histogram, and its own
# comment there says the pref is reset when platform autofill "isn't allowed
# or doesn't fulfill all preconditions".
#
# On stock Chrome the user recovers in Settings -> Autofill services. Aerium
# deliberately ships no autofill settings UI, so there is nothing to recover
# with: third-party autofill works for the first few launches and then never
# again. That matches the reported symptom, and it reproduces on the upstream
# fork for the same reason.
#
# Only writing the pref when it is true costs nothing. Every durable
# restriction - enterprise policy, an unsupported platform, Google being the
# selected service - is re-checked inside
# getAndroidAutofillFrameworkAvailability() on every single call and decides
# the outcome there regardless of what this pref holds. The pref only needs to
# carry the intent, and the intent here is always true.
sed_i '/^  \/\/ Ensure the pref is reset if platform autofill is restricted\.$/,/^                    uses_platform_autofill_);$/c\
  \/\/ Aerium: never write this pref false. Upstream stores the computed\
  \/\/ availability here on every profile construction, and the Java side\
  \/\/ reads it back as one of two routes to AVAILABLE, so a single launch\
  \/\/ where the autofill service fails to resolve latches third-party\
  \/\/ autofill off for good. Aerium has no autofill settings UI to turn it\
  \/\/ back on, so the latch would be permanent. Durable restrictions are\
  \/\/ re-checked in getAndroidAutofillFrameworkAvailability() on every call\
  \/\/ and still win, so keeping the stored intent true changes nothing else.\
  if (uses_platform_autofill_) {\
    prefs->SetBoolean(prefs::kAutofillUsingPlatformAutofill,\
                      uses_platform_autofill_);\
  }' chrome/browser/ui/autofill/autofill_client_provider.cc

# --- Stop Settings crashing on open. patch.sh deletes the six autofill and
# password entries (orders 11-17) from main_preferences.xml, but MainSettings
# .java still expects the XML to define them. Both branches of
# updateAutofillPreferences() call addPreferenceIfAbsent(), which returns
# mAllPreferences.get(key) - and mAllPreferences is populated by
# cachePreferences() walking the inflated XML, so once the entries are gone
# that lookup is null. The assumeNonNull() guarding it does not actually
# check anything (build/android/.../NullUtil.java: "Since it does not
# actually check", it just returns its argument), so the null reaches
# setOnPreferenceClickListener() and the fragment dies with an NPE the
# instant Settings is opened. That is the crash in the published
# 151.0.7922.71 APK.
#
# Rewritten to only remove, which is idempotent and null-safe: correct
# whether or not the XML still defines the entries, so the perl in patch.sh
# quietly failing to match cannot resurrect the crash - it would only put the
# entries back in settings search.
#
# The two helpers are deleted rather than left behind, because Chromium
# builds Java with treat_warnings_as_errors and errorprone.py maps every
# check to a warning (-XepAllErrorsAsWarnings) without disabling
# UnusedMethod, so an uncalled private method would fail the build.
# maybeStartPasswordsExportFlow() is kept and still called: it reads fragment
# arguments and touches none of the removed preferences. Unused imports are
# fine - RemoveUnusedImports is in errorprone.py's disable list.
# The same six things are also reachable from the three-dot menu, which is a
# separate surface from Settings and was still offering all of them: a
# "Passwords and autofill" parent item whose submenu holds Google Password
# Manager, Payment methods, and Addresses and more. Removing the preferences
# from main_preferences.xml did nothing to this menu.
#
# The gate is one predicate, so that is what changes. Deleting the block that
# adds the item would leave buildPasswordsAndAutofillParentItem() - and the
# three submenu builders it calls - referenced by nothing, and Chromium builds
# Java with treat_warnings_as_errors while errorprone maps UnusedMethod to a
# warning, so dead private methods fail the build. Returning false keeps every
# call site in place and simply never reaches them.
# --- chrome://aerium-first-run - the onboarding page, shown once on the very
# first launch.
#
# The desktop repos get this from ungoogled-chromium's ungoogled_first_run.h,
# which Aerium then extends. Android has no ungoogled layer and no
# StartupBrowserCreator, so neither the page nor the AddFirstRunTabs() call
# that opens it exists here - both halves are built rather than ported.
#
# The page is header-only, the same shape as the desktop chrome://aerium page:
# a DefaultWebUIConfig plus an inline URLDataSource needs no BUILD.gn entry, no
# .cc and no TypeScript, which keeps a page of static text out of the resource
# pipeline entirely.
#
# What is deliberately NOT carried over is the desktop page's preset chooser.
# On desktop it exists because the browser ships with Chromium's defaults and
# the page is what changes them. On Android the same decisions are compiled in
# by this script - Safe Browsing, network prediction, HTTPS-First, the search
# engine list - so a preset button would mostly re-apply settings the build
# already made. Several of the prefs it writes (background mode, the memory
# and battery saver tiers, Aerium's own clear-on-exit pref) do not exist on
# Android at all. So the page explains what was decided instead of offering to
# decide it again.
cat > chrome/browser/ui/webui/aerium_first_run.h <<'AERIUM_FIRST_RUN_H'
#ifndef CHROME_BROWSER_UI_WEBUI_AERIUM_FIRST_RUN_H_
#define CHROME_BROWSER_UI_WEBUI_AERIUM_FIRST_RUN_H_

#include <string>

#include "base/memory/ref_counted_memory.h"
#include "chrome/browser/profiles/profile.h"
#include "content/public/browser/url_data_source.h"
#include "content/public/browser/web_ui.h"
#include "content/public/browser/web_ui_controller.h"
#include "content/public/browser/webui_config.h"

// chrome://aerium-first-run - shown once, on the first launch after install.
// ChromeTabbedActivity::createInitialTab opens this instead of the New Tab
// Page when the AERIUM_FIRST_RUN_PAGE_SHOWN preference is still unset.
class AeriumFirstRunDataSource : public content::URLDataSource {
 public:
  AeriumFirstRunDataSource() = default;
  AeriumFirstRunDataSource(const AeriumFirstRunDataSource&) = delete;
  AeriumFirstRunDataSource& operator=(const AeriumFirstRunDataSource&) = delete;
  ~AeriumFirstRunDataSource() override = default;

  // Defined below the class rather than here. The chromium-style clang
  // plugin rejects a virtual method whose non-empty body is written inside
  // the class declaration - it forces every translation unit that includes
  // the header to carry the code. Writing the definitions out-of-line keeps
  // the page header-only, which is the whole point of this file, and is what
  // the plugin actually asks for.
  std::string GetSource() override;
  std::string GetMimeType(const GURL& url) override;

  void StartDataRequest(const GURL& url,
                        const content::WebContents::Getter& wc_getter,
                        GotDataCallback callback) override;
};

inline std::string AeriumFirstRunDataSource::GetSource() {
  return "aerium-first-run";
}

inline std::string AeriumFirstRunDataSource::GetMimeType(const GURL& url) {
  return "text/html";
}

inline void AeriumFirstRunDataSource::StartDataRequest(
    const GURL& url,
    const content::WebContents::Getter& wc_getter,
    content::URLDataSource::GotDataCallback callback) {
  std::move(callback).Run(
      base::MakeRefCounted<base::RefCountedString>(std::string(
          R"AERIUMHTML(<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>Welcome to Aerium</title>
<style>
  :root {
    --bg: #f6f8fc; --card: #ffffff; --ink: #14203f; --muted: #4a5878;
    --line: #dde4f0; --accent: #2c6bae; --chip: #eaf1fa;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0d1428; --card: #141d38; --ink: #e9f1fb; --muted: #9fb0d0;
      --line: #24304f; --accent: #7fc4e4; --chip: #1b2747;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--ink);
    font: 16px/1.55 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    -webkit-text-size-adjust: 100%;
  }
  main { max-width: 44rem; margin: 0 auto; padding: 1.5rem 1.1rem 3rem; }
  header { text-align: center; padding: 1rem 0 0.5rem; }
  .mark { width: 84px; height: 84px; }
  h1 { font-size: 1.6rem; line-height: 1.25; margin: 0.75rem 0 0.35rem; }
  .lede { color: var(--muted); margin: 0 0 1.5rem; }
  section {
    background: var(--card); border: 1px solid var(--line);
    border-radius: 14px; padding: 1rem 1.1rem; margin: 0 0 0.9rem;
  }
  h2 { font-size: 1.05rem; margin: 0 0 0.5rem; }
  p { margin: 0 0 0.6rem; }
  p:last-child, ul:last-child { margin-bottom: 0; }
  ul { margin: 0 0 0.6rem; padding-left: 1.15rem; }
  li { margin: 0.25rem 0; }
  a { color: var(--accent); }
  .chips { display: flex; flex-wrap: wrap; gap: 0.4rem; margin: 0.15rem 0 0; padding: 0; list-style: none; }
  .chips li {
    background: var(--chip); border-radius: 999px;
    font-size: 0.85rem; margin: 0;
  }
  /* The padding lives on the anchor, not the li, so the whole pill is the
     tap target rather than just the width of the words. */
  .chips a {
    display: block; padding: 0.45rem 0.9rem; border-radius: inherit;
    color: var(--accent); text-decoration: none;
  }
  .chips a:hover, .chips a:focus-visible {
    background: var(--accent); color: var(--card);
  }
  .note { color: var(--muted); font-size: 0.9rem; }
  footer { text-align: center; color: var(--muted); font-size: 0.85rem; margin-top: 1.5rem; }
</style>
<main>
  <header>
    <svg class="mark" viewBox="0 0 512 512" aria-hidden="true">
      <path d="M 330 384.17 L 149.1 488.61 A 256 256 0 0 1 108 47.12 L 108 256 A 148 148 0 0 0 330 384.17 Z" fill="#1B2C5E"/>
      <path d="M 108 256 L 108 47.12 A 256 256 0 0 1 510.9 232.27 L 330 127.83 A 148 148 0 0 0 108 256 Z" fill="#2A4485"/>
      <path d="M 330 127.83 L 510.9 232.27 A 256 256 0 0 1 149.1 488.61 L 330 384.17 A 148 148 0 0 0 330 127.83 Z" fill="#111C42"/>
      <circle cx="256" cy="256" r="134" fill="#E9F1FB"/>
      <circle cx="256" cy="256" r="104" fill="#2C6BAE"/>
      <circle cx="238" cy="236" r="82" fill="#4C97CF"/>
      <circle cx="222" cy="218" r="46" fill="#7FC4E4"/>
    </svg>
    <h1>Welcome to Aerium</h1>
    <p class="lede">A Chromium build with the Google plumbing taken out. Here is what it already did for you, and the two things worth setting up yourself.</p>
  </header>

  <section>
    <h2>Already decided for you</h2>
    <p>These are compiled into the build, not toggles someone hoped you would find:</p>
    <ul>
      <li><strong>Safe Browsing is off.</strong> It was the main recurring call home &mdash; every URL you visit, checked against Google.</li>
      <li><strong>Nothing is preloaded or predicted.</strong> Pages, DNS and links are fetched when you ask for them, which is also easier on the battery.</li>
      <li><strong>HTTPS-First is on</strong> in its balanced mode, so plain HTTP is upgraded where a site supports it.</li>
      <li><strong>Global Privacy Control is sent</strong> on every request &mdash; a legally recognised opt-out under CCPA.</li>
      <li><strong>The search engine list is privacy-first</strong>, with Startpage as the default and DuckDuckGo and SearXNG alongside it.</li>
      <li><strong>Translate is gone</strong>, along with the settings entry and its search index.</li>
    </ul>
  </section>

  <section>
    <h2>Passwords and autofill</h2>
    <p>Aerium ships no password manager, no saved payment methods and no stored addresses, and the settings and menu entries for them are removed rather than merely hidden.</p>
    <p>Instead, web forms are filled by <strong>whichever autofill service you have chosen in Android</strong>. Set one in <em>Settings &rsaquo; Passwords &amp; accounts &rsaquo; Autofill service</em>. Any of these work well:</p>
    <ul class="chips">
      <li><a href="https://bitwarden.com" rel="noreferrer">Bitwarden</a></li>
      <li><a href="https://proton.me/pass" rel="noreferrer">Proton Pass</a></li>
      <li><a href="https://www.keepassdx.com" rel="noreferrer">KeePassDX</a></li>
    </ul>
    <p class="note" style="margin-top:0.7rem">A dedicated manager also fills apps, not just this browser, and your vault outlives any one browser.</p>
  </section>

  <section>
    <h2>Extensions</h2>
    <p>This build supports extensions, which stock Chrome on Android does not. A content blocker such as uBlock Origin is the single most useful thing to add.</p>
  </section>

  <section>
    <h2>Secure DNS</h2>
    <p>Turn it on in <a href="chrome://settings/privacy">Privacy and security</a> and pick a resolver you trust. It keeps the names of the sites you visit away from your network and your carrier.</p>
  </section>

  <section>
    <h2>Updates</h2>
    <p>There is no auto-updater and no Play Store listing, so security updates are not automatic. New builds are published on GitHub &mdash; check occasionally, or subscribe to releases to be told.</p>
    <p><a href="https://github.com/aerium-browser/aerium-browser-android/releases">github.com/aerium-browser/aerium-browser-android/releases</a></p>
  </section>

  <section>
    <h2>Where this build comes from</h2>
    <p>Aerium for Android is built on <a href="https://github.com/GrapheneOS/Vanadium">Vanadium</a>, the hardened Chromium from GrapheneOS, with Aerium's own changes on top. Everything is public: the patches, the scripts that apply them, and the CI that produced the file you installed.</p>
  </section>

  <footer>You can reach this page again at any time from chrome://aerium-first-run</footer>
</main>
)AERIUMHTML")));
}

class AeriumFirstRun;

class AeriumFirstRunUIConfig
    : public content::DefaultWebUIConfig<AeriumFirstRun> {
 public:
  AeriumFirstRunUIConfig()
      : DefaultWebUIConfig("chrome", "aerium-first-run") {}
};

class AeriumFirstRun : public content::WebUIController {
 public:
  explicit AeriumFirstRun(content::WebUI* web_ui)
      : content::WebUIController(web_ui) {
    content::URLDataSource::Add(Profile::FromWebUI(web_ui),
                                std::make_unique<AeriumFirstRunDataSource>());
  }
  AeriumFirstRun(const AeriumFirstRun&) = delete;
  AeriumFirstRun& operator=(const AeriumFirstRun&) = delete;
};

#endif  // CHROME_BROWSER_UI_WEBUI_AERIUM_FIRST_RUN_H_
AERIUM_FIRST_RUN_H

# Registered inside the IS_ANDROID arm of both lists, next to the webapks
# entries, so it exists only where it is reachable.
sed_i 's|#include "chrome/browser/ui/webui/webapks/webapks_ui.h"|&\n#include "chrome/browser/ui/webui/aerium_first_run.h"|' \
    chrome/browser/ui/webui/chrome_web_ui_configs.cc
sed_i 's|  map.AddWebUIConfig(std::make_unique<WebApksUIConfig>());|&\n  map.AddWebUIConfig(std::make_unique<AeriumFirstRunUIConfig>());|' \
    chrome/browser/ui/webui/chrome_web_ui_configs.cc

# The "have we greeted this install yet" flag. Chromium keeps its
# SharedPreferences keys in one registry and validates membership in tests and
# debug builds, so the key is added to both the constants and getKeysInUse()
# rather than only where it is read. The Chrome.<Feature>.<Key> shape is the
# format that validation expects for new keys.
CPK=chrome/browser/preferences/android/java/src/org/chromium/chrome/browser/preferences/ChromePreferenceKeys.java
sed_i 's|    public static final String FIRST_RUN_FLOW_COMPLETE = "first_run_flow";|    /** Whether the Aerium first-run page has been shown for this install. */\n    public static final String AERIUM_FIRST_RUN_PAGE_SHOWN =\n            "Chrome.Aerium.FirstRunPageShown";\n\n&|' \
    $CPK
sed_i 's|^                ADAPTIVE_TOOLBAR_CUSTOMIZATION_ENABLED,$|                AERIUM_FIRST_RUN_PAGE_SHOWN,\n&|' \
    $CPK

# The trigger. createInitialTab() is where Android picks the New Tab Page or
# the homepage for a cold start with no tabs to restore, which is the closest
# thing here to the desktop AddFirstRunTabs() call. Never in incognito, and the
# flag is written before the tab is launched so a crash on the way cannot leave
# it greeting on every launch.
sed_i 's|        getTabCreator(incognito).launchUrl(url, TabLaunchType.FROM_STARTUP);|        // Aerium: greet once, on the first launch after install.\n        if (!incognito\n                \&\& !ChromeSharedPreferences.getInstance()\n                        .readBoolean(\n                                ChromePreferenceKeys.AERIUM_FIRST_RUN_PAGE_SHOWN, false)) {\n            ChromeSharedPreferences.getInstance()\n                    .writeBoolean(ChromePreferenceKeys.AERIUM_FIRST_RUN_PAGE_SHOWN, true);\n            url = "chrome://aerium-first-run/";\n        }\n&|' \
    chrome/android/java/src/org/chromium/chrome/browser/ChromeTabbedActivity.java

# --- Let the system autofill service win even when it is Google's.
#
# Stock Chromium refuses to delegate to Autofill with Google: if the selected
# system service is AWG, getAndroidAutofillFrameworkAvailability() returns
# ANDROID_AUTOFILL_SERVICE_IS_GOOGLE and AutofillClientProvider falls back to
# ChromeAutofillClient - the browser's own engine. On a device set to Google,
# forms would be filled by Aerium rather than by the service the user chose,
# which is the opposite of what this build wants.
#
# Vanadium already removes it. Patch 0254 ("remove unused separate autofill
# status") deletes AWG_COMPONENT_NAME and both of its call sites, so by the
# time this script runs there is nothing left to strip - an earlier version of
# this block tried to strip it anyway and killed the build on its own guard.
#
# What is left here is the assertion, which is the part that actually needs to
# survive a bump: if Vanadium ever drops 0254, the exception comes back and
# Aerium silently starts filling forms itself on Google-configured devices.
# That is a behaviour regression no compiler would catch, so check the outcome
# rather than redo the work.
AUTOFILL_UTILS=chrome/browser/autofill/android/java/src/org/chromium/chrome/browser/autofill/AutofillClientProviderUtils.java
if [ -e $AUTOFILL_UTILS ] \
   && grep -q 'ANDROID_AUTOFILL_SERVICE_IS_GOOGLE' $AUTOFILL_UTILS; then
    echo "[aerium] FATAL: the AWG exception is back in" \
         "AutofillClientProviderUtils.java - Vanadium patch 0254 no longer" \
         "removes it." >&2
    echo "[aerium]        Without it gone, a device whose system autofill" \
         "service is Google falls back to the browser's own engine instead" \
         "of delegating. Strip the ANDROID_AUTOFILL_SERVICE_IS_GOOGLE branch" \
         "of getAndroidAutofillFrameworkAvailability() here." >&2
    return 1
fi

TABBED_MENU=chrome/android/java/src/org/chromium/chrome/browser/tabbed_mode/TabbedAppMenuPropertiesDelegate.java
sed_i '/^    private boolean shouldShowPasswordsAndAutofillParentItem() {$/,/^    }$/c\
    private boolean shouldShowPasswordsAndAutofillParentItem() {\
        \/\/ Aerium ships no password, payment or address storage UI, so the\
        \/\/ menu entry that leads to it - and its Google Password Manager,\
        \/\/ Payment methods and Addresses and more children - are never\
        \/\/ built. Web forms are filled by the system autofill service.\
        return false;\
    }' $TABBED_MENU

MAIN_SETTINGS=chrome/android/java/src/org/chromium/chrome/browser/settings/MainSettings.java
sed_i '/^    private void updateAutofillPreferences() {$/,/^    }$/c\
    private void updateAutofillPreferences() {\
        \/\/ Aerium ships no autofill or password storage UI, and patch.sh\
        \/\/ removes these entries from main_preferences.xml so settings\
        \/\/ search does not index them either. Removal is null-safe; the\
        \/\/ upstream add\/find calls were not, once the XML entries were gone.\
        removePreferenceIfPresent(PREF_AUTOFILL_AND_PASSWORDS);\
        removePreferenceIfPresent(PREF_AUTOFILL_SECTION);\
        removePreferenceIfPresent(PREF_PASSWORDS);\
        removePreferenceIfPresent(PREF_AUTOFILL_PAYMENTS);\
        removePreferenceIfPresent(PREF_AUTOFILL_ADDRESSES);\
        removePreferenceIfPresent(PREF_AUTOFILL_OPTIONS);\
\
        maybeStartPasswordsExportFlow();\
    }' $MAIN_SETTINGS
sed_i '/^    private void updateAutofillAndPasswords() {$/,/^    }$/d' $MAIN_SETTINGS
sed_i '/^    \/\/ TODO(crbug.com\/482988366): Remove this method once the Autofill and passwords feature is$/,/^    }$/d' \
    $MAIN_SETTINGS
# The second crash site, and the one the rewrite above does not reach.
# setManagedPreferenceDelegateForPreference() is the other reader of
# mAllPreferences, with the same do-nothing assumeNonNull() in front of the
# dereference, and onCreatePreferences calls it for PREF_PASSWORDS
# unconditionally - so Settings would still have died on open with only
# updateAutofillPreferences() fixed. Its other two call sites pass keys whose
# entries survive, so the helper itself stays.
sed_i '/^        \/\/ TODO(crbug.com\/40242060): Remove the passwords managed subtitle for local and UPM$/,/^        setManagedPreferenceDelegateForPreference(PREF_PASSWORDS);$/d' \
    $MAIN_SETTINGS

# --- Battery efficiency pass. Aerium takes its name from aerogel, the
# world's lightest solid, so keeping the browser light on battery is a brand
# commitment, not just an optimization. Each change below flips a single
# feature/pref default; all remain user-changeable where a settings UI exists.
# Verified against Chromium 151.0.7922.71 source at each file path below.

# Disable network prediction/preloading (prefetching links, DNS, etc. on
# page load) by default - trades a little latency for meaningfully less
# background radio/network activity. User-changeable in
# Settings -> Privacy and security -> Preload pages.
sed -i 's/static_cast<int>(NetworkPredictionOptions::kDefault),/static_cast<int>(NetworkPredictionOptions::kDisabled),/' \
    chrome/browser/preloading/preloading_prefs.cc

# Disable Optimization Guide (hints fetching + on-device target prediction
# model downloads/updates) - periodic background network chatter with no
# user-facing toggle on Android.
sed -i 's/BASE_FEATURE(kOptimizationHints, base::FEATURE_ENABLED_BY_DEFAULT);/BASE_FEATURE(kOptimizationHints, base::FEATURE_DISABLED_BY_DEFAULT);/; s/BASE_FEATURE(kOptimizationTargetPrediction, base::FEATURE_ENABLED_BY_DEFAULT);/BASE_FEATURE(kOptimizationTargetPrediction, base::FEATURE_DISABLED_BY_DEFAULT);/' \
    components/optimization_guide/core/optimization_guide_features.cc

# Disable Domain Reliability (periodic diagnostic beacons to Google about
# request failures/latency on Google-owned domains).
sed -i 's/registry->RegisterBooleanPref(prefs::kDomainReliabilityAllowedByPolicy, true);/registry->RegisterBooleanPref(prefs::kDomainReliabilityAllowedByPolicy, false);/' \
    components/domain_reliability/domain_reliability_prefs.cc

# Disable Interest Feed V2 (the Discover feed on the New Tab Page) - a
# recurring background JobScheduler task that fetches articles even when
# the feed isn't being looked at.
sed -i 's/BASE_FEATURE(kInterestFeedV2, base::FEATURE_ENABLED_BY_DEFAULT);/BASE_FEATURE(kInterestFeedV2, base::FEATURE_DISABLED_BY_DEFAULT);/' \
    components/feed/feed_feature_list.cc

# Disable Safety Hub's background password-check job (a periodic
# JobScheduler task, roughly weekly, that runs even without the Safety
# Hub settings page ever being opened).
sed -i 's/BASE_FEATURE(kSafetyHub, base::FEATURE_ENABLED_BY_DEFAULT);/BASE_FEATURE(kSafetyHub, base::FEATURE_DISABLED_BY_DEFAULT);/' \
    components/safety_check/features.cc

# --- Auto-darken web content, offered but off. Chromium already implements
# this end to end: RadioButtonGroupThemePreference draws a "darken websites"
# checkbox under Settings -> Appearance -> Theme whenever the theme is Dark or
# System default, and ThemeSettingsFragment already reads and writes it through
# WebContentsDarkModeController. The whole feature is wired and simply hidden
# behind a disabled flag, so this exposes it rather than building anything.
#
# On an OLED panel the display is usually the largest single power draw, and
# web content is most of the screen - the browser's own chrome is a small strip
# at the top. Darkening pages is therefore where the real saving is, which is
# why it is worth offering at all.
#
# It has to be TWO changes, not one. Enabling the feature alone would turn auto
# dark ON for everyone, because the content setting's registered default is
# derived from the feature's own param:
#
#   const auto auto_dark_web_content_setting =
#       content_settings::kDarkenWebsitesCheckboxOptOut.Get()
#           ? CONTENT_SETTING_ALLOW
#           : CONTENT_SETTING_BLOCK;
#
# and opt_out ships as true. Setting it false makes the default BLOCK, so the
# checkbox appears unchecked and darkening only happens if asked for. Auto dark
# misrenders some sites, so it must never be the default.
#
# The BASE_FEATURE macro is split across two lines, hence the N to pull the
# second line into the pattern space before substituting.
sed_i '/BASE_FEATURE(kDarkenWebsitesCheckboxInThemesSetting,/{N;s/base::FEATURE_DISABLED_BY_DEFAULT/base::FEATURE_ENABLED_BY_DEFAULT/}' \
    components/content_settings/core/common/features.cc
sed_i 's|"opt_out", true};|"opt_out", false};|' \
    components/content_settings/core/common/features.cc

# --- Pure black (AMOLED) surfaces. On an OLED panel a black pixel is switched
# off and draws no power, while Chromium's dark theme paints #1F1F1F - about
# 12% grey - so every pixel stays lit. Aerium is named after aerogel and the
# battery pass above already trims background CPU and radio work; the display
# is the one large draw it never touched.
#
# This is possible cheaply because of how Chromium 152 resolves colour.
# semantic_colors_dynamic.xml routes the surfaces through Material 3 theme
# attributes rather than fixed values:
#
#   <macro name="default_bg_color">?attr/colorSurface</macro>
#   <macro name="settings_bg_color">?attr/colorSurfaceContainerHigh</macro>
#
# so overriding those attributes in a theme overlay repaints the toolbar, the
# New Tab Page, settings, sheets and cards at once, and can be switched on and
# off per launch instead of being baked in.
#
# Every surface role goes to #000000, including the overflow menu, the cards
# inside settings and the progress-bar track. Those three float over or sit on
# another surface, so black-on-black leaves them without an edge - that is a
# deliberate trade, taking the boundary in exchange for the pixels being off.
# elevationOverlayEnabled is turned off because Material's elevation overlay
# lightens a surface in proportion to its elevation, which would put the grey
# straight back.
sed_i 's|^</resources>$|    <!-- Aerium: see theme.sh. Pure black for OLED panels. -->\n    <style name="ThemeOverlay.BrowserUI.AeriumPureBlack" parent="">\n        <item name="android:colorBackground">@android:color/black</item>\n        <item name="colorSurface">@android:color/black</item>\n        <item name="colorSurfaceDim">@android:color/black</item>\n        <item name="colorSurfaceContainerLowest">@android:color/black</item>\n        <item name="colorSurfaceContainerLow">@android:color/black</item>\n        <item name="colorSurfaceContainer">@android:color/black</item>\n        <item name="colorSurfaceContainerHigh">@android:color/black</item>\n        <item name="colorSurfaceBright">@android:color/black</item>\n        <item name="colorSurfaceContainerHighest">@android:color/black</item>\n        <item name="elevationOverlayEnabled">false</item>\n    </style>\n&|' \
    components/browser_ui/styles/android/java/res/values/themes.xml


# The toggle. theme_preferences.xml holds only the radio group, so the switch
# goes in beside it rather than into RadioButtonGroupThemePreference, whose
# checkbox is an accessory view reparented under the selected radio button -
# a mechanism worth staying out of for a setting that is not per-theme.
sed_i 's|^</PreferenceScreen>$|    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\n        android:key="aerium_pure_black"\n        android:title="@string/aerium_pure_black_title"\n        android:summary="@string/aerium_pure_black_summary" />\n&|' \
    chrome/browser/ui/android/night_mode/java/res/xml/theme_preferences.xml

TSF=chrome/browser/ui/android/night_mode/java/src/org/chromium/chrome/browser/night_mode/settings/ThemeSettingsFragment.java
sed_i 's|^import org.chromium.chrome.browser.preferences.ChromeSharedPreferences;$|import org.chromium.chrome.browser.preferences.ChromePreferenceKeys;\n&|' \
    $TSF
sed_i 's|^import org.chromium.components.browser_ui.settings.CustomDividerFragment;$|import org.chromium.components.browser_ui.settings.ChromeSwitchPreference;\n&|' \
    $TSF
sed_i 's|^        // TODO(crbug.com/40198953): Notify feature engagement system that settings were opened.$|        // Aerium: pure black surfaces. Stored in shared preferences rather than\n        // a profile pref because it is read in Activity.onCreate, before the\n        // profile is available. Default on: it only takes effect in dark mode,\n        // which the user has already chosen, and a battery feature nobody finds\n        // is not one.\n        ChromeSwitchPreference pureBlack =\n                (ChromeSwitchPreference) findPreference("aerium_pure_black");\n        if (pureBlack != null) {\n            pureBlack.setChecked(\n                    sharedPreferencesManager.readBoolean(\n                            ChromePreferenceKeys.AERIUM_PURE_BLACK, true));\n            pureBlack.setOnPreferenceChangeListener(\n                    (preference, newValue) -> {\n                        sharedPreferencesManager.writeBoolean(\n                                ChromePreferenceKeys.AERIUM_PURE_BLACK, (boolean) newValue);\n                        // Surfaces are chosen when an Activity is themed, so the\n                        // change lands on the next one rather than repainting this\n                        // screen underneath the switch that just moved.\n                        showRestartSnackbar();\n                        return true;\n                    });\n        }\n\n&|' \
    $TSF

# The overlay is applied per Activity. applyThemeOverlays() runs inside
# onCreate before super.onCreate, which is where Chromium already applies its
# dynamic-colour and density overlays - and after initializeNightModeStateProvider(),
# so the night-mode state is known. Applying last means it wins over the
# Material You palette, which otherwise supplies the surfaces on Android 12+.
#
# Shared preferences rather than a profile pref: this is read before the
# profile exists.
CBACA=chrome/android/java/src/org/chromium/chrome/browser/ChromeBaseAppCompatActivity.java
sed_i 's|^import org.chromium.chrome.browser.night_mode.NightModeUtils;$|&\nimport org.chromium.chrome.browser.preferences.ChromePreferenceKeys;\nimport org.chromium.chrome.browser.preferences.ChromeSharedPreferences;|' \
    $CBACA
sed_i 's|^        if (StyleUtils.shouldApplyDesktopDensity()) {$|        // Aerium: pure black surfaces on OLED. Applied last so it overrides the\n        // dynamic-colour palette above, and only in dark mode - there is nothing\n        // to blacken in a light theme.\n        if (getNightModeStateProvider().isInNightMode()\n                \&\& ChromeSharedPreferences.getInstance()\n                        .readBoolean(ChromePreferenceKeys.AERIUM_PURE_BLACK, true)) {\n            applySingleThemeOverlay(R.style.ThemeOverlay_BrowserUI_AeriumPureBlack);\n        }\n\n&|' \
    $CBACA

# The key itself. Same registry and the same getKeysInUse() list the first-run
# flag was added to - Chromium validates membership in tests and debug builds.
sed_i 's|    public static final String FIRST_RUN_FLOW_COMPLETE = "first_run_flow";|    /** Whether Aerium paints pure black surfaces while in dark mode. */\n    public static final String AERIUM_PURE_BLACK = "Chrome.Aerium.PureBlack";\n\n&|' \
    $CPK
sed_i 's|^                ADAPTIVE_TOOLBAR_CUSTOMIZATION_ENABLED,$|                AERIUM_PURE_BLACK,\n&|' \
    $CPK

# The two strings for the switch.
sed_i 's|^      <message name="IDS_THEME_SETTINGS" desc="Title for the Theme settings.*|      <message name="IDS_AERIUM_PURE_BLACK_TITLE" desc="Title of the switch in Appearance - Theme that paints the browser pure black instead of dark grey.">\n        Pure black\n      </message>\n      <message name="IDS_AERIUM_PURE_BLACK_SUMMARY" desc="Summary under the Pure black switch explaining what it does and why.">\n        Use true black instead of dark grey in dark mode. Saves power on OLED screens, where black pixels are switched off.\n      </message>\n&|' \
    chrome/browser/ui/android/strings/android_chrome_strings.grd

# --- AMOLED backgrounds for darkened web pages. Turning on "Darken websites"
# above does not give black pages: Blink inverts lightness in LAB space and
# then floors near-black greys at #121212 on purpose. dark_mode_color_filter.cc
# says why - "Further darken dark grays to match the primary surface color
# recommended by the material design guidelines".
#
# Following the pipeline for a white page: L=100, inverted by
# lab.x = min(110 - lab.x, 100) to L=10, back to sRGB as 27.5/255, then
# AdjustGray sees a neutral grey inside (18/255, 32/255) and clamps it to
# 18/255 - #121212 exactly. Every white and near-white page lands there.
#
# Dropping the floor to zero sends that same band to #000000 instead, so a
# darkened page is off pixels rather than Material's dark surface. The upper
# threshold is left alone: it decides which greys are treated as near-black at
# all, and widening it would flatten a page background into the cards sitting
# on it. Pages that are already light grey rather than white (#F1F1F1 inverts
# to about #252525) stay outside the band and keep their own separation.
#
# This rides the existing "Darken websites" switch rather than adding a third
# one. That switch is off by default and is already the separate control for
# web content; making its output black is what an OLED panel wants, and a
# grey-vs-black choice underneath it would mean plumbing a new setting from
# Java through the renderer into Blink for a distinction nobody asks for.
sed_i 's|    static const float kAdjustedBrightness = 18.0f / 255.0f;|    // Aerium: 0 instead of 18/255 - see theme.sh. Pure black, not Material grey.\n    static const float kAdjustedBrightness = 0.0f;|' \
    third_party/blink/renderer/platform/graphics/dark_mode_color_filter.cc

# --- Blacken sites that ship their own dark theme. Off by default.
#
# Force dark does not touch these sites, and that is correct: its classifiers
# are brightness-gated (150 for foreground, 205 for background, set in
# dark_mode_settings_builder.cc), so a site whose background is already dark
# falls below the threshold and is left alone rather than inverted back to
# light. What it keeps, though, is the site's own grey - GitHub is #0d1117,
# YouTube #181818 - and on an OLED panel every one of those pixels is lit.
#
# So: when the classifier declines to invert a background and the colour is
# already near black, pull it the rest of the way to #000000. Anything lighter
# is left alone, which keeps a genuinely mid-grey background distinct from the
# cards drawn on it.
#
# This cannot be a live setting. DarkModeFilter is built once per renderer
# process from GetCurrentDarkModeSettings(), itself a function-static, so
# nothing about force dark's tuning can change without a new process - even
# Chromium's own thresholds are fixed at startup. It is therefore a
# base::Feature appended to the command line before native starts, and the
# switch says so. Features propagate to renderers on their own, which a plain
# switch would not.
sed_i 's|  int background_brightness_threshold = 0;|&\n  // Aerium: pull near-black backgrounds the classifier skips to #000000.\n  bool blacken_dark_backgrounds = false;|' \
    third_party/blink/renderer/platform/graphics/dark_mode_settings.h

DMSB=third_party/blink/renderer/platform/graphics/dark_mode_settings_builder.cc
sed_i 's|#include "base/command_line.h"|&\n#include "base/feature_list.h"|' $DMSB
sed_i 's|const constexpr int kDefaultForegroundBrightnessThreshold = 150;|// Aerium: see theme.sh. Named "AeriumBlackenDarkBackgrounds" on the command\n// line, which is what ChromeApplicationImpl appends when the setting is on.\nBASE_FEATURE(kAeriumBlackenDarkBackgrounds, base::FEATURE_DISABLED_BY_DEFAULT);\n\n&|' $DMSB
sed_i 's|      Clamp<int>(kDefaultBackgroundBrightnessThreshold, 0, 255);|&\n  settings.blacken_dark_backgrounds =\n      base::FeatureList::IsEnabled(kAeriumBlackenDarkBackgrounds);|' $DMSB

sed_i 's|    sk_sp<cc::ColorFilter> image_filter;|&\n    // Aerium: see theme.sh.\n    bool blacken_dark_backgrounds = false;|' \
    third_party/blink/renderer/platform/graphics/dark_mode_filter.h

DMF=third_party/blink/renderer/platform/graphics/dark_mode_filter.cc
sed_i 's|  image_classifier = std::make_unique<DarkModeImageClassifier>();|&\n  blacken_dark_backgrounds = settings.blacken_dark_backgrounds;|' $DMF
sed_i '/^SkColor4f DarkModeFilter::InvertColorIfNeeded(const SkColor4f\& color,$/{N;s|                                              ElementRole role) {|                                              ElementRole role) {\n  // Aerium: take a background that is already near black the rest of the way\n  // down. Checked before the classifier because a colour this dark is one it\n  // would decline to invert anyway.\n  //\n  // Ungated on purpose. AdjustGray, which the colour filter applies after\n  // inverting, only touches NEUTRAL greys - it tests IsWithinEpsilon on the\n  // channels - so a page with a tinted background inverts to a tinted near\n  // black and keeps the cast, while a white page goes to true black. Same\n  // switch, two different answers. This tests the channels independently, so\n  // it catches both. It runs only when force dark is running at all, which is\n  // to say only when the user asked for darkening.\n  if (role == ElementRole::kBackground) {\n    constexpr float kNearBlack = 48.0f / 255.0f;\n    if (color.fR < kNearBlack \&\& color.fG < kNearBlack \&\&\n        color.fB < kNearBlack) {\n      return SkColor4f{0.0f, 0.0f, 0.0f, color.fA};\n    }\n  }\n|}' $DMF

# The key, the startup hook and the switch.
sed_i 's|    public static final String FIRST_RUN_FLOW_COMPLETE = "first_run_flow";|    /** Whether Aerium blackens sites that ship their own dark theme. */\n    public static final String AERIUM_BLACKEN_DARK_SITES = "Chrome.Aerium.BlackenDarkSites";\n\n&|' \
    $CPK
sed_i 's|^                ADAPTIVE_TOOLBAR_CUSTOMIZATION_ENABLED,$|                AERIUM_BLACKEN_DARK_SITES,\n&|' \
    $CPK

CAI=chrome/android/java/src/org/chromium/chrome/browser/ChromeApplicationImpl.java
sed_i 's|^import org.chromium.base.CommandLine;$|&\nimport org.chromium.chrome.browser.preferences.ChromePreferenceKeys;\nimport org.chromium.chrome.browser.preferences.ChromeSharedPreferences;|' \
    $CAI
sed_i 's|            FontPreloader.getInstance().load(getApplication());|&\n\n            // Aerium: the renderer fixes its dark-mode settings at process\n            // start, so this has to be on the command line before native\n            // comes up rather than flipped live. Merged into any existing\n            // value instead of overwriting whatever else asked for features.\n            if (ChromeSharedPreferences.getInstance()\n                    .readBoolean(ChromePreferenceKeys.AERIUM_BLACKEN_DARK_SITES, false)) {\n                CommandLine commandLine = CommandLine.getInstance();\n                String existing = commandLine.getSwitchValue("enable-features");\n                String merged =\n                        (existing == null \|\| existing.isEmpty())\n                                ? "AeriumBlackenDarkBackgrounds"\n                                : existing + ",AeriumBlackenDarkBackgrounds";\n                commandLine.appendSwitchWithValue("enable-features", merged);\n            }|' \
    $CAI

sed_i 's|^</PreferenceScreen>$|    <org.chromium.components.browser_ui.settings.ChromeSwitchPreference\n        android:key="aerium_blacken_dark_sites"\n        android:title="@string/aerium_blacken_dark_sites_title"\n        android:summary="@string/aerium_blacken_dark_sites_summary" />\n&|' \
    chrome/browser/ui/android/night_mode/java/res/xml/theme_preferences.xml

sed_i 's|^        // TODO(crbug.com/40198953): Notify feature engagement system that settings were opened.$|        ChromeSwitchPreference blackenDarkSites =\n                (ChromeSwitchPreference) findPreference("aerium_blacken_dark_sites");\n        if (blackenDarkSites != null) {\n            blackenDarkSites.setChecked(\n                    sharedPreferencesManager.readBoolean(\n                            ChromePreferenceKeys.AERIUM_BLACKEN_DARK_SITES, false));\n            blackenDarkSites.setOnPreferenceChangeListener(\n                    (preference, newValue) -> {\n                        sharedPreferencesManager.writeBoolean(\n                                ChromePreferenceKeys.AERIUM_BLACKEN_DARK_SITES,\n                                (boolean) newValue);\n                        showRestartSnackbar();\n                        return true;\n                    });\n        }\n\n&|' \
    $TSF

sed_i 's|^      <message name="IDS_AERIUM_PURE_BLACK_TITLE" desc=|      <message name="IDS_AERIUM_BLACKEN_DARK_SITES_TITLE" desc="Title of the switch that also blackens websites which already have their own dark theme.">\n        Blacken dark sites\n      </message>\n      <message name="IDS_AERIUM_BLACKEN_DARK_SITES_SUMMARY" desc="Summary under the Blacken dark sites switch. Mentions that a restart is needed.">\n        Extend darkening to sites that ship their own dark theme, so their dark grey becomes true black too. Restart Aerium to apply.\n      </message>\n&|' \
    chrome/browser/ui/android/strings/android_chrome_strings.grd

# --- Make the blacken switch reach sites that ship their own dark theme.
#
# The switch above did nothing on YouTube or Reddit, and the reason sits
# upstream of the filter rather than in it. ComputedStyle::ForceDark() is
#
#     DarkColorScheme() && ColorSchemeForced()
#
# and ComputedStyleBuilder::SetUsedColorScheme computes the second as
#
#     forced_scheme = (!has_dark && dark_scheme) || (force_dark && !prefers_dark)
#
# A site that declares color-scheme: dark, read with night mode on, has both
# has_dark and prefers_dark true, so neither clause fires - the scheme is dark
# because the page asked for it, not because we forced it. ForceDark() is
# false, DarkModeFilter is never consulted, and the clamp above never runs.
#
# A site with no color-scheme declaration has has_dark false, so the first
# clause fires and the clamp does run. That is exactly the split observed:
# eksisozluk went black, YouTube and Reddit kept their own grey.
#
# So when the setting is on, a dark scheme counts as forced even where the page
# chose it, which is what puts the filter in the paint path. Gated on
# force_dark too, so "Darken websites" being off still switches all of this off
# rather than leaving the filter running by itself.
#
# ColorSchemeForced() has exactly one reader in the tree - ForceDark() - so
# nothing else about how the page is styled changes.
CSTYLE=third_party/blink/renderer/core/style/computed_style.cc
sed_i 's|#include "third_party/blink/renderer/platform/graphics/graphics_context.h"|#include "third_party/blink/renderer/platform/graphics/dark_mode_settings_builder.h"\n&|' \
    $CSTYLE
sed_i 's|^  SetColorSchemeForced(forced_scheme);$|  // Aerium: see theme.sh. A page that ships its own dark theme is skipped by\n  // force dark, which is where the blacken switch lives, so treat its dark\n  // scheme as forced when that switch is on.\n  if (force_dark \&\& dark_scheme \&\&\n      GetCurrentDarkModeSettings().blacken_dark_backgrounds) {\n    forced_scheme = true;\n  }\n\n&|' \
    $CSTYLE

# Engaging force dark on a page that is already dark means its images go
# through the filter too, and those are the one thing on such a page that is
# not meant to be darkened - a photo on YouTube is already the right colour.
# The classifier would leave photographs alone (ShouldApplyFilterToImage only
# accepts kIcon and kSeparator), but icons drawn on a dark page are light and
# inverting them would be wrong, so images are skipped outright. Chromium has
# the same switch for its own reasons in AutoDarkModeSkipImages; this reuses
# that exit rather than adding a second one.
sed_i 's|  if (RuntimeEnabledFeatures::AutoDarkModeSkipImagesEnabled()) {|  // Aerium: see theme.sh - never filter images when blackening dark sites.\n  if (immutable_.blacken_dark_backgrounds \|\|\n      RuntimeEnabledFeatures::AutoDarkModeSkipImagesEnabled()) {|' $DMF

# --- Tell the user a restart is needed, and offer to do it.
#
# Neither switch can take effect where it is flipped. Pure black is chosen when
# an Activity is themed, so it lands on the next one; blacken dark sites is a
# command-line feature the renderer reads once at process start. Leaving that
# to a line of summary text means the setting looks broken until the user
# happens to restart.
#
# A snackbar rather than a dialog, and the relaunch on a button rather than
# automatic: restarting the browser out from under someone who was mid-session
# to apply a colour preference is worse than the wrong colour for a minute.
sed_i 's|^import android.content.Context;$|import android.app.Activity;\n&|' $TSF
sed_i 's|^import org.chromium.chrome.browser.settings.ChromeBaseSettingsFragment;$|&\nimport org.chromium.chrome.browser.lifetime.ApplicationLifetime;\nimport org.chromium.chrome.browser.ui.messages.snackbar.Snackbar;\nimport org.chromium.chrome.browser.ui.messages.snackbar.SnackbarManager;\nimport org.chromium.chrome.browser.ui.messages.snackbar.SnackbarManager.SnackbarManageable;|' \
    $TSF
sed_i '/^    @Override$/{N;s|^    @Override\n    public void onCreatePreferences|    // Aerium: see theme.sh. Long enough to read and act on. The instanceof is\n    // not defensive padding - this fragment is reachable from more than one\n    // host, and only a SnackbarManageable one can show it; the interface\n    // itself promises a non-null manager, so there is nothing further to\n    // check.\n    private static final int RESTART_SNACKBAR_DURATION_MS = 10000;\n\n    private void showRestartSnackbar() {\n        Activity activity = getActivity();\n        if (!(activity instanceof SnackbarManageable)) return;\n        SnackbarManager manager = ((SnackbarManageable) activity).getSnackbarManager();\n        manager.showSnackbar(\n                Snackbar.make(\n                                getString(R.string.aerium_restart_to_apply),\n                                new SnackbarManager.SnackbarController() {\n                                    @Override\n                                    public void onAction(@Nullable Object actionData) {\n                                        ApplicationLifetime.terminate(true);\n                                    }\n                                },\n                                Snackbar.TYPE_ACTION,\n                                Snackbar.UMA_UNKNOWN)\n                        .setAction(getString(R.string.aerium_relaunch), null)\n                        .setDuration(RESTART_SNACKBAR_DURATION_MS));\n    }\n\n    @Override\n    public void onCreatePreferences|}' \
    $TSF

# The snackbar and the restart come from targets night_mode did not depend on.
# Neither depends back on night_mode, so this adds no cycle.
#
# Both go in at the settings:java line because it is the only dep in this file
# that appears once - flags:java and preferences:java are each repeated in the
# two test targets, and sed would have added the dep to those as well. It
# leaves lifetime one line out of alphabetical order, which gn build does not
# mind; only `gn format` would, and nothing in this pipeline runs it.
sed_i 's|^    "//chrome/browser/settings:java",$|    "//chrome/browser/lifetime/android:java",\n&\n    "//chrome/browser/ui/messages/android:java",|' \
    chrome/browser/ui/android/night_mode/BUILD.gn

sed_i 's|^      <message name="IDS_AERIUM_BLACKEN_DARK_SITES_TITLE" desc=|      <message name="IDS_AERIUM_RESTART_TO_APPLY" desc="Text of the bar shown after changing an appearance setting that only takes effect once the browser has been restarted.">\n        Restart Aerium to apply this change\n      </message>\n      <message name="IDS_AERIUM_RELAUNCH" desc="Button on that bar which closes and reopens the browser.">\n        Relaunch\n      </message>\n&|' \
    chrome/browser/ui/android/strings/android_chrome_strings.grd

# --- Incognito follows the pure black switch too.
#
# ChromeColors reaches for a fixed baseline colour whenever isIncognito is set,
# in three places:
#
#     return isIncognito
#             ? context.getColor(R.color.default_bg_color_dark)
#             : SemanticColorUtils.getDefaultBgColor(context);
#
# The second branch resolves the default_bg_color macro to ?attr/colorSurface,
# which is what the overlay above replaces - so normal tabs go black. The first
# branch is a colour resource and deliberately ignores the dynamic palette, so
# that incognito looks the same on every device. That also puts it out of reach
# of the overlay, leaving incognito on Chromium's dark grey while every other
# surface is black.
#
# So the overlay names a colour for it, and ChromeColors reads that instead.
# Read defensively rather than through MaterialColors.getColor: the attribute
# only exists while the overlay is applied, and these three are called with
# whatever context the caller has - including ones themed from outside
# browser_ui. Missing attribute means the upstream colour, exactly as before,
# rather than an exception.
#
# It follows the switch, and with it the night-mode gate: incognito in a light
# theme keeps its grey. That is the same rule the rest of the overlay follows
# and a browser being run for its OLED behaviour is not in a light theme.
sed_i 's|    <!-- Aerium: see theme.sh. Pure black for OLED panels. -->|    <!-- Aerium: set by the overlay below and read by ChromeColors, so that\n         incognito - which ignores the dynamic palette by design - follows the\n         pure black switch as well. Absent whenever the overlay is not\n         applied, which is what makes the fallback there the upstream colour. -->\n    <attr name="aeriumIncognitoBgColor" format="color" />\n\n&|' \
    components/browser_ui/styles/android/java/res/values/themes.xml
sed_i 's|        <item name="colorSurfaceContainerHighest">@android:color/black</item>|&\n        <item name="aeriumIncognitoBgColor">@android:color/black</item>|' \
    components/browser_ui/styles/android/java/res/values/themes.xml

CC=components/browser_ui/styles/android/java/src/org/chromium/components/browser_ui/styles/ChromeColors.java
sed_i 's|^import android.content.res.ColorStateList;$|&\nimport android.util.TypedValue;|' $CC
sed_i 's|^    private static final String TAG = "ChromeColors";$|&\n\n    /**\n     * Aerium: the incognito colour named by the pure black overlay, or {@code\n     * fallbackColorRes} when that overlay is not on this context'"'"'s theme. See\n     * theme.sh.\n     */\n    private static @ColorInt int incognitoSurfaceColor(\n            Context context, @ColorRes int fallbackColorRes) {\n        TypedValue value = new TypedValue();\n        if (context.getTheme().resolveAttribute(R.attr.aeriumIncognitoBgColor, value, true)\n                \&\& value.type >= TypedValue.TYPE_FIRST_COLOR_INT\n                \&\& value.type <= TypedValue.TYPE_LAST_COLOR_INT) {\n            return value.data;\n        }\n        return context.getColor(fallbackColorRes);\n    }|' \
    $CC
sed_i 's|^                ? context.getColor(R.color.toolbar_background_incognito)$|                ? incognitoSurfaceColor(context, R.color.toolbar_background_incognito)|' $CC
sed_i 's|^                ? context.getColor(R.color.default_bg_color_dark)$|                ? incognitoSurfaceColor(context, R.color.default_bg_color_dark)|' $CC
sed_i 's|^            return context.getColor(R.color.default_bg_color_dark);$|            return incognitoSurfaceColor(context, R.color.default_bg_color_dark);|' $CC

# --- The same overlay on the pre-inflated toolbar.
#
# There are two applyThemeOverlays in the tree. The one above, on
# ChromeBaseAppCompatActivity, is the one every Activity runs. WarmupManager
# has its own - its own TODO admits the duplication - and it applies only the
# elegant-text-height and font-family overlays, because those were all it ever
# needed.
#
# WarmupManager inflates the toolbar hierarchy before an Activity exists, and
# where that pre-inflated hierarchy is taken up - Custom Tabs in particular -
# its views resolve colours against the warmup context, which has no pure black
# overlay on it. The result is a grey toolbar over black content on exactly the
# launches the warmup path is there to speed up.
#
# The night-mode state comes from the global provider rather than the context
# Configuration, because the app'"'"'s own light/dark choice does not reach an
# application context'"'"'s Configuration - only the system setting does, and the
# two disagree whenever someone has set the browser to Dark on a light phone.
#
# Applied first here rather than last, unlike the Activity path. The two
# overlays beside it set text attributes and nothing about surfaces, so there
# is no ordering to preserve.
WM=chrome/android/java/src/org/chromium/chrome/browser/WarmupManager.java
sed_i 's|^import org.chromium.chrome.browser.flags.ChromeFeatureList;$|&\nimport org.chromium.chrome.browser.night_mode.GlobalNightModeStateProviderHolder;\nimport org.chromium.chrome.browser.preferences.ChromePreferenceKeys;\nimport org.chromium.chrome.browser.preferences.ChromeSharedPreferences;|' \
    $WM
sed_i 's|^    static void applyThemeOverlays(Context context) {$|&\n        // Aerium: see theme.sh. The Activity path applies this too; a view\n        // inflated here is themed before any Activity exists, so it has to be\n        // applied on both or a warm start comes up grey.\n        if (GlobalNightModeStateProviderHolder.getInstance().isInNightMode()\n                \&\& ChromeSharedPreferences.getInstance()\n                        .readBoolean(ChromePreferenceKeys.AERIUM_PURE_BLACK, true)) {\n            context.getTheme().applyStyle(R.style.ThemeOverlay_BrowserUI_AeriumPureBlack, true);\n        }\n|' \
    $WM

# --- Aerium's own palette, the Android half of the desktop brand work.
#
# Chromium Android takes its colours from the wallpaper on Android 12 and up
# (DynamicColors.applyToActivityIfAvailable), so the browser looks like
# whatever picture is behind it rather than like itself. Brave does not do
# that and neither should this: a brand that changes with the wallpaper is not
# a brand. Below Android 12 the same call is a no-op and the baseline palette
# shows through, so today Aerium has two different unbranded looks.
#
# The values are the desktop ones, unchanged, so the two platforms agree: the
# same #2C6BAE seed, the same pale ladder in light, the same DEEP navy ladder
# in dark that replaced the first, too-light attempt.
#
# Surfaces and the primary role only. On-colours, secondary, tertiary, error
# and the outlines are left to the baseline palette, for the same reason the
# desktop mixer leaves them to the generated one: Chromium tuned its contrast
# against surfaces of these lightnesses, and re-deriving readability by hand
# buys nothing. Baseline on-surface is near-black in light and near-white in
# dark, which is right over both ladders.
#
# Only the wallpaper branch is replaced, not shouldApplyDynamicColors(). The
# branch above it honours a colour the user picked for the New Tab Page, and
# taking that away to install a brand would be answering a question nobody
# asked. So: their choice first, ours instead of the wallpaper's.
#
# Dark surfaces here are what shows when Pure black is switched off. With it
# on, the AeriumPureBlack overlay is applied after this one and takes the
# surfaces to black, leaving the primary from here - which is the intended
# stack: brand accent on an OLED-black ground.
sed_i 's|^</resources>$|    <!-- Aerium: see theme.sh. The desktop palette, applied to Android. -->\n    <style name="ThemeOverlay.BrowserUI.AeriumBrandLight" parent="">\n        <item name="colorPrimary">#2C6BAE</item>\n        <item name="colorOnPrimary">#FFFFFF</item>\n        <item name="colorPrimaryContainer">#D8E6F5</item>\n        <item name="colorOnPrimaryContainer">#0B2138</item>\n        <item name="colorSurface">#F2F7FD</item>\n        <item name="colorSurfaceDim">#DCE7F4</item>\n        <item name="colorSurfaceBright">#FFFFFF</item>\n        <item name="colorSurfaceContainerLowest">#FFFFFF</item>\n        <item name="colorSurfaceContainerLow">#F7FAFE</item>\n        <item name="colorSurfaceContainer">#E9F1FB</item>\n        <item name="colorSurfaceContainerHigh">#E1ECF9</item>\n        <item name="colorSurfaceContainerHighest">#D8E6F5</item>\n    </style>\n\n    <style name="ThemeOverlay.BrowserUI.AeriumBrandDark" parent="">\n        <item name="colorPrimary">#7FC4E4</item>\n        <item name="colorOnPrimary">#06283D</item>\n        <item name="colorPrimaryContainer">#1B2A57</item>\n        <item name="colorOnPrimaryContainer">#D8E6F5</item>\n        <item name="colorSurface">#0E1834</item>\n        <item name="colorSurfaceDim">#060B16</item>\n        <item name="colorSurfaceBright">#1B2A57</item>\n        <item name="colorSurfaceContainerLowest">#060B16</item>\n        <item name="colorSurfaceContainerLow">#0A1226</item>\n        <item name="colorSurfaceContainer">#141F44</item>\n        <item name="colorSurfaceContainerHigh">#1B2A57</item>\n        <item name="colorSurfaceContainerHighest">#22376E</item>\n    </style>\n\n&|' \
    components/browser_ui/styles/android/java/res/values/themes.xml

sed_i 's|^            DynamicColors.applyToActivityIfAvailable(this);$|            // Aerium: our palette rather than the wallpaper'"'"'s - see theme.sh.\n            // Applied on every OS version, where the call it replaces did\n            // nothing below Android 12.\n            applySingleThemeOverlay(\n                    getNightModeStateProvider().isInNightMode()\n                            ? R.style.ThemeOverlay_BrowserUI_AeriumBrandDark\n                            : R.style.ThemeOverlay_BrowserUI_AeriumBrandLight);|' \
    $CBACA
# That was the file's only use of the DynamicColors class - the NTP branch
# above goes through NtpCustomizationUtils - so the import has to go with it or
# the Java build fails on an unused import.
sed_i '/^import com\.google\.android\.material\.color\.DynamicColors;$/d' $CBACA

# The pre-inflated CCT hierarchy needs it for the same reason it needed the
# black overlay, and upstream says so itself at the top of the Activity copy:
# "if you're adding new overlays here, it's quite likely they're needed in
# WarmupManager". Brand first, black second, matching the Activity order.
sed_i 's|^        // Aerium: see theme.sh. The Activity path applies this too; a view$|        // Aerium: the brand palette, ahead of the black one so black still\n        // wins on surfaces. See theme.sh.\n        context.getTheme()\n                .applyStyle(\n                        GlobalNightModeStateProviderHolder.getInstance().isInNightMode()\n                                ? R.style.ThemeOverlay_BrowserUI_AeriumBrandDark\n                                : R.style.ThemeOverlay_BrowserUI_AeriumBrandLight,\n                        /* force= */ true);\n\n&|' \
    $WM

# --- Drop the XR feature module. Worth ~20 MB of the APK, for a feature four
# separate gn args already turn off.
#
# args.gn sets enable_vr, enable_arcore, enable_openxr and enable_cardboard all
# false, and the shipped APK nevertheless contains:
#
#     18.64 MB  lib/arm64-v8a/libimpress_api_jni.so
#      0.70 MB  lib/arm64-v8a/libandroidx.xr.arcore.openxr.so
#      0.56 MB  lib/arm64-v8a/libandroidx.xr.runtime.openxr.so
#      0.10 MB  lib/arm64-v8a/libarcore_sdk_jni.so
#      0.07 MB  lib/arm64-v8a/libarcore_sdk_c.so
#
# measured off the central directory of the published 152.0.7977.54 build.
#
# Those five names appear in exactly one place in the tree - the
# loadable_modules_64_bit list of xr_module_desc - and they arrive as a dynamic
# feature module rather than as ordinary deps, which is why the gn args do not
# reach them: the args gate Chromium's own XR code, while the module carries
# prebuilt AARs (androidx.xr, Google's impress, the ARCore client). A bundle
# would deliver that module on demand; a monolithic APK packs it in
# unconditionally.
#
# So the module is removed from the list the APK is built from. chrome_java
# keeps its :xr_java dependency, which is only the module-installer bridge and
# pulls none of the AARs, so nothing stops compiling; at runtime the module is
# simply not installed, which is a state the installer already handles because
# it is the normal state for a DFM.
#
# Nothing here affects startup. It removes code that was never loaded - four
# args say the features behind it are off - and a smaller APK is marginally
# kinder to page cache, not worse.
sed_i '/^  xr_module_desc,$/d' \
    chrome/android/modules/chrome_feature_modules.gni

# --- HTTPS-First Balanced Mode by default: upgrades navigations to HTTPS
# when a site is expected to support it, without the disruptive full-site
# interstitials of strict HTTPS-Only Mode. Stock Chromium ships this off,
# with a gradual auto-enable heuristic for "typically secure" users that is
# itself feature-flagged off at this version - so nobody gets it without
# this flip. User-changeable in Settings -> Privacy and security -> Security.
sed -i 's/prefs::kHttpsFirstBalancedMode, false,/prefs::kHttpsFirstBalancedMode, true,/' \
    chrome/browser/ui/browser_ui_prefs.cc

# --- Global Privacy Control (https://w3c.github.io/gpc/). Chromium 152
# implements this itself, in third_party/blink/renderer/modules/
# global_privacy_control/ - a directory that does not exist at 151. Aerium
# used to add the whole feature by hand: the navigator.globalPrivacyControl
# IDL attribute, its Navigator member, and the Sec-GPC header at all four
# request paths. All six substitutions are gone, because upstream now covers
# every one of them.
#
# Keeping ours was not merely redundant, it broke the build. Upstream declares
# the attribute on a mixin that Navigator includes, so our navigator.idl line
# became a second declaration on the same interface and the generated bindings
# failed to compile: "redefinition of GlobalPrivacyControlAttributeGetCallback"
# in v8_navigator.cc, one definition from each. Run 81 died on it after 1h36m.
#
# What replaces them is one flag. Upstream gates both halves of the feature on
# blink::features::kGlobalPrivacyControlForce: the JS property through the
# GlobalPrivacyControl runtime feature it implies, and the header itself
# through IsGlobalPrivacyControlEnabled(), which
# browser_initiated_resource_request.cc consults at the same call site our sed
# used to patch - it even removes and re-sets the header the same way. The
# runtime feature ships off, so it is turned on here.
#
# Behaviour is unchanged from Aerium's own version: sent unconditionally, no
# per-site toggle. The ipc_utils.cc navigation-header allowlist needs no
# widening either, since 152 added net::HttpRequestHeaders::kSecGPC to it.
#
# Desktop is still on 151 and keeps its hand-written GPC patches. When Linux
# and Windows move to 152 they will hit this same collision and need the same
# treatment.
sed_i '/^      name: "GlobalPrivacyControlForce",$/a\
      status: "stable",' \
    third_party/blink/renderer/platform/runtime_enabled_features.json5

# --- Widevine, toggleable and off by default (Brave-style). Aerium doesn't
# bundle Google's proprietary CDM binary, but the interface is compiled in
# (enable_widevine defaults to true for is_android and would default to true
# for Chrome-branded desktop builds too - see third_party/widevine/cdm/
# widevine.gni). Registering it unconditionally means every DRM-gated site
# can silently probe for it, so gate registration on a new chrome://flags
# entry instead. No ungoogled-chromium existing_switch_flag_entries.h here
# (Vanadium isn't ungoogled-chromium-based), so the flag is added directly
# to the main kFeatureEntries array.
sed -i '/^const FeatureEntry kFeatureEntries\[\] = {$/a\
    {"enable-widevine",\
     "Enable Widevine DRM",\
     "Registers the Widevine CDM so DRM-protected sites can play back content. Off by default - Aerium flag.",\
     kOsAll, SINGLE_VALUE_TYPE("enable-widevine")},
' chrome/browser/about_flags.cc
sed -i '/^  AddWidevine(cdms);$/c\
  // Off by default - Aerium doesn'"'"'t bundle Google'"'"'s proprietary CDM, and\
  // registering it unconditionally means every DRM-gated site can silently\
  // probe for it. Users who want DRM playback turn it on at\
  // chrome://flags/#enable-widevine.\
  if (base::CommandLine::ForCurrentProcess()->HasSwitch("enable-widevine")) {\
    AddWidevine(cdms);\
  }' chrome/common/media/cdm_registration.cc

# --- extension-mime-request-handling flag: controls how CRX/User Script
# MIME-type downloads are handled (silently treat as a regular file, or
# always prompt before installing). This flag doesn't exist on Vanadium at
# all - it's added by ungoogled-chromium's own
# add-flag-to-configure-extension-downloading.patch, which Windows/Linux get
# for free via their shared ungoogled-chromium core, but Vanadium carries no
# ungoogled-chromium patches. Ported here in full (flag definition + the
# behavior it gates) rather than skipped, for parity across all three
# platforms. Verified against Chromium 151.0.7922.71 source.
#
# Choice array + flag entry go straight into about_flags.cc's
# kFeatureEntries, same as the enable-widevine flag above - no separate
# ungoogled_flag_choices.h/ungoogled_flag_entries.h indirection needed since
# Vanadium isn't ungoogled-chromium-based.
sed -i '/^const FeatureEntry kFeatureEntries\[\] = {$/i\
const FeatureEntry::Choice kExtensionHandlingChoices[] = {\
    {flags_ui::kGenericExperimentChoiceDefault, "", ""},\
    {"Download as regular file",\
     "extension-mime-request-handling",\
     "download-as-regular-file"},\
    {"Always prompt for install",\
     "extension-mime-request-handling",\
     "always-prompt-for-install"},\
};\
' chrome/browser/about_flags.cc
sed -i '/^const FeatureEntry kFeatureEntries\[\] = {$/a\
    {"extension-mime-request-handling",\
     "Handling of extension MIME type requests",\
     "Used when deciding how to handle a request for a CRX or User Script MIME type. Aerium flag, ported from ungoogled-chromium.",\
     kOsAll, MULTI_VALUE_TYPE(kExtensionHandlingChoices)},\
' chrome/browser/about_flags.cc

# The behavior the flag gates: skip the install-confirmation prompt for
# trusted-site extension downloads unless "always prompt for install" is
# selected, and treat CRX/user-script downloads as regular files when
# "download as regular file" is selected.
sed -i '/^#include "extensions\/buildflags\/buildflags.h"$/i\
#include "extensions/browser/extension_util.h"' \
    chrome/browser/download/download_target_determiner.cc
sed -i '/^  \/\/ Don.t prompt for extension downloads if the installation site is allow$/,/^    return DownloadConfirmationReason::NONE;$/c\
  if (!extensions::util::ShouldDownloadAsRegularFile()) {\
    // Don'"'"'t prompt for extension downloads.\
    if (download_crx_util::IsTrustedExtensionDownload(GetProfile(), *download_) ||\
        filename.MatchesExtension(extensions::kExtensionFileExtension))\
      return DownloadConfirmationReason::NONE;\
  }' chrome/browser/download/download_target_determiner.cc
sed -i '/^bool ExtensionManagement::IsOffstoreInstallAllowed($/,/^    const GURL\& referrer_url) const {$/{/^    const GURL\& referrer_url) const {$/a\
  const base::CommandLine\& command_line =\
      *base::CommandLine::ForCurrentProcess();\
  if (command_line.HasSwitch("extension-mime-request-handling") \&\&\
      command_line.GetSwitchValueASCII("extension-mime-request-handling") ==\
      "always-prompt-for-install") {\
    return true;\
  }
}' chrome/browser/extensions/extension_management.cc
sed -i '/^bool IsExtensionDownload(const download::DownloadItem\& download_item) {$/i\
bool ShouldDownloadAsRegularFile() {\
    const base::CommandLine\& command_line =\
        *base::CommandLine::ForCurrentProcess();\
    return command_line.HasSwitch("extension-mime-request-handling") \&\&\
        command_line.GetSwitchValueASCII("extension-mime-request-handling") ==\
        "download-as-regular-file";\
}\
' extensions/browser/extension_util.cc
# 152 dropped the UserScript::IsURLUserScript() arm of this condition, so the
# old multi-line anchor is gone; the check is now a single line.
sed -i '/^  if (download_item.GetMimeType() == Extension::kMimeType) {$/{n
s/^    return true;$/    return !ShouldDownloadAsRegularFile();/
}' extensions/browser/extension_util.cc
sed -i '/^\/\/ Returns true if this is an extension download\. This also considers user$/i\
// Returns true if the user wants all extensions to be downloaded as regular\
// files.\
bool ShouldDownloadAsRegularFile();\
' extensions/browser/extension_util.h

# Seed the flag on by default at "Always prompt for install" (@2) - a
# security backstop, not an opt-in feature the way the rest of Aerium's
# privacy flags are treated, so it stays the one silently-seeded default.
# Matches Windows/Linux's default-flags.patch exactly (same shared file).
sed -i 's/^  registry->RegisterListPref(prefs::kAboutFlagsEntries);$/  \/\/ Silently seed just this one flag by default (security backstop - don'"'"'t\
  \/\/ silently download-and-run a CRX\/user-script MIME type without asking\
  \/\/ first). Aerium'"'"'s other recommended privacy flags are listed as opt-in\
  \/\/ choices instead, so picking them is a visible decision.\
  base::ListValue default_flags;\
  default_flags.Append("extension-mime-request-handling@2");\
  registry->RegisterListPref(prefs::kAboutFlagsEntries,\
                             std::move(default_flags));/' \
    components/webui/flags/pref_service_flags_storage.cc

# --- Default search engines: replace every per-country engine list with one
# fixed privacy-focused set - Startpage (default), DuckDuckGo, DuckDuckGo
# Lite, DuckDuckGo HTML and SearXNG (searx.be instance). Stock keeps
# Google-led per-country lists; ungoogled-style builds leave the user with a
# broken/absent default until they configure one manually. Any other engine
# can still be added by hand in settings.
#
# Mechanics (verified against Chromium 151.0.7922.71 source):
# - prepopulated_engines.json is the master engine list (startpage already
#   exists upstream, id 113, with a bundled icon; the DuckDuckGo variants and
#   SearXNG are new entries). New IDs take the free slots just above
#   upstream's highest (116), with kMaxPrepopulatedEngineID raised to match -
#   exactly what the comment above that constant instructs.
#   kCurrentDataVersion is raised so profiles created by earlier builds pick
#   up the new list on update.
#
#   IDs must stay <= 1000. Using 1001+ to dodge upstream collisions (which an
#   earlier revision did) breaks two Chromium invariants:
#     * template_url_data.cc GenerateGUID() only emits the deterministic sync
#       GUID for prepopulate_id in [1, 1000]; above that each construction
#       gets a random UUID, which is precisely what the deterministic GUID
#       exists to avoid ("to make sure sync doesn't incur in duplicates for
#       prepopulated engines"), so synced profiles accumulate duplicate rows
#       and duplicate keywords for the same engine.
#     * search_engine_choice_service.cc treats
#       prepopulate_id > kMaxPrepopulatedEngineID as "distribution custom
#       engine"; raising the constant to 1003 to cover 1001+ IDs disabled
#       that classification for genuinely custom engines too.
#   On a Chromium bump, check whether upstream claimed 117-119; if so move
#   ours to the next free IDs below 1000.
# - regional_settings.json's "ZZ" element is the fallback list for countries
#   without their own entry; GetRegionalSettings() in
#   regional_capabilities_utils.cc is redirected to always use it
#   (CountryId() == "ZZ" == unknown country, see country_codes.h), which
#   makes the ZZ list the single list for every country.
# - GetPrepopulatedFallbackSearch() in template_url_prepopulate_data.cc picks
#   the engine it looks up by ID first, falling back to the list head;
#   pointing it at startpage.id makes Startpage the out-of-the-box default
#   (Vanadium's patch 0116 already retargeted the stock google.id lookup to
#   duckduckgo.id, hence the dual pattern below).
SE_DEFS=third_party/search_engines_data/resources/definitions
sed_i '/^    "ecosia": {$/i\
    "duckduckgo_html": {\
      "name": "DuckDuckGo HTML",\
      "keyword": "html.duckduckgo.com",\
      "favicon_url": "https://duckduckgo.com/favicon.ico",\
      "search_url": "https://html.duckduckgo.com/html/?q={searchTerms}",\
      "suggest_url": "https://duckduckgo.com/ac/?q={searchTerms}\&type=list",\
      "type": "SEARCH_ENGINE_DUCKDUCKGO",\
      "id": 117\
    },\
\
    "duckduckgo_lite": {\
      "name": "DuckDuckGo Lite",\
      "keyword": "lite.duckduckgo.com",\
      "favicon_url": "https://duckduckgo.com/favicon.ico",\
      "search_url": "https://lite.duckduckgo.com/lite/?q={searchTerms}",\
      "suggest_url": "https://duckduckgo.com/ac/?q={searchTerms}\&type=list",\
      "type": "SEARCH_ENGINE_DUCKDUCKGO",\
      "id": 118\
    },\
' $SE_DEFS/prepopulated_engines.json
sed_i '/^    "seznam": {$/i\
    "searx": {\
      "name": "SearXNG",\
      "keyword": "searx.be",\
      "favicon_url": "https://searx.be/favicon.ico",\
      "search_url": "https://searx.be/search?q={searchTerms}",\
      "type": "SEARCH_ENGINE_OTHER",\
      "id": 119\
    },\
' $SE_DEFS/prepopulated_engines.json
# kCurrentDataVersion decides whether Chromium re-merges the prepopulated
# engine list into an existing profile's keyword database: the merge runs
# only when this value is above the one recorded in that database, and
# components/search_engines/util.cc DCHECKs that it never moves backwards
# ("If a data change happened, it should not cause a version downgrade").
# The three engines added above therefore reach an already-installed profile
# only if this number rises.
#
# It used to be hardcoded, which was a slow-acting trap of exactly the kind
# sed_i exists to catch, except no sed_i could catch it: upstream's own value
# climbs about one per milestone (209 at 151, 210 at 152), so a fixed number
# is overtaken eventually, and on that day the write silently becomes a
# downgrade. The substitution still changes the file, so it still reports as
# applied - the refresh just stops happening.
#
# Deriving it from upstream with a constant offset removes the cliff: it can
# never be overtaken, and it only decreases if upstream's does. The offset is
# 41 because upstream is 210 here, which reproduces 251 - the value this used
# to hardcode - so no already-shipped profile sees its version go backwards.
SE_DATA_VERSION_OFFSET=41
SE_DATA_VERSION=
# The engines inserted above claim ids 117-119, sitting immediately above
# upstream's highest (116 at both 151 and 152). Unlike the data version these
# ids cannot be derived, and must not be: Chromium stores a prepopulated
# engine's id in the profile's keyword database, so renumbering them between
# releases would orphan the rows existing installs already hold instead of
# updating them. That makes the range something upstream can walk into but we
# cannot walk away from, so it is checked rather than computed.
AERIUM_FIRST_ENGINE_ID=117
AERIUM_MAX_ENGINE_ID=119
# All of this is guarded on the file existing rather than failing outright
# when it is absent, because devutils/verify-seds.sh sources this over an
# empty tree to collect sed targets. Returning early there would cut the
# collection short and drop every substitution below this line from the check.
if [ -e $SE_DEFS/prepopulated_engines.json ]; then
    SE_DATA_VERSION=$(grep -o '"kCurrentDataVersion": [0-9]\+' \
        $SE_DEFS/prepopulated_engines.json | grep -o '[0-9]\+' || true)
    if [ -z "$SE_DATA_VERSION" ]; then
        echo "[aerium] FATAL: no kCurrentDataVersion in" \
             "$SE_DEFS/prepopulated_engines.json - upstream renamed it?" >&2
        return 1
    fi

    SE_MAX_ENGINE_ID=$(grep -o '"kMaxPrepopulatedEngineID": [0-9]\+' \
        $SE_DEFS/prepopulated_engines.json | grep -o '[0-9]\+' || true)
    if [ -z "$SE_MAX_ENGINE_ID" ]; then
        echo "[aerium] FATAL: no kMaxPrepopulatedEngineID in" \
             "$SE_DEFS/prepopulated_engines.json - upstream renamed it?" >&2
        return 1
    fi
    # Upstream reaching 117 means one of its engines now wears an id Aerium
    # also hands out, and nothing downstream would notice: two entries with
    # one id is a data conflict, not a build error.
    if [ "$SE_MAX_ENGINE_ID" -ge "$AERIUM_FIRST_ENGINE_ID" ]; then
        echo "[aerium] FATAL: upstream kMaxPrepopulatedEngineID is now" \
             "$SE_MAX_ENGINE_ID, which collides with the ids Aerium adds" \
             "($AERIUM_FIRST_ENGINE_ID-$AERIUM_MAX_ENGINE_ID)." >&2
        echo "[aerium]        Renumber the engines inserted in theme.sh above" \
             "upstream's range and move both constants with them. Existing" \
             "profiles keep the old ids, so treat that as a migration." >&2
        return 1
    fi
    # And the constants only mean anything if they still describe the blobs
    # inserted above, which carry their ids literally.
    _id=$AERIUM_FIRST_ENGINE_ID
    while [ "$_id" -le "$AERIUM_MAX_ENGINE_ID" ]; do
        if ! grep -qE "\"id\": $_id,?$" $SE_DEFS/prepopulated_engines.json
        then
            echo "[aerium] FATAL: no engine with id $_id in" \
                 "$SE_DEFS/prepopulated_engines.json - theme.sh's added" \
                 "engines and AERIUM_FIRST/MAX_ENGINE_ID have drifted apart" >&2
            return 1
        fi
        _id=$((_id + 1))
    done
fi
sed_i 's/"kMaxPrepopulatedEngineID": [0-9]\+,/"kMaxPrepopulatedEngineID": '"$AERIUM_MAX_ENGINE_ID"',/; s/"kCurrentDataVersion": [0-9]\+/"kCurrentDataVersion": '"$((SE_DATA_VERSION + SE_DATA_VERSION_OFFSET))"'/; s/"name": "startpage",/"name": "Startpage",/' \
    $SE_DEFS/prepopulated_engines.json
sed_i '/^    "ZZ": {$/,/^    }$/{s/^        "&google",$/        "\&startpage",\n        "\&duckduckgo",\n        "\&duckduckgo_lite",\n        "\&duckduckgo_html",\n        "\&searx"/; /^        "&bing",$/d; /^        "&yahoo"$/d}' \
    $SE_DEFS/regional_settings.json
sed_i 's|auto iter = TemplateURLPrepopulateData::kRegionalSettings.find(country_id);|// Aerium: every country gets the same privacy-focused engine list - the\n  // "ZZ" default in regional_settings.json - instead of per-country\n  // Google-led lists.\n  auto iter = TemplateURLPrepopulateData::kRegionalSettings.find(CountryId());|' \
    components/regional_capabilities/regional_capabilities_utils.cc
sed_i 's/^\( *\)\(google\|duckduckgo\)\.id,$/\1startpage.id,/' \
    components/search_engines/template_url_prepopulate_data.cc

# --- Fingerprint protection parity with Windows: canvas image-data noise,
# canvas measureText noise, get*ClientRect*() noise, and WebGL renderer/
# vendor spoofing. Windows ships these as user-toggleable ungoogled-chromium/
# bromite chrome://flags entries seeded on by default; Vanadium has no
# equivalent flags-extension mechanism and no components/ungoogled switches
# target, so instead of porting the command-line-switch delivery machinery,
# these are wired as always-on via runtime_enabled_features.json5's
# status:"stable" (compile-time default-on, verified against Chromium
# 151.0.7922.71 source: no flag needed, no extra BUILD.gn deps needed).
sed -i '/^  data: \[$/a\
    {\
      name: "FingerprintingClientRectsNoise",\
      status: "stable",\
    },\
    {\
      name: "FingerprintingCanvasMeasureTextNoise",\
      status: "stable",\
    },\
    {\
      name: "FingerprintingCanvasImageDataNoise",\
      status: "stable",\
    },' \
    third_party/blink/renderer/platform/runtime_enabled_features.json5

# get*ClientRect*() noise: precompute a per-document scale factor, applied to
# Element.getClientRects()/getBoundingClientRect() and Range.getClientRects()/
# getBoundingClientRect() readouts.
sed -i '/^#include "base\/notreached.h"$/a\
#include "base/rand_util.h"' \
    third_party/blink/renderer/core/dom/document.cc
sed -i '/^  DCHECK(agent_);$/a\
  if (RuntimeEnabledFeatures::FingerprintingClientRectsNoiseEnabled()) {\
    // Precompute -0.0003% to 0.0003% noise factor for get*ClientRect*() fingerprinting\
    noise_factor_x_ = 1 + (base::RandDouble() - 0.5) * 0.000003;\
    noise_factor_y_ = 1 + (base::RandDouble() - 0.5) * 0.000003;\
  }' \
    third_party/blink/renderer/core/dom/document.cc
sed -i '/^SelectorQueryCache& Document::GetSelectorQueryCache() {$/i\
double Document::GetNoiseFactorX() {\
  return noise_factor_x_;\
}\
\
double Document::GetNoiseFactorY() {\
  return noise_factor_y_;\
}\
' \
    third_party/blink/renderer/core/dom/document.cc
sed -i '/^  V8VisibilityState visibilityState() const;$/i\
  // Values for get*ClientRect fingerprint deception\
  double GetNoiseFactorX();\
  double GetNoiseFactorY();\
' \
    third_party/blink/renderer/core/dom/document.h
sed -i '/^  base::ElapsedTimer start_time_;$/a\
\
  double noise_factor_x_ = 1;\
  double noise_factor_y_ = 1;' \
    third_party/blink/renderer/core/dom/document.h
sed -i '/^    result.emplace_back(quad.BoundingBox());$/i\
    if (RuntimeEnabledFeatures::FingerprintingClientRectsNoiseEnabled()) {\
      quad.Scale(GetDocument().GetNoiseFactorX(), GetDocument().GetNoiseFactorY());\
    }' \
    third_party/blink/renderer/core/dom/element.cc
sed -i '/AdjustRectForScrollAndAbsoluteZoom(result,/{n;a\
  if (RuntimeEnabledFeatures::FingerprintingClientRectsNoiseEnabled()) {\
    result.Scale(GetDocument().GetNoiseFactorX(), GetDocument().GetNoiseFactorY());\
  }
}' \
    third_party/blink/renderer/core/dom/element.cc
sed -i '/^  return MakeGarbageCollected<DOMRectList>(quads);$/i\
  if (RuntimeEnabledFeatures::FingerprintingClientRectsNoiseEnabled()) {\
    for (gfx::QuadF\& quad : quads) {\
      quad.Scale(owner_document_->GetNoiseFactorX(), owner_document_->GetNoiseFactorY());\
    }\
  }\
' \
    third_party/blink/renderer/core/dom/range.cc
sed -i 's/^  return DOMRect::FromRectF(BoundingRect());$/  auto rect = BoundingRect();\
  if (RuntimeEnabledFeatures::FingerprintingClientRectsNoiseEnabled()) {\
    rect.Scale(owner_document_->GetNoiseFactorX(), owner_document_->GetNoiseFactorY());\
  }\
  return DOMRect::FromRectF(rect);/' \
    third_party/blink/renderer/core/dom/range.cc

# Canvas measureText() noise: scale the returned TextMetrics by the same
# per-document factor.
sed -i '/^ private:$/i\
  void Shuffle(const double factor);\
' \
    third_party/blink/renderer/core/html/canvas/text_metrics.h
sed -i '/^void TextMetrics::Update(const Font\* font,$/i\
void TextMetrics::Shuffle(const double factor) {\
  // x-direction\
  width_ *= factor;\
  actual_bounding_box_left_ *= factor;\
  actual_bounding_box_right_ *= factor;\
\
  // y-direction\
  font_bounding_box_ascent_ *= factor;\
  font_bounding_box_descent_ *= factor;\
  actual_bounding_box_ascent_ *= factor;\
  actual_bounding_box_descent_ *= factor;\
  em_height_ascent_ *= factor;\
  em_height_descent_ *= factor;\
  baselines_->setAlphabetic(baselines_->alphabetic() * factor);\
  baselines_->setHanging(baselines_->hanging() * factor);\
  baselines_->setIdeographic(baselines_->ideographic() * factor);\
}\
' \
    third_party/blink/renderer/core/html/canvas/text_metrics.cc
sed -i '/^\/\/ IWYU pragma: no_include "base\/numerics\/clamped_math.h"$/a\
\
#include "third_party/blink/renderer/core/offscreencanvas/offscreen_canvas.h"\
#include "third_party/blink/renderer/core/frame/local_dom_window.h"' \
    third_party/blink/renderer/modules/canvas/canvas2d/base_rendering_context_2d.cc
sed -i 's/^  return MakeGarbageCollected<TextMetrics>($/  TextMetrics* text_metrics = MakeGarbageCollected<TextMetrics>(/' \
    third_party/blink/renderer/modules/canvas/canvas2d/base_rendering_context_2d.cc
sed -i 's/^      host->GetPlainTextPainter());$/      host->GetPlainTextPainter());\
\
  \/\/ Scale text metrics if enabled\
  if (RuntimeEnabledFeatures::FingerprintingCanvasMeasureTextNoiseEnabled()) {\
    if (HostAsOffscreenCanvas()) {\
      if (auto* window = DynamicTo<LocalDOMWindow>(GetTopExecutionContext())) {\
        if (window->GetFrame() \&\& window->GetFrame()->GetDocument())\
          text_metrics->Shuffle(window->GetFrame()->GetDocument()->GetNoiseFactorX());\
      }\
    } else if (canvas) {\
      text_metrics->Shuffle(canvas->GetDocument().GetNoiseFactorX());\
    }\
  }\
  return text_metrics;/' \
    third_party/blink/renderer/modules/canvas/canvas2d/base_rendering_context_2d.cc

# Canvas image-data noise: slightly perturb up to 10 pixels of ImageData
# readback (getImageData/toBlob/toDataURL) - imperceptible visually, breaks
# byte-for-byte canvas fingerprint hashing.
sed -i 's/^  include_dirs = \[\]$/  include_dirs = [\
    "\/\/third_party\/skia\/include\/private", # For shuffler in graphics\/static_bitmap_image.cc\
  ]/' \
    third_party/blink/renderer/platform/BUILD.gn
# The shuffler's per-pixel writes are raw pointer arithmetic, which Chromium
# 150's unsafe-buffers plugin rejects as -Werror under Vanadium's
# warnings-as-errors build (ungoogled-chromium-windows compiles the identical
# upstream bromite code only because it sets treat_warnings_as_errors=false).
# File-level opt-out is the mechanism docs/unsafe_buffers.md prescribes.
sed -i '/^#include "third_party\/blink\/renderer\/platform\/graphics\/static_bitmap_image.h"$/i\
#ifdef UNSAFE_BUFFERS_BUILD\
// The Bromite canvas shuffler below does raw per-pixel pointer arithmetic.\
#pragma allow_unsafe_buffers\
#endif\
' \
    third_party/blink/renderer/platform/graphics/static_bitmap_image.cc
sed -i '/^#include "base\/numerics\/checked_math.h"$/i\
#include "base/rand_util.h"\
#include "base/logging.h"' \
    third_party/blink/renderer/platform/graphics/static_bitmap_image.cc
sed -i '/^#include "third_party\/blink\/renderer\/platform\/transforms\/affine_transform.h"$/i\
#include "third_party/blink/renderer/platform/runtime_enabled_features.h"' \
    third_party/blink/renderer/platform/graphics/static_bitmap_image.cc
sed -i '/^#include "third_party\/skia\/include\/core\/SkSurface.h"$/a\
#include "third_party/skia/src/core/SkColorData.h"' \
    third_party/blink/renderer/platform/graphics/static_bitmap_image.cc
sed -i '/^}  \/\/ namespace blink$/i\
// set the component to maximum-delta if it is >= maximum, or add to existing color component (color + delta)\
#define shuffleComponent(color, max, delta) ( (color) >= (max) ? ((max)-(delta)) : ((color)+(delta)) )\
\
#define writable_addr(T, p, stride, x, y) (T*)((const char *)p + y * stride + x * sizeof(T))\
\
void StaticBitmapImage::ShuffleSubchannelColorData(const void *addr, const SkImageInfo\& info, int srcX, int srcY) {\
  auto w = info.width() - srcX, h = info.height() - srcY;\
\
  // skip tiny images; info.width()/height() can also be 0\
  if ((w < 8) || (h < 8)) {\
    return;\
  }\
\
  // generate the first random number here\
  double shuffleX = base::RandDouble();\
\
  // cap maximum pixels to change\
  auto pixels = (w + h) / 128;\
  if (pixels > 10) {\
    pixels = 10;\
  } else if (pixels < 2) {\
    pixels = 2;\
  }\
\
  auto colorType = info.colorType();\
  auto fRowBytes = info.minRowBytes(); // stride\
\
  DLOG(INFO) << "BRM: ShuffleSubchannelColorData() w=" << w << " h=" << h << " colorType=" << colorType << " fRowBytes=" << fRowBytes;\
\
  // second random number (for y/height)\
  double shuffleY = base::RandDouble();\
\
  // calculate random coordinates using bisection\
  auto currentW = w, currentH = h;\
  for(;pixels >= 0; pixels--) {\
    int x = currentW * shuffleX, y = currentH * shuffleY;\
\
    // calculate randomisation amounts for each RGB component\
    uint8_t shuffleR = base::RandIntInclusive(0, 4);\
    uint8_t shuffleG = (shuffleR + x) % 4;\
    uint8_t shuffleB = (shuffleG + y) % 4;\
\
    // manipulate pixel data to slightly change the R, G, B components\
    switch (colorType) {\
      case kAlpha_8_SkColorType:\
      {\
         auto *pixel = writable_addr(uint8_t, addr, fRowBytes, x, y);\
         auto r = SkColorGetR(*pixel), g = SkColorGetG(*pixel), b = SkColorGetB(*pixel), a = SkColorGetA(*pixel);\
\
         r = shuffleComponent(r, UINT8_MAX-1, shuffleR);\
         g = shuffleComponent(g, UINT8_MAX-1, shuffleG);\
         b = shuffleComponent(b, UINT8_MAX-1, shuffleB);\
         // alpha is left unchanged\
\
         *pixel = SkColorSetARGB(a, r, g, b);\
      }\
      break;\
      case kGray_8_SkColorType:\
      {\
         auto *pixel = writable_addr(uint8_t, addr, fRowBytes, x, y);\
         *pixel = shuffleComponent(*pixel, UINT8_MAX-1, shuffleB);\
      }\
      break;\
      case kRGB_565_SkColorType:\
      {\
         auto *pixel = writable_addr(uint16_t, addr, fRowBytes, x, y);\
         unsigned    r = SkPacked16ToR32(*pixel);\
         unsigned    g = SkPacked16ToG32(*pixel);\
         unsigned    b = SkPacked16ToB32(*pixel);\
\
         r = shuffleComponent(r, 31, shuffleR);\
         g = shuffleComponent(g, 63, shuffleG);\
         b = shuffleComponent(b, 31, shuffleB);\
\
         unsigned r16 = (r \& SK_R16_MASK) << SK_R16_SHIFT;\
         unsigned g16 = (g \& SK_G16_MASK) << SK_G16_SHIFT;\
         unsigned b16 = (b \& SK_B16_MASK) << SK_B16_SHIFT;\
\
         *pixel = r16 | g16 | b16;\
      }\
      break;\
      case kARGB_4444_SkColorType:\
      {\
         auto *pixel = writable_addr(uint16_t, addr, fRowBytes, x, y);\
         auto a = SkGetPackedA4444(*pixel), r = SkGetPackedR4444(*pixel), g = SkGetPackedG4444(*pixel), b = SkGetPackedB4444(*pixel);\
\
         r = shuffleComponent(r, 15, shuffleR);\
         g = shuffleComponent(g, 15, shuffleG);\
         b = shuffleComponent(b, 15, shuffleB);\
         // alpha is left unchanged\
\
         unsigned a4 = (a \& 0xF) << SK_A4444_SHIFT;\
         unsigned r4 = (r \& 0xF) << SK_R4444_SHIFT;\
         unsigned g4 = (g \& 0xF) << SK_G4444_SHIFT;\
         unsigned b4 = (b \& 0xF) << SK_B4444_SHIFT;\
\
         *pixel = r4 | b4 | g4 | a4;\
      }\
      break;\
      case kRGBA_8888_SkColorType:\
      {\
         auto *pixel = writable_addr(uint32_t, addr, fRowBytes, x, y);\
         auto a = SkGetPackedA32(*pixel), r = SkGetPackedR32(*pixel), g = SkGetPackedG32(*pixel), b = SkGetPackedB32(*pixel);\
\
         r = shuffleComponent(r, UINT8_MAX-1, shuffleR);\
         g = shuffleComponent(g, UINT8_MAX-1, shuffleG);\
         b = shuffleComponent(b, UINT8_MAX-1, shuffleB);\
         // alpha is left unchanged\
\
         *pixel = (a << SK_A32_SHIFT) | (r << SK_R32_SHIFT) |\
                  (g << SK_G32_SHIFT) | (b << SK_B32_SHIFT);\
      }\
      break;\
      case kBGRA_8888_SkColorType:\
      {\
         auto *pixel = writable_addr(uint32_t, addr, fRowBytes, x, y);\
         auto a = SkGetPackedA32(*pixel), b = SkGetPackedR32(*pixel), g = SkGetPackedG32(*pixel), r = SkGetPackedB32(*pixel);\
\
         r = shuffleComponent(r, UINT8_MAX-1, shuffleR);\
         g = shuffleComponent(g, UINT8_MAX-1, shuffleG);\
         b = shuffleComponent(b, UINT8_MAX-1, shuffleB);\
         // alpha is left unchanged\
\
         *pixel = (a << SK_BGRA_A32_SHIFT) | (r << SK_BGRA_R32_SHIFT) |\
                  (g << SK_BGRA_G32_SHIFT) | (b << SK_BGRA_B32_SHIFT);\
      }\
      break;\
      default:\
         // the remaining formats are not expected to be used in Chromium\
         LOG(WARNING) << "BRM: ShuffleSubchannelColorData(): Ignoring pixel format";\
         return;\
    }\
\
    // keep bisecting or reset current width/height as needed\
    if (x == 0) {\
       currentW = w;\
    } else {\
       currentW = x;\
    }\
    if (y == 0) {\
       currentH = h;\
    } else {\
       currentH = y;\
    }\
  }\
}\
\
#undef writable_addr\
#undef shuffleComponent\
' \
    third_party/blink/renderer/platform/graphics/static_bitmap_image.cc
sed -i '/^  bool IsStaticBitmapImage() const override { return true; }$/i\
  static void ShuffleSubchannelColorData(const void *addr, const SkImageInfo\& info, int srcX, int srcY);\
' \
    third_party/blink/renderer/platform/graphics/static_bitmap_image.h
sed -i '/^#include "jpeglib.h"  \/\/ for JPEG_MAX_DIMENSION$/a\
#include "third_party/blink/renderer/platform/graphics/static_bitmap_image.h"\
#include "third_party/blink/renderer/platform/runtime_enabled_features.h"' \
    third_party/blink/renderer/platform/image-encoders/image_encoder.cc
sed -i '/^                          double quality) {$/a\
  if (RuntimeEnabledFeatures::FingerprintingCanvasImageDataNoiseEnabled()) {\
    // shuffle subchannel color data within the pixmap\
    StaticBitmapImage::ShuffleSubchannelColorData(src.writable_addr(), src.info(), 0, 0);\
  }' \
    third_party/blink/renderer/platform/image-encoders/image_encoder.cc

# getImageData() noise (separate call site from toBlob/toDataURL above).
sed -i '/^      DCHECK(!bounds.intersect(SkIRect::MakeXYWH(sx, sy, sw, sh)));$/a\
    }\
    if (read_pixels_successful \&\& RuntimeEnabledFeatures::FingerprintingCanvasImageDataNoiseEnabled()) {\
      StaticBitmapImage::ShuffleSubchannelColorData(image_data_pixmap.addr(), image_data_pixmap.info(), sx, sy);' \
    third_party/blink/renderer/modules/canvas/canvas2d/base_rendering_context_2d.cc

# WebGL renderer/vendor spoofing: return generic strings for
# WEBGL_debug_renderer_info instead of the real GPU string (a strong
# fingerprinting signal). Self-contained BASE_FEATURE, no flags UI needed
# on Android - always on, matching the "Blank" choice Windows seeds by
# default (empty renderer/vendor strings).
sed -i '/^namespace blink::features {$/a\
\
BASE_FEATURE(kSpoofWebGLInfo, "SpoofWebGLInfo", base::FEATURE_ENABLED_BY_DEFAULT);\
const char kSpoofWebGLRenderer[] = "renderer";\
const char kSpoofWebGLVendor[] = "vendor";\
const base::FeatureParam<std::string> kSpoofWebGLRendererParam{\&kSpoofWebGLInfo, kSpoofWebGLRenderer, " "};\
const base::FeatureParam<std::string> kSpoofWebGLVendorParam{\&kSpoofWebGLInfo, kSpoofWebGLVendor, " "};' \
    third_party/blink/common/features.cc
sed -i '/^namespace features {$/a\
BLINK_COMMON_EXPORT BASE_DECLARE_FEATURE(kSpoofWebGLInfo);\
BLINK_COMMON_EXPORT extern const char kSpoofWebGLRenderer[];\
BLINK_COMMON_EXPORT extern const char kSpoofWebGLVendor[];\
BLINK_COMMON_EXPORT extern const base::FeatureParam<std::string> kSpoofWebGLRendererParam;\
BLINK_COMMON_EXPORT extern const base::FeatureParam<std::string> kSpoofWebGLVendorParam;' \
    third_party/blink/public/common/features.h
sed -i '/^    case WebGLDebugRendererInfo::kUnmaskedRendererWebgl:$/{n;n;i\
        if (base::FeatureList::IsEnabled(blink::features::kSpoofWebGLInfo))\
          return WebGLAny(script_state, String(blink::features::kSpoofWebGLRendererParam.Get()));
}' \
    third_party/blink/renderer/modules/webgl/webgl_rendering_context_base.cc
sed -i '/^    case WebGLDebugRendererInfo::kUnmaskedVendorWebgl:$/{n;n;i\
        if (base::FeatureList::IsEnabled(blink::features::kSpoofWebGLInfo))\
          return WebGLAny(script_state, String(blink::features::kSpoofWebGLVendorParam.Get()));
}' \
    third_party/blink/renderer/modules/webgl/webgl_rendering_context_base.cc

echo "[aerium] theme + rename pass applied"
