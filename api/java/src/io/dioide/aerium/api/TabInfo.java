// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public final class TabInfo {
    public final int id;
    public final String url;
    public final String title;
    public final boolean aerogel;
    public final boolean loading;
    public final float progress;
    public final boolean canGoBack;
    public final boolean canGoForward;

    public TabInfo(
            int id,
            String url,
            String title,
            boolean aerogel,
            boolean loading,
            float progress,
            boolean canGoBack,
            boolean canGoForward) {
        this.id = id;
        this.url = url;
        this.title = title;
        this.aerogel = aerogel;
        this.loading = loading;
        this.progress = progress;
        this.canGoBack = canGoBack;
        this.canGoForward = canGoForward;
    }
}
