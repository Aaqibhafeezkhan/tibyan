import 'dart:io';

import 'package:flutter/services.dart';

/// The app's assets read from the source tree, as the bundle would serve
/// them (keys are paths from the project root). Counts what it loads.
class DiskBundle extends CachingAssetBundle {
  final loaded = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}
