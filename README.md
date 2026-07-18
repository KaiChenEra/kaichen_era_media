# kaichen_era_media

Shared media utilities for KaiChenEra apps — image picker + cropper, canonical 40 KB WebP normalization with 6-stage compression ladder, and dual-format (hex + base64) sha256 hashing.

Designed to be **host-agnostic**: lingo_cosmos and kinjin_sticker both depend on this package via their respective sticker integrations; new hosts can drop it in directly.

## Usage

```dart
import 'package:kaichen_era_media/kaichen_era_media.dart';

// Pick + crop a section cover (4:3) and run through the WebP ladder.
final result = await ImagePickerService().pickSingleImageToWebp(
  options: ImagePickToWebpOptions(
    cropper: MediaCropperOptions.cover4x3,
    hashStrategy: WebpHashStrategy.output, // sha256 reflects on-disk bytes
  ),
);
if (result == null) return; // user cancelled

await File('media/${result.fileKey.hex}.webp').writeAsBytes(result.bytes);
// result.fileKey.hex   → matches Drift `media.sha256` columns
// result.fileKey.base64 → matches R2 `sha256_base64` upload header
```

## Public API surface

- `normalizeBytesToWebp(bytes, ...)` → `MediaWebpResult`
- `ImagePickerService.pickSingleImageToWebp` / `pickMultiImagesToWebp`
- `Sha256Pair` (hex + base64 in one digest pass) + `computeSha256Hex` / `computeSha256Base64` shorthands
- Constants: `kStickerWebpStages` (the 6-tier ladder) / `kStickerMaxWebpFileBytes` (40 KB)

## Documentation

- [docs/PRD.Media.md](docs/PRD.Media.md) — API contract (input / output / strategy semantics)
- [docs/ARCH.Media.md](docs/ARCH.Media.md) — internal pipeline (WebP ladder algorithm, sha256 timing rationale, picker→ladder data flow)
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md) — doc taxonomy + PR workflow

## License

Internal; consumed by KaiChenEra projects only.
