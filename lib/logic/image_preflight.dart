class ImageQualityResult {
  final bool isAcceptable;
  final String? warningMessage;

  const ImageQualityResult({
    required this.isAcceptable,
    this.warningMessage,
  });
}

class ImagePreflight {
  /// Minimum file size in bytes (e.g. 5 KB) to consider an image non-empty.
  static const int minSizeBytes = 5 * 1024;

  /// Target maximum dimension for client-side pre-processing.
  static const int maxDimensionPx = 1600;

  /// Evaluates whether an image file has sufficient size and characteristics.
  static ImageQualityResult evaluate({
    required int fileSizeBytes,
    int? width,
    int? height,
  }) {
    if (fileSizeBytes < minSizeBytes) {
      return const ImageQualityResult(
        isAcceptable: false,
        warningMessage:
            'The selected image is very small or empty. Please capture a clear photo of the prescription.',
      );
    }

    if (width != null && height != null) {
      if (width < 300 || height < 300) {
        return ImageQualityResult(
          isAcceptable: true,
          warningMessage:
              'The image resolution is low (${width}x${height}px). Details might be hard to read.',
        );
      }
    }

    return const ImageQualityResult(isAcceptable: true);
  }
}
