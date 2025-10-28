// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A collection of helper utilities for writing stable, reliable tests.
///
/// These utilities help address common testing issues like flaky tests,
/// race conditions, and timing-related failures.
class TestHelpers {
  /// Run a test with retry logic for handling flaky tests.
  ///
  /// This is useful for tests that occasionally fail due to timing issues
  /// or other transient problems.
  ///
  /// Example:
  /// ```dart
  /// await TestHelpers.retryableTest(
  ///   'My flaky test',
  ///   () async {
  ///     // Test code that might occasionally fail
  ///   },
  /// );
  /// ```
  static Future<void> retryableTest(
    String description,
    Future<void> Function() testBody, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    assert(maxRetries > 0, 'maxRetries must be greater than 0');

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await testBody();
        return; // Success, exit retry loop
      } catch (e, stackTrace) {
        if (attempt == maxRetries - 1) {
          // Final attempt failed
          debugPrint('Test "$description" failed after $maxRetries attempts');
          debugPrint('Last error: $e');
          debugPrint('Stack trace: $stackTrace');
          rethrow;
        }

        // Log retry attempt
        debugPrint('Test "$description" attempt ${attempt + 1} failed: $e');
        debugPrint('Retrying after ${delay.inMilliseconds}ms...');

        // Wait before retrying
        await Future<void>.delayed(delay);
      }
    }
  }

  /// Wait for a condition to become true.
  ///
  /// This is useful for waiting on asynchronous operations to complete
  /// without using arbitrary delays.
  ///
  /// Example:
  /// ```dart
  /// await TestHelpers.waitForCondition(
  ///   () => myController.isReady,
  ///   timeout: Duration(seconds: 5),
  /// );
  /// ```
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(milliseconds: 100),
    String? description,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    while (!condition() && stopwatch.elapsed < timeout) {
      await Future<void>.delayed(interval);
    }

    stopwatch.stop();

    if (!condition()) {
      final String desc = description ?? 'Condition';
      throw TimeoutException(
        '$desc not met within ${timeout.inMilliseconds}ms',
        timeout,
      );
    }
  }

  /// Wait for a widget to appear in the widget tree.
  ///
  /// This is particularly useful for widgets that appear after async operations.
  ///
  /// Example:
  /// ```dart
  /// await TestHelpers.waitForWidget(
  ///   tester,
  ///   find.byKey(Key('my_widget')),
  /// );
  /// ```
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    Duration pumpInterval = const Duration(milliseconds: 100),
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      await tester.pump(pumpInterval);

      if (finder.evaluate().isNotEmpty) {
        stopwatch.stop();
        return;
      }
    }

    stopwatch.stop();
    throw TimeoutException(
      'Widget not found after ${timeout.inMilliseconds}ms: $finder',
      timeout,
    );
  }

  /// Pump until a condition is met or timeout occurs.
  ///
  /// This combines pumping the widget tree with a condition check.
  ///
  /// Example:
  /// ```dart
  /// await TestHelpers.pumpUntil(
  ///   tester,
  ///   () => find.byType(LoadingIndicator).evaluate().isEmpty,
  ///   description: 'Loading indicator disappears',
  /// );
  /// ```
  static Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
    Duration pumpDuration = const Duration(milliseconds: 100),
    String? description,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    while (!condition() && stopwatch.elapsed < timeout) {
      await tester.pump(pumpDuration);
    }

    stopwatch.stop();

    if (!condition()) {
      final String desc = description ?? 'Condition';
      throw TimeoutException(
        '$desc not met after pumping for ${timeout.inMilliseconds}ms',
        timeout,
      );
    }
  }

  /// Safely tap a widget with retry logic.
  ///
  /// This handles cases where the widget might not be immediately tappable.
  ///
  /// Example:
  /// ```dart
  /// await TestHelpers.safeTap(
  ///   tester,
  ///   find.byKey(Key('submit_button')),
  /// );
  /// ```
  static Future<void> safeTap(
    WidgetTester tester,
    Finder finder, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await tester.tap(finder);
        await tester.pumpAndSettle();
        return; // Success
      } catch (e) {
        if (attempt == maxRetries - 1) {
          debugPrint('Failed to tap widget after $maxRetries attempts: $finder');
          rethrow;
        }

        debugPrint('Tap attempt ${attempt + 1} failed, retrying...');
        await tester.pump(retryDelay);
      }
    }
  }

  /// Enter text into a text field with proper settling.
  ///
  /// This ensures the text field is ready and properly updated.
  ///
  /// Example:
  /// ```dart
  /// await TestHelpers.safeEnterText(
  ///   tester,
  ///   find.byType(TextField),
  ///   'Hello, World!',
  /// );
  /// ```
  static Future<void> safeEnterText(
    WidgetTester tester,
    Finder finder,
    String text, {
    Duration settleTime = const Duration(milliseconds: 300),
  }) async {
    await tester.enterText(finder, text);
    await tester.pump(settleTime);
    await tester.pumpAndSettle();
  }

  /// Verify that no errors or warnings were logged during test execution.
  ///
  /// This can be used to ensure tests don't produce unexpected debug output.
  ///
  /// Example:
  /// ```dart
  /// testWidgets('My test', (tester) async {
  ///   final errors = <String>[];
  ///   TestHelpers.captureDebugPrints(() async {
  ///     // Test code
  ///   }, errors);
  ///   expect(errors, isEmpty);
  /// });
  /// ```
  static Future<void> captureDebugPrints(
    Future<void> Function() callback,
    List<String> output,
  ) async {
    final DebugPrintCallback originalDebugPrint = debugPrint;

    try {
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          output.add(message);
        }
      };

      await callback();
    } finally {
      debugPrint = originalDebugPrint;
    }
  }

  /// Run a test with timeout protection.
  ///
  /// This prevents tests from hanging indefinitely.
  ///
  /// Example:
  /// ```dart
  /// await TestHelpers.withTimeout(
  ///   () async {
  ///     // Test code that might hang
  ///   },
  ///   timeout: Duration(seconds: 30),
  /// );
  /// ```
  static Future<T> withTimeout<T>(
    Future<T> Function() callback, {
    Duration timeout = const Duration(minutes: 1),
    String? timeoutMessage,
  }) {
    return callback().timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException(
          timeoutMessage ?? 'Test timed out after ${timeout.inSeconds} seconds',
          timeout,
        );
      },
    );
  }

  /// Create a mock delay that can be controlled in tests.
  ///
  /// Useful for testing time-dependent behavior without actual waiting.
  ///
  /// Example:
  /// ```dart
  /// final delay = TestHelpers.mockDelay(Duration(seconds: 1));
  /// // In your code: await delay();
  /// // In tests, this completes immediately
  /// ```
  static Future<void> Function() mockDelay(Duration duration) {
    return () async {
      // In tests, we can make this configurable
      if (kDebugMode) {
        // Fast mode for tests
        await Future<void>.delayed(Duration.zero);
      } else {
        await Future<void>.delayed(duration);
      }
    };
  }

  /// Verify widget is scrolled into view before interaction.
  ///
  /// This is useful for tests with scrollable content.
  ///
  /// Example:
  /// ```dart
  /// await TestHelpers.scrollIntoView(
  ///   tester,
  ///   find.byKey(Key('bottom_button')),
  /// );
  /// ```
  static Future<void> scrollIntoView(
    WidgetTester tester,
    Finder finder, {
    Finder? scrollable,
    double alignment = 0.0,
  }) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
}

/// Test quality metrics tracking.
///
/// Use this to monitor test reliability and identify flaky tests.
class TestQualityMonitor {
  static final List<TestResult> _testResults = <TestResult>[];

  /// Record a test result.
  static void recordTestResult(
    String testName,
    bool passed,
    Duration duration, {
    String? errorMessage,
  }) {
    _testResults.add(
      TestResult(
        testName: testName,
        passed: passed,
        duration: duration,
        timestamp: DateTime.now(),
        errorMessage: errorMessage,
      ),
    );
  }

  /// Generate a quality report for all recorded tests.
  static String generateQualityReport() {
    if (_testResults.isEmpty) {
      return 'No test results recorded';
    }

    final List<String> flakyTests = _getFlakyTests();
    final List<String> slowTests = _getSlowTests();
    final int totalTests = _testResults.length;
    final int passedTests = _testResults.where((TestResult r) => r.passed).length;

    final StringBuffer report = StringBuffer()
      ..writeln('=== Test Quality Report ===')
      ..writeln('Total tests: $totalTests')
      ..writeln('Passed: $passedTests')
      ..writeln('Failed: ${totalTests - passedTests}')
      ..writeln()
      ..writeln('Flaky tests (>10% failure rate): ${flakyTests.length}');

    for (final String test in flakyTests) {
      report.writeln('  - $test');
    }

    report
      ..writeln()
      ..writeln('Slow tests (>30s): ${slowTests.length}');

    for (final String test in slowTests) {
      report.writeln('  - $test');
    }

    return report.toString();
  }

  /// Clear all recorded test results.
  static void clear() {
    _testResults.clear();
  }

  static List<String> _getFlakyTests() {
    final Map<String, _TestStats> testStats = <String, _TestStats>{};

    for (final TestResult result in _testResults) {
      testStats[result.testName] ??= _TestStats();
      testStats[result.testName]!.addResult(result.passed);
    }

    return testStats.entries
        .where((_TestStats stats) => stats.failureRate > 0.1)
        .map((MapEntry<String, _TestStats> entry) =>
            '${entry.key} (${(entry.value.failureRate * 100).toStringAsFixed(1)}% failure)')
        .toList();
  }

  static List<String> _getSlowTests() {
    final Map<String, List<Duration>> testTimes = <String, List<Duration>>{};

    for (final TestResult result in _testResults) {
      testTimes[result.testName] ??= <Duration>[];
      testTimes[result.testName]!.add(result.duration);
    }

    return testTimes.entries.where((MapEntry<String, List<Duration>> entry) {
      final Duration avg = entry.value.fold(Duration.zero, (Duration a, Duration b) => a + b) ~/
          entry.value.length;
      return avg.inSeconds > 30;
    }).map((MapEntry<String, List<Duration>> entry) => entry.key).toList();
  }
}

/// Represents the result of a single test execution.
class TestResult {
  /// Creates a test result.
  const TestResult({
    required this.testName,
    required this.passed,
    required this.duration,
    required this.timestamp,
    this.errorMessage,
  });

  /// The name of the test.
  final String testName;

  /// Whether the test passed.
  final bool passed;

  /// How long the test took to run.
  final Duration duration;

  /// When the test was run.
  final DateTime timestamp;

  /// Error message if the test failed.
  final String? errorMessage;
}

class _TestStats {
  int _totalRuns = 0;
  int _failures = 0;

  void addResult(bool passed) {
    _totalRuns++;
    if (!passed) {
      _failures++;
    }
  }

  double get failureRate => _totalRuns > 0 ? _failures / _totalRuns : 0.0;
}
