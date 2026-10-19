// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

#include <string>
#include <vector>

#include "base/android/jni_array.h"
#include "base/android/jni_string.h"
#include "chrome/browser/extensions/extension_util.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/browser/ui/toolbar/toolbar_actions_model.h"
#include "extensions/browser/disable_reason.h"
#include "extensions/browser/extension_registrar.h"
#include "extensions/browser/extension_registry.h"
#include "extensions/browser/extension_util.h"
#include "extensions/browser/ui_util.h"
#include "extensions/browser/uninstall_reason.h"
#include "extensions/common/extension.h"
#include "extensions/common/manifest_handlers/options_page_info.h"
#include "url/gurl.h"

#include "aerium/bridge/jni_headers/ExtensionsImpl_jni.h"

namespace {

const extensions::Extension* Find(Profile* profile, const std::string& id) {
  return extensions::ExtensionRegistry::Get(profile)->GetInstalledExtension(id);
}

const char* Flag(bool value) {
  return value ? "1" : "0";
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

DEFINE_JNI(ExtensionsImpl)
