import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the active [ThemeMode] and persists the customer's preference.
///
/// Persistence is best-effort: the shared_preferences instance is created
/// lazily inside a guard so that environments without the plugin (widget and
/// golden tests) keep the in-memory value instead of crashing.
class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit({SharedPreferencesAsync? preferences})
    : _injectedPreferences = preferences,
      super(ThemeMode.system) {
    unawaited(_restore());
  }

  static const _storageKey = 'lumin.themeMode';

  final SharedPreferencesAsync? _injectedPreferences;

  SharedPreferencesAsync? _resolvePreferences() {
    if (_injectedPreferences != null) {
      return _injectedPreferences;
    }
    try {
      return SharedPreferencesAsync();
    } catch (_) {
      return null;
    }
  }

  Future<void> _restore() async {
    try {
      final prefs = _resolvePreferences();
      if (prefs == null) {
        return;
      }
      final stored = await prefs.getString(_storageKey);
      final restored = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
      if (restored != null && restored != state) {
        emit(restored);
      }
    } catch (_) {
      // Persistence unavailable (e.g. in tests) — keep the default.
    }
  }

  /// Toggles between light and dark, resolving "system" to its opposite.
  void toggle(Brightness currentBrightness) {
    final next = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system =>
        currentBrightness == Brightness.dark
            ? ThemeMode.light
            : ThemeMode.dark,
    };
    setMode(next);
  }

  void setMode(ThemeMode mode) {
    if (mode == state) {
      return;
    }
    emit(mode);
    unawaited(_persist(mode));
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final prefs = _resolvePreferences();
      if (prefs == null) {
        return;
      }
      await prefs.setString(_storageKey, mode.name);
    } catch (_) {
      // Ignore persistence failures.
    }
  }
}
