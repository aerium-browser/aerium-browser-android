// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import android.graphics.Bitmap;

import androidx.annotation.Nullable;

import java.util.function.Consumer;

public interface SitesApi {
    enum Permission {
        JAVASCRIPT,
        COOKIES,
        POPUPS,
        SOUND
    }

    boolean isSecure(int tabId);

    @Nullable
    String registrableDomain(String host);

    void usage(int tabId, Consumer<SiteUsage> result);

    void clearData(int tabId, Runnable done);

    boolean isAllowed(int tabId, Permission permission);

    void setAllowed(int tabId, Permission permission, boolean allowed);

    void icon(int tabId, int sizePx, Consumer<Bitmap> result);

    void openSettings(int tabId);
}
