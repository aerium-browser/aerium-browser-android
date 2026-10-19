// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import org.chromium.chrome.browser.browsing_data.BrowsingDataBridge;
import org.chromium.chrome.browser.browsing_data.BrowsingDataType;
import org.chromium.chrome.browser.browsing_data.TimePeriod;
import org.chromium.chrome.browser.profiles.ProfileManager;

import io.dioide.aerium.api.BrowsingDataApi;

import java.util.Set;

final class BrowsingDataImpl implements BrowsingDataApi {
    @Override
    public void clear(Set<Kind> kinds, Period period, Set<String> keepDomains, Runnable done) {
        int[] types = new int[kinds.size()];
        int i = 0;
        for (Kind kind : kinds) types[i++] = type(kind);
        BrowsingDataBridge.getForProfile(ProfileManager.getLastUsedRegularProfile())
                .clearBrowsingDataExcludingDomains(
                        done::run,
                        types,
                        timePeriod(period),
                        keepDomains.toArray(new String[0]),
                        new String[0]);
    }

    private static int type(Kind kind) {
        switch (kind) {
            case HISTORY:
                return BrowsingDataType.HISTORY;
            case SITE_DATA:
                return BrowsingDataType.SITE_DATA;
            case CACHE:
                return BrowsingDataType.CACHE;
            case FORM_DATA:
                return BrowsingDataType.FORM_DATA;
            case SITE_SETTINGS:
                return BrowsingDataType.SITE_SETTINGS;
        }
        throw new IllegalArgumentException("Unknown kind " + kind);
    }

    private static int timePeriod(Period period) {
        switch (period) {
            case LAST_15_MINUTES:
                return TimePeriod.LAST_15_MINUTES;
            case LAST_HOUR:
                return TimePeriod.LAST_HOUR;
            case LAST_DAY:
                return TimePeriod.LAST_DAY;
            case LAST_WEEK:
                return TimePeriod.LAST_WEEK;
            case FOUR_WEEKS:
                return TimePeriod.FOUR_WEEKS;
            case ALL_TIME:
                return TimePeriod.ALL_TIME;
        }
        throw new IllegalArgumentException("Unknown period " + period);
    }
}
