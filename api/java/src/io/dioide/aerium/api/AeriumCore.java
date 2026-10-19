// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public interface AeriumCore {
    int VERSION = 1;

    int apiVersion();

    TabsApi tabs();

    NavigationApi navigation();

    ExtensionsApi extensions();

    SettingsApi settings();

    SitesApi sites();

    BrowsingDataApi data();
}
