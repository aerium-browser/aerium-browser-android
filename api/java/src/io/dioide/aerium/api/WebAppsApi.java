// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import androidx.annotation.Nullable;

import java.util.List;

public interface WebAppsApi {
    List<WebAppInfo> list();

    boolean launch(String id);

    @Nullable
    String findForUrl(String url);

    boolean open(String id, String url);

    void remove(String id);
}
