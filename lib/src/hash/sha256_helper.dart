import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// SHA-256 digest in **both** hex and base64 form, computed from the
/// same byte buffer.
///
/// Why two formats: the on-device Drift schema stores `sha256` as a
/// hex string (`StickerContentMedia.sha256`, `AppContentInstance.sha256`,
/// etc.), while the server-side R2 upload protocol expects
/// `sha256_base64` in the presigned-URL request body and the
/// `x-amz-checksum-sha256` header. Forcing every caller to convert
/// between the two formats is error-prone (one missed conversion
/// silently breaks deduplication or upload).
///
/// Constructing via [Sha256Pair.from] computes both formats from the
/// same digest in one pass, so the two strings are guaranteed to
/// describe the same bytes.
class Sha256Pair {
  /// Lowercase hex string, e.g. `"b406b14e...ab9cc11ab1"` (64 chars).
  final String hex;

  /// Standard base64 (with padding) of the raw 32-byte digest, e.g.
  /// `"tAaxTqLQ9gxOzN1nQvqXdrsFQgnzVH7BR3WAq5zBGrE="`.
  final String base64;

  const Sha256Pair({required this.hex, required this.base64});

  /// Compute both formats from a byte buffer in one pass.
  factory Sha256Pair.from(List<int> bytes) {
    final digest = crypto.sha256.convert(bytes);
    return Sha256Pair(
      hex: digest.toString(),
      base64: base64Encode(digest.bytes),
    );
  }

  /// Same as [Sha256Pair.from] but accepts the typed-data flavor that
  /// the WebP / image pipelines naturally produce.
  factory Sha256Pair.fromBytes(Uint8List bytes) => Sha256Pair.from(bytes);

  @override
  String toString() => 'Sha256Pair(hex=$hex)';

  @override
  bool operator ==(Object other) =>
      other is Sha256Pair && other.hex == hex && other.base64 == base64;

  @override
  int get hashCode => Object.hash(hex, base64);
}

/// Convenience: hex sha256 (matches `crypto.sha256.convert(b).toString()`).
String computeSha256Hex(List<int> bytes) =>
    crypto.sha256.convert(bytes).toString();

/// Convenience: base64 sha256 (raw 32-byte digest, then standard base64).
String computeSha256Base64(List<int> bytes) =>
    base64Encode(crypto.sha256.convert(bytes).bytes);
