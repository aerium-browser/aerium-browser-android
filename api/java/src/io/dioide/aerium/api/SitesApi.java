// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import java.util.List;

public interface SitesApi {
    List<SiteRule> rules();

    SiteMode mode(String site);

    void setMode(String site, SiteMode mode);

    void clear(String site, Runnable done);

    Subscription observe(Runnable onChange);
}
