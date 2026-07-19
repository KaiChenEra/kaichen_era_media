/// Public barrel for the KaiChenEra shared media package.
///
/// What lives here:
///
/// - **WebP normalisation**: lossless WebP bounded to 512px and 500,000 bytes,
///   `normalizeBytesToWebp(bytes)`, returning final WebP bytes and the sha256
///   of those exact bytes.
/// - **Image picker**: `ImagePickerService.pickSingleImageToWebp` /
///   `pickMultiImagesToWebp` — `image_picker` + `image_cropper` +
///   WebP normalization, returning `MediaWebpResult` with no database or sticker
///   persistence concerns.
/// - **Hashing**: `Sha256Pair` (hex + base64 from one digest pass),
///   plus `computeSha256Hex` / `computeSha256Base64` shorthands.
///
/// What does **not** live here:
///   - sticker-specific orchestration such as rows, sections, or borders.
///   - AI subject lift — `kaichen_era_sticker_ai`.
library;

export 'src/webp/webp_normalizer.dart'
    show kStickerWebpMaxBytes, kStickerWebpMaxSide, normalizeBytesToWebp;
export 'src/webp/webp_result.dart';

export 'src/hash/sha256_helper.dart';

export 'src/picker/image_picker_options.dart';
export 'src/picker/image_picker_service.dart' show ImagePickerService;
