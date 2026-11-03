import 'package:fs_shim/fs_browser.dart' as impl;
import 'package:fs_shim/fs_shim.dart';

FileSystem createFs() => impl.fileSystemWeb;