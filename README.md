# kaichen_era_media

Shared, host-agnostic image picking, cropping, canonical WebP normalization,
and SHA-256 utilities for KaiChenEra apps.

## Usage

```dart
import 'package:kaichen_era_media/kaichen_era_media.dart';

final result = await ImagePickerService().pickSingleImageToWebp(
  options: const ImagePickToWebpOptions(
    cropper: MediaCropperOptions.cover4x3,
  ),
);
if (result == null) return;

await File('media/${result.sha256.hex}.webp').writeAsBytes(result.bytes);
// result.sha256.hex matches the bytes written above.
// result.sha256.base64 is the matching R2 checksum.
```

## Public API

- `normalizeBytesToWebp(bytes, ...)` returns `MediaWebpResult`.
- `ImagePickerService` supplies single- and multi-image WebP flows.
- `Sha256Pair` exposes one digest as hex and base64.
- `kStickerWebpMaxSide` and `kStickerWebpMaxBytes` define the canonical 512px / 500,000-byte bounds.

## Documentation

- [docs/PRD.Media.md](docs/PRD.Media.md)
- [docs/ARCH.Media.md](docs/ARCH.Media.md)
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md)

## License

Internal; consumed by KaiChenEra projects only.
