import 'dart:typed_data';

import 'package:apptest/core/utils/project_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('normalizes and resizes a selected photo for upload', () async {
    final source = img.Image(width: 2400, height: 1200);
    img.fill(source, color: img.ColorRgb8(180, 120, 60));

    final prepared = await ProjectImage.prepareAsync(
      Uint8List.fromList(img.encodePng(source)),
    );
    final decoded = img.decodeJpg(prepared.bytes);

    expect(prepared.fileName, endsWith('.jpg'));
    expect(prepared.bytes.sublist(0, 3), [0xff, 0xd8, 0xff]);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1600);
    expect(decoded.height, 800);
  });

  test('rejects data that is not a supported image', () async {
    await expectLater(
      ProjectImage.prepareAsync(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<FormatException>()),
    );
  });
}
