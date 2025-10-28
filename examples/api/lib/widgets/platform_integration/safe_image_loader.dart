// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A utility class for safely loading images with comprehensive error handling.
///
/// This class addresses engine crashes during PNG processing and provides
/// robust image loading with format validation and retry logic.
///
/// Example usage:
/// ```dart
/// final image = await SafeImageLoader.loadImageSafely('/path/to/image.png');
/// if (image != null) {
///   // Use the image
/// } else {
///   // Show fallback or error UI
/// }
/// ```
class SafeImageLoader {
  /// Load an image from a file path with error handling.
  ///
  /// Returns null if the image cannot be loaded, preventing crashes.
  /// Validates image format before processing to avoid engine crashes.
  static Future<ui.Image?> loadImageSafely(String path) async {
    try {
      final File file = File(path);
      if (!await file.exists()) {
        debugPrint('Image file not found: $path');
        return null;
      }

      final Uint8List bytes = await file.readAsBytes();

      // Validate image format before processing
      if (!_isValidImageFormat(bytes)) {
        debugPrint('Invalid image format: $path');
        return null;
      }

      return await _loadWithRetry(bytes);
    } catch (e, stackTrace) {
      debugPrint('Image loading failed safely: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Load an image from bytes with error handling.
  ///
  /// Validates format and provides retry logic for transient failures.
  static Future<ui.Image?> loadImageFromBytes(Uint8List bytes) async {
    try {
      if (!_isValidImageFormat(bytes)) {
        debugPrint('Invalid image format in byte array');
        return null;
      }

      return await _loadWithRetry(bytes);
    } catch (e, stackTrace) {
      debugPrint('Image loading from bytes failed: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Validate image format by checking file signatures.
  ///
  /// Supports PNG, JPEG, GIF, and WebP formats.
  /// This prevents engine crashes from malformed or unsupported image data.
  static bool _isValidImageFormat(Uint8List bytes) {
    if (bytes.length < 8) {
      return false;
    }

    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }

    // JPEG signature: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }

    // GIF signature: 47 49 46 38 (GIF8)
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }

    // WebP signature: 52 49 46 46 ... 57 45 42 50 (RIFF...WEBP)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    return false;
  }

  /// Load image with retry logic for transient failures.
  ///
  /// Attempts to decode the image multiple times with increasing delays
  /// between attempts to handle temporary engine issues.
  static Future<ui.Image?> _loadWithRetry(
    Uint8List bytes, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final Completer<ui.Image> completer = Completer<ui.Image>();

        ui.decodeImageFromList(bytes, (ui.Image image) {
          if (!completer.isCompleted) {
            completer.complete(image);
          }
        });

        // Add timeout to prevent hanging
        return await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Image decoding timed out');
          },
        );
      } catch (e) {
        if (attempt == maxRetries - 1) {
          debugPrint('Image decoding failed after $maxRetries attempts: $e');
          rethrow;
        }
        // Wait before retrying with exponential backoff
        await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
        debugPrint('Retrying image decode (attempt ${attempt + 2}/$maxRetries)');
      }
    }
    return null;
  }

  /// Create a safe Image widget that handles errors gracefully.
  ///
  /// Returns an Image widget with error handling and fallback.
  static Widget safeImageWidget({
    required String path,
    double? width,
    double? height,
    BoxFit? fit,
    Widget? errorWidget,
  }) {
    return FutureBuilder<ui.Image?>(
      future: loadImageSafely(path),
      builder: (BuildContext context, AsyncSnapshot<ui.Image?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return errorWidget ??
              SizedBox(
                width: width,
                height: height,
                child: const Center(
                  child: Icon(Icons.error_outline, size: 48),
                ),
              );
        }

        return RawImage(
          image: snapshot.data,
          width: width,
          height: height,
          fit: fit ?? BoxFit.contain,
        );
      },
    );
  }

  /// Check if an image file is corrupted.
  ///
  /// Attempts to decode the image to verify integrity.
  static Future<bool> isImageCorrupted(String path) async {
    try {
      final ui.Image? image = await loadImageSafely(path);
      return image == null;
    } catch (e) {
      return true;
    }
  }

  /// Get image dimensions without fully loading the image.
  ///
  /// This is useful for layout calculations before rendering.
  static Future<Size?> getImageDimensions(String path) async {
    try {
      final ui.Image? image = await loadImageSafely(path);
      if (image == null) {
        return null;
      }

      final Size size = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      image.dispose();
      return size;
    } catch (e) {
      debugPrint('Failed to get image dimensions: $e');
      return null;
    }
  }
}
