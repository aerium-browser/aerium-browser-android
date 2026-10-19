// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import android.app.Activity;

import org.chromium.chrome.browser.app.ChromeActivity;

import io.dioide.aerium.api.ActionsApi;

final class ActionsImpl implements ActionsApi {
    @Override
    public boolean run(Activity activity, int actionId) {
        if (!(activity instanceof ChromeActivity chrome)) return false;
        return chrome.onMenuOrKeyboardAction(actionId, false, null, null);
    }
}
