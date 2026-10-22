// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "base/android/callback_android.h"
#include "base/android/jni_array.h"
#include "base/android/jni_string.h"
#include "base/android/scoped_java_ref.h"
#include "base/files/file_path.h"
#include "base/functional/bind.h"
#include "base/memory/scoped_refptr.h"
#include "chrome/browser/extensions/chrome_zipfile_installer.h"
#include "chrome/browser/extensions/extension_util.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/browser/ui/toolbar/toolbar_actions_model.h"
#include "extensions/browser/crx_installer.h"
#include "extensions/browser/disable_reason.h"
#include "extensions/browser/extension_file_task_runner.h"
#include "extensions/browser/extension_registrar.h"
#include "extensions/browser/extension_registry.h"
#include "extensions/browser/extension_util.h"
#include "extensions/browser/install/crx_install_error.h"
#include "extensions/browser/ui_util.h"
#include "extensions/browser/uninstall_reason.h"
#include "extensions/browser/zipfile_installer.h"
#include "extensions/common/extension.h"
#include "extensions/common/manifest_handlers/options_page_info.h"
#include "third_party/jni_zero/jni_zero.h"
#include "url/gurl.h"

#include "aerium/bridge/jni_headers/ExtensionsImpl_jni.h"

namespace {

const extensions::Extension* Find(Profile* profile, const std::string& id) {
  return extensions::ExtensionRegistry::Get(profile)->GetInstalledExtension(id);
}

const char* Flag(bool value) {
  return value ? "1" : "0";
}

void OnCrxInstalled(const base::android::ScopedJavaGlobalRef<jobject>& done,
                    const std::optional<extensions::CrxInstallError>& error) {
  base::android::RunBooleanCallbackAndroid(done, !error.has_value());
}

void OnZipUnpacked(extensions::ZipFileInstaller::DoneCallback load,
                   const base::android::ScopedJavaGlobalRef<jobject>& done,
                   const base::FilePath& zip_file,
                   const base::FilePath& unzip_dir,
                   const std::string& error) {
  const bool unpacked = error.empty();
  std::move(load).Run(zip_file, unzip_dir, error);
  base::android::RunBooleanCallbackAndroid(done, unpacked);
}

}  // namespace

static std::vector<std::string> JNI_ExtensionsImpl_List(JNIEnv* env,
                                                        Profile* profile) {
  std::vector<std::string> fields;
  extensions::ExtensionRegistry* registry =
      extensions::ExtensionRegistry::Get(profile);
  ToolbarActionsModel* toolbar = ToolbarActionsModel::Get(profile);
  for (const auto& extension : registry->GenerateInstalledExtensionsSet()) {
    if (!extensions::ui_util::ShouldDisplayInExtensionSettings(*extension)) {
      continue;
    }
    const std::string& id = extension->id();
    fields.push_back(id);
    fields.push_back(extension->name());
    fields.push_back(extension->VersionString());
    fields.push_back(Flag(registry->enabled_extensions().Contains(id)));
    fields.push_back(Flag(extensions::util::IsIncognitoEnabled(id, profile)));
    fields.push_back(Flag(toolbar && toolbar->IsActionPinned(id)));
    fields.push_back(
        Flag(extensions::OptionsPageInfo::HasOptionsPage(extension.get())));
  }
  return fields;
}

static void JNI_ExtensionsImpl_SetEnabled(JNIEnv* env,
                                          Profile* profile,
                                          const std::string& id,
                                          bool enabled) {
  if (!Find(profile, id)) {
    return;
  }
  extensions::ExtensionRegistrar* registrar =
      extensions::ExtensionRegistrar::Get(profile);
  if (enabled) {
    registrar->EnableExtension(id);
  } else {
    registrar->DisableExtension(
        id, {extensions::disable_reason::DISABLE_USER_ACTION});
  }
}

static void JNI_ExtensionsImpl_SetAllowedInAerogel(JNIEnv* env,
                                                   Profile* profile,
                                                   const std::string& id,
                                                   bool allowed) {
  const extensions::Extension* extension = Find(profile, id);
  if (!extension || !extensions::util::CanBeIncognitoEnabled(extension)) {
    return;
  }
  extensions::util::SetIsIncognitoEnabled(id, profile, allowed);
}

static void JNI_ExtensionsImpl_SetPinned(JNIEnv* env,
                                         Profile* profile,
                                         const std::string& id,
                                         bool pinned) {
  ToolbarActionsModel* toolbar = ToolbarActionsModel::Get(profile);
  if (!toolbar || !toolbar->actions_initialized() || !toolbar->HasAction(id)) {
    return;
  }
  toolbar->SetActionVisibility(id, pinned);
}

static void JNI_ExtensionsImpl_Remove(JNIEnv* env,
                                      Profile* profile,
                                      const std::string& id) {
  if (!Find(profile, id)) {
    return;
  }
  std::u16string error;
  extensions::ExtensionRegistrar::Get(profile)->UninstallExtension(
      id, extensions::UNINSTALL_REASON_USER_INITIATED, &error);
}

static std::string JNI_ExtensionsImpl_OptionsUrl(JNIEnv* env,
                                                 Profile* profile,
                                                 const std::string& id) {
  const extensions::Extension* extension = Find(profile, id);
  if (!extension || !extensions::OptionsPageInfo::HasOptionsPage(extension)) {
    return std::string();
  }
  return extensions::OptionsPageInfo::GetOptionsPage(extension).spec();
}

static void JNI_ExtensionsImpl_Install(
    JNIEnv* env,
    Profile* profile,
    const std::string& path,
    const jni_zero::JavaParamRef<jobject>& done) {
  const base::FilePath file(path);
  base::android::ScopedJavaGlobalRef<jobject> callback(done);
  if (file.MatchesExtension(FILE_PATH_LITERAL(".zip"))) {
    extensions::ZipFileInstaller::Create(
        extensions::GetExtensionFileTaskRunner(),
        base::BindOnce(
            &OnZipUnpacked,
            extensions::MakeRegisterInExtensionServiceCallback(profile),
            std::move(callback)))
        ->InstallZipFileToUnpackedExtensionsDir(
            file, extensions::ExtensionRegistrar::Get(profile)
                      ->unpacked_install_directory());
    return;
  }
  scoped_refptr<extensions::CrxInstaller> installer =
      extensions::CrxInstaller::CreateSilent(profile);
  installer->set_allow_silent_install(true);
  installer->set_off_store_install_allow_reason(
      extensions::CrxInstaller::OffStoreInstallAllowedFromSettingsPage);
  installer->AddInstallerCallback(
      base::BindOnce(&OnCrxInstalled, std::move(callback)));
  installer->InstallCrx(file);
}

DEFINE_JNI(ExtensionsImpl)
