import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'page_pack.dart';

/// The new Madina edition ships inside the app, so the mushaf opens on
/// first launch without a download: its pages are read straight from the
/// app's assets ([PagePackSpec.assetDir]), never copied out.
///
/// Builds before that copied the bundled zip to disk and extracted it
/// (65 MB twice over). That copy is now redundant: once a bundled page is
/// known to read, it is removed. Returns whether anything was removed.
Future<bool> removeExtractedBundledPack(
  AssetBundle bundle,
  Directory root,
) async {
  const spec = PagePackSpec.madina1441;
  final dir = Directory(p.join(root.path, spec.id));
  final zip = File(p.join(root.path, 'bundled-${spec.id}.zip'));
  final part = File(p.join(root.path, '${spec.id}.zip.part'));
  final stale = [dir, zip, part].where((e) => e.existsSync()).toList();
  if (stale.isEmpty) return false;
  // Only when the bundled pages are there to read instead.
  final page = await bundle.load('${spec.assetDir}001.svg.xz');
  if (page.lengthInBytes == 0) return false;
  for (final e in stale) {
    await e.delete(recursive: true);
  }
  return true;
}
