// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;


import '../framework/adb.dart';
import '../framework/framework.dart';
import '../framework/task_result.dart';
import '../framework/utils.dart';
import 'build_test_task.dart';

final Directory galleryDirectory = dir('${flutterDirectory.path}/dev/integration_tests/flutter_gallery');

TaskFunction createGalleryTransitionTest(List<String> args, {bool semanticsEnabled = false}) {
  return GalleryTransitionTest(args, semanticsEnabled: semanticsEnabled, workingDirectory: galleryDirectory,);
}

TaskFunction createGalleryTransitionE2ETest(List<String> args, {bool semanticsEnabled = false}) {
  return GalleryTransitionTest(
    args,
    testFile: semanticsEnabled
        ? 'transitions_perf_e2e_with_semantics'
        : 'transitions_perf_e2e',
    needFullTimeline: false,
    timelineSummaryFile: 'e2e_perf_summary',
    transitionDurationFile: null,
    timelineTraceFile: null,
    driverFile: 'transitions_perf_e2e_test',
    workingDirectory: galleryDirectory,
  );
}

TaskFunction createGalleryTransitionHybridTest(List<String> args, {bool semanticsEnabled = false}) {
  return GalleryTransitionTest(
    args,
    semanticsEnabled: semanticsEnabled,
    driverFile: semanticsEnabled
        ? 'transitions_perf_hybrid_with_semantics_test'
        : 'transitions_perf_hybrid_test',
    workingDirectory: galleryDirectory,
  );
}

class GalleryTransitionTest extends BuildTestTask {
  GalleryTransitionTest(List<String> args, {
    this.semanticsEnabled = false,
    this.testFile = 'transitions_perf',
    this.needFullTimeline = true,
    this.timelineSummaryFile = 'transitions.timeline_summary',
    this.timelineTraceFile = 'transitions.timeline',
    this.transitionDurationFile = 'transition_durations.timeline',
    this.driverFile,
    Directory workingDirectory,
  }) : super(args, workingDirectory: workingDirectory);

  final bool semanticsEnabled;
  final bool needFullTimeline;
  final String testFile;
  final String timelineSummaryFile;
  final String timelineTraceFile;
  final String transitionDurationFile;
  final String driverFile;

  @override
  List<String> getBuildArgs() {
      switch (targetPlatform) {
        case DeviceOperatingSystem.android:
          return <String>[
              'apk',
              '--no-android-gradle-daemon',
              '--profile',
              '-t',
              'test_driver/$testFile.dart',
              '--target-platform',
              'android-arm,android-arm64',
            ];
        case DeviceOperatingSystem.ios:
          return <String>[
            'ios',
            // Skip codesign on presubmit checks
            if (targetPlatform != null)
              '--no-codesign',
            '--profile',
            '-t',
            'test_driver/$testFile.dart',
          ];
        default:
          throw Exception('$deviceOperatingSystem has no build configuration');
      }
    }

  @override
  List<String> getTestArgs(String deviceId) {
    final String testDriver = driverFile ?? (semanticsEnabled
      ? '${testFile}_with_semantics_test'
      : '${testFile}_test');
    return <String>[
        '--profile',
        if (needFullTimeline)
          '--trace-startup',
        '--use-application-binary="${getApplicationBinaryPath()}"',
        '--driver', 'test_driver/$testDriver.dart',
        '-d', deviceId,
      ];
  }

  @override
  Future<TaskResult> parseTaskResult() async {
    final Map<String, dynamic> summary = json.decode(
      file('${workingDirectory.path}/build/$timelineSummaryFile.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    if (transitionDurationFile != null) {
      final Map<String, dynamic> original = json.decode(
        file('${workingDirectory.path}/build/$transitionDurationFile.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final Map<String, List<int>> transitions = <String, List<int>>{};
      for (final String key in original.keys) {
        transitions[key] = List<int>.from(original[key] as List<dynamic>);
      }
      summary['transitions'] = transitions;
      summary['missed_transition_count'] = _countMissedTransitions(transitions);
    }

    return TaskResult.success(summary,
      detailFiles: <String>[
        if (transitionDurationFile != null)
          '${workingDirectory.path}/build/$transitionDurationFile.json',
        if (timelineTraceFile != null)
          '${workingDirectory.path}/build/$timelineTraceFile.json'
      ],
      benchmarkScoreKeys: <String>[
        if (transitionDurationFile != null)
          'missed_transition_count',
        'average_frame_build_time_millis',
        'worst_frame_build_time_millis',
        '90th_percentile_frame_build_time_millis',
        '99th_percentile_frame_build_time_millis',
        'average_frame_rasterizer_time_millis',
        'worst_frame_rasterizer_time_millis',
        '90th_percentile_frame_rasterizer_time_millis',
        '99th_percentile_frame_rasterizer_time_millis',
      ],
    );
  }

  @override
  String getApplicationBinaryPath() {
    if (applicationBinaryPath != null) {
      return applicationBinaryPath;
    }

    switch (targetPlatform) {
      case DeviceOperatingSystem.android:
        return 'build/app/outputs/flutter-apk/app-profile.apk';
      case DeviceOperatingSystem.ios:
        return 'build/ios/iphoneos/Flutter Gallery.app';
      default:
        throw UnimplementedError('getApplicationBinaryPath does not support $deviceOperatingSystem');
    }
  }
}

int _countMissedTransitions(Map<String, List<int>> transitions) {
  const int _kTransitionBudget = 100000; // µs
  int count = 0;
  transitions.forEach((String demoName, List<int> durations) {
    final int longestDuration = durations.reduce(math.max);
    if (longestDuration > _kTransitionBudget) {
      print('$demoName missed transition time budget ($longestDuration µs > $_kTransitionBudget µs)');
      count++;
    }
  });
  return count;
}
