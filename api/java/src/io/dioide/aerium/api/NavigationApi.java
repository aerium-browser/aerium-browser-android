// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public interface NavigationApi {
    void load(int tabId, String url);

    void back(int tabId);

    void forward(int tabId);

    void reload(int tabId);

    void stop(int tabId);
}
