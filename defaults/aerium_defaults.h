// Copyright 2026 Dioide
// SPDX-License-Identifier: GPL-3.0-only

#ifndef AERIUM_DEFAULTS_AERIUM_DEFAULTS_H_
#define AERIUM_DEFAULTS_AERIUM_DEFAULTS_H_

class PrefRegistrySimple;

namespace base {
class CommandLine;
}

namespace user_prefs {
class PrefRegistrySyncable;
}

namespace aerium {

void ApplyFeatureDefaults(base::CommandLine* command_line);

void RegisterProfileDefaults(user_prefs::PrefRegistrySyncable* registry);

void RegisterLocalStateDefaults(PrefRegistrySimple* registry);

}  // namespace aerium

#endif  // AERIUM_DEFAULTS_AERIUM_DEFAULTS_H_
