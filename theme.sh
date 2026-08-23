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

  std::string GetSource() override { return "aerium-first-run"; }
  std::string GetMimeType(const GURL& url) override { return "text/html"; }

  void StartDataRequest(const GURL& url,
                        const content::WebContents::Getter& wc_getter,
                        GotDataCallback callback) override {
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
    padding: 0.25rem 0.7rem; font-size: 0.85rem; margin: 0;
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
      <li>Bitwarden</li><li>Proton Pass</li><li>KeePassDX</li><li>1Password</li><li>Enpass</li>
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
};

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
# Chromium refuses to delegate to Autofill with Google: if the selected system
# service is AWG, getAndroidAutofillFrameworkAvailability() returns
# ANDROID_AUTOFILL_SERVICE_IS_GOOGLE and AutofillClientProvider falls back to
# ChromeAutofillClient - the browser's own engine. So on a device set to
# Google, forms were filled by Aerium rather than by the service the user
# chose, which is the opposite of what this build wants: whatever the user
# picked at the system level fills the form, browser included in nothing.
#
# Only the availability check goes. The matching AWG guard in
# saveThirdPartyPackageUsedForAutofill() stays, because it is the last use of
# AWG_COMPONENT_NAME and dropping it too would leave that constant unused -
# UnusedVariable is only disabled for test code, so an unused private static
# field fails the build. Keeping it costs nothing: it only skips recording the
# package for the restore route, and the pref route (kept true by the latch
# fix above) already keeps platform autofill selected.
#
# perl rather than sed_i because the `if (AWG_COMPONENT_NAME.equals(...))`
# line occurs twice in this file and only the multi-line form tells them
# apart. The die gives it the same fail-loudly behaviour sed_i provides.
perl -0777 -pi -e '
    s{\n        if \(AWG_COMPONENT_NAME\.equals\(autofillServicePackage\)\) \{\n            return AndroidAutofillAvailabilityStatus\.ANDROID_AUTOFILL_SERVICE_IS_GOOGLE;\n        \}\n}
     {\n        // Aerium: no AWG exception. Whichever service the user selected\n        // at the system level is the one that fills forms.\n}
     or die "[aerium] FATAL: AWG availability check not found in AutofillClientProviderUtils.java\n";
' chrome/browser/autofill/android/java/src/org/chromium/chrome/browser/autofill/AutofillClientProviderUtils.java

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
