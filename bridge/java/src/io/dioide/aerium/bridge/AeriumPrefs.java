// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import org.chromium.base.CommandLine;
import org.chromium.base.ContextUtils;

public final class AeriumPrefs {
    public static final String EXTERNAL_LINKS_IN_AEROGEL = "aerium.external_links_in_aerogel";
    public static final String CLOSE_TABS_ON_EXIT = "aerium.close_tabs_on_exit";
    public static final String CROSS_ORIGIN_REFERRER = "aerium.cross_origin_referrer";
    public static final String CROSS_ORIGIN_REFERRER_SWITCH = "aerium-cross-origin-referrer";

    private AeriumPrefs() {}

    public static boolean get(String key) {
        return ContextUtils.getAppSharedPreferences().getBoolean(key, false);
    }

    public static void set(String key, boolean value) {
        ContextUtils.getAppSharedPreferences().edit().putBoolean(key, value).apply();
    }

    public static boolean startWithoutTabs(boolean activityRestored) {
        return !activityRestored && get(CLOSE_TABS_ON_EXIT);
    }

    public static int getCrossOriginReferrer() {
        return ContextUtils.getAppSharedPreferences().getInt(CROSS_ORIGIN_REFERRER, 0);
    }

    public static void setCrossOriginReferrer(int mode) {
        ContextUtils.getAppSharedPreferences().edit().putInt(CROSS_ORIGIN_REFERRER, mode).apply();
    }

    public static void applyToCommandLine() {
        int mode = getCrossOriginReferrer();
        if (mode == 1 || mode == 2) {
            CommandLine.getInstance()
                    .appendSwitchWithValue(CROSS_ORIGIN_REFERRER_SWITCH, Integer.toString(mode));
        }
    }
}
