// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

package io.dioide.aerium.bridge;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.fragment.app.FragmentManager;

import org.chromium.chrome.browser.settings.SettingsNavigationFactory;

import io.dioide.aerium.api.AeriumCore;
import io.dioide.aerium.api.Slot;
import io.dioide.aerium.api.SurfaceFactory;
import io.dioide.aerium.api.SurfaceHost;

public class SurfaceFragment extends Fragment implements SurfaceHost {
    private static final String SLOT = "aerium_slot";

    public static Bundle arguments(Slot slot) {
        Bundle arguments = new Bundle();
        arguments.putString(SLOT, slot.name());
        return arguments;
    }

    @Override
    public View onCreateView(
            LayoutInflater inflater,
            @Nullable ViewGroup container,
            @Nullable Bundle savedInstanceState) {
        SurfaceFactory factory = AeriumUi.surface(slot());
        if (factory == null) return new View(inflater.getContext());
        return factory.create(inflater.getContext(), this);
    }

    @Override
    public AeriumCore core() {
        return Aerium.core();
    }

    @Override
    public void close() {
        FragmentActivity activity = getActivity();
        if (activity == null) return;
        FragmentManager manager = getParentFragmentManager();
        if (manager.getBackStackEntryCount() > 0) {
            manager.popBackStack();
        } else {
            activity.finish();
        }
    }

    @Override
    public void open(Slot slot) {
        SettingsNavigationFactory.createSettingsNavigation()
                .startSettings(requireContext(), SurfaceFragment.class, arguments(slot));
    }

    private Slot slot() {
        Bundle arguments = getArguments();
        String name = arguments == null ? null : arguments.getString(SLOT);
        return name == null ? Slot.SETTINGS : Slot.valueOf(name);
    }
}
