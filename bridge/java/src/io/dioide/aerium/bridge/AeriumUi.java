// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import androidx.annotation.Nullable;

import org.chromium.base.ServiceLoaderUtil;

import io.dioide.aerium.api.AeriumCore;
import io.dioide.aerium.api.Slot;
import io.dioide.aerium.api.SurfaceFactory;
import io.dioide.aerium.api.UiProvider;

public final class AeriumUi {
    private static boolean sLoaded;
    private static @Nullable UiProvider sProvider;

    private AeriumUi() {}

    public static @Nullable UiProvider get() {
        if (!sLoaded) {
            sLoaded = true;
            sProvider = ServiceLoaderUtil.maybeCreate(UiProvider.class);
        }
        return sProvider;
    }

    public static void attach(AeriumCore core) {
        UiProvider provider = get();
        if (provider != null) provider.attach(core);
    }

    public static @Nullable SurfaceFactory surface(Slot slot) {
        UiProvider provider = get();
        return provider == null ? null : provider.surface(slot);
    }
}
