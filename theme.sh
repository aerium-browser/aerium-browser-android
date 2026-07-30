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
    # patches both worker fetch-context implementations at once), so treat
    # every trailing existing-or-not path as a target and require that each of
    # them actually changed.
    local -a files=() expr=()
    local arg seen_file=0
    for arg in "$@"; do
        if [ "$seen_file" = 1 ] || [ -e "$arg" ]; then
            case "$arg" in
                -*) expr+=("$arg"); continue ;;
            esac
            seen_file=1
            files+=("$arg")
        else
            expr+=("$arg")
        fi
    done
    if [ "${#files[@]}" -eq 0 ]; then
        echo "[aerium] FATAL: no existing sed target in: $*" >&2
        return 1
    fi

    local f before rc=0
    local -a before_sums=()
    for f in "${files[@]}"; do
        before_sums+=("$(cksum < "$f")")
    done
    sed -i "$@" || return 1
    local i=0
    for f in "${files[@]}"; do
        if [ "${before_sums[$i]}" = "$(cksum < "$f")" ]; then
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
# Settings -> Autofill services.
sed -i 's/registry->RegisterBooleanPref(kAutofillUsingPlatformAutofill, false);/registry->RegisterBooleanPref(kAutofillUsingPlatformAutofill, true);/' \
    components/autofill/core/common/autofill_prefs.cc

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

# --- Global Privacy Control (https://w3c.github.io/gpc/): a Sec-GPC opt-out
# header plus a readable navigator.globalPrivacyControl JS property, neither
# of which stock Chromium implements (Brave and DuckDuckGo do; CCPA requires
# it from browsers serving California users starting 2027-01-01). Sent/
# reported unconditionally - there's no per-site toggle, matching how DNT
# (still present in Chromium, just hidden from the settings UI) already
# behaves at these same call sites.
sed -i 's|\[MeasureAs=NavigatorVendor\] readonly attribute DOMString vendor;|&\n    // https://w3c.github.io/gpc/#dom-navigator-globalprivacycontrol\n    readonly attribute boolean globalPrivacyControl;|' \
    third_party/blink/renderer/core/frame/navigator.idl
sed -i 's|String vendorSub() const;|&\n  bool globalPrivacyControl() const;|' \
    third_party/blink/renderer/core/frame/navigator.h
sed -i '/^String Navigator::vendorSub() const {$/,/^}$/{/^}$/a\
\
bool Navigator::globalPrivacyControl() const {\
  // https://w3c.github.io/gpc/#dom-navigator-globalprivacycontrol\
  return true;\
}
}' third_party/blink/renderer/core/frame/navigator.cc
sed -i '/^  \/\/ TODO(crbug\.com\/40833603): WARNING: This bypasses the permissions policy\.$/i\
  // Global Privacy Control opt-out signal (https://w3c.github.io/gpc/),\
  // legally recognized under CCPA. Sent unconditionally, matching\
  // Brave/DuckDuckGo'"'"'s default behavior - there'"'"'s no per-site toggle.\
  if (should_update_existing_headers) {\
    headers->RemoveHeader("Sec-GPC");\
  }\
  headers->SetHeaderIfMissing("Sec-GPC", "1");\
' content/browser/loader/browser_initiated_resource_request.cc
sed -i '/^  \/\/ The request.s extra data may indicate that we should set a custom user$/i\
  // Global Privacy Control - see content\/browser\/loader\/\
  \/\/ browser_initiated_resource_request.cc for the browser-initiated case.\
  request.SetHttpHeaderField(blink::WebString::FromUtf8("Sec-GPC"), "1");
' content/renderer/render_frame_impl.cc
sed -i '/^  auto url_request_extra_data = base::MakeRefCounted<WebURLRequestExtraData>();$/i\
  request.SetHttpHeaderField(WebString::FromUtf8("Sec-GPC"), "1");
' third_party/blink/renderer/platform/loader/fetch/url_loader/dedicated_or_shared_worker_global_scope_context_impl.cc \
  third_party/blink/renderer/modules/service_worker/web_service_worker_fetch_context_impl.cc
# Sec-GPC injected above at render_frame_impl.cc's FinalizeRequestInternal
# feeds into every renderer-initiated navigation's BeginNavigation IPC to the
# browser process. content/browser/renderer_host/ipc_utils.cc's
# VerifyNavigationHeaders() strictly allowlists which headers a navigation
# may carry - DNT is on that list (why the DNT injection at the same call
# site is safe), but Sec-GPC never was, since it doesn't exist upstream.
# Without this, the browser kills the renderer on every single navigation
# (content/browser/bad_message.h reason 342,
# RFH_INVALID_NAVIGATION_HEADERS) - the Windows/Linux repos hit this exact
# crash (RESULT_CODE_KILLED_BAD_MESSAGE on any URL entry) before it was
# found and fixed there; ported here before it could bite Android too.
sed_i 's/header.name() != net::HttpRequestHeaders::kDNT) {/header.name() != net::HttpRequestHeaders::kDNT \&\&\n        header.name() != "Sec-GPC") {/' \
    content/browser/renderer_host/ipc_utils.cc

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
sed -i '/^                                  download_item.GetMimeType())) {$/{n
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
sed_i 's/"kMaxPrepopulatedEngineID": [0-9]\+,/"kMaxPrepopulatedEngineID": 119,/; s/"kCurrentDataVersion": [0-9]\+/"kCurrentDataVersion": 251/; s/"name": "startpage",/"name": "Startpage",/' \
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
