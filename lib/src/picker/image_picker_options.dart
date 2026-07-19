import 'package:flutter/cupertino.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../webp/webp_normalizer.dart';

/// Options for cropping a picked image before WebP normalization.
class MediaCropperOptions {
  /// Aspect ratio enforced by the cropper. Null = free-form.
  final CropAspectRatio? aspectRatio;

  /// Toolbar / control colors. Cupertino-friendly defaults.
  final Color toolbarColor;
  final Color toolbarTextColor;
  final Color activeControlsColor;

  /// Title shown atop the cropper sheet.
  final String title;

  /// Initial preset; inferred from [aspectRatio] when null.
  final CropAspectRatioPreset? initialPreset;

  /// Lock the aspect ratio (true ⇔ aspect ratio fixed by [aspectRatio]).
  final bool lockAspectRatio;

  const MediaCropperOptions({
    this.aspectRatio,
    this.toolbarColor = const Color(0xFF007AFF),
    this.toolbarTextColor = CupertinoColors.white,
    this.activeControlsColor = const Color(0xFF007AFF),
    this.title = '裁剪图片',
    this.initialPreset,
    this.lockAspectRatio = true,
  });

  /// 4:3 cover preset (matches sticker section cover layout 32x≈42.67 / 64x48 /
  /// 200x150). Used by [ImagePickerService.pickSingleImageToWebp] when the
  /// caller wants a section-cover-style cropper.
  static const MediaCropperOptions cover4x3 = MediaCropperOptions(
    aspectRatio: CropAspectRatio(ratioX: 4, ratioY: 3),
    initialPreset: CropAspectRatioPreset.ratio4x3,
    title: '裁剪封面',
  );

  static const MediaCropperOptions landscape4x3 = MediaCropperOptions(
    aspectRatio: CropAspectRatio(ratioX: 4, ratioY: 3),
    initialPreset: CropAspectRatioPreset.ratio4x3,
  );

  static const MediaCropperOptions square = MediaCropperOptions(
    aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
    initialPreset: CropAspectRatioPreset.square,
  );

  static const MediaCropperOptions portrait4x5 = MediaCropperOptions(
    aspectRatio: CropAspectRatio(ratioX: 4, ratioY: 5),
  );

  static const MediaCropperOptions portrait3x4 = MediaCropperOptions(
    aspectRatio: CropAspectRatio(ratioX: 3, ratioY: 4),
  );

  static const MediaCropperOptions portrait9x16 = MediaCropperOptions(
    aspectRatio: CropAspectRatio(ratioX: 9, ratioY: 16),
  );

  static const MediaCropperOptions landscape16x9 = MediaCropperOptions(
    aspectRatio: CropAspectRatio(ratioX: 16, ratioY: 9),
    initialPreset: CropAspectRatioPreset.ratio16x9,
  );
}

/// Options for the full pick, optional crop, and WebP normalization pipeline.
class ImagePickToWebpOptions {
  /// Where to source the image: `gallery` or `camera`.
  final ImageSource source;

  /// Cropper options. Null = no cropper (caller gets raw picked image
  /// straight into WebP normalization).
  final MediaCropperOptions? cropper;

  /// Maximum output edge. Aspect ratio is preserved.
  final int maxSide;

  const ImagePickToWebpOptions({
    this.source = ImageSource.gallery,
    this.cropper,
    this.maxSide = kStickerWebpMaxSide,
  });
}
