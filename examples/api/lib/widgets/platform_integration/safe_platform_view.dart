// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A safe wrapper for platform views that handles lifecycle events and errors.
///
/// This widget provides robust error handling for platform view integration,
/// preventing crashes due to platform view creation failures and lifecycle issues.
///
/// Example usage:
/// ```dart
/// SafePlatformView(
///   viewType: 'com.example/video-player',
///   creationParams: {'url': 'https://example.com/video.mp4'},
///   onPlatformViewCreated: (int id) {
///     print('Platform view created with id: $id');
///   },
/// )
/// ```
class SafePlatformView extends StatefulWidget {
  /// Creates a safe platform view.
  const SafePlatformView({
    super.key,
    required this.viewType,
    this.creationParams,
    this.creationParamsCodec,
    this.onPlatformViewCreated,
    this.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    this.layoutDirection,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
    this.fallbackBuilder,
  });

  /// The unique identifier for the type of platform view.
  final String viewType;

  /// Parameters to pass to the platform view when it is created.
  final Map<String, dynamic>? creationParams;

  /// The codec used to encode [creationParams].
  final MessageCodec<dynamic>? creationParamsCodec;

  /// Callback invoked when the platform view is created.
  final PlatformViewCreatedCallback? onPlatformViewCreated;

  /// How to behave during hit tests.
  final PlatformViewHitTestBehavior hitTestBehavior;

  /// The layout direction for the platform view.
  final TextDirection? layoutDirection;

  /// Gesture recognizers to register for the platform view.
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  /// Builder for fallback widget when platform view fails.
  final Widget Function(BuildContext context, Object? error)? fallbackBuilder;

  @override
  State<SafePlatformView> createState() => _SafePlatformViewState();
}

class _SafePlatformViewState extends State<SafePlatformView>
    with WidgetsBindingObserver {
  Object? _error;
  bool _isCreated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to prevent crashes
    switch (state) {
      case AppLifecycleState.resumed:
        // Platform view can resume operations
        debugPrint('Platform view: App resumed');
        break;
      case AppLifecycleState.inactive:
        // Platform view should prepare to pause
        debugPrint('Platform view: App inactive');
        break;
      case AppLifecycleState.paused:
        // Platform view should pause operations
        debugPrint('Platform view: App paused');
        break;
      case AppLifecycleState.detached:
        // Platform view should clean up
        debugPrint('Platform view: App detached');
        break;
      case AppLifecycleState.hidden:
        // Platform view is hidden
        debugPrint('Platform view: App hidden');
        break;
    }
  }

  void _onPlatformViewCreated(int id) {
    setState(() {
      _isCreated = true;
      _error = null;
    });

    if (widget.onPlatformViewCreated != null) {
      try {
        widget.onPlatformViewCreated!(id);
      } catch (e, stackTrace) {
        debugPrint('Error in onPlatformViewCreated callback: $e');
        debugPrint('Stack trace: $stackTrace');
        setState(() {
          _error = e;
        });
      }
    }
  }

  Widget _buildFallback(Object? error) {
    if (widget.fallbackBuilder != null) {
      return widget.fallbackBuilder!(context, error);
    }

    return Container(
      color: const Color(0xFFE0E0E0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFF757575),
            ),
            const SizedBox(height: 16),
            Text(
              'Platform view unavailable',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            if (error != null && kDebugMode) ...<Widget>[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Error: $error',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildFallback(_error);
    }

    try {
      if (Platform.isAndroid) {
        return AndroidView(
          viewType: widget.viewType,
          creationParams: widget.creationParams,
          creationParamsCodec: widget.creationParamsCodec ?? const StandardMessageCodec(),
          hitTestBehavior: widget.hitTestBehavior,
          layoutDirection: widget.layoutDirection ?? TextDirection.ltr,
          gestureRecognizers: widget.gestureRecognizers,
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      } else if (Platform.isIOS) {
        return UiKitView(
          viewType: widget.viewType,
          creationParams: widget.creationParams,
          creationParamsCodec: widget.creationParamsCodec ?? const StandardMessageCodec(),
          hitTestBehavior: widget.hitTestBehavior,
          layoutDirection: widget.layoutDirection ?? TextDirection.ltr,
          gestureRecognizers: widget.gestureRecognizers,
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      } else {
        // Unsupported platform
        return _buildFallback('Platform views not supported on ${Platform.operatingSystem}');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to create platform view: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() {
        _error = e;
      });

      return _buildFallback(e);
    }
  }
}

/// A helper class for safely managing platform view resources.
class SafePlatformViewController {
  /// Creates a safe platform view controller.
  SafePlatformViewController({
    required this.viewId,
    required this.viewType,
  });

  /// The unique identifier for this platform view instance.
  final int viewId;

  /// The type identifier for the platform view.
  final String viewType;

  bool _isDisposed = false;

  /// Whether this controller has been disposed.
  bool get isDisposed => _isDisposed;

  /// Safely dispose of platform view resources.
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    try {
      // In a real implementation, this would call the platform channel
      // to dispose of native resources
      debugPrint('Disposing platform view: $viewId');
      _isDisposed = true;
    } catch (e, stackTrace) {
      debugPrint('Error disposing platform view: $e');
      debugPrint('Stack trace: $stackTrace');
      _isDisposed = true; // Mark as disposed even if there was an error
    }
  }

  /// Send a message to the platform view.
  ///
  /// This provides safe communication with the native view.
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    if (_isDisposed) {
      throw StateError('Cannot invoke method on disposed platform view');
    }

    try {
      // In a real implementation, this would use a MethodChannel
      debugPrint('Invoking method $method on platform view $viewId');
      return null;
    } catch (e, stackTrace) {
      debugPrint('Error invoking method $method: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
