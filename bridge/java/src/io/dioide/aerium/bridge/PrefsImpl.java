// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import org.chromium.chrome.browser.profiles.ProfileManager;
import org.chromium.components.prefs.PrefChangeRegistrar;
import org.chromium.components.prefs.PrefService;
import org.chromium.components.user_prefs.UserPrefs;

import io.dioide.aerium.api.PrefsApi;
import io.dioide.aerium.api.Subscription;

final class PrefsImpl implements PrefsApi {
    @Override
    public boolean getBoolean(String name) {
        return prefs().getBoolean(name);
    }

    @Override
    public void setBoolean(String name, boolean value) {
        prefs().setBoolean(name, value);
    }

    @Override
    public int getInteger(String name) {
        return prefs().getInteger(name);
    }

    @Override
    public void setInteger(String name, int value) {
        prefs().setInteger(name, value);
    }

    @Override
    public String getString(String name) {
        return prefs().getString(name);
    }

    @Override
    public void setString(String name, String value) {
        prefs().setString(name, value);
    }

    @Override
    public Subscription observe(String name, Runnable onChange) {
        PrefChangeRegistrar registrar = new PrefChangeRegistrar(prefs());
        registrar.addObserver(name, onChange::run);
        return registrar::destroy;
    }

    private static PrefService prefs() {
        return UserPrefs.get(ProfileManager.getLastUsedRegularProfile());
    }
}
