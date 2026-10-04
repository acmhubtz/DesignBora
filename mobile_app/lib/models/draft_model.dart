class ArchiveEntry {
  final String name;
  final int size;

  ArchiveEntry({required this.name, required this.size});

  factory ArchiveEntry.fromJson(Map<String, dynamic> json) {
    return ArchiveEntry(
      name: json['name']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class DraftModel {
  /// Aina ambazo backend inazitengenezea preview yenye watermark
  static const previewableExtensions = {
    'jpg',
    'jpeg',
    'png',
    'pdf',
    'psd',
    'ai',
    'eps',
    'svg',
    'tif',
    'tiff',
    'gif',
    'webp',
    'bmp',
    'heic',
    'doc',
    'docx',
    'odt',
    'rtf',
    'txt',
    'xls',
    'xlsx',
    'ods',
    'ppt',
    'pptx',
    'odp',
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
    '3gp',
    'zip',
  };

  final int id;
  final int versionNo;
  final String watermarkedFileUrl; // URL ya preview; "" kama haina
  final String status;
  final String fileType; // IMAGE | PDF | VIDEO | ARCHIVE | OTHER
  final String extension; // aina ya faili la asili
  final int? fileSize;
  final String? submittedAt;
  final List<ArchiveEntry> archiveEntries;

  DraftModel({
    required this.id,
    required this.versionNo,
    required this.watermarkedFileUrl,
    required this.status,
    required this.fileType,
    required this.extension,
    this.fileSize,
    this.submittedAt,
    this.archiveEntries = const [],
  });

  bool get isImage => fileType == 'IMAGE';
  bool get isPdf => fileType == 'PDF';
  bool get isVideo => fileType == 'VIDEO';
  bool get isArchive => fileType == 'ARCHIVE';
  bool get hasPreview =>
      watermarkedFileUrl.isNotEmpty && (isImage || isPdf || isVideo);

  String get typeLabel => extension.isEmpty ? 'FAILI' : extension.toUpperCase();

  String get detailsLabel {
    final size = formatFileSize(fileSize);
    return size == null ? typeLabel : '$typeLabel • $size';
  }

  factory DraftModel.fromJson(Map<String, dynamic> json) {
    final entries = json['archiveEntries'];
    return DraftModel(
      id: json['id'],
      versionNo: json['versionNo'],
      watermarkedFileUrl: json['watermarkedFileUrl'] ?? '',
      status: json['status'] ?? '',
      fileType: json['fileType'] ?? 'IMAGE',
      extension: json['extension'] ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt(),
      submittedAt: json['submittedAt']?.toString(),
      archiveEntries: entries is List
          ? entries
                .whereType<Map<String, dynamic>>()
                .map(ArchiveEntry.fromJson)
                .toList()
          : const [],
    );
  }
}

String? formatFileSize(int? bytes) {
  if (bytes == null) return null;
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
