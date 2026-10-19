// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import android.content.SharedPreferences;

import androidx.annotation.Nullable;

import org.chromium.base.ContextUtils;
import org.chromium.chrome.browser.homepage.HomepageManager;
import org.chromium.chrome.browser.profiles.ProfileManager;
import org.chromium.components.prefs.PrefChangeRegistrar;
import org.chromium.components.prefs.PrefService;
import org.chromium.components.user_prefs.UserPrefs;

import io.dioide.aerium.api.CoreSettings;
import io.dioide.aerium.api.Setting;
import io.dioide.aerium.api.SettingsApi;
import io.dioide.aerium.api.Subscription;

import java.util.HashSet;
import java.util.Set;

final class SettingsImpl implements SettingsApi {
    private static final String WEBRTC_PREF = "webrtc.ip_handling_policy";
    private static final String SUGGEST_PREF = "search.suggest_enabled";
    private static final String[] REFERRER_MODES = {
        CoreSettings.REFERRER_FULL, CoreSettings.REFERRER_ORIGIN, CoreSettings.REFERRER_NONE,
    };

    private final Set<SharedPreferences.OnSharedPreferenceChangeListener> mListeners =
            new HashSet<>();

    @Override
    public <T> T get(Setting<T> setting) {
        return setting.type.cast(read(setting));
    }

    @Override
    public <T> void set(Setting<T> setting, T value) {
        if (setting == CoreSettings.EXTERNAL_LINKS_IN_AEROGEL) {
            AeriumPrefs.set(AeriumPrefs.EXTERNAL_LINKS_IN_AEROGEL, (Boolean) value);
        } else if (setting == CoreSettings.CLOSE_TABS_ON_EXIT) {
            AeriumPrefs.set(AeriumPrefs.CLOSE_TABS_ON_EXIT, (Boolean) value);
        } else if (setting == CoreSettings.REFERRER_POLICY) {
            AeriumPrefs.setCrossOriginReferrer(referrerMode((String) value));
        } else if (setting == CoreSettings.WEBRTC_POLICY) {
            prefs().setString(WEBRTC_PREF, webrtcPolicy((String) value));
        } else if (setting == CoreSettings.SEARCH_SUGGESTIONS) {
            prefs().setBoolean(SUGGEST_PREF, (Boolean) value);
        } else if (setting == CoreSettings.HOMEPAGE) {
            HomepageManager.getInstance().setPrefHomepageEnabled((Boolean) value);
        } else {
            throw unknown(setting);
        }
    }

    @Override
    public Subscription observe(Setting<?> setting, Runnable onChange) {
        if (setting == CoreSettings.HOMEPAGE) {
            HomepageManager.HomepageStateListener listener = onChange::run;
            HomepageManager.getInstance().addListener(listener);
            return () -> HomepageManager.getInstance().removeListener(listener);
        }
        String profilePref = profilePref(setting);
        if (profilePref != null) {
            PrefChangeRegistrar registrar = new PrefChangeRegistrar(prefs());
            registrar.addObserver(profilePref, onChange::run);
            return registrar::destroy;
        }
        String key = sharedKey(setting);
        SharedPreferences.OnSharedPreferenceChangeListener listener =
                (shared, changed) -> {
                    if (key.equals(changed)) onChange.run();
                };
        mListeners.add(listener);
        ContextUtils.getAppSharedPreferences().registerOnSharedPreferenceChangeListener(listener);
        return () -> {
            ContextUtils.getAppSharedPreferences()
                    .unregisterOnSharedPreferenceChangeListener(listener);
            mListeners.remove(listener);
        };
    }

    private Object read(Setting<?> setting) {
        if (setting == CoreSettings.EXTERNAL_LINKS_IN_AEROGEL) {
            return AeriumPrefs.get(AeriumPrefs.EXTERNAL_LINKS_IN_AEROGEL);
        }
        if (setting == CoreSettings.CLOSE_TABS_ON_EXIT) {
            return AeriumPrefs.get(AeriumPrefs.CLOSE_TABS_ON_EXIT);
        }
        if (setting == CoreSettings.REFERRER_POLICY) {
            int mode = AeriumPrefs.getCrossOriginReferrer();
            return REFERRER_MODES[mode >= 0 && mode < REFERRER_MODES.length ? mode : 0];
        }
        if (setting == CoreSettings.WEBRTC_POLICY) {
            String value = prefs().getString(WEBRTC_PREF);
            return value.isEmpty() ? CoreSettings.WEBRTC_DEFAULT : value;
        }
        if (setting == CoreSettings.SEARCH_SUGGESTIONS) {
            return prefs().getBoolean(SUGGEST_PREF);
        }
        if (setting == CoreSettings.HOMEPAGE) {
            return HomepageManager.getInstance().isHomepageEnabled();
        }
        throw unknown(setting);
    }

    private static @Nullable String profilePref(Setting<?> setting) {
        if (setting == CoreSettings.WEBRTC_POLICY) return WEBRTC_PREF;
        if (setting == CoreSettings.SEARCH_SUGGESTIONS) return SUGGEST_PREF;
        return null;
    }

    private static String sharedKey(Setting<?> setting) {
        if (setting == CoreSettings.EXTERNAL_LINKS_IN_AEROGEL) {
            return AeriumPrefs.EXTERNAL_LINKS_IN_AEROGEL;
        }
        if (setting == CoreSettings.CLOSE_TABS_ON_EXIT) return AeriumPrefs.CLOSE_TABS_ON_EXIT;
        if (setting == CoreSettings.REFERRER_POLICY) return AeriumPrefs.CROSS_ORIGIN_REFERRER;
        throw unknown(setting);
    }

    private static int referrerMode(String value) {
        for (int i = 0; i < REFERRER_MODES.length; i++) {
            if (REFERRER_MODES[i].equals(value)) return i;
        }
        throw new IllegalArgumentException("Unknown referrer policy " + value);
    }

    private static String webrtcPolicy(String value) {
        switch (value) {
            case CoreSettings.WEBRTC_DEFAULT:
            case CoreSettings.WEBRTC_ALL_INTERFACES:
            case CoreSettings.WEBRTC_PUBLIC_INTERFACE:
            case CoreSettings.WEBRTC_PROXY_ONLY:
                return value;
            default:
                throw new IllegalArgumentException("Unknown WebRTC policy " + value);
        }
    }

    private static PrefService prefs() {
        return UserPrefs.get(ProfileManager.getLastUsedRegularProfile());
    }

    private static IllegalArgumentException unknown(Setting<?> setting) {
        return new IllegalArgumentException("Unknown setting " + setting.key);
    }
}
