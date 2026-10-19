// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import java.util.Set;

public interface BrowsingDataApi {
    enum Kind {
        HISTORY,
        SITE_DATA,
        CACHE,
        FORM_DATA,
        SITE_SETTINGS
    }

    enum Period {
        LAST_15_MINUTES,
        LAST_HOUR,
        LAST_DAY,
        LAST_WEEK,
        FOUR_WEEKS,
        ALL_TIME
    }

    void clear(Set<Kind> kinds, Period period, Set<String> keepDomains, Runnable done);
}
