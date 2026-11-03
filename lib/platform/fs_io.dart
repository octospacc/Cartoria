import 'package:fs_shim/fs_io.dart' as impl;
import 'package:fs_shim/fs_shim.dart';

FileSystem createFs() => impl.fileSystemIo;