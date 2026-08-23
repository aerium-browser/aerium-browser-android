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
