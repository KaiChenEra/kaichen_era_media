import 'dart:typed_data';

import '../hash/sha256_helper.dart';
import 'webp_hash_strategy.dart';

/// Full result of running raw bytes through the canonical WebP
/// normalization ladder.
///
/// All four sha256 fields ([input], [output], plus [fileKey] which
/// echoes one of them) are computed off the same byte buffers in one
/// pass — there's no risk of hex/base64 drifting from the bytes they
/// describe.
class MediaWebpResult {
  /// The WebP-encoded output bytes (≤ `maxFileBytes` if any stage
  /// hit budget; otherwise the most aggressive stage's output).
  final Uint8List bytes;

  /// sha256 of the **input** bytes the caller passed in.
  final Sha256Pair input;

  /// sha256 of the **output** WebP bytes (i.e. the bytes that will be
  /// written to disk).
  final Sha256Pair output;

  /// Which strategy was requested.
  final WebpHashStrategy strategy;

  /// Echoes either [input] or [output] depending on [strategy]. Use
  /// `.hex` to populate Drift `media.sha256`-style columns and
  /// `.base64` for R2 presign / `x-amz-checksum-sha256` headers.
  final Sha256Pair fileKey;

  const MediaWebpResult({
    required this.bytes,
    required this.input,
    required this.output,
    required this.strategy,
    required this.fileKey,
  });

  /// Build a result with [fileKey] resolved from [strategy].
  factory MediaWebpResult.from({
    required Uint8List bytes,
    required Sha256Pair input,
    required Sha256Pair output,
    required WebpHashStrategy strategy,
  }) {
    return MediaWebpResult(
      bytes: bytes,
      input: input,
      output: output,
      strategy: strategy,
      fileKey: strategy == WebpHashStrategy.input ? input : output,
    );
  }

  @override
  String toString() => 'MediaWebpResult(${bytes.length} bytes, '
      'strategy=$strategy, fileKey=${fileKey.hex.substring(0, 8)}...)';
}
