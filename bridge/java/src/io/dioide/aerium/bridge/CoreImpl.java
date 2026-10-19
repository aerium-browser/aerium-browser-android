// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import io.dioide.aerium.api.ActionsApi;
import io.dioide.aerium.api.AeriumCore;
import io.dioide.aerium.api.BrowsingDataApi;
import io.dioide.aerium.api.ExtensionsApi;
import io.dioide.aerium.api.NavigationApi;
import io.dioide.aerium.api.PrefsApi;
import io.dioide.aerium.api.SettingsApi;
import io.dioide.aerium.api.SitesApi;
import io.dioide.aerium.api.TabsApi;
import io.dioide.aerium.api.WebAppsApi;

final class CoreImpl implements AeriumCore {
    private final SettingsApi mSettings = new SettingsImpl();
    private final TabsApi mTabs = new TabsImpl();
    private final NavigationApi mNavigation = new NavigationImpl();
    private final BrowsingDataApi mBrowsingData = new BrowsingDataImpl();
    private final ExtensionsApi mExtensions = new ExtensionsImpl();
    private final SitesApi mSites = new SitesImpl();
    private final PrefsApi mPrefs = new PrefsImpl();
    private final ActionsApi mActions = new ActionsImpl();
    private final WebAppsApi mWebApps = new WebAppsImpl();

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

    @Override
    public ExtensionsApi extensions() {
        return mExtensions;
    }

    @Override
    public SitesApi sites() {
        return mSites;
    }

    @Override
    public PrefsApi prefs() {
        return mPrefs;
    }

    @Override
    public ActionsApi actions() {
        return mActions;
    }

    @Override
    public WebAppsApi webApps() {
        return mWebApps;
    }
}
