import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

class ImageProcessingException implements Exception {
  const ImageProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CompressedImage {
  CompressedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.sha256,
    this.mimeType = 'image/jpeg',
  }) : sizeBytes = bytes.length;

  final Uint8List bytes;
  final int width;
  final int height;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
}

abstract interface class ImageCompressor {
  Future<CompressedImage> compress(Uint8List bytes);
}

class IsolateImageCompressor implements ImageCompressor {
  const IsolateImageCompressor();

  @override
  Future<CompressedImage> compress(Uint8List bytes) {
    return Isolate.run<CompressedImage>(() => compressImageBytes(bytes));
  }
}

const int defaultMaxImageSide = 1024;
const int defaultJpegQuality = 80;
const int minimumJpegQuality = 60;
const int defaultMaxImageBytes = 3 * 1024 * 1024;

CompressedImage compressImageBytes(
  Uint8List bytes, {
  int maxSide = defaultMaxImageSide,
  int startQuality = defaultJpegQuality,
  int minQuality = minimumJpegQuality,
  int maxSizeBytes = defaultMaxImageBytes,
}) {
  if (!_isJpeg(bytes) && !_isPng(bytes) && !_isWebp(bytes)) {
    throw const ImageProcessingException("Format d'image non pris en charge.");
  }
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const ImageProcessingException("Format d'image non pris en charge.");
  }
  img.Image image = img.bakeOrientation(decoded);
  final int largest = image.width > image.height ? image.width : image.height;
  if (largest > maxSide) {
    if (image.width >= image.height) {
      final int height = (image.height * maxSide / image.width).round();
      image = img.copyResize(
        image,
        width: maxSide,
        height: height < 1 ? 1 : height,
        interpolation: img.Interpolation.average,
      );
    } else {
      final int width = (image.width * maxSide / image.height).round();
      image = img.copyResize(
        image,
        width: width < 1 ? 1 : width,
        height: maxSide,
        interpolation: img.Interpolation.average,
      );
    }
  }
  image.exif = img.ExifData();
  Uint8List encoded = Uint8List(0);
  for (int quality = startQuality; quality >= minQuality; quality -= 5) {
    encoded = img.encodeJpg(image, quality: quality);
    if (encoded.length <= maxSizeBytes) {
      break;
    }
    if (quality - 5 < minQuality && quality != minQuality) {
      encoded = img.encodeJpg(image, quality: minQuality);
      break;
    }
  }
  return CompressedImage(
    bytes: encoded,
    width: image.width,
    height: image.height,
    sha256: sha256.convert(encoded).toString(),
  );
}

bool _isJpeg(Uint8List bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}

bool _isPng(Uint8List bytes) {
  const List<int> signature = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];
  if (bytes.length < signature.length) {
    return false;
  }
  for (int index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) {
      return false;
    }
  }
  return true;
}

bool _isWebp(Uint8List bytes) {
  if (bytes.length < 12) {
    return false;
  }
  return bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}
