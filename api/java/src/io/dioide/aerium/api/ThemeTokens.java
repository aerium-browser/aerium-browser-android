// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import androidx.annotation.ColorInt;

public final class ThemeTokens {
    public final @ColorInt int background;
    public final @ColorInt int surface;
    public final @ColorInt int onSurface;
    public final @ColorInt int accent;
    public final @ColorInt int haze;
    public final float cornerRadiusDp;

    public ThemeTokens(
            @ColorInt int background,
            @ColorInt int surface,
            @ColorInt int onSurface,
            @ColorInt int accent,
            @ColorInt int haze,
            float cornerRadiusDp) {
        this.background = background;
        this.surface = surface;
        this.onSurface = onSurface;
        this.accent = accent;
        this.haze = haze;
        this.cornerRadiusDp = cornerRadiusDp;
    }
}
