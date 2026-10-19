// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import android.app.Activity;
import android.content.Context;
import android.view.View;

import androidx.annotation.Nullable;

import org.chromium.base.ContextUtils;
import org.chromium.chrome.browser.app.ChromeActivity;
import org.chromium.chrome.browser.tab.Tab;
import org.chromium.chrome.browser.ui.appmenu.AppMenuItemProperties;
import org.chromium.chrome.browser.ui.appmenu.AppMenuSheet;
import org.chromium.ui.modelutil.MVCListAdapter.ModelList;
import org.chromium.ui.modelutil.PropertyModel;

import io.dioide.aerium.api.MenuHost;
import io.dioide.aerium.api.MenuItem;
import io.dioide.aerium.api.Slot;
import io.dioide.aerium.api.SurfaceFactory;

import java.lang.ref.WeakReference;

public final class MenuSurface implements AppMenuSheet.Presenter {
    private static @Nullable WeakReference<ModelList> sPageMenu;

    private MenuSurface() {}

    public static void attach(ModelList pageMenu) {
        sPageMenu = new WeakReference<>(pageMenu);
        if (AppMenuSheet.getPresenter() == null) AppMenuSheet.setPresenter(new MenuSurface());
    }

    @Override
    public @Nullable AppMenuSheet.Session show(
            Context context, ModelList items, AppMenuSheet.Host host) {
        WeakReference<ModelList> page = sPageMenu;
        if (page == null || page.get() != items) return null;
        SurfaceFactory factory = AeriumUi.surface(Slot.MENU);
        Activity activity = ContextUtils.activityFromContext(context);
        if (factory == null || activity == null || activity.isFinishing()) return null;
        Tab tab = activity instanceof ChromeActivity chrome ? chrome.getActivityTab() : null;
        Sheet sheet = new Sheet(activity, tab == null ? MenuHost.NO_TAB : tab.getId(), items, host);
        View view = factory.create(activity, sheet);
        if (view == null) return null;
        sheet.dialog().setOnDismissListener(dialog -> host.dismissed());
        sheet.present(view, SurfaceDialog.isNight(activity), false);
        return sheet;
    }

    private static @Nullable PropertyModel find(ModelList list, int id) {
        for (int i = 0; i < list.size(); i++) {
            PropertyModel model = list.get(i).model;
            if (model.containsKey(AppMenuItemProperties.MENU_ITEM_ID)
                    && model.get(AppMenuItemProperties.MENU_ITEM_ID) == id) {
                return model;
            }
            if (!model.containsKey(AppMenuItemProperties.ADDITIONAL_ICONS)) continue;
            ModelList icons = model.get(AppMenuItemProperties.ADDITIONAL_ICONS);
            if (icons == null) continue;
            PropertyModel inner = find(icons, id);
            if (inner != null) return inner;
        }
        return null;
    }

    private static boolean has(PropertyModel model, PropertyModel.WritableBooleanPropertyKey key) {
        if (model.containsKey(key) && model.get(key)) return true;
        if (!model.containsKey(AppMenuItemProperties.ADDITIONAL_ICONS)) return false;
        ModelList icons = model.get(AppMenuItemProperties.ADDITIONAL_ICONS);
        if (icons == null) return false;
        for (int i = 0; i < icons.size(); i++) {
            PropertyModel inner = icons.get(i).model;
            if (inner.containsKey(key) && inner.get(key)) return true;
        }
        return false;
    }

    private static final class Sheet extends SurfaceDialog
            implements MenuHost, AppMenuSheet.Session {
        private final ModelList mItems;
        private final AppMenuSheet.Host mHost;

        Sheet(Activity activity, int tabId, ModelList items, AppMenuSheet.Host host) {
            super(activity, tabId, () -> {});
            mItems = items;
            mHost = host;
        }

        @Override
        public @Nullable MenuItem item(int id) {
            PropertyModel model = find(mItems, id);
            if (model == null) return null;
            boolean enabled =
                    !model.containsKey(AppMenuItemProperties.ENABLED)
                            || model.get(AppMenuItemProperties.ENABLED);
            return new MenuItem(
                    id,
                    enabled,
                    has(model, AppMenuItemProperties.CHECKABLE),
                    has(model, AppMenuItemProperties.CHECKED));
        }

        @Override
        public void select(int id) {
            close();
            mHost.select(id);
        }

        @Override
        public boolean isShowing() {
            return dialog().isShowing();
        }

        @Override
        public void dismiss() {
            close();
        }
    }
}
