import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smartagri/core/media/image_compressor.dart';

img.Image solidImage(int width, int height) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(40, 120, 60));
  return image;
}

img.Image noiseImage(int width, int height) {
  final img.Image image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 37 + y * 17) % 256,
        (x * 11 + y * 53) % 256,
        (x * 97 + y * 7) % 256,
      );
    }
  }
  return image;
}

void main() {
  test('resizes the largest side to 1024 pixels', () {
    final CompressedImage result = compressImageBytes(
      img.encodeJpg(solidImage(2000, 1000)),
    );

    expect(result.width, 1024);
    expect(result.height, 512);
    expect(result.mimeType, 'image/jpeg');
    expect(result.bytes[0], 0xFF);
    expect(result.bytes[1], 0xD8);
    expect(result.sizeBytes, result.bytes.length);
  });

  test('never enlarges a smaller image', () {
    final CompressedImage result = compressImageBytes(
      img.encodePng(solidImage(320, 180)),
    );

    expect(result.width, 320);
    expect(result.height, 180);
  });

  test('accepts PNG and WebP inputs and always returns JPEG', () {
    final CompressedImage fromPng = compressImageBytes(
      img.encodePng(solidImage(640, 480)),
    );
    final CompressedImage fromWebp = compressImageBytes(
      img.encodeWebP(solidImage(640, 480)),
    );

    expect(fromPng.mimeType, 'image/jpeg');
    expect(fromWebp.mimeType, 'image/jpeg');
    expect(fromWebp.bytes[0], 0xFF);
    expect(fromWebp.bytes[1], 0xD8);
  });

  test('applies the EXIF orientation before resizing', () {
    final img.Image source = solidImage(240, 120);
    source.exif.imageIfd.orientation = 6;
    final CompressedImage result = compressImageBytes(img.encodeJpg(source));

    expect(result.width, 120);
    expect(result.height, 240);
  });

  test('computes the lowercase hexadecimal sha256 of the final bytes', () {
    final CompressedImage result = compressImageBytes(
      img.encodeJpg(solidImage(800, 600)),
    );

    expect(result.sha256, sha256.convert(result.bytes).toString());
    expect(result.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('drops every EXIF tag, including GPS, from the output', () {
    final img.Image source = solidImage(400, 300);
    source.exif.gpsIfd.gpsLatitude = 13.5116;
    source.exif.gpsIfd.gpsLongitude = 2.1254;
    source.exif.gpsIfd.gpsLatitudeRef = 'N';
    source.exif.gpsIfd.gpsLongitudeRef = 'E';
    final Uint8List input = img.encodeJpg(source);

    expect(img.decodeJpg(input)!.exif.gpsIfd.gpsLatitude, isNotNull);

    final CompressedImage result = compressImageBytes(input);
    final img.Image output = img.decodeJpg(result.bytes)!;

    expect(output.exif.gpsIfd.gpsLatitude, isNull);
    expect(output.exif.gpsIfd.gpsLongitude, isNull);
    expect(output.exif.isEmpty, isTrue);
  });

  test('rejects unsupported formats with a readable message', () {
    expect(
      () => compressImageBytes(Uint8List.fromList(<int>[1, 2, 3, 4])),
      throwsA(
        isA<ImageProcessingException>().having(
          (ImageProcessingException error) => error.message,
          'message',
          "Format d'image non pris en charge.",
        ),
      ),
    );
    expect(
      () => compressImageBytes(img.encodeGif(img.Image(width: 4, height: 4))),
      throwsA(isA<ImageProcessingException>()),
    );
  });

  test('keeps the result under 3 MiB for a large detailed image', () {
    final CompressedImage result = compressImageBytes(
      img.encodePng(noiseImage(1200, 1200)),
    );

    expect(result.sizeBytes, lessThanOrEqualTo(defaultMaxImageBytes));
    expect(result.width, lessThanOrEqualTo(1024));
    expect(result.height, lessThanOrEqualTo(1024));
  });

  test('lowers the JPEG quality down to 60 when the budget is exceeded', () {
    final Uint8List input = img.encodePng(noiseImage(800, 800));
    final CompressedImage normal = compressImageBytes(input);
    final CompressedImage reduced = compressImageBytes(input, maxSizeBytes: 0);

    expect(reduced.sizeBytes, lessThan(normal.sizeBytes));
  });

  test('runs the implementation in an isolate', () async {
    const ImageCompressor compressor = IsolateImageCompressor();
    final CompressedImage result = await compressor.compress(
      img.encodeJpg(solidImage(50, 25)),
    );

    expect(result.width, 50);
    expect(result.height, 25);
    expect(result.mimeType, 'image/jpeg');
  });
}
