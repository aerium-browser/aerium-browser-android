// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import androidx.annotation.Nullable;

import java.util.List;

public interface TabsApi {
    boolean isReady();

    List<TabInfo> list(boolean aerogel);

    @Nullable
    TabInfo current();

    @Nullable
    TabInfo get(int tabId);

    int open(String url, OpenMode mode);

    void launch(String url);

    void select(int tabId);

    void close(int tabId, boolean remember);

    void closeAll(boolean aerogel, boolean remember);

    void setDesktopSite(int tabId, boolean desktopSite);

    Subscription observe(Observer observer);

    interface Observer {
        default void onTabAdded(TabInfo tab) {}

        default void onTabRemoved(int tabId) {}

        default void onTabUpdated(TabInfo tab) {}

        default void onCurrentTabChanged(@Nullable TabInfo tab) {}
    }
}
