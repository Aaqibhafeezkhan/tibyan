import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// The new Madina edition's pages as the app ships them
/// (`assets/pages/hafs-1441/`), in the shape the published pack's zip
/// gives them, for tests that lay pages out on disk.
Archive bundledPagesArchive() {
  final archive = Archive();
  final dir = Directory('assets/pages/hafs-1441');
  for (final f in dir.listSync().whereType<File>()) {
    archive.add(ArchiveFile.bytes(p.basename(f.path), f.readAsBytesSync()));
  }
  return archive;
}
