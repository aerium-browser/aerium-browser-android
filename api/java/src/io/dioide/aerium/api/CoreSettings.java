// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public final class CoreSettings {
    public static final Setting<Boolean> BACKGROUND_PLAYBACK =
            new Setting<>("background_playback", Boolean.class);
    public static final Setting<Boolean> DRM = new Setting<>("drm", Boolean.class);
    public static final Setting<Boolean> OPEN_LINKS_IN_APPS =
            new Setting<>("open_links_in_apps", Boolean.class);
    public static final Setting<Boolean> EXTERNAL_LINKS_IN_AEROGEL =
            new Setting<>("external_links_in_aerogel", Boolean.class);
    public static final Setting<Boolean> CLOSE_TABS_ON_EXIT =
            new Setting<>("close_tabs_on_exit", Boolean.class);
    public static final Setting<Boolean> CLEAR_ON_EXIT =
            new Setting<>("clear_on_exit", Boolean.class);
    public static final Setting<Boolean> GLOBAL_PRIVACY_CONTROL =
            new Setting<>("global_privacy_control", Boolean.class);
    public static final Setting<Boolean> SEARCH_SUGGESTIONS =
            new Setting<>("search_suggestions", Boolean.class);
    public static final Setting<Boolean> UPDATE_CHECK =
            new Setting<>("update_check", Boolean.class);
    public static final Setting<String> WEBRTC_POLICY =
            new Setting<>("webrtc_policy", String.class);
    public static final Setting<String> REFERRER_POLICY =
            new Setting<>("referrer_policy", String.class);

    private CoreSettings() {}
}
