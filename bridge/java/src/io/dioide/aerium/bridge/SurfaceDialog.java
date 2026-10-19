// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import android.app.Activity;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;

import androidx.activity.ComponentDialog;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import org.chromium.chrome.browser.tab.Tab;
import org.chromium.chrome.browser.tab.TabUtils;

import io.dioide.aerium.api.AeriumCore;
import io.dioide.aerium.api.Slot;
import io.dioide.aerium.api.SurfaceFactory;
import io.dioide.aerium.api.SurfaceHost;

public final class SurfaceDialog implements SurfaceHost {
    private final Activity mActivity;
    private final int mTabId;
    private final Runnable mShowDefault;
    private final ComponentDialog mDialog;

    private SurfaceDialog(Activity activity, int tabId, Runnable showDefault) {
        mActivity = activity;
        mTabId = tabId;
        mShowDefault = showDefault;
        mDialog = new ComponentDialog(activity, android.R.style.Theme_Translucent_NoTitleBar);
    }

    public static boolean show(Tab tab, Slot slot, Runnable showDefault) {
        SurfaceFactory factory = AeriumUi.surface(slot);
        Activity activity = TabUtils.getActivity(tab);
        if (factory == null || activity == null) return false;
        SurfaceDialog host = new SurfaceDialog(activity, tab.getId(), showDefault);
        View view = factory.create(activity, host);
        if (view == null) return false;
        boolean dark =
                tab.isIncognitoBranded()
                        || (activity.getResources().getConfiguration().uiMode
                                        & Configuration.UI_MODE_NIGHT_MASK)
                                == Configuration.UI_MODE_NIGHT_YES;
        host.present(view, dark);
        return true;
    }

    @Override
    public AeriumCore core() {
        return Aerium.core();
    }

    @Override
    public int tabId() {
        return mTabId;
    }

    @Override
    public void close() {
        if (mDialog.isShowing()) mDialog.dismiss();
    }

    @Override
    public void open(Slot slot) {
        close();
        SurfaceFragment.start(mActivity, slot);
    }

    @Override
    public void showDefault() {
        close();
        mShowDefault.run();
    }

    private void present(View view, boolean dark) {
        mDialog.setContentView(
                view,
                new ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        mDialog.setCanceledOnTouchOutside(false);
        Window window = mDialog.getWindow();
        if (window != null) {
            window.setLayout(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
            window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
            window.setWindowAnimations(0);
            window.setDimAmount(0f);
            WindowCompat.setDecorFitsSystemWindows(window, false);
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.setNavigationBarContrastEnforced(false);
            }
            WindowInsetsControllerCompat controller =
                    WindowCompat.getInsetsController(window, window.getDecorView());
            controller.setAppearanceLightStatusBars(false);
            controller.setAppearanceLightNavigationBars(!dark);
        }
        mDialog.show();
    }
}
