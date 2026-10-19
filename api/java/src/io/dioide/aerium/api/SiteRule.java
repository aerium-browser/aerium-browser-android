// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public final class SiteRule {
    public final String site;
    public final SiteMode mode;

    public SiteRule(String site, SiteMode mode) {
        this.site = site;
        this.mode = mode;
    }
}
