# PRD: kaichen_era_media — public API contract

> Internal pipeline / algorithms see [ARCH.Media](ARCH.Media.md).

## 1. Scope

A small, host-agnostic Flutter package that owns:

1. **WebP normalization** — turn arbitrary input bytes (PNG / JPEG / HEIC / WebP) into ≤ 40 KB lossy WebP using a deterministic 6-stage ladder.
2. **Image picking** — `image_picker` + optional `image_cropper` wrapping the same WebP ladder.
3. **sha256 hashing** — single-pass dual-format (hex + base64) digest matching every store the consumers care about (Drift `media.sha256` columns use hex; R2 / S3 presign upload bodies use base64).

Intentionally **not** in scope: any sticker / chat / domain semantics. Consumers (sticker_sdk, lingo, kinjin) layer those on top.

## 2. Public surface

### 2.1 `normalizeBytesToWebp`

```dart
Future<MediaWebpResult> normalizeBytesToWebp(
  Uint8List input, {
  int maxFileBytes = kStickerMaxWebpFileBytes,                   // = 40 * 1024
  List<({int maxSide, int quality})> stages = kStickerWebpStages,
  WebpHashStrategy hashStrategy = WebpHashStrategy.output,
});
```

**Inputs**
- `input` — arbitrary image bytes the platform decoder can read (PNG / JPEG / WebP / HEIC). Decoded once and re-encoded to WebP at every stage; large inputs (~4 MP) take 200–400 ms; callers should run this off the UI isolate (via `compute(...)` or in a background helper).
- `maxFileBytes` — first stage whose output ≤ this returns immediately. If every stage overshoots, the most aggressive stage's output is returned (no truncation, no error).
- `stages` — top-down `(maxSide, quality)` ladder. Default tuned for sticker assets:
  - `(512, 90)` → `(512, 80)` → `(480, 70)` → `(384, 55)` → `(320, 40)` → `(256, 30)`.
- `hashStrategy` — see §2.3.

**Output** — `MediaWebpResult` (§2.2).

### 2.2 `MediaWebpResult`

```dart
class MediaWebpResult {
  final Uint8List bytes;          // WebP-encoded output
  final Sha256Pair input;         // sha256 of the *input* bytes
  final Sha256Pair output;        // sha256 of the *output* WebP bytes
  final WebpHashStrategy strategy;
  final Sha256Pair fileKey;       // = output (default) or input, per strategy
}
```

`fileKey` is the convenience field consumers persist as the row's content-address column / file name. Always equals **either** `input` or `output` literally (no third value), so any check against `fileKey.hex == media.sha256` is well-defined.

### 2.3 `WebpHashStrategy`

```dart
enum WebpHashStrategy { input, output }
```

| Strategy | Effect | When to use |
|---|---|---|
| `output` (default) | `fileKey` = sha256 of the encoded WebP bytes | Sticker storage / R2 file_key — matches the on-disk file byte-for-byte. Two re-compressions of the same source at different quality settings yield different keys (genuinely different files). |
| `input` | `fileKey` = sha256 of the source bytes | Source-level dedup (uploading the same logo across multiple destinations only stores one R2 object). Beware: two callers using `input` strategy on the same source may write files of different qualities under one key — only enable when content-by-source identity is what you want. |

This single API field exists because the legacy `StickerMediaPickerService._processAndSaveImage` computed sha256 on **input** bytes before WebP encoding while storing `extension: 'webp'` on the row, leaving `media.sha256` not matching the actual on-disk file. The strategy is now explicit; callers cannot accidentally describe one and store the other.

### 2.4 `Sha256Pair`

```dart
class Sha256Pair {
  final String hex;     // 64-char lowercase, matches `crypto.sha256.convert(b).toString()`
  final String base64;  // standard base64 of the raw 32-byte digest, padded
  factory Sha256Pair.fromBytes(Uint8List bytes);
}
```

Constructed in **one digest pass** so the two strings are guaranteed to describe the same bytes. Both formats co-exist because Drift schemas store hex (`StickerContentMedia.sha256`, `AppContentInstance.sha256`, …) while R2 presigned-URL request bodies + `x-amz-checksum-sha256` headers use base64. Forcing every call site to convert hex↔base64 was error-prone; one missed conversion silently broke deduplication or upload.

Convenience top-levels: `computeSha256Hex(bytes)` / `computeSha256Base64(bytes)` for cases where only one format is needed.

### 2.5 `ImagePickerService`

Singleton (`ImagePickerService()`) — backing `image_picker` + `image_cropper` instances are long-lived to avoid native re-init overhead.

```dart
Future<MediaWebpResult?> pickSingleImageToWebp({
  ImagePickToWebpOptions options = const ImagePickToWebpOptions(),
});

Future<List<MediaWebpResult>> pickMultiImagesToWebp({
  required int maxCount,
  int currentCount = 0,
  ImagePickToWebpOptions options = const ImagePickToWebpOptions(),
});
```

**`ImagePickToWebpOptions`**

```dart
class ImagePickToWebpOptions {
  final ImageSource source;             // gallery / camera
  final MediaCropperOptions? cropper;   // null → no cropper, raw picked image
  final int maxFileBytes;               // = 40 KB by default
  final List<({int maxSide, int quality})> stages;
  final WebpHashStrategy hashStrategy;
}
```

**Cancellation semantics**
- User cancels picker → `pickSingleImageToWebp` returns `null`. Multi-pick returns `[]` (empty).
- User cancels cropper after picking → `null`. Picker tmp file is best-effort cleaned up.
- Multi-pick: a single image's failure doesn't abort the batch; surviving entries are returned and the failure is logged.

**`MediaCropperOptions.cover4x3`** — preset matching sticker section cover layout (4:3 ratio, locked). Other ratios → construct via the constructor.

## 3. Cancellation & error semantics

| Path | Empty-result indicator | Throws |
|---|---|---|
| `normalizeBytesToWebp` | n/a (always returns) | `StateError` if the platform compressor returns null at any stage |
| `pickSingleImageToWebp` | returns `null` on user cancel | propagates platform plugin errors (camera permission denied, etc.) |
| `pickMultiImagesToWebp` | returns `[]` on cancel / max reached | per-image failures are caught + logged; batch survives |

## 4. Defaults and constants

| Constant | Value | Used by |
|---|---|---|
| `kStickerMaxWebpFileBytes` | `40 * 1024` (40 KB) | Default `maxFileBytes` |
| `kStickerWebpStages` | `(512,90) → (512,80) → (480,70) → (384,55) → (320,40) → (256,30)` | Default `stages` |
| `MediaCropperOptions.cover4x3` | 4:3 locked aspect, 4:3 preset | Section cover crop |

## 5. Related docs

- [ARCH.Media](ARCH.Media.md) — implementation, WebP ladder rationale, sha256 timing
- [`kaichen_era_sticker_sdk`](https://github.com/KaiChenEra/kaichen_era_sticker_sdk) — primary consumer (sticker picker and WebP normalization)
- [`lingo_cosmos_app/docs/arch/ARCH.Sticker.SubjectLift.md`](https://github.com/KaiChenEra/lingo_cosmos_app/blob/dev/docs/arch/ARCH.Sticker.SubjectLift.md) — non-sticker_sdk consumer (lingo's display page calls `normalizeBytesToWebp` directly during save)

## 6. Change history

| Date | Change |
|---|---|
| 2026-04-28 | Initial PRD covering 0.1.0 release |
