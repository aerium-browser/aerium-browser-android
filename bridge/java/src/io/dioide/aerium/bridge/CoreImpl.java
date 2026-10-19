// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import io.dioide.aerium.api.AeriumCore;
import io.dioide.aerium.api.BrowsingDataApi;
import io.dioide.aerium.api.NavigationApi;
import io.dioide.aerium.api.SettingsApi;
import io.dioide.aerium.api.TabsApi;

final class CoreImpl implements AeriumCore {
    private final SettingsApi mSettings = new SettingsImpl();
    private final TabsApi mTabs = new TabsImpl();
    private final NavigationApi mNavigation = new NavigationImpl();
    private final BrowsingDataApi mBrowsingData = new BrowsingDataImpl();

    @Override
    public int apiVersion() {
        return VERSION;
    }

    @Override
    public SettingsApi settings() {
        return mSettings;
    }

    @Override
    public TabsApi tabs() {
        return mTabs;
    }

    @Override
    public NavigationApi navigation() {
        return mNavigation;
    }

    @Override
    public BrowsingDataApi browsingData() {
        return mBrowsingData;
    }
}
