// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public interface AeriumCore {
    int VERSION = 1;

    int apiVersion();

    SettingsApi settings();

    TabsApi tabs();

    NavigationApi navigation();

    BrowsingDataApi browsingData();

    ExtensionsApi extensions();
}
