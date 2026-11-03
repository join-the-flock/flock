// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'version.dart';

/// Flock's human-readable version reporting, isolated from Flutter's formatter.
/// Being a part keeps dependencies private and leaves JSON reporting untouched.
class _FlockVersionDescription {
  _FlockVersionDescription(this._version);

  final FlutterVersion _version;

  String heading(String fallbackVersionText) {
    final FlockUpstream? upstream = _upstream;
    final String versionText = upstream == null
        ? fallbackVersionText
        : _upstreamVersionText(upstream);
    final String branch = upstream == null
        ? _version.getBranchName()
        : _version._git
              .runSync(['symbolic-ref', '--short', 'HEAD'], workingDirectory: _version.flutterRoot)
              .stdout
              .trim();
    final String distributionChannel = _distributionChannel(branch);
    final branchText = branch != distributionChannel
        ? ' • branch ${branch.isEmpty || branch == 'HEAD' ? 'detached' : branch}'
        : '';
    return 'Flock (Flutter$versionText) • channel $distributionChannel$branchText • https://github.com/join-the-flock/flock.git';
  }

  String _upstreamVersionText(FlockUpstream upstream) {
    final String version = GitTagVersion.determine(
      _version._platform,
      git: _version._git,
      gitRef: upstream.revision,
      workingDirectory: _version.flutterRoot,
      logger: _version._logger,
    ).frameworkVersionFor(upstream.revision);
    return version == kUnknownFrameworkVersion ? '' : ' $version';
  }

  String get frameworkText {
    final frameworkText =
        'Flock framework • revision ${_version.frameworkRevisionShort} (${_version.frameworkAge}) • ${_version.frameworkCommitDate}';
    final FlockUpstream? upstream = _upstream;
    final upstreamText = upstream == null
        ? 'Flutter upstream • revision unknown'
        : 'Flutter upstream • revision ${_shortGitRevision(upstream.revision)} '
              '(${_version._clock.now().difference(DateTime.parse(upstream.commitDate)).ago()}) '
              '• ${upstream.commitDate}';
    return '$frameworkText\n$upstreamText';
  }

  late final FlockUpstream? _upstream =
      _version.fs.directory(_version.fs.path.join(_version.flutterRoot, '.git')).existsSync() ||
          _version.fs.file(_version.fs.path.join(_version.flutterRoot, '.git')).existsSync()
      ? FlockUpstream.determine(
          git: _version._git,
          flutterRoot: _version.flutterRoot,
          revision: _version.frameworkRevision,
        )
      : null;

  String _distributionChannel(String branch) {
    if (kOfficialChannels.contains(branch)) {
      return branch;
    }
    if (_upstream == null) {
      return kOfficialChannels.contains(_version.channel) ? _version.channel : 'unknown';
    }
    // A feature branch may track another feature branch. Only official names
    // provide evidence of a distribution channel.
    final RunResult tracking = _version._git.runSync([
      'rev-parse',
      '--abbrev-ref',
      '--symbolic',
      kGitTrackingUpstream,
    ], workingDirectory: _version.flutterRoot);
    final String trackedBranch = tracking.stdout.trim().split('/').skip(1).join('/');
    if (tracking.exitCode == 0 && kOfficialChannels.contains(trackedBranch)) {
      return trackedBranch;
    }
    final RunResult branches = _version._git.runSync([
      'for-each-ref',
      '--format=%(refname)',
      '--contains',
      _upstream.revision,
      'refs/heads/',
      'refs/remotes/',
    ], workingDirectory: _version.flutterRoot);
    final localChannels = <String>{};
    final remoteChannels = <String>{};
    for (final String ref in branches.stdout.trim().split('\n')) {
      final List<String> parts = ref.split('/');
      switch (parts) {
        case ['refs', 'heads', final String name] when kOfficialChannels.contains(name):
          localChannels.add(name);
        case ['refs', 'remotes', _, final String name] when kOfficialChannels.contains(name):
          remoteChannels.add(name);
      }
    }
    // A local distribution branch is stronger evidence than remote branches:
    // Flutter's master/main aliases can both contain the same upstream commit.
    final channels = localChannels.isNotEmpty ? localChannels : remoteChannels;
    return branches.exitCode == 0 && channels.length == 1 ? channels.single : 'unknown';
  }
}

/// The included Flutter commit, before Nest's assembly commits and patches.
/// This is presentation metadata; it never replaces the Flock SDK revision.
@visibleForTesting
class FlockUpstream {
  const FlockUpstream(this.revision, this.commitDate);

  final String revision;
  final String commitDate;

  static FlockUpstream? determine({
    required Git git,
    required String flutterRoot,
    required String revision,
  }) {
    RunResult log(String ref, {bool findPatch = false}) => git.logSync([
      ref,
      '--first-parent',
      '-n',
      '1',
      '--format=%H%x00%P%x00%ai%x00%s%x00%b',
      if (findPatch) '--grep=^Patch-Filename: ',
    ], workingDirectory: flutterRoot);

    // Published branches retain these headers from git-import-patches, but
    // push-flock-repo does not publish refs/patches/upstream-head.
    RunResult result = log(revision, findPatch: true);
    if (result.exitCode != 0) {
      return null;
    }
    String candidate;
    if (result.stdout.trim().isNotEmpty) {
      final visited = <String>{};
      while (true) {
        final List<String> fields = result.stdout.trim().split('\x00');
        if (result.exitCode != 0 || fields.length != 5 || !visited.add(fields[0])) {
          return null;
        }
        final bool isPatch = RegExp(
          r'^Patch-Filename: .+\.patch$',
          multiLine: true,
        ).hasMatch(fields[4]);
        // CI pins the engine before importing patches, so upstream-head can
        // itself be an assembly commit. Its parent is the included Flutter.
        final isEnginePin = fields[3] == 'save engine version';
        if (!isPatch && !isEnginePin) {
          candidate = fields[0];
          break;
        }
        final List<String> parents = fields[1].split(' ');
        if (parents.length != 1 || parents.single.isEmpty) {
          return null;
        }
        result = log(parents.single);
      }
    } else {
      final RunResult ref = git.runSync([
        'rev-parse',
        '--verify',
        'refs/patches/upstream-head^{commit}',
      ], workingDirectory: flutterRoot);
      if (ref.exitCode != 0 || ref.stdout.trim().isEmpty) {
        return null;
      }
      candidate = ref.stdout.trim();
      result = log(candidate);
      final List<String> fields = result.stdout.trim().split('\x00');
      if (result.exitCode != 0 || fields.length != 5) {
        return null;
      }
      if (fields[3] == 'save engine version') {
        candidate = fields[1];
        result = log(candidate);
      }
    }
    // Reject unrelated assembly refs and incomplete shallow history.
    final RunResult ancestor = git.runSync([
      'merge-base',
      '--is-ancestor',
      candidate,
      revision,
    ], workingDirectory: flutterRoot);
    final List<String> fields = result.stdout.trim().split('\x00');
    if (ancestor.exitCode != 0 ||
        result.exitCode != 0 ||
        fields.length != 5 ||
        DateTime.tryParse(fields[2]) == null) {
      return null;
    }
    return FlockUpstream(candidate, fields[2]);
  }
}
