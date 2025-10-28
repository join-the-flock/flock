// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:process/process.dart';

import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/os.dart';
import '../base/platform.dart';
import '../build_info.dart';
import '../desktop_device.dart';
import '../device.dart';
import '../macos/application_package.dart';
import '../project.dart';
import 'build_macos.dart';
import 'macos_workflow.dart';

/// A device that represents a desktop MacOS target.
class MacOSDevice extends DesktopDevice {
  MacOSDevice({
    required ProcessManager processManager,
    required Logger logger,
    required FileSystem fileSystem,
    required OperatingSystemUtils operatingSystemUtils,
  }) : _processManager = processManager,
       _logger = logger,
       _operatingSystemUtils = operatingSystemUtils,
       super(
         'macos',
         platformType: PlatformType.macos,
         ephemeral: false,
         processManager: processManager,
         logger: logger,
         fileSystem: fileSystem,
         operatingSystemUtils: operatingSystemUtils,
       );

  final ProcessManager _processManager;
  final Logger _logger;
  final OperatingSystemUtils _operatingSystemUtils;

  @override
  Future<bool> isSupported() async => true;

  @override
  String get name => 'macOS';

  @override
  bool get supportsFlavors => true;

  @override
  Future<TargetPlatform> get targetPlatform async => TargetPlatform.darwin;

  @override
  Future<String> get targetPlatformDisplayName async {
    if (_operatingSystemUtils.hostPlatform == HostPlatform.darwin_arm64) {
      return 'darwin-arm64';
    }
    return 'darwin-x64';
  }

  @override
  bool isSupportedForProject(FlutterProject flutterProject) {
    return flutterProject.macos.existsSync();
  }

  @override
  Future<void> buildForDevice({
    required BuildInfo buildInfo,
    String? mainPath,
    bool usingCISystem = false,
  }) async {
    await buildMacOS(
      flutterProject: FlutterProject.current(),
      buildInfo: buildInfo,
      targetOverride: mainPath,
      verboseLogging: _logger.isVerbose,
      usingCISystem: usingCISystem,
    );
  }

  @override
  String? executablePathForDevice(covariant MacOSApp package, BuildInfo buildInfo) {
    return package.executable(buildInfo);
  }

  @override
  void onAttached(covariant MacOSApp package, BuildInfo buildInfo, Process process) {
    // Bring app to foreground. Ideally this would be done post-launch rather
    // than post-attach, since this won't run for release builds, but there's
    // no general-purpose way of knowing when a process is far enough along in
    // the launch process for 'open' to foreground it.
    final String? applicationBundle = package.applicationBundle(buildInfo);
    if (applicationBundle == null) {
      _logger.printError('Failed to foreground app; application bundle not found');
      return;
    }

    // Retry logic to handle transient failures when app is still launching
    _foregroundAppWithRetry(applicationBundle, maxRetries: 3);
  }

  Future<void> _foregroundAppWithRetry(String applicationBundle, {int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final ProcessResult result = await _processManager.run(<String>['open', applicationBundle]);
        if (result.exitCode == 0) {
          return; // Success
        }

        if (attempt < maxRetries - 1) {
          // Wait before retrying (increasing delay)
          await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          _logger.printTrace('Retrying foreground app (attempt ${attempt + 2}/$maxRetries)');
        } else {
          // Final attempt failed, log detailed error
          _logger.printTrace('Failed to foreground app after $maxRetries attempts; open returned ${result.exitCode}');
          if (result.stderr.toString().isNotEmpty) {
            _logger.printTrace('stderr: ${result.stderr}');
          }
        }
      } catch (e) {
        if (attempt == maxRetries - 1) {
          _logger.printTrace('Failed to foreground app: $e');
        }
      }
    }
  }
}

class MacOSDevices extends PollingDeviceDiscovery {
  MacOSDevices({
    required Platform platform,
    required MacOSWorkflow macOSWorkflow,
    required ProcessManager processManager,
    required Logger logger,
    required FileSystem fileSystem,
    required OperatingSystemUtils operatingSystemUtils,
  }) : _logger = logger,
       _platform = platform,
       _macOSWorkflow = macOSWorkflow,
       _processManager = processManager,
       _fileSystem = fileSystem,
       _operatingSystemUtils = operatingSystemUtils,
       super('macOS devices');

  final MacOSWorkflow _macOSWorkflow;
  final Platform _platform;
  final ProcessManager _processManager;
  final Logger _logger;
  final FileSystem _fileSystem;
  final OperatingSystemUtils _operatingSystemUtils;

  @override
  bool get supportsPlatform => _platform.isMacOS;

  @override
  bool get canListAnything => _macOSWorkflow.canListDevices;

  @override
  Future<List<Device>> pollingGetDevices({
    Duration? timeout,
    bool forWirelessDiscovery = false,
  }) async {
    if (!canListAnything) {
      return const <Device>[];
    }
    return <Device>[
      MacOSDevice(
        processManager: _processManager,
        logger: _logger,
        fileSystem: _fileSystem,
        operatingSystemUtils: _operatingSystemUtils,
      ),
    ];
  }

  @override
  Future<List<String>> getDiagnostics() async => const <String>[];

  @override
  List<String> get wellKnownIds => const <String>['macos'];
}
