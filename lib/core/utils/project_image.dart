import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ProjectImage {
  const ProjectImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  static Future<ProjectImage> prepareAsync(Uint8List sourceBytes) async {
    final bytes = await compute(_prepareBytes, sourceBytes);
    return ProjectImage(
      bytes: bytes,
      fileName: 'chantier-${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  static Uint8List _prepareBytes(Uint8List sourceBytes) {
    if (sourceBytes.length < 12) {
      throw const FormatException(
        'Ce format de photo n’est pas pris en charge. Choisissez un JPEG, PNG ou WebP.',
      );
    }
    img.Image? decoded;
    try {
      decoded = img.decodeImage(sourceBytes);
    } on RangeError {
      throw const FormatException(
        'Ce format de photo n’est pas pris en charge. Choisissez un JPEG, PNG ou WebP.',
      );
    } on img.ImageException {
      throw const FormatException(
        'Ce format de photo n’est pas pris en charge. Choisissez un JPEG, PNG ou WebP.',
      );
    }
    if (decoded == null) {
      throw const FormatException(
        'Ce format de photo n’est pas pris en charge. Choisissez un JPEG, PNG ou WebP.',
      );
    }

    final oriented = img.bakeOrientation(decoded);
    final longestSide = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final resized = longestSide > 1600
        ? img.copyResize(
            oriented,
            width: (oriented.width * 1600 / longestSide).round(),
            height: (oriented.height * 1600 / longestSide).round(),
          )
        : oriented;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 78));
  }
}
