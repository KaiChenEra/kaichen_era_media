import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../hash/sha256_helper.dart';
import 'webp_hash_strategy.dart';
import 'webp_result.dart';
import 'webp_stages.dart';

/// Run a byte buffer through the canonical lossy-WebP compression
/// ladder. Returns both the output bytes and source/output sha256 in
/// one pass.
///
/// Mirrors lingo's historical `_addBorderToImage` → `_convertToWebp`
/// pipeline and kinjin's `normalizeBytesToStickerWebp`. The temp
/// files are removed before returning.
///
/// Compared to the legacy lingo `StickerMediaPickerService` flow, this
/// helper computes sha256 **after** WebP encoding (output strategy
/// reflects on-disk bytes), fixing the legacy bug where sha256 was
/// taken on the *source* image before compression — making the
/// stored Drift `media.sha256` not match the actual on-disk WebP.
///
/// [hashStrategy] decides whether the returned `fileKey` echoes
/// [MediaWebpResult.input] (source dedup) or [MediaWebpResult.output]
/// (default — accurate to on-disk bytes).
Future<MediaWebpResult> normalizeBytesToWebp(
  Uint8List input, {
  int maxFileBytes = kStickerMaxWebpFileBytes,
  List<({int maxSide, int quality})> stages = kStickerWebpStages,
  WebpHashStrategy hashStrategy = WebpHashStrategy.output,
}) async {
  final inputSha = Sha256Pair.from(input);

  final tmpDir = await getTemporaryDirectory();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final tmpIn = p.join(tmpDir.path, 'media_in_$stamp.png');
  final tmpOut = p.join(tmpDir.path, 'media_out_$stamp.webp');
  await File(tmpIn).writeAsBytes(input, flush: true);

  Uint8List? lastBytes;
  try {
    final totalSw = Stopwatch()..start();
    for (var i = 0; i < stages.length; i++) {
      final stage = stages[i];
      final stepSw = Stopwatch()..start();
      final result = await FlutterImageCompress.compressAndGetFile(
        tmpIn,
        tmpOut,
        format: CompressFormat.webp,
        quality: stage.quality,
        minWidth: stage.maxSide,
        minHeight: stage.maxSide,
      );
      if (result == null) {
        throw StateError('FlutterImageCompress 返回 null (stage ${i + 1})');
      }
      final bytes = await File(result.path).readAsBytes();
      lastBytes = bytes;
      debugPrint(
        '[MediaNormalize] stage${i + 1} side=${stage.maxSide} q=${stage.quality}: '
        '${bytes.length} bytes, ${stepSw.elapsedMilliseconds}ms',
      );
      if (bytes.length <= maxFileBytes) {
        debugPrint(
          '[MediaNormalize] hit budget @stage${i + 1}, '
          'total ${totalSw.elapsedMilliseconds}ms',
        );
        return _build(bytes, inputSha, hashStrategy);
      }
    }
    debugPrint(
      '[MediaNormalize] 终极档(${stages.last.maxSide}px '
      'Q=${stages.last.quality}) 仍 ${lastBytes!.length} bytes > '
      '$maxFileBytes bytes, 保留最后一版.',
    );
    return _build(lastBytes, inputSha, hashStrategy);
  } finally {
    final inFile = File(tmpIn);
    if (await inFile.exists()) {
      await inFile.delete();
    }
    final outFile = File(tmpOut);
    if (await outFile.exists()) {
      await outFile.delete();
    }
  }
}

MediaWebpResult _build(
    Uint8List webpBytes, Sha256Pair inputSha, WebpHashStrategy strategy) {
  final outputSha = Sha256Pair.fromBytes(webpBytes);
  return MediaWebpResult.from(
    bytes: webpBytes,
    input: inputSha,
    output: outputSha,
    strategy: strategy,
  );
}
