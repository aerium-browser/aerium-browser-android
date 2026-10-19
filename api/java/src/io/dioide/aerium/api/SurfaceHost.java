// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public interface SurfaceHost {
    AeriumCore core();

    void close();

    void open(Slot slot);
}
