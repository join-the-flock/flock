// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/time.dart';
import 'package:flutter_tools/src/git.dart';
import 'package:flutter_tools/src/version.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fake_process_manager.dart';

void main() {
  const root = '/flutter';
  const date = '2026-10-01 12:00:00 +0000';
  late FakeProcessManager processes;
  late Git git;

  FakeCommand log(String ref, String output, {bool findPatch = false, int exitCode = 0}) =>
      FakeCommand(
        command: [
          'git',
          '-c',
          'log.showSignature=false',
          'log',
          ref,
          '--first-parent',
          '-n',
          '1',
          '--format=%H%x00%P%x00%ai%x00%s%x00%b',
          if (findPatch) '--grep=^Patch-Filename: ',
        ],
        stdout: output,
        exitCode: exitCode,
      );

  String commit(
    String revision,
    String parent, {
    String subject = 'upstream',
    bool patch = false,
  }) =>
      '$revision\x00$parent\x00$date\x00$subject\x00${patch ? 'Patch-Dir: patches\nPatch-Filename: fix.patch\n' : ''}';

  FakeCommand ancestor(String base, {int exitCode = 0}) => FakeCommand(
    command: ['git', 'merge-base', '--is-ancestor', base, 'flock-head'],
    exitCode: exitCode,
  );

  FlockUpstream? determine() =>
      FlockUpstream.determine(git: git, flutterRoot: root, revision: 'flock-head');

  setUp(() {
    processes = FakeProcessManager.empty();
    git = Git(
      currentPlatform: FakePlatform(),
      runProcessWith: ProcessUtils(processManager: processes, logger: BufferLogger.test()),
    );
  });

  tearDown(() => expect(processes, hasNoRemainingExpectations));

  testWithoutContext(
    'published history identifies base without private ref, past local commits',
    () {
      processes.addCommands([
        log('flock-head', commit('patch2', 'patch1', patch: true), findPatch: true),
        log('patch1', commit('patch1', 'base', patch: true)),
        log('base', commit('base', 'older')),
        ancestor('base'),
      ]);
      expect(determine()?.revision, 'base');
    },
  );

  testWithoutContext('CI engine pin is not an upstream Flutter commit', () {
    processes.addCommands([
      log('flock-head', commit('patch', 'pin', patch: true), findPatch: true),
      log('pin', commit('pin', 'base', subject: 'save engine version')),
      log('base', commit('base', 'older')),
      ancestor('base'),
    ]);
    final FlockUpstream? upstream = determine();
    expect(upstream?.revision, 'base');
    expect(upstream?.commitDate, date);
  });

  for (final enginePin in [false, true]) {
    testWithoutContext('assembly ref fallback, engine pin: $enginePin', () {
      processes.addCommands([
        log('flock-head', '', findPatch: true),
        FakeCommand(
          command: const ['git', 'rev-parse', '--verify', 'refs/patches/upstream-head^{commit}'],
          stdout: enginePin ? 'pin' : 'base',
        ),
        if (enginePin) log('pin', commit('pin', 'base', subject: 'save engine version')),
        log('base', commit('base', 'older')),
        ancestor('base'),
      ]);
      expect(determine()?.revision, 'base');
    });
  }

  testWithoutContext('unrelated assembly ref is rejected', () {
    processes.addCommands([
      log('flock-head', '', findPatch: true),
      const FakeCommand(
        command: ['git', 'rev-parse', '--verify', 'refs/patches/upstream-head^{commit}'],
        stdout: 'unrelated',
      ),
      log('unrelated', commit('unrelated', 'older')),
      ancestor('unrelated', exitCode: 1),
    ]);
    expect(determine(), isNull);
  });

  testWithoutContext('missing shallow parent does not invent upstream information', () {
    processes.addCommands([
      log('flock-head', commit('patch', 'missing', patch: true), findPatch: true),
      log('missing', '', exitCode: 128),
    ]);
    expect(determine(), isNull);
  });

  testWithoutContext('missing ref and metadata are safe', () {
    processes.addCommands([
      log('flock-head', '', findPatch: true),
      const FakeCommand(
        command: ['git', 'rev-parse', '--verify', 'refs/patches/upstream-head^{commit}'],
        exitCode: 128,
      ),
    ]);
    expect(determine(), isNull);
  });

  for (final (branch, tracking, refs, expectedChannel) in [
    (
      'feature/version',
      'origin/feature/version',
      'refs/heads/master\nrefs/remotes/origin/master\nrefs/remotes/origin/main',
      'master',
    ),
    ('stable', '', '', 'stable'),
    ('', '', 'refs/heads/master', 'master'),
    ('feature/tracked', 'origin/beta', '', 'beta'),
    ('feature/ambiguous', '', 'refs/heads/stable\nrefs/heads/master', 'unknown'),
    ('feature/no-channel', '', 'refs/remotes/origin/feature/master', 'unknown'),
    ('feature/remote-only', '', 'refs/remotes/origin/beta', 'beta'),
  ]) {
    testUsingContext('cached presentation reports upstream independently on branch "$branch"', () {
      final fs = MemoryFileSystem.test();
      fs.file('$root/.git').createSync(recursive: true); // Worktree support.
      final manifest = <String, Object>{
        'frameworkVersion': '3.51.0-0.0.pre-15',
        'channel': branch == 'stable' ? 'stable' : kUserBranch,
        'repositoryUrl': 'https://github.com/flutter/flutter.git',
        'frameworkRevision': 'flock-head',
        'frameworkCommitDate': '2026-11-01 12:00:00 +0000',
        'engineRevision': 'base',
        'engineBuildDate': '2026-10-01 12:00:00 +0000',
        'dartSdkVersion': '3.15.0',
        'devToolsVersion': '2.62.0',
        'flutterVersion': '3.51.0-0.0.pre-15',
      };
      FlutterVersion.getVersionFile(fs, root)
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(manifest));
      final version = FlutterVersion(
        flutterRoot: root,
        fs: fs,
        git: git,
        platform: FakePlatform(),
        clock: SystemClock.fixed(DateTime.utc(2026, 11, 3, 12)),
      );
      final Map<String, Object> before = version.toJson();
      processes.addCommands([
        log('flock-head', commit('patch', 'base', patch: true), findPatch: true),
        log('base', commit('base', 'older')),
        ancestor('base'),
        FakeCommand(
          command: const ['git', 'tag', '--points-at', 'base'],
          stdout: branch == 'stable' ? '3.50.0' : '',
        ),
        if (branch != 'stable') ...[
          const FakeCommand(
            command: [
              'git',
              'for-each-ref',
              '--sort=-v:refname',
              '--count=1',
              '--format=%(refname:short)',
              'refs/tags/[0-9]*.*.*',
            ],
            stdout: '3.50.0',
          ),
          const FakeCommand(command: ['git', 'merge-base', 'base', '3.50.0'], stdout: 'tag-base'),
          const FakeCommand(
            command: ['git', 'rev-list', '--count', 'tag-base..base'],
            stdout: '10',
          ),
        ],
        FakeCommand(command: const ['git', 'symbolic-ref', '--short', 'HEAD'], stdout: branch),
        if (branch != 'stable') ...[
          FakeCommand(
            command: const ['git', 'rev-parse', '--abbrev-ref', '--symbolic', '@{upstream}'],
            stdout: tracking,
            exitCode: tracking.isEmpty ? 128 : 0,
          ),
          if (tracking != 'origin/beta')
            FakeCommand(
              command: const [
                'git',
                'for-each-ref',
                '--format=%(refname)',
                '--contains',
                'base',
                'refs/heads/',
                'refs/remotes/',
              ],
              stdout: refs,
            ),
        ],
        const FakeCommand(
          command: [
            'git',
            '-c',
            'log.showSignature=false',
            'log',
            '-n',
            '1',
            '--pretty=format:%ar',
          ],
          stdout: '2 days ago',
        ),
      ]);
      final text = version.toString();
      expect(text.split('\n').first, endsWith('https://github.com/join-the-flock/flock.git'));
      expect(version.toJson()['repositoryUrl'], 'https://github.com/flutter/flutter.git');
      expect(
        text,
        startsWith(
          'Flock (Flutter ${branch == 'stable' ? '3.50.0' : '3.50.1-0.0.pre-10'}) • channel $expectedChannel',
        ),
      );
      if (branch != 'stable') {
        expect(text, contains('branch ${branch.isEmpty ? 'detached' : branch}'));
      }
      expect(text, contains('Flock framework • revision flock-head (2 days ago) • 2026-11-01'));
      expect(text, contains('Flutter upstream • revision base (1 months ago) • $date'));
      expect(version.toJson(), before);
      expect(version.toJson()['frameworkRevision'], 'flock-head');
      expect(version.toJson()['frameworkVersion'], '3.51.0-0.0.pre-15');
    });
  }
}
