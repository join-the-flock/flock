import 'package:flutter/src/flock/ime/ime.dart';

/// Global configuration and entrypoint for Flock functionality within
/// Flutter.
///
/// Some Flock features can be enabled and disabled. This class controls
/// those features.
///
/// Flock features span various areas of Flutter. Flock does its best to
/// provide access to those areas, independently. Flock calls them modules.
/// Those modules are accessible through this class, e.g., [ime].
class Flock {
  /// The input method editor (IME) module for Flock.
  static FlockIme get ime => FlockIme.instance;

  const Flock._();
}
