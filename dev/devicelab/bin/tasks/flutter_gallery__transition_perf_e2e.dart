// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_devicelab/tasks/gallery.dart';
import 'package:flutter_devicelab/framework/adb.dart';
import 'package:flutter_devicelab/framework/framework.dart';

Future<void> main(List<String> args) async {
  deviceOperatingSystem = DeviceOperatingSystem.android;
  await task(createGalleryTransitionE2ETest(args));
}
