// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public interface SettingsApi {
    <T> T get(Setting<T> setting);

    <T> void set(Setting<T> setting, T value);

    Subscription observe(Setting<?> setting, Runnable onChange);
}
