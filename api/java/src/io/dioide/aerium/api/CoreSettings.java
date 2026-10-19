// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.api;

public final class CoreSettings {
    public static final Setting<Boolean> EXTERNAL_LINKS_IN_AEROGEL =
            new Setting<>("external_links_in_aerogel", Boolean.class);
    public static final Setting<Boolean> CLOSE_TABS_ON_EXIT =
            new Setting<>("close_tabs_on_exit", Boolean.class);
    public static final Setting<Boolean> SEARCH_SUGGESTIONS =
            new Setting<>("search_suggestions", Boolean.class);
    public static final Setting<String> WEBRTC_POLICY =
            new Setting<>("webrtc_policy", String.class);
    public static final Setting<String> REFERRER_POLICY =
            new Setting<>("referrer_policy", String.class);

    public static final String WEBRTC_DEFAULT = "default";
    public static final String WEBRTC_ALL_INTERFACES = "default_public_and_private_interfaces";
    public static final String WEBRTC_PUBLIC_INTERFACE = "default_public_interface_only";
    public static final String WEBRTC_PROXY_ONLY = "disable_non_proxied_udp";

    public static final String REFERRER_FULL = "full";
    public static final String REFERRER_ORIGIN = "origin";
    public static final String REFERRER_NONE = "none";

    private CoreSettings() {}
}
