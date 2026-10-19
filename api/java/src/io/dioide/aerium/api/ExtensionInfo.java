// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public final class ExtensionInfo {
    public final String id;
    public final String name;
    public final String version;
    public final boolean enabled;
    public final boolean allowedInAerogel;
    public final boolean pinned;
    public final boolean hasPopup;

    public ExtensionInfo(
            String id,
            String name,
            String version,
            boolean enabled,
            boolean allowedInAerogel,
            boolean pinned,
            boolean hasPopup) {
        this.id = id;
        this.name = name;
        this.version = version;
        this.enabled = enabled;
        this.allowedInAerogel = allowedInAerogel;
        this.pinned = pinned;
        this.hasPopup = hasPopup;
    }
}
