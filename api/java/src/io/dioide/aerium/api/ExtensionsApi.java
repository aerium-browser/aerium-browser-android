// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import android.app.Activity;

import java.io.File;
import java.util.List;
import java.util.function.Consumer;

public interface ExtensionsApi {
    List<ExtensionInfo> list();

    void setEnabled(String id, boolean enabled);

    void setAllowedInAerogel(String id, boolean allowed);

    void setPinned(String id, boolean pinned);

    void remove(String id);

    void openOptions(String id);

    boolean openPopup(Activity activity, String id);

    void install(File file, Consumer<Boolean> done);

    Subscription observe(Runnable onChange);
}
