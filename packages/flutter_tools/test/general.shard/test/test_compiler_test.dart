// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/compile.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/test/test_compiler.dart';
import 'package:flutter_tools/src/test/test_time_recorder.dart';
import 'package:package_config/package_config_types.dart';
import 'package:test/fake.dart';

import '../../src/common.dart';
import '../../src/context.dart';
import '../../src/logging_logger.dart';
import '../../src/package_config.dart';
import '../../src/throwing_pub.dart';

final Platform linuxPlatform = FakePlatform(environment: <String, String>{});

final debugBuild = BuildInfo(
  BuildMode.debug,
  '',
  treeShakeIcons: false,
  packageConfig: PackageConfig(<Package>[Package('test_api', Uri.parse('file:///test_api/'))]),
  packageConfigPath: '.dart_tool/package_config.json',
);

void main() {
  late FakeResidentCompiler residentCompiler;
  late FileSystem fileSystem;
  late LoggingLogger logger;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.file('pubspec.yaml')
      ..createSync()
      ..writeAsStringSync('''
name: foo
''');
    fileSystem.file('test/foo.dart').createSync(recursive: true);
    writePackageConfigFiles(mainLibName: 'foo', directory: fileSystem.currentDirectory);
    residentCompiler = FakeResidentCompiler(fileSystem);
    logger = LoggingLogger();
  });

  testUsingContext(
    'TestCompiler reports a dill file when compile is successful',
    () async {
      residentCompiler.compilerOutput = const CompilerOutput('abc.dill', 0, <Uri>[]);
      final testCompiler = FakeTestCompiler(
        debugBuild,
        FlutterProject.fromDirectoryTest(fileSystem.currentDirectory),
        residentCompiler,
      );

      final Uri input = Uri.parse('test/foo.dart');
      expect(
        await testCompiler.compile(input),
        TestCompilerComplete(outputPath: 'test/foo.dart.dill', mainUri: input),
      );
    },
    overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      Platform: () => linuxPlatform,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => BufferLogger.test(),
      Pub: ThrowingPub.new,
    },
  );

  testUsingContext(
    'TestCompiler does not try to cache the dill file when precompiled dill is passed',
    () async {
      residentCompiler.compilerOutput = const CompilerOutput('abc.dill', 0, <Uri>[]);
      final testCompiler = FakeTestCompiler(
        debugBuild,
        FlutterProject.fromDirectoryTest(fileSystem.currentDirectory),
        residentCompiler,
        precompiledDillPath: 'precompiled.dill',
      );

      final Uri input = Uri.parse('test/foo.dart');
      expect(
        await testCompiler.compile(input),
        TestCompilerComplete(outputPath: 'abc.dill', mainUri: input),
      );
    },
    overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      Platform: () => linuxPlatform,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => BufferLogger.test(),
      Pub: ThrowingPub.new,
    },
  );

  testUsingContext(
    'TestCompiler reports an error when a compile fails',
    () async {
      residentCompiler.compilerOutput = const CompilerOutput(
        'abc.dill',
        1,
        <Uri>[],
        errorMessage: 'A big bad happened',
      );
      final testCompiler = FakeTestCompiler(
        debugBuild,
        FlutterProject.fromDirectoryTest(fileSystem.currentDirectory),
        residentCompiler,
      );

      final Uri input = Uri.parse('test/foo.dart');
      expect(
        await testCompiler.compile(input),
        TestCompilerFailure(error: 'A big bad happened', mainUri: input),
      );
      expect(residentCompiler.didShutdown, true);
    },
    overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      Platform: () => linuxPlatform,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => BufferLogger.test(),
      Pub: ThrowingPub.new,
    },
  );

  testUsingContext(
    'TestCompiler records test timings when provided TestTimeRecorder',
    () async {
      residentCompiler.compilerOutput = const CompilerOutput('abc.dill', 0, <Uri>[]);
      final testTimeRecorder = TestTimeRecorder(logger);
      final testCompiler = FakeTestCompiler(
        debugBuild,
        FlutterProject.fromDirectoryTest(fileSystem.currentDirectory),
        residentCompiler,
        testTimeRecorder: testTimeRecorder,
      );

      final Uri input = Uri.parse('test/foo.dart');
      expect(
        await testCompiler.compile(Uri.parse('test/foo.dart')),
        TestCompilerComplete(outputPath: 'test/foo.dart.dill', mainUri: input),
      );
      testTimeRecorder.print();

      // Expect one message for each phase.
      final List<String> logPhaseMessages = logger.messages
          .where((String m) => m.startsWith('Runtime for phase '))
          .toList();
      expect(logPhaseMessages, hasLength(TestTimePhases.values.length));

      // As the compile method adds a job to a queue etc we expect at
      // least one phase to take a non-zero amount of time.
      final List<String> logPhaseMessagesNonZero = logPhaseMessages
          .where((String m) => !m.contains(Duration.zero.toString()))
          .toList();
      expect(logPhaseMessagesNonZero, isNotEmpty);
    },
    overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      Platform: () => linuxPlatform,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => logger,
      Pub: ThrowingPub.new,
    },
  );

  testUsingContext(
    'TestCompiler disposing test compiler shuts down backing compiler',
    () async {
      final testCompiler = FakeTestCompiler(
        debugBuild,
        FlutterProject.fromDirectoryTest(fileSystem.currentDirectory),
        residentCompiler,
      );
      testCompiler.compiler = residentCompiler;

      expect(testCompiler.compilerController.isClosed, false);

      await testCompiler.dispose();

      expect(testCompiler.compilerController.isClosed, true);
      expect(residentCompiler.didShutdown, true);
    },
    overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      Platform: () => linuxPlatform,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => BufferLogger.test(),
      Pub: ThrowingPub.new,
    },
  );

  testUsingContext(
    'TestCompiler updates dart_plugin_registrant.dart',
    () async {
      final Directory fakeDartPlugin = fileSystem.directory('a_plugin');
      fileSystem.file('pubspec.yaml').writeAsStringSync('''
name: foo
dependencies:
  flutter:
    sdk: flutter
  a_plugin: 1.0.0
''');
      writePackageConfigFiles(
        directory: fileSystem.currentDirectory,
        mainLibName: 'foo',
        packages: <String, String>{'a_plugin': '/a_plugin'},
      );
      fakeDartPlugin.childFile('pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
name: a_plugin
flutter:
  plugin:
    implements: a
    platforms:
      linux:
        dartPluginClass: APlugin
environment:
  sdk: ^3.7.0-0
  flutter: ">=2.5.0"
''');

      residentCompiler.compilerOutput = const CompilerOutput('abc.dill', 0, <Uri>[]);
      final testCompiler = FakeTestCompiler(
        debugBuild,
        FlutterProject.fromDirectoryTest(fileSystem.currentDirectory),
        residentCompiler,
      );

      await testCompiler.compile(Uri.parse('test/foo.dart'));

      final File generatedMain = fileSystem
          .directory('.dart_tool')
          .childDirectory('flutter_build')
          .childFile('dart_plugin_registrant.dart');

      expect(generatedMain, exists);
      expect(generatedMain.readAsStringSync(), contains('APlugin.registerWith();'));
    },
    overrides: <Type, Generator>{
      FileSystem: () => fileSystem,
      Platform: () => linuxPlatform,
      ProcessManager: () => FakeProcessManager.any(),
      Logger: () => BufferLogger.test(),
      Pub: ThrowingPub.new,
    },
  );
}

/// Override the creation of the Resident Compiler to simplify testing.
class FakeTestCompiler extends TestCompiler {
  FakeTestCompiler(
    super.buildInfo,
    super.flutterProject,
    this.residentCompiler, {
    super.precompiledDillPath,
    super.testTimeRecorder,
  });

  final FakeResidentCompiler? residentCompiler;

  @override
  Future<ResidentCompiler?> createCompiler() async {
    return residentCompiler;
  }
}

class FakeResidentCompiler extends Fake implements ResidentCompiler {
  FakeResidentCompiler(this.fileSystem);

  final FileSystem? fileSystem;

  CompilerOutput? compilerOutput;
  var didShutdown = false;

  @override
  Future<CompilerOutput?> recompile(
    Uri mainUri,
    List<Uri>? invalidatedFiles, {
    String? outputPath,
    PackageConfig? packageConfig,
    String? projectRootPath,
    FileSystem? fs,
    bool suppressErrors = false,
    bool checkDartPluginRegistry = false,
    File? dartPluginRegistrant,
    Uri? nativeAssetsYaml,
    bool recompileRestart = false,
  }) async {
    if (compilerOutput != null) {
      fileSystem!.file(compilerOutput!.outputFilename).createSync(recursive: true);
    }
    return compilerOutput;
  }

  @override
  void accept() {}

  @override
  void reset() {}

  @override
  Future<Object> shutdown() async {
    didShutdown = true;
    return Object();
  }
}
