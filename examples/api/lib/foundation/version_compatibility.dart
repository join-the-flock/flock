// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Utility class for managing version compatibility across Flutter releases.
///
/// This helps identify known issues in specific Flutter versions and provides
/// recommendations for handling version-specific behavior.
class VersionCompatibility {
  /// Current Flutter version string.
  ///
  /// In a production app, this would come from the Flutter SDK.
  static const String currentFlutterVersion = '3.35.6';

  /// Minimum supported Flutter version.
  static const String minFlutterVersion = '3.32.0';

  /// Minimum supported Dart version.
  static const String minDartVersion = '3.9.0';

  /// Check if a given Flutter version is compatible.
  ///
  /// Returns true if the version meets minimum requirements.
  static bool isCompatibleFlutterVersion(String version) {
    try {
      return _compareVersions(version, minFlutterVersion) >= 0;
    } catch (e) {
      debugPrint('Error parsing version: $e');
      return false;
    }
  }

  /// Check if a given Dart version is compatible.
  static bool isCompatibleDartVersion(String version) {
    try {
      return _compareVersions(version, minDartVersion) >= 0;
    } catch (e) {
      debugPrint('Error parsing version: $e');
      return false;
    }
  }

  /// Get a comprehensive compatibility report.
  ///
  /// Returns information about supported platforms, known issues, and
  /// recommendations for the current version.
  static Map<String, dynamic> getCompatibilityReport() {
    return <String, dynamic>{
      'flutter_version': currentFlutterVersion,
      'min_flutter_version': minFlutterVersion,
      'min_dart_version': minDartVersion,
      'supported_platforms': _getSupportedPlatforms(),
      'known_issues': _getKnownIssues(),
      'recommendations': _getRecommendations(),
      'platform_info': _getPlatformInfo(),
    };
  }

  /// Get list of supported platforms with minimum OS versions.
  static List<String> _getSupportedPlatforms() {
    final List<String> platforms = <String>[];

    if (Platform.isAndroid || !kIsWeb) {
      platforms.add('Android (API 21+)');
    }
    if (Platform.isIOS || !kIsWeb) {
      platforms.add('iOS (12.0+)');
    }
    if (Platform.isMacOS || !kIsWeb) {
      platforms.add('macOS (10.14+)');
    }
    if (Platform.isWindows || !kIsWeb) {
      platforms.add('Windows (10+)');
    }
    if (Platform.isLinux || !kIsWeb) {
      platforms.add('Linux (Ubuntu 18.04+)');
    }
    if (kIsWeb) {
      platforms.add('Web (Chrome 84+, Safari 14+, Firefox 88+)');
    }

    return platforms;
  }

  /// Get known issues for specific versions.
  ///
  /// This helps developers identify and work around version-specific bugs.
  static List<Map<String, String>> _getKnownIssues() {
    return <Map<String, String>>[
      <String, String>{
        'version': '3.35.x',
        'platform': 'macOS',
        'issue': 'Failed to foreground app error',
        'severity': 'High',
        'workaround': 'Use flutter clean && flutter run, or upgrade to fixed version',
        'issue_number': '#176850',
      },
      <String, String>{
        'version': '3.35.x',
        'platform': 'iOS',
        'issue': 'CupertinoTextField text alignment regression',
        'severity': 'Medium',
        'workaround': 'Use PlatformAwareTextField wrapper or specify textAlignVertical explicitly',
        'issue_number': '#176817',
      },
      <String, String>{
        'version': '3.35.x',
        'platform': 'Android',
        'issue': 'Page transition performance regression (31%)',
        'severity': 'High',
        'workaround': 'Use ZoomPageTransitionsBuilder or custom transition with reduced duration',
        'issue_number': '#177016',
      },
      <String, String>{
        'version': '3.35.x',
        'platform': 'iOS',
        'issue': 'Debugging performance degradation',
        'severity': 'Medium',
        'workaround': 'Use profile mode for performance testing instead of debug mode',
        'issue_number': '#175962',
      },
      <String, String>{
        'version': '3.35.x',
        'platform': 'Android 14+',
        'issue': 'Camera plugin crashes with context errors',
        'severity': 'High',
        'workaround': 'Use SafeCameraController with retry logic',
        'issue_number': '#176613',
      },
    ];
  }

  /// Get recommendations for the current version.
  static List<String> _getRecommendations() {
    return <String>[
      'Test on multiple Flutter versions before release',
      'Use platform-aware UI components for consistency',
      'Implement regression testing for critical user flows',
      'Monitor platform-specific performance metrics',
      'Keep dependency versions pinned in production',
      'Use Flutter Version Manager (fvm) for version consistency',
      'Enable null safety for better code quality',
      'Test on latest OS versions (iOS 17, Android 14)',
      'Use profile builds for performance testing, not debug builds',
      'Implement comprehensive error handling for plugin operations',
    ];
  }

  /// Get detailed platform information.
  static Map<String, dynamic> _getPlatformInfo() {
    return <String, dynamic>{
      'operating_system': Platform.operatingSystem,
      'operating_system_version': Platform.operatingSystemVersion,
      'is_web': kIsWeb,
      'is_debug': kDebugMode,
      'is_profile': kProfileMode,
      'is_release': kReleaseMode,
    };
  }

  /// Check if a specific issue affects the current version/platform.
  ///
  /// Returns true if the issue is known to affect the current configuration.
  static bool hasKnownIssue(String issueNumber) {
    final List<Map<String, String>> issues = _getKnownIssues();
    return issues.any((Map<String, String> issue) =>
        issue['issue_number'] == issueNumber);
  }

  /// Get workaround for a specific issue.
  ///
  /// Returns the recommended workaround, or null if issue not found.
  static String? getWorkaround(String issueNumber) {
    final List<Map<String, String>> issues = _getKnownIssues();
    try {
      final Map<String, String> issue = issues.firstWhere(
        (Map<String, String> i) => i['issue_number'] == issueNumber,
      );
      return issue['workaround'];
    } catch (e) {
      return null;
    }
  }

  /// Compare two version strings.
  ///
  /// Returns:
  /// - negative if version1 < version2
  /// - 0 if version1 == version2
  /// - positive if version1 > version2
  static int _compareVersions(String version1, String version2) {
    final List<int> v1Parts = version1.split('.').map(int.parse).toList();
    final List<int> v2Parts = version2.split('.').map(int.parse).toList();

    final int maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final int v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final int v2Part = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1Part < v2Part) {
        return -1;
      }
      if (v1Part > v2Part) {
        return 1;
      }
    }

    return 0;
  }

  /// Print a human-readable compatibility report.
  ///
  /// Useful for debugging and understanding the current environment.
  static void printCompatibilityReport() {
    final Map<String, dynamic> report = getCompatibilityReport();

    debugPrint('=== Flutter Compatibility Report ===');
    debugPrint('Flutter Version: ${report['flutter_version']}');
    debugPrint('Minimum Flutter: ${report['min_flutter_version']}');
    debugPrint('Minimum Dart: ${report['min_dart_version']}');
    debugPrint('');

    debugPrint('Platform Info:');
    final Map<String, dynamic> platformInfo = report['platform_info'] as Map<String, dynamic>;
    platformInfo.forEach((String key, dynamic value) {
      debugPrint('  $key: $value');
    });
    debugPrint('');

    debugPrint('Supported Platforms:');
    for (final String platform in report['supported_platforms'] as List<String>) {
      debugPrint('  - $platform');
    }
    debugPrint('');

    debugPrint('Known Issues:');
    for (final Map<String, String> issue in report['known_issues'] as List<Map<String, String>>) {
      debugPrint('  ${issue['issue_number']}: ${issue['issue']}');
      debugPrint('    Platform: ${issue['platform']}');
      debugPrint('    Severity: ${issue['severity']}');
      debugPrint('    Workaround: ${issue['workaround']}');
      debugPrint('');
    }

    debugPrint('Recommendations:');
    for (final String rec in report['recommendations'] as List<String>) {
      debugPrint('  - $rec');
    }
  }
}
