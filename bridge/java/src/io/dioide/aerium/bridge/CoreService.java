// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import org.chromium.build.annotations.ServiceImpl;

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

@ServiceImpl(AeriumCore.class)
public class CoreService implements AeriumCore {
    private final AeriumCore mCore = Aerium.core();

    @Override
    public int apiVersion() {
        return mCore.apiVersion();
    }

    @Override
    public SettingsApi settings() {
        return mCore.settings();
    }

    @Override
    public TabsApi tabs() {
        return mCore.tabs();
    }

    @Override
    public NavigationApi navigation() {
        return mCore.navigation();
    }

    @Override
    public BrowsingDataApi browsingData() {
        return mCore.browsingData();
    }

    @Override
    public ExtensionsApi extensions() {
        return mCore.extensions();
    }

    @Override
    public SitesApi sites() {
        return mCore.sites();
    }

    @Override
    public PrefsApi prefs() {
        return mCore.prefs();
    }

    @Override
    public ActionsApi actions() {
        return mCore.actions();
    }

    @Override
    public WebAppsApi webApps() {
        return mCore.webApps();
    }
}
