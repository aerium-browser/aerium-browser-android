// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;

import androidx.annotation.Nullable;

import org.chromium.base.ContextUtils;
import org.chromium.base.task.PostTask;
import org.chromium.base.task.TaskTraits;
import org.chromium.chrome.browser.settings.SettingsNavigationFactory;
import org.chromium.chrome.browser.site_settings.ChromeSiteSettingsDelegate;
import org.chromium.chrome.browser.tab.Tab;
import org.chromium.chrome.browser.tab.TabUtils;
import org.chromium.chrome.browser.ui.favicon.FaviconHelper;
import org.chromium.components.browser_ui.site_settings.SingleWebsiteSettings;
import org.chromium.components.browser_ui.site_settings.SiteDataCleaner;
import org.chromium.components.browser_ui.site_settings.Website;
import org.chromium.components.browser_ui.site_settings.WebsiteAddress;
import org.chromium.components.browser_ui.site_settings.WebsitePermissionsFetcher;
import org.chromium.components.browser_ui.site_settings.WebsitePreferenceBridge;
import org.chromium.components.content_settings.ContentSetting;
import org.chromium.components.content_settings.ContentSettingsType;
import org.chromium.components.security_state.ConnectionSecurityLevel;
import org.chromium.components.security_state.SecurityStateModel;
import org.chromium.content_public.browser.WebContents;

import io.dioide.aerium.api.SiteUsage;
import io.dioide.aerium.api.SitesApi;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Locale;
import java.util.function.Consumer;

final class SitesImpl implements SitesApi {
    @Override
    public boolean isSecure(int tabId) {
        Tab tab = TabsImpl.tab(tabId);
        WebContents contents = tab == null ? null : tab.getWebContents();
        return contents != null
                && SecurityStateModel.getSecurityLevelForWebContents(contents)
                        == ConnectionSecurityLevel.SECURE;
    }

    @Override
    public @Nullable String registrableDomain(String host) {
        WebsiteAddress address = WebsiteAddress.create(host);
        String domain = address == null ? null : address.getDomainAndRegistry();
        return domain == null ? null : domain.toLowerCase(Locale.US);
    }

    @Override
    public void usage(int tabId, Consumer<SiteUsage> result) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab == null) {
            result.accept(new SiteUsage(0, 0, 0));
            return;
        }
        fetch(
                tab,
                sites -> {
                    int cookies = 0;
                    long bytes = 0;
                    int permissions = 0;
                    for (Website site : sites) {
                        cookies += site.getNumberOfCookies();
                        bytes += site.getTotalUsage();
                        permissions +=
                                site.getPermissionInfos().size()
                                        + site.getChosenObjectInfo().size();
                    }
                    result.accept(new SiteUsage(cookies, bytes, permissions));
                });
    }

    @Override
    public void clearData(int tabId, Runnable done) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab == null) {
            done.run();
            return;
        }
        ChromeSiteSettingsDelegate delegate = delegate(tab);
        fetch(
                tab,
                sites -> {
                    if (sites.isEmpty()) {
                        done.run();
                        return;
                    }
                    int[] left = {sites.size()};
                    for (Website site : sites) {
                        SiteDataCleaner.clearData(
                                delegate,
                                site,
                                () -> {
                                    left[0]--;
                                    if (left[0] == 0) done.run();
                                });
                    }
                });
    }

    @Override
    public boolean isAllowed(int tabId, Permission permission) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab == null) return false;
        return WebsitePreferenceBridge.getContentSetting(
                        tab.getProfile(), type(permission), tab.getUrl(), tab.getUrl())
                == ContentSetting.ALLOW;
    }

    @Override
    public void setAllowed(int tabId, Permission permission, boolean allowed) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab == null) return;
        WebsitePreferenceBridge.setContentSettingDefaultScope(
                tab.getProfile(),
                type(permission),
                tab.getUrl(),
                tab.getUrl(),
                allowed ? ContentSetting.ALLOW : ContentSetting.BLOCK);
    }

    @Override
    public void icon(int tabId, int sizePx, Consumer<Bitmap> result) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab == null) return;
        FaviconHelper favicons = new FaviconHelper();
        boolean[] released = {false};
        Runnable release =
                () -> {
                    if (released[0]) return;
                    released[0] = true;
                    PostTask.postTask(TaskTraits.UI_DEFAULT, favicons::destroy);
                };
        boolean started =
                favicons.getLocalFaviconImageForURL(
                        tab.getProfile(),
                        tab.getUrl(),
                        sizePx,
                        true,
                        (image, iconUrl) -> {
                            release.run();
                            if (image != null) result.accept(image);
                        });
        if (!started) release.run();
    }

    @Override
    public void openSettings(int tabId) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab == null) return;
        SettingsNavigationFactory.createSettingsNavigation()
                .startSettings(
                        context(tab),
                        SingleWebsiteSettings.class,
                        SingleWebsiteSettings.createFragmentArgsForSite(tab.getUrl().getSpec()));
    }

    private static void fetch(Tab tab, Consumer<List<Website>> result) {
        String host = tab.getUrl().getHost();
        WebsiteAddress address = WebsiteAddress.create(host);
        String domain = address == null ? null : address.getDomainAndRegistry();
        new WebsitePermissionsFetcher(delegate(tab))
                .fetchAllPreferences(
                        (Collection<Website> all) -> {
                            List<Website> exact = new ArrayList<>();
                            List<Website> sameDomain = new ArrayList<>();
                            for (Website site : all) {
                                WebsiteAddress siteAddress = site.getAddress();
                                String siteHost = siteAddress.getHost();
                                if (siteHost != null && siteHost.equalsIgnoreCase(host)) {
                                    exact.add(site);
                                } else if (domain != null
                                        && domain.equalsIgnoreCase(
                                                siteAddress.getDomainAndRegistry())) {
                                    sameDomain.add(site);
                                }
                            }
                            result.accept(exact.isEmpty() ? sameDomain : exact);
                        });
    }

    private static ChromeSiteSettingsDelegate delegate(Tab tab) {
        return new ChromeSiteSettingsDelegate(context(tab), tab.getProfile());
    }

    private static Context context(Tab tab) {
        Activity activity = TabUtils.getActivity(tab);
        return activity != null ? activity : ContextUtils.getApplicationContext();
    }

    private static int type(Permission permission) {
        switch (permission) {
            case JAVASCRIPT:
                return ContentSettingsType.JAVASCRIPT;
            case COOKIES:
                return ContentSettingsType.COOKIES;
            case POPUPS:
                return ContentSettingsType.POPUPS;
            case SOUND:
                return ContentSettingsType.SOUND;
        }
        throw new IllegalArgumentException("Unknown permission " + permission);
    }
}
