// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import java.util.Set;

public interface BrowsingDataApi {
    enum Kind {
        HISTORY,
        SITE_DATA,
        CACHE,
        DOWNLOADS,
        FORM_DATA
    }

    void clear(Set<Kind> kinds, boolean keepRuledSites, Runnable done);
}
