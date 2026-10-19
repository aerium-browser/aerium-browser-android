// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import android.graphics.Bitmap;

import androidx.annotation.Nullable;

public final class WebAppInfo {
    public final String id;
    public final String name;
    public final String url;
    public final String scope;
    public final @Nullable Bitmap icon;

    public WebAppInfo(String id, String name, String url, String scope, @Nullable Bitmap icon) {
        this.id = id;
        this.name = name;
        this.url = url;
        this.scope = scope;
        this.icon = icon;
    }
}
