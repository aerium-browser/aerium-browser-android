// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public interface PrefsApi {
    boolean getBoolean(String name);

    void setBoolean(String name, boolean value);

    int getInteger(String name);

    void setInteger(String name, int value);

    String getString(String name);

    void setString(String name, String value);

    Subscription observe(String name, Runnable onChange);
}
