// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

import java.util.List;

public final class ToolbarSpec {
    public enum Position {
        TOP,
        BOTTOM
    }

    public enum Button {
        BACK,
        FORWARD,
        RELOAD,
        HOME,
        NEW_TAB,
        AEROGEL,
        TABS,
        MENU,
        SHARE,
        BOOKMARK,
        FIND,
        READER,
        EXTENSIONS,
        CLEAR
    }

    public final Position position;
    public final List<Button> buttons;

    public ToolbarSpec(Position position, List<Button> buttons) {
        this.position = position;
        this.buttons = List.copyOf(buttons);
    }
}
