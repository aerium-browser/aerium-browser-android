// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import android.content.Context;
import android.view.View;

import androidx.annotation.Nullable;

public interface SurfaceFactory {
    @Nullable
    View create(Context context, SurfaceHost host);
}
