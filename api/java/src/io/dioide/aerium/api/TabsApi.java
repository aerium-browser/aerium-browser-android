// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import android.app.Activity;
import android.graphics.Bitmap;

import androidx.annotation.Nullable;

import java.util.List;

public interface TabsApi {
    boolean isReady();

    List<TabInfo> list(boolean aerogel);

    List<TabInfo> listAll(boolean aerogel);

    List<TabInfo> list(Activity window);

    @Nullable
    TabInfo current();

    @Nullable
    TabInfo current(Activity window);

    @Nullable
    TabInfo get(int tabId);

    int open(String url, OpenMode mode);

    void launch(String url);

    void select(int tabId);

    void close(int tabId, boolean remember);

    void closeAll(boolean aerogel, boolean remember);

    void move(Activity window, int tabId, int index);

    void setDesktopSite(int tabId, boolean desktopSite);

    @Nullable
    Bitmap favicon(int tabId);

    Subscription observe(Observer observer);

    Subscription observe(Activity window, Observer observer);

    interface Observer {
        default void onTabAdded(TabInfo tab) {}

        default void onTabRemoved(int tabId) {}

        default void onTabUpdated(TabInfo tab) {}

        default void onCurrentTabChanged(@Nullable TabInfo tab) {}

        default void onTabListChanged() {}
    }
}
