import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A module that provides access to any aspects of the IME that are relevant
/// for Flock features and bug fixes.
class FlockIme {
  /// The singleton instance for [FlockIme].
  static FlockIme get instance {
    _instance ??= FlockIme._();
    return _instance!;
  }

  static FlockIme? _instance;

  /// Disposes Flock's IME singleton.
  ///
  /// Accessing the [instance] will create a new [FlockIme].
  static void dispose() {
    _instance?._dispose();
    _instance = null;
  }

  // ignore: sort_constructors_first
  FlockIme._() {
    TextInput.flockIsImeConnected.addListener(_onFlutterImeConnectionChange);
  }

  /// Dispose Flock's IME module.
  ///
  /// This instance must not be used after disposal.
  void _dispose() {
    TextInput.flockIsImeConnected.removeListener(_onFlutterImeConnectionChange);
  }

  /// The current connection status between Flutter and the host OS input
  /// method editor (IME).
  ValueListenable<FlockImeConnectionStatus> get connectionStatus => _connectionStatus;
  final ValueNotifier<FlockImeConnectionStatus> _connectionStatus = ValueNotifier<FlockImeConnectionStatus>(
    FlockImeConnectionStatus.disconnected,
  );

  void _onFlutterImeConnectionChange() {
    // Flock added a connection status listenable to Flutter's text input system.
    // That listenable is a boolean. Flock forwards it here and converts it into a
    // FlockImeConnectionStatus because Flock may want to introduce other status values
    // in the future. By exposing an enum, Flock keeps its options open.
    //
    // For example, Flock might want to add device-specific info:
    //  - software keyboard
    //  - minimized software keyboard
    //  - hardware keyboard
    //  - etc.
    _connectionStatus.value = TextInput.flockIsImeConnected.value //
        ? FlockImeConnectionStatus.connected
        : FlockImeConnectionStatus.disconnected;
  }
}

/// Possible statuses for the connection between Flutter and the host
/// operating system's input method editor (IME).
enum FlockImeConnectionStatus {
  /// There's no active connection between Flutter and the host IME.
  disconnected,

  /// Flutter is connected to the host IME.
  connected;
}
