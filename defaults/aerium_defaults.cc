// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

#include "aerium/defaults/aerium_defaults.h"

#include <iterator>
#include <set>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "base/base_switches.h"
#include "base/command_line.h"
#include "base/strings/string_split.h"
#include "base/values.h"
#include "chrome/browser/preloading/preloading_prefs.h"
#include "chrome/common/pref_names.h"
#include "components/autofill/core/common/autofill_prefs.h"
#include "components/content_settings/core/browser/cookie_settings.h"
#include "components/content_settings/core/browser/website_settings_info.h"
#include "components/content_settings/core/browser/website_settings_registry.h"
#include "components/content_settings/core/common/content_settings.h"
#include "components/content_settings/core/common/content_settings_types.h"
#include "components/content_settings/core/common/pref_names.h"
#include "components/embedder_support/pref_names.h"
#include "components/metrics/metrics_pref_names.h"
#include "components/password_manager/core/common/password_manager_pref_names.h"
#include "components/payments/core/payment_prefs.h"
#include "components/pref_registry/pref_registry_syncable.h"
#include "components/prefs/pref_registry.h"
#include "components/prefs/pref_registry_simple.h"
#include "components/prefs/pref_store.h"
#include "components/privacy_sandbox/privacy_sandbox_prefs.h"
#include "components/safe_browsing/core/common/safe_browsing_prefs.h"

namespace aerium {

namespace {

constexpr char kCrossOriginReferrerSwitch[] = "aerium-cross-origin-referrer";
constexpr char kCrossOriginReferrerFeature[] = "AeriumCrossOriginReferrer";

constexpr const char* kFeaturesOff[] = {
    "AbusiveOriginNotificationPermissionRevocation",
    "AutofillServerCommunication",
    "BrowsingTopics",
    "ConversionMeasurement",
    "DetailedLanguageSettings",
    "Glic",
    "InterestFeedV2",
    "MediaDrmPreprovisioning",
    "NTPPopularSitesBakedInContent",
    "NetworkTimeServiceQuerying",
    "OptimizationHints",
    "OptimizationHintsFetchingSRP",
    "OptimizationTargetPrediction",
    "SafetyHub",
    "SafetyHubThreeDotDetails",
    "WebGPUService",
};

constexpr const char* kFeaturesOn[] = {
    "AndroidDevToolsFrontend",
    "CertificateTransparencyAskBeforeEnabling",
    "GlobalPrivacyControlForce",
    "HstsTopLevelNavigationsOnly",
    "LocalNetworkAccessChecksWebRTC",
    "LocalNetworkAccessChecksWebSockets",
    "LocalNetworkAccessChecksWebTransport",
    "OmniboxSiteSearch",
    "OriginKeyedProcessesByDefault",
    "PartitionConnectionsByNetworkIsolationKey",
    "ReduceAcceptLanguage",
    "SitePerProcess",
    "SplitCacheByIncludeCredentials",
    "SplitCacheByNetworkIsolationKey",
    "SplitCodeCacheByNetworkIsolationKey",
    "StrictOriginIsolation",
    "SubmenusInAppMenu",
    "TaskManagerClank",
};

void CollectNames(const std::string& list, std::set<std::string>* names) {
  for (std::string_view entry : base::SplitStringPiece(
           list, ",", base::TRIM_WHITESPACE, base::SPLIT_WANT_NONEMPTY)) {
    if (entry.front() == '*') {
      entry.remove_prefix(1);
    }
    names->insert(std::string(entry.substr(0, entry.find_first_of("<:"))));
  }
}

std::string Extend(std::string list,
                   const std::vector<std::string>& names,
                   const std::set<std::string>& taken) {
  for (const std::string& name : names) {
    if (taken.contains(name.substr(0, name.find(':')))) {
      continue;
    }
    if (!list.empty()) {
      list += ',';
    }
    list += name;
  }
  return list;
}

void SetDefault(PrefRegistry* registry,
                std::string_view name,
                base::Value value) {
  const base::Value* current = nullptr;
  if (!registry->defaults()->GetValue(name, &current) || !current ||
      current->type() != value.type()) {
    return;
  }
  registry->SetDefaultPrefValue(name, std::move(value));
}

void SetContentDefault(PrefRegistry* registry,
                       ContentSettingsType type,
                       ContentSetting setting) {
  const content_settings::WebsiteSettingsInfo* info =
      content_settings::WebsiteSettingsRegistry::GetInstance()->Get(type);
  if (!info) {
    return;
  }
  SetDefault(registry, info->default_value_pref_name(),
             base::Value(static_cast<int>(setting)));
}

}  // namespace

void ApplyFeatureDefaults(base::CommandLine* command_line) {
  const std::string enabled =
      command_line->GetSwitchValueASCII(switches::kEnableFeatures);
  const std::string disabled =
      command_line->GetSwitchValueASCII(switches::kDisableFeatures);
  std::set<std::string> taken;
  CollectNames(enabled, &taken);
  CollectNames(disabled, &taken);
  std::vector<std::string> on(std::begin(kFeaturesOn), std::end(kFeaturesOn));
  std::vector<std::string> off(std::begin(kFeaturesOff), std::end(kFeaturesOff));
  const std::string referrer_mode =
      command_line->GetSwitchValueASCII(kCrossOriginReferrerSwitch);
  if (referrer_mode == "1" || referrer_mode == "2") {
    on.push_back(std::string(kCrossOriginReferrerFeature) + ":mode/" +
                 referrer_mode);
  }
  const std::string new_enabled = Extend(enabled, on, taken);
  const std::string new_disabled = Extend(disabled, off, taken);
  if (new_enabled != enabled) {
    command_line->AppendSwitchASCII(switches::kEnableFeatures, new_enabled);
  }
  if (new_disabled != disabled) {
    command_line->AppendSwitchASCII(switches::kDisableFeatures, new_disabled);
  }
}

void RegisterProfileDefaults(user_prefs::PrefRegistrySyncable* registry) {
  SetDefault(registry, embedder_support::kAlternateErrorPagesEnabled,
             base::Value(false));
  SetDefault(registry, prefs::kNetworkPredictionOptions,
             base::Value(static_cast<int>(
                 prefetch::NetworkPredictionOptions::kDisabled)));
  SetDefault(registry, prefs::kEnableHyperlinkAuditing, base::Value(false));
  SetDefault(registry, prefs::kViewSourceLineWrappingEnabled, base::Value(true));
  SetDefault(registry, prefs::kEnableDoNotTrack, base::Value(true));
  SetDefault(registry, prefs::kHttpsOnlyModeEnabled, base::Value(true));
  SetDefault(registry, prefs::kHttpsFirstBalancedMode, base::Value(true));
  SetDefault(registry, prefs::kWebRTCIPHandlingPolicy,
             base::Value("disable_non_proxied_udp"));
  SetDefault(registry, prefs::kEnableMediaRouter, base::Value(false));
  SetDefault(registry, "media_router.media_remoting.enabled",
             base::Value(false));
  SetDefault(registry, "signin.allowed", base::Value(false));
  SetDefault(registry, "signin.allowed_on_next_startup", base::Value(false));
  SetDefault(registry, prefs::kSafeBrowsingEnabled, base::Value(false));
  SetDefault(registry, prefs::kSafeBrowsingExtendedReportingOptInAllowed,
             base::Value(false));
  SetDefault(registry, prefs::kPrivacySandboxRelatedWebsiteSetsEnabled,
             base::Value(false));
  SetDefault(registry, payments::kCanMakePaymentEnabled, base::Value(false));
  SetDefault(registry, "ntp_snippets.enable", base::Value(false));
  SetDefault(registry, "ntp_snippets.list_visible", base::Value(false));
  SetDefault(registry, "ntp_snippets_by_dse.enable", base::Value(false));
  SetDefault(registry, autofill::prefs::kAutofillUsingPlatformAutofill,
             base::Value(true));
  SetDefault(registry, password_manager::prefs::kOfferToSavePasswordsEnabledGMS,
             base::Value(false));
  SetDefault(registry, password_manager::prefs::kAutoSignInEnabledGMS,
             base::Value(false));
  SetDefault(registry, password_manager::prefs::kPasswordLeakDetectionEnabled,
             base::Value(false));
  SetDefault(registry, prefs::kCookieControlsMode,
             base::Value(static_cast<int>(
                 content_settings::CookieControlsMode::kBlockThirdParty)));
  SetContentDefault(registry, ContentSettingsType::SENSORS,
                    CONTENT_SETTING_BLOCK);
  SetContentDefault(registry, ContentSettingsType::BACKGROUND_SYNC,
                    CONTENT_SETTING_BLOCK);
  SetContentDefault(registry, ContentSettingsType::PROTECTED_MEDIA_IDENTIFIER,
                    CONTENT_SETTING_ASK);
}

void RegisterLocalStateDefaults(PrefRegistrySimple* registry) {
  SetDefault(registry, metrics::prefs::kMetricsReportingEnabled,
             base::Value(false));
}

}  // namespace aerium
