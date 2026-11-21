import 'package:Cartoria/util/file_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('categoryFor', () {
    test('image extensions', () {
      for (final ext in ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic']) {
        expect(categoryFor('file.$ext'), FileCategory.image,
            reason: 'extension $ext');
      }
    });

    test('video extensions', () {
      for (final ext in ['mp4', 'mov', 'webm', 'mkv', 'm4v', 'avi']) {
        expect(categoryFor('file.$ext'), FileCategory.video,
            reason: 'extension $ext');
      }
    });

    test('audio extensions', () {
      for (final ext in ['mp3', 'wav', 'm4a', 'ogg', 'flac', 'aac', 'opus']) {
        expect(categoryFor('file.$ext'), FileCategory.audio,
            reason: 'extension $ext');
      }
    });

    test('text extensions', () {
      for (final ext in [
        'txt',
        'md',
        'json',
        'yaml',
        'xml',
        'csv',
        'dart',
        'js',
        'ts',
        'py',
        'rs',
        'go',
        'c',
        'cpp',
        'h',
        'html',
        'css',
        'sh',
        'toml',
      ]) {
        expect(categoryFor('file.$ext'), FileCategory.text,
            reason: 'extension $ext');
      }
    });

    test('pdf', () {
      expect(categoryFor('doc.pdf'), FileCategory.pdf);
    });

    test('unknown extension → other', () {
      expect(categoryFor('file.xyz'), FileCategory.other);
    });

    test('no extension → other', () {
      expect(categoryFor('README'), FileCategory.other);
    });

    test('uppercase extension is normalized', () {
      expect(categoryFor('PHOTO.PNG'), FileCategory.image);
    });

    test('multiple dots uses last extension', () {
      expect(categoryFor('file.tar.gz'), FileCategory.other);
      expect(categoryFor('archive.tar.png'), FileCategory.image);
    });
  });
}