#!/usr/bin/env python3
import sys

GUARD = '#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)'
BUILDFLAGS = '#include "components/safe_browsing/buildflags.h"\n'

EDITS = []


def edit(path, old, new, need_buildflags=False, after_include=None):
    EDITS.append((path, old, new, need_buildflags, after_include))


edit('chrome/browser/interstitials/chrome_settings_page_helper.cc',
     '''#if BUILDFLAG(IS_ANDROID)
  safe_browsing::ShowSafeBrowsingSettings(
      web_contents->GetTopLevelNativeWindow(),
      safe_browsing::SettingsAccessPoint::kSecurityInterstitial);
#else''',
     '''#if BUILDFLAG(IS_ANDROID)
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  safe_browsing::ShowSafeBrowsingSettings(
      web_contents->GetTopLevelNativeWindow(),
      safe_browsing::SettingsAccessPoint::kSecurityInterstitial);
#endif
#else''')

edit('chrome/browser/interstitials/chrome_settings_page_helper.cc',
     '''    content::WebContents& web_contents) {
  safe_browsing::ShowAdvancedProtectionSettings(
      web_contents.GetTopLevelNativeWindow());
}''',
     '''    content::WebContents& web_contents) {
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  safe_browsing::ShowAdvancedProtectionSettings(
      web_contents.GetTopLevelNativeWindow());
#endif
}''')

edit('chrome/browser/ui/page_info/chrome_page_info_delegate.cc',
     '''void ChromePageInfoDelegate::OnSuspiciousSiteBackToSafety() {
#if BUILDFLAG(IS_ANDROID)''',
     '''void ChromePageInfoDelegate::OnSuspiciousSiteBackToSafety() {
#if BUILDFLAG(IS_ANDROID) && BUILDFLAG(SAFE_BROWSING_AVAILABLE)''',
     need_buildflags=True,
     after_include='#include "components/safe_browsing/content/browser/ui_manager.h"\n')

edit('chrome/browser/ui/page_info/chrome_page_info_delegate.cc',
     '''void ChromePageInfoDelegate::OnSuspiciousSiteMarkAsSafe() {
#if BUILDFLAG(IS_ANDROID)''',
     '''void ChromePageInfoDelegate::OnSuspiciousSiteMarkAsSafe() {
#if BUILDFLAG(IS_ANDROID) && BUILDFLAG(SAFE_BROWSING_AVAILABLE)''')

edit('chrome/browser/component_updater/registration.cc',
     '''#if BUILDFLAG(IS_ANDROID)
  RegisterRealTimeUrlChecksAllowlistComponent(cus);
#endif  // BUIDLFLAG(IS_ANDROID)''',
     '''#if BUILDFLAG(IS_ANDROID) && BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  RegisterRealTimeUrlChecksAllowlistComponent(cus);
#endif  // BUIDLFLAG(IS_ANDROID)''')

edit('chrome/browser/password_manager/android/all_passwords_bottom_sheet_controller.cc',
     '''  password_reuse_detection_manager_client_ =
      ChromePasswordReuseDetectionManagerClient::FromWebContents(web_contents_);''',
     '''#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  password_reuse_detection_manager_client_ =
      ChromePasswordReuseDetectionManagerClient::FromWebContents(web_contents_);
#endif''',
     need_buildflags=True,
     after_include='#include "content/public/browser/web_contents.h"\n')

edit('chrome/browser/password_manager/android/all_passwords_bottom_sheet_controller.cc',
     '''  driver_->FillIntoFocusedField(true, password);
  password_reuse_detection_manager_client_->OnPasswordSelected(password);''',
     '''  driver_->FillIntoFocusedField(true, password);
  if (password_reuse_detection_manager_client_) {
    password_reuse_detection_manager_client_->OnPasswordSelected(password);
  }''')

edit('chrome/browser/notifications/notification_platform_bridge_android.cc',
     '''  safe_browsing::NotificationContentDetectionUkmUtil::
      RecordSuspiciousNotificationInteractionUkm(
          static_cast<int>(
              safe_browsing::SuspiciousNotificationWarningInteractions::
                  kAlwaysAllow),
          url, notification_id, profile);''',
     '''#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  safe_browsing::NotificationContentDetectionUkmUtil::
      RecordSuspiciousNotificationInteractionUkm(
          static_cast<int>(
              safe_browsing::SuspiciousNotificationWarningInteractions::
                  kAlwaysAllow),
          url, notification_id, profile);
#endif''',
     need_buildflags=True,
     after_include='#include "chrome/browser/safe_browsing/notification_content_detection/notification_content_detection_util.h"\n')

edit('chrome/browser/enterprise/connectors/referrer_cache_utils.cc',
     '''  safe_browsing::ReferrerChain referrers;
  auto* observer_manager =
      safe_browsing::SafeBrowsingNavigationObserverManagerFactory::
          GetForBrowserContext(web_contents.GetBrowserContext());
  if (observer_manager) {
    observer_manager->IdentifyReferrerChainByEventURL(
        url, sessions::SessionTabHelper::IdForTab(&web_contents),
        kReferrerUserGestureLimit, &referrers);
  }
  return referrers;''',
     '''  safe_browsing::ReferrerChain referrers;
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  auto* observer_manager =
      safe_browsing::SafeBrowsingNavigationObserverManagerFactory::
          GetForBrowserContext(web_contents.GetBrowserContext());
  if (observer_manager) {
    observer_manager->IdentifyReferrerChainByEventURL(
        url, sessions::SessionTabHelper::IdForTab(&web_contents),
        kReferrerUserGestureLimit, &referrers);
  }
#endif
  return referrers;''',
     need_buildflags=True,
     after_include='#include "components/safe_browsing/core/common/proto/csd.pb.h"\n')

edit('chrome/browser/safe_browsing/android/safe_browsing_bridge.cc',
     '''  base::FilePath file_path(base::android::ConvertJavaStringToUTF8(env, path));
  return safe_browsing::FileTypePolicies::GetInstance()->UmaValueForFile(
      file_path);''',
     '''#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  base::FilePath file_path(base::android::ConvertJavaStringToUTF8(env, path));
  return safe_browsing::FileTypePolicies::GetInstance()->UmaValueForFile(
      file_path);
#else
  return 0;
#endif''')

edit('chrome/browser/ui/android/safe_browsing/suspicious_site_dialog_view_android.cc',
     '''void SuspiciousSiteDialogViewAndroid::ContinueAnyway(JNIEnv* env) {
  controller_->OnContinueButtonClicked();
}

void SuspiciousSiteDialogViewAndroid::GoBack(JNIEnv* env) {
  controller_->HandleBackNavigation(
      safe_browsing::SuspiciousSiteWarningUserInteraction::kBackToSafetyButton);
}

void SuspiciousSiteDialogViewAndroid::OnLearnMoreClicked(JNIEnv* env) {
  controller_->OnHelpCenterLinkClicked();
}

void SuspiciousSiteDialogViewAndroid::Close(
    JNIEnv* env,
    ui::ModalDialogWrapper::DismissalCause dismissalCause) {
  controller_->CloseDialog(dismissalCause);
}''',
     '''void SuspiciousSiteDialogViewAndroid::ContinueAnyway(JNIEnv* env) {
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  controller_->OnContinueButtonClicked();
#endif
}

void SuspiciousSiteDialogViewAndroid::GoBack(JNIEnv* env) {
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  controller_->HandleBackNavigation(
      safe_browsing::SuspiciousSiteWarningUserInteraction::kBackToSafetyButton);
#endif
}

void SuspiciousSiteDialogViewAndroid::OnLearnMoreClicked(JNIEnv* env) {
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  controller_->OnHelpCenterLinkClicked();
#endif
}

void SuspiciousSiteDialogViewAndroid::Close(
    JNIEnv* env,
    ui::ModalDialogWrapper::DismissalCause dismissalCause) {
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  controller_->CloseDialog(dismissalCause);
#endif
}''',
     need_buildflags=True,
     after_include='#include "ui/android/window_android.h"\n')

edit('chrome/browser/ui/android/safe_browsing/suspicious_site_dialog_view_android.cc',
     '''    content::WebContents* web_contents) {
  safe_browsing::SuspiciousSiteControllerAndroid::CreateForWebContents(
      web_contents);
}''',
     '''    content::WebContents* web_contents) {
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  safe_browsing::SuspiciousSiteControllerAndroid::CreateForWebContents(
      web_contents);
#endif
}''')

edit('chrome/browser/ui/android/safe_browsing/password_reuse_dialog_view_android.cc',
     '''void PasswordReuseDialogViewAndroid::CheckPasswords(JNIEnv* env) {
  controller_->ShowCheckPasswords();
}

void PasswordReuseDialogViewAndroid::Ignore(JNIEnv* env) {
  controller_->IgnoreDialog();
}

void PasswordReuseDialogViewAndroid::Close(JNIEnv* env) {
  controller_->CloseDialog();
}''',
     '''void PasswordReuseDialogViewAndroid::CheckPasswords(JNIEnv* env) {
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  controller_->ShowCheckPasswords();
#endif
}

void PasswordReuseDialogViewAndroid::Ignore(JNIEnv* env) {
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  controller_->IgnoreDialog();
#endif
}

void PasswordReuseDialogViewAndroid::Close(JNIEnv* env) {
#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  controller_->CloseDialog();
#endif
}''',
     need_buildflags=True,
     after_include='#include "ui/android/window_android.h"\n')

edit('chrome/browser/glic/host/glic_web_client_handler.cc',
     '''    if (!g_browser_process->safe_browsing_service()) {
      return;
    }
    safe_browsing::BaseUIManager* ui_manager =
        g_browser_process->safe_browsing_service()->ui_manager().get();
    if (ui_manager) {''',
     '''#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
    if (!g_browser_process->safe_browsing_service()) {
      return;
    }
    safe_browsing::BaseUIManager* ui_manager =
        g_browser_process->safe_browsing_service()->ui_manager().get();
    if (ui_manager) {''',
     need_buildflags=True,
     after_include='#include "components/safe_browsing/core/common/safe_browsing_prefs.h"\n')

edit('chrome/browser/glic/host/glic_web_client_handler.cc',
     '''        ui_manager->DisplayBlockingPage(resource);
      }
    }
  }''',
     '''        ui_manager->DisplayBlockingPage(resource);
      }
    }
#endif
  }''')


edit('chrome/browser/interstitials/enterprise_util.cc',
     """  safe_browsing::SafeBrowsingNavigationObserverManager*
      navigation_observer_manager =
          safe_browsing::SafeBrowsingNavigationObserverManagerFactory::
              GetForBrowserContext(web_contents->GetBrowserContext());
  SessionID tab_id = sessions::SessionTabHelper::IdForTab(web_contents);
  safe_browsing::ReferrerChainProvider::AttributionResult attribution_result =
      navigation_observer_manager->IdentifyReferrerChainByPendingEventURL(
          page_url, enterprise_connectors::kReferrerUserGestureLimit,
          &referrer_chain);
  if (attribution_result ==
      safe_browsing::ReferrerChainProvider::NAVIGATION_EVENT_NOT_FOUND) {
    CHECK(referrer_chain.empty());
    navigation_observer_manager->IdentifyReferrerChainByEventURL(
        page_url, tab_id, enterprise_connectors::kReferrerUserGestureLimit,
        &referrer_chain);
  }
}""",
     """#if BUILDFLAG(SAFE_BROWSING_AVAILABLE)
  safe_browsing::SafeBrowsingNavigationObserverManager*
      navigation_observer_manager =
          safe_browsing::SafeBrowsingNavigationObserverManagerFactory::
              GetForBrowserContext(web_contents->GetBrowserContext());
  SessionID tab_id = sessions::SessionTabHelper::IdForTab(web_contents);
  safe_browsing::ReferrerChainProvider::AttributionResult attribution_result =
      navigation_observer_manager->IdentifyReferrerChainByPendingEventURL(
          page_url, enterprise_connectors::kReferrerUserGestureLimit,
          &referrer_chain);
  if (attribution_result ==
      safe_browsing::ReferrerChainProvider::NAVIGATION_EVENT_NOT_FOUND) {
    CHECK(referrer_chain.empty());
    navigation_observer_manager->IdentifyReferrerChainByEventURL(
        page_url, tab_id, enterprise_connectors::kReferrerUserGestureLimit,
        &referrer_chain);
  }
#endif
}""")

def main():
    applied, skipped = 0, 0
    for path, old, new, need_buildflags, after_include in EDITS:
        try:
            with open(path, encoding='utf-8') as fh:
                text = fh.read()
        except FileNotFoundError:
            print('[aerium] FATAL: %s is missing' % path, file=sys.stderr)
            return 1

        if new in text:
            skipped += 1
        elif text.count(old) == 1:
            text = text.replace(old, new)
            applied += 1
        else:
            print('[aerium] FATAL: %s has %d matches for the anchor below, '
                  'expected 1 - upstream changed this call site and the '
                  'safe_browsing_mode=0 link guard no longer fits:\n%s'
                  % (path, text.count(old), old), file=sys.stderr)
            return 1

        if need_buildflags and BUILDFLAGS not in text:
            if text.count(after_include) != 1:
                print('[aerium] FATAL: cannot place the buildflags include in '
                      '%s, anchor %r matched %d times'
                      % (path, after_include, text.count(after_include)),
                      file=sys.stderr)
                return 1
            text = text.replace(after_include, after_include + BUILDFLAGS)

        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(text)

    print('[aerium] safe browsing link guards: %d applied, %d already present'
          % (applied, skipped))
    return 0


if __name__ == '__main__':
    sys.exit(main())
