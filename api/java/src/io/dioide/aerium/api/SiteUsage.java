// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public final class SiteUsage {
    public final int cookies;
    public final long bytes;
    public final int permissions;

    public SiteUsage(int cookies, long bytes, int permissions) {
        this.cookies = cookies;
        this.bytes = bytes;
        this.permissions = permissions;
    }
}
