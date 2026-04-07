import 'package:flutter/material.dart';
import 'package:kawai_notes/core/constants/storage_key_constant.dart';
import 'package:kawai_notes/core/extensions/logger_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ThemeStorageService {
  Future<ThemeMode> getThemeMode();
  Future<void> setThemeMode(ThemeMode themeMode);
  Future<void> removeThemeMode();

  Future<bool> getMaterialYouMode();
  Future<void> setMaterialYouMode(bool value);
}

class ThemeStorageServiceImpl implements ThemeStorageService {
  final SharedPreferences _sharedPreferences;

  ThemeStorageServiceImpl(this._sharedPreferences);

  @override
  Future<ThemeMode> getThemeMode() async {
    try {
      final themeModeString = _sharedPreferences.getString(
        StorageKeyConstant.themeModeKey,
      );

      if (themeModeString != null) {
        switch (themeModeString) {
          case 'light':
            logData('GET themeMode', 'light');
            return ThemeMode.light;
          case 'dark':
            logData('GET themeMode', 'dark');
            return ThemeMode.dark;
          case 'system':
            logData('GET themeMode', 'system');
            return ThemeMode.system;
          default:
            logData('GET themeMode', 'system (default)');
            return ThemeMode.system;
        }
      }

      logData('GET themeMode', 'system (default)');
      return ThemeMode.system;
    } catch (e, s) {
      logError('Failed to get theme mode', e, s);
      return ThemeMode.system;
    }
  }

  @override
  Future<void> setThemeMode(ThemeMode themeMode) async {
    try {
      String themeModeString;
      switch (themeMode) {
        case ThemeMode.light:
          themeModeString = 'light';
          break;
        case ThemeMode.dark:
          themeModeString = 'dark';
          break;
        case ThemeMode.system:
          themeModeString = 'system';
          break;
      }

      await _sharedPreferences.setString(
        StorageKeyConstant.themeModeKey,
        themeModeString,
      );
      logData('SAVE themeMode', themeModeString);
    } catch (e, s) {
      logError('Failed to set theme mode', e, s);
    }
  }

  @override
  Future<void> removeThemeMode() async {
    try {
      await _sharedPreferences.remove(StorageKeyConstant.themeModeKey);
      logData('REMOVE themeMode', 'success');
    } catch (e, s) {
      logError('Failed to remove theme mode', e, s);
    }
  }

  @override
  Future<bool> getMaterialYouMode() async {
    try {
      final value = _sharedPreferences.getBool(
        StorageKeyConstant.materialYouKey,
      );
      if (value != null) {
        logData('GET materialYouMode', value.toString());
        return value;
      }
      logData('GET materialYouMode', 'true (default)');
      return true; // Default to true
    } catch (e, s) {
      logError('Failed to get material you mode', e, s);
      return true;
    }
  }

  @override
  Future<void> setMaterialYouMode(bool value) async {
    try {
      await _sharedPreferences.setBool(
        StorageKeyConstant.materialYouKey,
        value,
      );
      logData('SAVE materialYouMode', value.toString());
    } catch (e, s) {
      logError('Failed to set material you mode', e, s);
    }
  }
}
