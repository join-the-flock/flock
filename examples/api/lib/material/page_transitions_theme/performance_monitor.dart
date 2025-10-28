// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/scheduler.dart';

/// A utility class for monitoring frame rendering performance.
///
/// This class helps detect frame drops and performance issues by monitoring
/// the time taken to render each frame. It's particularly useful for
/// identifying performance regressions in page transitions and animations.
class PerformanceMonitor {
  /// Target frame duration for 60fps (approximately 16.67ms)
  static const Duration _targetFrameDuration = Duration(milliseconds: 16);

  /// Target frame duration for 120fps (approximately 8.33ms)
  static const Duration _targetFrameDuration120fps = Duration(milliseconds: 8);

  /// Start monitoring frame rendering performance.
  ///
  /// This adds a persistent frame callback that logs whenever a frame takes
  /// longer than the target duration (defaulting to 60fps).
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   PerformanceMonitor.startFrameMonitoring();
  ///   runApp(MyApp());
  /// }
  /// ```
  static void startFrameMonitoring({
    Duration targetDuration = _targetFrameDuration,
    void Function(Duration frameDuration)? onFrameDrop,
  }) {
    SchedulerBinding.instance.addPersistentFrameCallback((Duration timeStamp) {
      // Note: In production, you would want to track the delta between frames
      // For this example, we're showing the concept
      if (timeStamp > targetDuration) {
        // Log or report performance issue
        if (onFrameDrop != null) {
          onFrameDrop(timeStamp);
        } else {
          // Default behavior: print to console (only in debug mode)
          assert(() {
            print('Frame drop detected: ${timeStamp.inMilliseconds}ms');
            return true;
          }());
        }
      }
    });
  }

  /// Stop frame monitoring by removing the callback.
  ///
  /// Note: The current implementation uses addPersistentFrameCallback which
  /// doesn't provide a direct way to remove specific callbacks. In production,
  /// you would need to maintain a reference to the callback to remove it.
  static void stopFrameMonitoring() {
    // Implementation note: Would need to store callback reference to remove
    // For this example, we're showing the API structure
  }

  /// Get frame statistics for the last N frames.
  ///
  /// Returns metrics like average frame time, max frame time, and dropped frames.
  static FrameStatistics getFrameStatistics({int frameCount = 100}) {
    // This would need to be implemented with actual frame tracking
    // For this example, we're showing the structure
    return FrameStatistics(
      averageFrameTime: Duration.zero,
      maxFrameTime: Duration.zero,
      droppedFrames: 0,
      totalFrames: 0,
    );
  }
}

/// Statistics about frame rendering performance.
class FrameStatistics {
  /// Creates frame statistics.
  const FrameStatistics({
    required this.averageFrameTime,
    required this.maxFrameTime,
    required this.droppedFrames,
    required this.totalFrames,
  });

  /// Average time taken to render a frame.
  final Duration averageFrameTime;

  /// Maximum time taken to render any single frame.
  final Duration maxFrameTime;

  /// Number of frames that exceeded the target duration.
  final int droppedFrames;

  /// Total number of frames measured.
  final int totalFrames;

  /// Calculate the frame drop rate as a percentage.
  double get dropRate => totalFrames > 0 ? (droppedFrames / totalFrames) * 100 : 0.0;

  @override
  String toString() {
    return 'FrameStatistics('
        'avg: ${averageFrameTime.inMilliseconds}ms, '
        'max: ${maxFrameTime.inMilliseconds}ms, '
        'dropped: $droppedFrames/$totalFrames (${dropRate.toStringAsFixed(1)}%))';
  }
}
