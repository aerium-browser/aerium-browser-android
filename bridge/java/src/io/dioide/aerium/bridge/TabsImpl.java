// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import android.app.Activity;

import androidx.annotation.Nullable;

import org.chromium.base.ApplicationStatus;
import org.chromium.base.Callback;
import org.chromium.chrome.browser.app.tabwindow.TabWindowManagerSingleton;
import org.chromium.chrome.browser.tab.Tab;
import org.chromium.chrome.browser.tab.TabLaunchType;
import org.chromium.chrome.browser.tab.TabSelectionType;
import org.chromium.chrome.browser.tabmodel.TabClosureParams;
import org.chromium.chrome.browser.tabmodel.TabModel;
import org.chromium.chrome.browser.tabmodel.TabModelSelector;
import org.chromium.chrome.browser.tabmodel.TabModelSelectorTabObserver;
import org.chromium.chrome.browser.tabmodel.TabModelUtils;
import org.chromium.chrome.browser.tabwindow.TabWindowManager;
import org.chromium.content_public.browser.LoadUrlParams;
import org.chromium.content_public.browser.NavigationHandle;

import io.dioide.aerium.api.OpenMode;
import io.dioide.aerium.api.Subscription;
import io.dioide.aerium.api.TabInfo;
import io.dioide.aerium.api.TabsApi;

import java.util.ArrayList;
import java.util.List;

final class TabsImpl implements TabsApi {
    @Override
    public List<TabInfo> list(boolean aerogel) {
        List<TabInfo> tabs = new ArrayList<>();
        TabModelSelector selector = selector();
        if (selector == null) return tabs;
        for (Tab tab : selector.getModel(aerogel)) tabs.add(info(tab));
        return tabs;
    }

    @Override
    public @Nullable TabInfo current() {
        TabModelSelector selector = selector();
        Tab tab = selector == null ? null : selector.getCurrentTab();
        return tab == null ? null : info(tab);
    }

    @Override
    public int open(String url, OpenMode mode) {
        TabModelSelector selector = selector();
        if (selector == null) return Tab.INVALID_TAB_ID;
        int type =
                mode == OpenMode.BACKGROUND
                        ? TabLaunchType.FROM_LONGPRESS_BACKGROUND
                        : TabLaunchType.FROM_CHROME_UI;
        Tab tab =
                selector.openNewTab(
                        new LoadUrlParams(url), type, null, mode == OpenMode.AEROGEL);
        return tab == null ? Tab.INVALID_TAB_ID : tab.getId();
    }

    @Override
    public void select(int tabId) {
        TabModelSelector selector = selector();
        TabModel model = selector == null ? null : selector.getModelForTabId(tabId);
        if (model == null) return;
        selector.selectModel(model.isIncognitoBranded());
        TabModelUtils.selectTabById(selector, tabId, TabSelectionType.FROM_USER);
    }

    @Override
    public void close(int tabId) {
        TabModelSelector selector = selector();
        Tab tab = selector == null ? null : selector.getTabById(tabId);
        if (tab == null) return;
        selector.tryCloseTab(TabClosureParams.closeTab(tab).allowUndo(false).build(), false);
    }

    @Override
    public void closeAll(boolean aerogel) {
        TabModelSelector selector = selector();
        if (selector == null) return;
        selector.getModel(aerogel)
                .getTabRemover()
                .closeTabs(TabClosureParams.closeAllTabs().allowUndo(false).build(), false);
    }

    @Override
    public Subscription observe(TabsApi.Observer observer) {
        return new Watch(observer);
    }

    static @Nullable TabModelSelector selector() {
        TabWindowManager manager = TabWindowManagerSingleton.getInstance();
        Activity activity = ApplicationStatus.getLastTrackedFocusedActivity();
        if (activity != null) {
            int id = manager.getIdForWindow(activity);
            TabModelSelector selector =
                    id == TabWindowManager.INVALID_WINDOW_ID
                            ? null
                            : manager.getTabModelSelectorById(id);
            if (selector != null) return selector;
        }
        for (TabModelSelector selector : manager.getAllTabModelSelectors()) {
            if (selector != null) return selector;
        }
        return null;
    }

    static @Nullable Tab tab(int tabId) {
        return TabWindowManagerSingleton.getInstance().getTabById(tabId);
    }

    static TabInfo info(Tab tab) {
        return new TabInfo(
                tab.getId(),
                tab.getUrl().getSpec(),
                tab.getTitle(),
                tab.isIncognitoBranded(),
                tab.isLoading(),
                tab.getProgress(),
                tab.canGoBack(),
                tab.canGoForward());
    }

    private static final class Watch implements Subscription, TabWindowManager.Observer {
        private final TabsApi.Observer mObserver;
        private final Callback<Tab> mCurrent;
        private @Nullable TabModelSelector mSelector;
        private @Nullable TabModelSelectorTabObserver mTabs;
        private boolean mCancelled;

        Watch(TabsApi.Observer observer) {
            mObserver = observer;
            mCurrent = tab -> mObserver.onCurrentTabChanged(tab == null ? null : info(tab));
            TabModelSelector selector = selector();
            if (selector != null) {
                attach(selector);
            } else {
                TabWindowManagerSingleton.getInstance().addObserver(this);
            }
        }

        @Override
        public void onTabModelSelectorAdded(TabModelSelector selector) {
            if (mCancelled || mSelector != null) return;
            TabWindowManagerSingleton.getInstance().removeObserver(this);
            attach(selector);
        }

        @Override
        public void cancel() {
            if (mCancelled) return;
            mCancelled = true;
            TabWindowManagerSingleton.getInstance().removeObserver(this);
            if (mTabs != null) mTabs.destroy();
            if (mSelector != null) mSelector.getCurrentTabSupplier().removeObserver(mCurrent);
            mTabs = null;
            mSelector = null;
        }

        private void attach(TabModelSelector selector) {
            mSelector = selector;
            mTabs =
                    new TabModelSelectorTabObserver(selector) {
                        @Override
                        protected void onTabRegistered(Tab tab) {
                            mObserver.onTabAdded(info(tab));
                        }

                        @Override
                        protected void onTabUnregistered(Tab tab) {
                            mObserver.onTabRemoved(tab.getId());
                        }

                        @Override
                        public void onTitleUpdated(Tab tab) {
                            changed(tab);
                        }

                        @Override
                        public void onUrlUpdated(Tab tab) {
                            changed(tab);
                        }

                        @Override
                        public void onLoadStarted(Tab tab, boolean toDifferentDocument) {
                            changed(tab);
                        }

                        @Override
                        public void onLoadStopped(Tab tab, boolean toDifferentDocument) {
                            changed(tab);
                        }

                        @Override
                        public void onLoadProgressChanged(Tab tab, float progress) {
                            changed(tab);
                        }

                        @Override
                        public void onDidFinishNavigationInPrimaryMainFrame(
                                Tab tab, NavigationHandle navigation) {
                            changed(tab);
                        }
                    };
            selector.getCurrentTabSupplier().addSyncObserver(mCurrent);
        }

        private void changed(Tab tab) {
            mObserver.onTabUpdated(info(tab));
        }
    }
}
