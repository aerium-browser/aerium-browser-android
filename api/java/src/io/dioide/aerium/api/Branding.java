// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import androidx.annotation.DrawableRes;

public interface Branding {
    String appName();

    @DrawableRes
    int logo();
}
