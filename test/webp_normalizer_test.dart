import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kaichen_era_media/kaichen_era_media.dart';

void main() {
  test('desktop normalization returns real WebP with alpha', () async {
    final source = img.Image(width: 48, height: 24, numChannels: 4)
      ..clear(img.ColorRgba8(0, 0, 0, 0));
    for (var y = 4; y < 20; y++) {
      for (var x = 8; x < 40; x++) {
        source.setPixelRgba(x, y, 240, 80, 120, 255);
      }
    }

    final result = await normalizeBytesToWebp(
      Uint8List.fromList(img.encodePng(source)),
      maxSide: 32,
    );

    expect(ascii.decode(result.bytes.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(result.bytes.sublist(8, 12)), 'WEBP');
    final decoded = img.decodeWebP(result.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 32);
    expect(decoded.height, 16);
    expect(decoded.getPixel(0, 0).a, 0);
  });

  test('finalized sticker stays lossless without a 40KB quality cap', () async {
    final source = img.Image(width: 512, height: 256, numChannels: 4);
    var noise = 0x12345678;
    int nextByte() {
      noise ^= (noise << 13) & 0xffffffff;
      noise ^= noise >> 17;
      noise ^= (noise << 5) & 0xffffffff;
      noise &= 0xffffffff;
      return noise >> 24;
    }

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(
          x,
          y,
          nextByte(),
          nextByte(),
          nextByte(),
          255,
        );
      }
    }

    final result = await normalizeBytesToWebp(
      Uint8List.fromList(img.encodePng(source)),
    );
    final decoded = img.decodeWebP(result.bytes)!;

    expect(result.bytes.length, greaterThan(40 * 1024));
    expect((decoded.width, decoded.height), (512, 256));
    for (final point in [(0, 0), (137, 59), (511, 255)]) {
      final expected = source.getPixel(point.$1, point.$2);
      final actual = decoded.getPixel(point.$1, point.$2);
      expect(
        (actual.r, actual.g, actual.b, actual.a),
        (expected.r, expected.g, expected.b, expected.a),
      );
    }
  });

  test('high-entropy sticker uses lossless WebP under 500 KB', () async {
    final source = img.Image(width: 512, height: 512, numChannels: 4);
    var noise = 0x87654321;
    int nextByte() {
      noise ^= (noise << 13) & 0xffffffff;
      noise ^= noise >> 17;
      noise ^= (noise << 5) & 0xffffffff;
      noise &= 0xffffffff;
      return noise >> 24;
    }

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(
          x,
          y,
          nextByte(),
          nextByte(),
          nextByte(),
          255,
        );
      }
    }

    final result = await normalizeBytesToWebp(
      Uint8List.fromList(img.encodePng(source)),
    );
    final decoded = img.decodeWebP(result.bytes)!;

    expect(result.bytes.length, lessThanOrEqualTo(kStickerWebpMaxBytes));
    expect(decoded.width, lessThan(512));
    expect(decoded.width, decoded.height);
  });
}
