// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import org.chromium.chrome.browser.tab.Tab;
import org.chromium.content_public.browser.LoadUrlParams;
import org.chromium.ui.base.PageTransition;

import io.dioide.aerium.api.NavigationApi;

final class NavigationImpl implements NavigationApi {
    @Override
    public void load(int tabId, String url) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab != null) tab.loadUrl(new LoadUrlParams(url, PageTransition.TYPED));
    }

    @Override
    public void back(int tabId) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab != null && tab.canGoBack()) tab.goBack();
    }

    @Override
    public void forward(int tabId) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab != null && tab.canGoForward()) tab.goForward();
    }

    @Override
    public void reload(int tabId) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab != null) tab.reload();
    }

    @Override
    public void stop(int tabId) {
        Tab tab = TabsImpl.tab(tabId);
        if (tab != null) tab.stopLoading();
    }
}
