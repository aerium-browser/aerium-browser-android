// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import java.util.List;

public interface ExtensionsApi {
    List<ExtensionInfo> list();

    void setEnabled(String id, boolean enabled);

    void setAllowedInAerogel(String id, boolean allowed);

    void setPinned(String id, boolean pinned);

    void remove(String id);

    void openOptions(String id);

    Subscription observe(Runnable onChange);
}
