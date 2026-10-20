// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import android.content.Context;
import android.content.Intent;
import android.content.pm.ShortcutManager;
import android.graphics.Bitmap;

import androidx.annotation.Nullable;

import org.chromium.base.ContextUtils;
import org.chromium.base.IntentUtils;
import org.chromium.base.Log;
import org.chromium.base.StrictModeContext;
import org.chromium.chrome.browser.browserservices.intents.BitmapHelper;
import org.chromium.chrome.browser.browserservices.intents.WebappConstants;
import org.chromium.chrome.browser.webapps.WebappDataStorage;
import org.chromium.chrome.browser.webapps.WebappRegistry;

import io.dioide.aerium.api.WebAppInfo;
import io.dioide.aerium.api.WebAppsApi;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

final class WebAppsImpl implements WebAppsApi {
    private static final String TAG = "AeriumWebApps";

    @Override
    public List<WebAppInfo> list() {
        List<WebAppInfo> apps = new ArrayList<>();
        for (WebappDataStorage app : installed()) {
            Intent launch = app.createWebappLaunchIntent();
            if (launch == null) continue;
            apps.add(
                    new WebAppInfo(
                            app.getId(),
                            name(launch, app),
                            app.getUrl(),
                            app.getScope(),
                            icon(launch)));
        }
        return apps;
    }

    @Override
    public boolean launch(String id) {
        WebappDataStorage app = find(id);
        Intent launch = app == null ? null : app.createWebappLaunchIntent();
        return launch != null && start(launch);
    }

    @Override
    public @Nullable String findForUrl(String url) {
        WebappDataStorage app;
        try (StrictModeContext ignored = StrictModeContext.allowDiskReads()) {
            WebappRegistry.warmUpSharedPrefs();
            app = WebappRegistry.getInstance().getWebappDataStorageForUrl(url);
        }
        return app == null ? null : app.getId();
    }

    @Override
    public boolean open(String id, String url) {
        WebappDataStorage app = find(id);
        Intent launch = app == null ? null : app.createWebappLaunchIntent();
        if (launch == null) return false;
        launch.putExtra(WebappConstants.EXTRA_URL, url);
        launch.putExtra(WebappConstants.EXTRA_FORCE_NAVIGATION, true);
        return start(launch);
    }

    private static boolean start(Intent launch) {
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        IntentUtils.addTrustedIntentExtras(launch);
        return IntentUtils.safeStartActivity(ContextUtils.getApplicationContext(), launch);
    }

    @Override
    public void remove(String id) {
        if (find(id) == null) return;
        WebappRegistry.getInstance().removeWebapp(id);
        Context context = ContextUtils.getApplicationContext();
        ShortcutManager shortcuts = context.getSystemService(ShortcutManager.class);
        if (shortcuts == null) return;
        try {
            shortcuts.disableShortcuts(Collections.singletonList(id));
        } catch (IllegalArgumentException | IllegalStateException e) {
            Log.w(TAG, "Could not disable the home screen shortcut", e);
        }
    }

    private static List<WebappDataStorage> installed() {
        try (StrictModeContext ignored = StrictModeContext.allowDiskReads()) {
            WebappRegistry.warmUpSharedPrefs();
            return WebappRegistry.getInstance().getInstalledWebapps();
        }
    }

    private static @Nullable WebappDataStorage find(String id) {
        for (WebappDataStorage app : installed()) {
            if (app.getId().equals(id)) return app;
        }
        return null;
    }

    private static String name(Intent launch, WebappDataStorage app) {
        String name = IntentUtils.safeGetStringExtra(launch, WebappConstants.EXTRA_SHORT_NAME);
        if (name == null || name.isEmpty()) {
            name = IntentUtils.safeGetStringExtra(launch, WebappConstants.EXTRA_NAME);
        }
        return name == null || name.isEmpty() ? app.getUrl() : name;
    }

    private static @Nullable Bitmap icon(Intent launch) {
        String encoded = IntentUtils.safeGetStringExtra(launch, WebappConstants.EXTRA_ICON);
        return encoded == null ? null : BitmapHelper.decodeBitmapFromString(encoded);
    }
}
