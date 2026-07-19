import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'webp_result.dart';

const int kStickerWebpMaxSide = 512;
const int kStickerWebpMaxBytes = 500000;

/// Encode one lossless WebP that fits the sticker pixel and byte limits.
Future<MediaWebpResult> normalizeBytesToWebp(
  Uint8List input, {
  int maxSide = kStickerWebpMaxSide,
  int maxBytes = kStickerWebpMaxBytes,
}) async {
  if (input.isEmpty) throw ArgumentError.value(input, 'input', 'is empty');
  if (maxSide < 1) throw RangeError.range(maxSide, 1, null, 'maxSide');
  if (maxBytes < 1) throw RangeError.range(maxBytes, 1, null, 'maxBytes');
  final bytes = await compute(
    _encodeWebp,
    (input: input, maxSide: maxSide, maxBytes: maxBytes),
  );
  return MediaWebpResult.fromBytes(bytes);
}

Uint8List _encodeWebp(
  ({Uint8List input, int maxSide, int maxBytes}) args,
) {
  final decoded = img.decodeImage(args.input);
  if (decoded == null) {
    throw StateError('WebP normalization source decode failed');
  }
  final longest =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  var targetSide = math.min(longest, args.maxSide);
  while (true) {
    final sized = targetSide == longest
        ? decoded
        : decoded.width >= decoded.height
            ? img.copyResize(
                decoded,
                width: targetSide,
                interpolation: img.Interpolation.cubic,
              )
            : img.copyResize(
                decoded,
                height: targetSide,
                interpolation: img.Interpolation.cubic,
              );
    final encoded = img.encodeWebP(sized);
    if (encoded.length <= args.maxBytes) return encoded;
    if (targetSide == 1) {
      throw StateError('WebP cannot fit the requested byte limit');
    }

    final estimated =
        (targetSide * math.sqrt(args.maxBytes / encoded.length) * 0.98).floor();
    targetSide = math.max(1, math.min(targetSide - 1, estimated));
  }
}
