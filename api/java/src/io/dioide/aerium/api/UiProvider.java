// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import androidx.annotation.Nullable;

public interface UiProvider {
    void attach(AeriumCore core);

    @Nullable
    SurfaceFactory surface(Slot slot);

    Branding branding();

    ToolbarSpec toolbar();

    ThemeTokens theme();
}
