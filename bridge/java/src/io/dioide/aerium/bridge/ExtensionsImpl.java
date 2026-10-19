// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import org.jni_zero.JniType;
import org.jni_zero.NativeMethods;

import org.chromium.base.task.PostTask;
import org.chromium.base.task.TaskTraits;
import org.chromium.chrome.browser.profiles.Profile;
import org.chromium.chrome.browser.profiles.ProfileManager;
import org.chromium.components.prefs.PrefChangeRegistrar;
import org.chromium.components.user_prefs.UserPrefs;

import io.dioide.aerium.api.ExtensionInfo;
import io.dioide.aerium.api.ExtensionsApi;
import io.dioide.aerium.api.Subscription;

import java.util.ArrayList;
import java.util.List;

final class ExtensionsImpl implements ExtensionsApi {
    private static final String SETTINGS_PREF = "extensions.settings";
    private static final String PINNED_PREF = "extensions.pinned_extensions";
    private static final int FIELDS = 7;

    @Override
    public List<ExtensionInfo> list() {
        String[] fields = ExtensionsImplJni.get().list(profile());
        List<ExtensionInfo> extensions = new ArrayList<>();
        for (int i = 0; i + FIELDS <= fields.length; i += FIELDS) {
            extensions.add(
                    new ExtensionInfo(
                            fields[i],
                            fields[i + 1],
                            fields[i + 2],
                            flag(fields[i + 3]),
                            flag(fields[i + 4]),
                            flag(fields[i + 5]),
                            flag(fields[i + 6])));
        }
        return extensions;
    }

    @Override
    public void setEnabled(String id, boolean enabled) {
        ExtensionsImplJni.get().setEnabled(profile(), id, enabled);
    }

    @Override
    public void setAllowedInAerogel(String id, boolean allowed) {
        ExtensionsImplJni.get().setAllowedInAerogel(profile(), id, allowed);
    }

    @Override
    public void setPinned(String id, boolean pinned) {
        ExtensionsImplJni.get().setPinned(profile(), id, pinned);
    }

    @Override
    public void remove(String id) {
        ExtensionsImplJni.get().remove(profile(), id);
    }

    @Override
    public void openOptions(String id) {
        String url = ExtensionsImplJni.get().optionsUrl(profile(), id);
        if (!url.isEmpty()) Aerium.core().tabs().launch(url);
    }

    @Override
    public Subscription observe(Runnable onChange) {
        PrefChangeRegistrar registrar = new PrefChangeRegistrar(UserPrefs.get(profile()));
        PrefChangeRegistrar.PrefObserver observer =
                () -> PostTask.postTask(TaskTraits.UI_DEFAULT, onChange);
        registrar.addObserver(SETTINGS_PREF, observer);
        registrar.addObserver(PINNED_PREF, observer);
        return registrar::destroy;
    }

    private static boolean flag(String value) {
        return "1".equals(value);
    }

    private static Profile profile() {
        return ProfileManager.getLastUsedRegularProfile();
    }

    @NativeMethods
    interface Natives {
        @JniType("std::vector<std::string>")
        String[] list(@JniType("Profile*") Profile profile);

        void setEnabled(
                @JniType("Profile*") Profile profile,
                @JniType("std::string") String id,
                boolean enabled);

        void setAllowedInAerogel(
                @JniType("Profile*") Profile profile,
                @JniType("std::string") String id,
                boolean allowed);

        void setPinned(
                @JniType("Profile*") Profile profile,
                @JniType("std::string") String id,
                boolean pinned);

        void remove(@JniType("Profile*") Profile profile, @JniType("std::string") String id);

        @JniType("std::string")
        String optionsUrl(@JniType("Profile*") Profile profile, @JniType("std::string") String id);
    }
}
