import 'dart:typed_data';

import '../hash/sha256_helper.dart';

/// Canonical WebP bytes and their content hash.
class MediaWebpResult {
  /// The WebP-encoded output bytes.
  final Uint8List bytes;

  /// sha256 of [bytes]. Use `.hex` for the media id/file name and `.base64`
  /// for the R2 checksum header.
  final Sha256Pair sha256;

  const MediaWebpResult({required this.bytes, required this.sha256});

  factory MediaWebpResult.fromBytes(Uint8List bytes) =>
      MediaWebpResult(bytes: bytes, sha256: Sha256Pair.fromBytes(bytes));

  @override
  String toString() =>
      'MediaWebpResult(${bytes.length} bytes, ${sha256.hex.substring(0, 8)}...)';
}
