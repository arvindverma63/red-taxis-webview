import 'dart:io';

import 'package:driver_app/features/auth/presentation/widgets/qr_image_decoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

img.Image _qrImage(String text, {int scale = 8, int quiet = 4}) {
  final qr = Encoder.encode(text, ErrorCorrectionLevel.m);
  final m = qr.matrix!;
  final size = (m.width + quiet * 2) * scale;
  final out = img.Image(width: size, height: size);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < m.height; y++) {
    for (var x = 0; x < m.width; x++) {
      if (m.get(x, y) == 1) {
        img.fillRect(out,
            x1: (x + quiet) * scale,
            y1: (y + quiet) * scale,
            x2: (x + quiet + 1) * scale - 1,
            y2: (y + quiet + 1) * scale - 1,
            color: img.ColorRgb8(0, 0, 0));
      }
    }
  }
  return out;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('qr'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('decodes a QR code from a PNG', () async {
    const payload = '{"tenantId":"org_ace_taxis","tenantKey":"rtk_pub_abc"}';
    final f = File('${dir.path}/q.png')..writeAsBytesSync(img.encodePng(_qrImage(payload)));
    expect(await decodeQrFromImageFile(f.path), payload);
  });

  test('decodes a large, screenshot-sized image', () async {
    const payload = 'org_ace_taxis:rtk_pub_abc';
    final qr = _qrImage(payload, scale: 6);
    final canvas = img.Image(width: 1080, height: 2200);
    img.fill(canvas, color: img.ColorRgb8(240, 240, 240));
    img.compositeImage(canvas, qr, dstX: 300, dstY: 700);
    final f = File('${dir.path}/s.jpg')..writeAsBytesSync(img.encodeJpg(canvas));
    expect(await decodeQrFromImageFile(f.path), payload);
  });

  test('returns null when the image has no QR code', () async {
    final blank = img.Image(width: 300, height: 300);
    img.fill(blank, color: img.ColorRgb8(200, 100, 50));
    final f = File('${dir.path}/b.png')..writeAsBytesSync(img.encodePng(blank));
    expect(await decodeQrFromImageFile(f.path), isNull);
  });

  test('returns null for a file that is not an image', () async {
    final f = File('${dir.path}/x.png')..writeAsStringSync('not an image');
    expect(await decodeQrFromImageFile(f.path), isNull);
  });
}
