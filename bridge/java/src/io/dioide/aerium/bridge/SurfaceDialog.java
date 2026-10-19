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
import android.view.WindowManager;

import androidx.activity.ComponentDialog;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import org.chromium.chrome.browser.lifecycle.ActivityLifecycleDispatcher;
import org.chromium.chrome.browser.lifecycle.DestroyObserver;
import org.chromium.chrome.browser.tab.Tab;
import org.chromium.chrome.browser.tab.TabUtils;

import io.dioide.aerium.api.AeriumCore;
import io.dioide.aerium.api.Slot;
import io.dioide.aerium.api.SurfaceFactory;
import io.dioide.aerium.api.SurfaceHost;

public class SurfaceDialog implements SurfaceHost {
    private final Activity mActivity;
    private final int mTabId;
    private final Runnable mShowDefault;
    private final ComponentDialog mDialog;

    SurfaceDialog(Activity activity, int tabId, Runnable showDefault) {
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
        host.present(view, tab.isIncognitoBranded() || isNight(activity), false);
        return true;
    }

    public static boolean show(
            Activity activity, Slot slot, ActivityLifecycleDispatcher lifecycle) {
        SurfaceFactory factory = AeriumUi.surface(slot);
        if (factory == null) return false;
        SurfaceDialog host = new SurfaceDialog(activity, NO_TAB, () -> {});
        View view = factory.create(activity, host);
        if (view == null) return false;
        lifecycle.register(
                new DestroyObserver() {
                    @Override
                    public void onDestroy() {
                        host.close();
                    }
                });
        host.present(view, isNight(activity), true);
        return true;
    }

    static boolean isNight(Activity activity) {
        return (activity.getResources().getConfiguration().uiMode
                        & Configuration.UI_MODE_NIGHT_MASK)
                == Configuration.UI_MODE_NIGHT_YES;
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

    ComponentDialog dialog() {
        return mDialog;
    }

    void present(View view, boolean dark, boolean fullWindow) {
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
            controller.setAppearanceLightStatusBars(fullWindow && !dark);
            controller.setAppearanceLightNavigationBars(!dark);
            if (fullWindow) {
                window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
            }
        }
        mDialog.show();
    }
}
