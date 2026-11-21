import 'package:Cartoria/util/mime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mimeTypeForName', () {
    test('image extensions', () {
      expect(mimeTypeForName('a.jpg'), 'image/jpeg');
      expect(mimeTypeForName('a.jpeg'), 'image/jpeg');
      expect(mimeTypeForName('a.png'), 'image/png');
      expect(mimeTypeForName('a.gif'), 'image/gif');
      expect(mimeTypeForName('a.webp'), 'image/webp');
      expect(mimeTypeForName('a.bmp'), 'image/bmp');
      expect(mimeTypeForName('a.heic'), 'image/heic');
    });

    test('video extensions', () {
      expect(mimeTypeForName('a.mp4'), 'video/mp4');
      expect(mimeTypeForName('a.m4v'), 'video/mp4');
      expect(mimeTypeForName('a.mov'), 'video/quicktime');
      expect(mimeTypeForName('a.webm'), 'video/webm');
      expect(mimeTypeForName('a.mkv'), 'video/x-matroska');
      expect(mimeTypeForName('a.avi'), 'video/x-msvideo');
    });

    test('audio extensions', () {
      expect(mimeTypeForName('a.mp3'), 'audio/mpeg');
      expect(mimeTypeForName('a.wav'), 'audio/wav');
      expect(mimeTypeForName('a.m4a'), 'audio/mp4');
      expect(mimeTypeForName('a.ogg'), 'audio/ogg');
      expect(mimeTypeForName('a.opus'), 'audio/ogg');
      expect(mimeTypeForName('a.flac'), 'audio/flac');
      expect(mimeTypeForName('a.aac'), 'audio/aac');
    });

    test('document extensions', () {
      expect(mimeTypeForName('a.pdf'), 'application/pdf');
      expect(mimeTypeForName('a.txt'), 'text/plain');
      expect(mimeTypeForName('a.md'), 'text/markdown');
      expect(mimeTypeForName('a.markdown'), 'text/markdown');
      expect(mimeTypeForName('a.json'), 'application/json');
      expect(mimeTypeForName('a.xml'), 'application/xml');
      expect(mimeTypeForName('a.zip'), 'application/zip');
    });

    test('uppercase extension', () {
      expect(mimeTypeForName('A.JPG'), 'image/jpeg');
    });

    test('unknown extension → octet-stream', () {
      expect(mimeTypeForName('a.xyz'), 'application/octet-stream');
    });

    test('no extension → octet-stream', () {
      expect(mimeTypeForName('README'), 'application/octet-stream');
    });
  });
}