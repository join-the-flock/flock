# Flock framework extensions

This SDK-internal package holds Flock-specific framework implementations so they
can evolve without adding helper classes to upstream Flutter source files.
It ships with the Flock SDK and is not published separately.

`FlockTextMinLines` implements the layout wrapper for plain `Text.minLines`.
Flutter retains the public Text API and supplies the effective text settings;
the wrapper and its render object live here. The integration tests in `test/`
exercise the public Text API, including rendering and selection behavior.

The Flutter and Flock packages intentionally depend on each other: Flock builds
on Flutter's rendering and widget primitives, while Flutter delegates its Flock
extensions to this package. Dart supports these package dependencies; this SDK
must include both packages.
