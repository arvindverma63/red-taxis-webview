import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads a QR code out of an image file (screenshot, saved image, photo).
/// Returns the decoded text, or null when no QR code could be read.
Future<String?> decodeQrFromImageFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return compute(_decode, bytes);
}

String? _decode(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) return null;
  image = img.bakeOrientation(image);

  // Try the original (capped) size first, then a few scales: very large photos
  // and very small codes both decode more reliably when resized.
  const maxSides = [1400, 800, 500, 2000];
  for (final side in maxSides) {
    final longest = image.width > image.height ? image.width : image.height;
    final scaled = longest > side
        ? img.copyResize(
            image,
            width: image.width >= image.height ? side : null,
            height: image.height > image.width ? side : null,
            interpolation: img.Interpolation.average,
          )
        : image;
    final text = _tryDecode(scaled);
    if (text != null) return text;
  }
  return null;
}

String? _tryDecode(img.Image image) {
  final pixels = Int32List(image.width * image.height);
  var i = 0;
  for (final p in image.convert(numChannels: 4)) {
    pixels[i++] = (p.a.toInt() << 24) |
        (p.r.toInt() << 16) |
        (p.g.toInt() << 8) |
        p.b.toInt();
  }
  final source = RGBLuminanceSource(image.width, image.height, pixels);
  for (final binarizer in [HybridBinarizer(source), GlobalHistogramBinarizer(source)]) {
    try {
      final result = QRCodeReader().decode(
        BinaryBitmap(binarizer),
        hints: DecodeHints()..put(DecodeHintType.tryHarder),
      );
      return result.text;
    } catch (_) {}
  }
  return null;
}
