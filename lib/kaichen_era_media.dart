/// Public barrel for the KaiChenEra shared media package.
///
/// What lives here:
///
/// - **WebP normalisation**: a single canonical lossy-WebP
///   compression ladder (`kStickerWebpStages` = 512→256 px, Q90→Q30)
///   plus `normalizeBytesToWebp(bytes)` which runs the ladder and
///   returns the WebP bytes alongside both source and output sha256
///   in hex+base64 (`MediaWebpResult`).
/// - **Image picker**: `ImagePickerService.pickSingleImageToWebp` /
///   `pickMultiImagesToWebp` — `image_picker` + `image_cropper` +
///   the WebP ladder, returning `MediaWebpResult` with no DB / repo
///   / sticker concerns.
/// - **Hashing**: `Sha256Pair` (hex + base64 from one digest pass),
///   plus `computeSha256Hex` / `computeSha256Base64` shorthands.
/// - **Caching**: `MediaCacheService` (concurrent-safe URL → local
///   file cache) and `ImageWithCache` (Flutter `ImageProvider` that
///   prefers the local file but falls back to network with a
///   background fetch).
///
/// What does **not** live here:
///   - sticker-specific orchestration (writing media rows, picking
///     section ids, applying the white border) — that's
///     `kaichen_era_sticker_sdk`'s job.
///   - AI subject lift — `kaichen_era_sticker_ai`.
library;

export 'src/webp/webp_hash_strategy.dart';
export 'src/webp/webp_normalizer.dart' show normalizeBytesToWebp;
export 'src/webp/webp_result.dart';
export 'src/webp/webp_stages.dart';

export 'src/hash/sha256_helper.dart';

export 'src/picker/image_picker_options.dart';
export 'src/picker/image_picker_service.dart' show ImagePickerService;

export 'src/cache/media_cache_service.dart' show MediaCacheService;
export 'src/cache/image_with_cache.dart' show ImageWithCache;
