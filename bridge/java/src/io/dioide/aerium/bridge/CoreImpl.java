// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import io.dioide.aerium.api.AeriumCore;
import io.dioide.aerium.api.SettingsApi;

final class CoreImpl implements AeriumCore {
    private final SettingsApi mSettings = new SettingsImpl();

    @Override
    public int apiVersion() {
        return VERSION;
    }

    @Override
    public SettingsApi settings() {
        return mSettings;
    }
}
