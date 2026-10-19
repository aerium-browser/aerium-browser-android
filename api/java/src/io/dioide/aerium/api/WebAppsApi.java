// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import java.util.List;

public interface WebAppsApi {
    List<WebAppInfo> list();

    boolean launch(String id);

    void remove(String id);
}
