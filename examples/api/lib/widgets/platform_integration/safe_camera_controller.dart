// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Exception thrown when camera operations fail.
class CameraException implements Exception {
  /// Creates a [CameraException].
  const CameraException(this.code, this.description);

  /// Error code.
  final String code;

  /// Detailed description of the error.
  final String description;

  @override
  String toString() => 'CameraException($code, $description)';
}

/// Placeholder for camera description.
/// In a real implementation, this would come from the camera plugin.
class CameraDescription {
  /// Creates a [CameraDescription].
  const CameraDescription({
    required this.name,
    required this.lensDirection,
  });

  /// The name of the camera.
  final String name;

  /// The direction the camera is facing.
  final String lensDirection;
}

/// Placeholder for resolution preset.
enum ResolutionPreset {
  /// Low resolution (240p).
  low,

  /// Medium resolution (480p).
  medium,

  /// High resolution (720p).
  high,

  /// Very high resolution (1080p).
  veryHigh,

  /// Ultra high resolution (2160p).
  ultraHigh,

  /// Maximum resolution available.
  max,
}

/// Basic camera controller placeholder.
/// In a real implementation, this would be from the camera plugin.
class CameraController {
  /// Creates a [CameraController].
  CameraController(
    this.description,
    this.resolutionPreset, {
    this.enableAudio = true,
  });

  /// The camera being controlled.
  final CameraDescription description;

  /// The resolution preset for the camera.
  final ResolutionPreset resolutionPreset;

  /// Whether audio should be enabled.
  final bool enableAudio;

  bool _isInitialized = false;

  /// Whether the camera is initialized.
  bool get isInitialized => _isInitialized;

  /// Initialize the camera.
  Future<void> initialize() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _isInitialized = true;
  }

  /// Dispose of the camera controller.
  void dispose() {
    _isInitialized = false;
  }
}

/// Get available cameras.
Future<List<CameraDescription>> availableCameras() async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return <CameraDescription>[
    const CameraDescription(name: 'back', lensDirection: 'back'),
    const CameraDescription(name: 'front', lensDirection: 'front'),
  ];
}

/// A safe wrapper around camera initialization that handles common failure scenarios.
///
/// This class provides robust error handling for camera operations, particularly
/// addressing issues with Android 14+ context association errors and other
/// platform-specific initialization problems.
///
/// Example usage:
/// ```dart
/// final safeCameraController = SafeCameraController();
/// try {
///   await safeCameraController.initializeCamera();
///   // Use the camera
/// } catch (e) {
///   // Handle error gracefully
///   print('Camera initialization failed: $e');
/// } finally {
///   safeCameraController.dispose();
/// }
/// ```
class SafeCameraController {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Whether the camera is initialized and ready to use.
  bool get isInitialized => _isInitialized && !_isDisposed;

  /// The underlying camera controller, or null if not initialized.
  CameraController? get controller => _controller;

  /// Initialize the camera with robust error handling.
  ///
  /// This method includes:
  /// - Checking for available cameras
  /// - Handling Android 14+ context errors with retry logic
  /// - Graceful degradation if initialization fails
  ///
  /// Throws [CameraException] if initialization fails after all retries.
  Future<void> initializeCamera({
    ResolutionPreset resolutionPreset = ResolutionPreset.high,
    bool enableAudio = false,
    int maxRetries = 3,
  }) async {
    if (_isDisposed) {
      throw CameraException(
        'disposed',
        'Cannot initialize camera after disposal',
      );
    }

    if (_isInitialized) {
      return; // Already initialized
    }

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final List<CameraDescription> cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw CameraException('no_cameras', 'No cameras available');
        }

        _controller = CameraController(
          cameras.first,
          resolutionPreset,
          enableAudio: enableAudio,
        );

        await _controller!.initialize();
        _isInitialized = true;
        return; // Success!
      } on CameraException catch (e) {
        // Handle specific Android 14+ context issues
        if (e.description.contains('Context not associated with display') ||
            e.description.contains('context')) {
          if (attempt < maxRetries - 1) {
            // Delay initialization until activity is fully ready
            await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            debugPrint('Retrying camera initialization (attempt ${attempt + 2}/$maxRetries)');
            continue;
          }
        }

        // If this is the last attempt or a different error, throw
        if (attempt == maxRetries - 1) {
          debugPrint('Camera initialization failed after $maxRetries attempts: $e');
          rethrow;
        }
      } catch (e) {
        // Generic error handling
        if (attempt == maxRetries - 1) {
          debugPrint('Camera initialization failed: $e');
          throw CameraException(
            'initialization_failed',
            'Failed to initialize camera: $e',
          );
        }
        // Wait before retrying
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
  }

  /// Dispose of the camera controller and free resources.
  ///
  /// This should be called when the camera is no longer needed.
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    if (_isInitialized && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
  }

  /// Handle an error that occurred during camera operations.
  ///
  /// This method can be used to implement custom error handling logic.
  void handleError(Object error, StackTrace stackTrace) {
    debugPrint('Camera error: $error');
    debugPrint('Stack trace: $stackTrace');

    // In a production app, you might want to:
    // - Log to crash reporting service
    // - Show user-friendly error message
    // - Attempt recovery
  }
}
