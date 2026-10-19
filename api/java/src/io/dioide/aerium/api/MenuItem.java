// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public final class MenuItem {
    public final int id;
    public final boolean enabled;
    public final boolean checkable;
    public final boolean checked;

    public MenuItem(int id, boolean enabled, boolean checkable, boolean checked) {
        this.id = id;
        this.enabled = enabled;
        this.checkable = checkable;
        this.checked = checked;
    }
}
