import 'dart:typed_data';

/// Validator and utility for learning material files and uploads.
class MaterialFileValidator {
  static const int maxFileSizeBytes = 3145728; // Strict 3 MB limit (3 * 1024 * 1024)
  static const int maxFileNameLength = 100;

  // Allowed file extensions
  static const Set<String> allowedExtensions = {
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
  };

  // MIME types for allowed formats + rich text/embed
  static const String mimePdf = 'application/pdf';
  static const String mimeDoc = 'application/msword';
  static const String mimeDocx =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  static const String mimePpt = 'application/vnd.ms-powerpoint';
  static const String mimePptx =
      'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  static const String mimeMarkdown = 'text/markdown';
  static const String mimeUriList = 'text/uri-list';

  /// Magic byte signatures:
  /// PDF: %PDF- -> 0x25, 0x50, 0x44, 0x46, 0x2D
  static const List<int> magicPdf = [0x25, 0x50, 0x44, 0x46, 0x2D];

  /// OLE2 (Compound File Binary Format used by .doc and .ppt): 0xD0, 0xCF, 0x11, 0xE0
  static const List<int> magicOle2 = [0xD0, 0xCF, 0x11, 0xE0];

  /// PK/ZIP (used by .docx and .pptx): 0x50, 0x4B, 0x03, 0x04
  static const List<int> magicZip = [0x50, 0x4B, 0x03, 0x04];

  /// Sanitize display filename: strip control characters, restrict to safe chars, truncate to 100 chars
  static String sanitizeFileName(String name) {
    var clean = name.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (clean.isEmpty) clean = 'Document';

    // Keep extension if possible when truncating
    if (clean.length > maxFileNameLength) {
      final dotIndex = clean.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex > clean.length - 10) {
        final ext = clean.substring(dotIndex);
        final base = clean.substring(0, maxFileNameLength - ext.length);
        clean = '$base$ext';
      } else {
        clean = clean.substring(0, maxFileNameLength);
      }
    }
    return clean;
  }

  /// Validates file extension, size, and magic bytes.
  /// Returns null if valid; returns an error string if invalid.
  static String? validateFile({
    required String fileName,
    required Uint8List fileBytes,
    required int byteSize,
  }) {
    // 1. Size check
    if (byteSize > maxFileSizeBytes || fileBytes.length > maxFileSizeBytes) {
      return 'File size exceeds the 3 MB (3,145,728 bytes) limit.';
    }

    if (byteSize == 0 || fileBytes.isEmpty) {
      return 'The selected file is empty (0 bytes).';
    }

    // 2. Extension check
    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx == -1 || dotIdx == fileName.length - 1) {
      return 'Unsupported file format. Only PDF, DOC, DOCX, PPT, and PPTX files are allowed.';
    }

    final ext = fileName.substring(dotIdx + 1).toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      return 'Unsupported file format. Only PDF, DOC, DOCX, PPT, and PPTX files are allowed.';
    }

    // 3. Magic-byte verification
    if (ext == 'pdf') {
      if (!_matchesBytes(fileBytes, magicPdf)) {
        return 'Corrupted or invalid PDF file. Header verification failed.';
      }
    } else if (ext == 'doc' || ext == 'ppt') {
      if (!_matchesBytes(fileBytes, magicOle2)) {
        return 'Corrupted or invalid legacy Office (${ext.toUpperCase()}) file. Header verification failed.';
      }
    } else if (ext == 'docx' || ext == 'pptx') {
      if (!_matchesBytes(fileBytes, magicZip)) {
        return 'Corrupted or invalid Office XML (${ext.toUpperCase()}) file. Header verification failed.';
      }
    }

    return null;
  }

  /// Determines MIME type from extension or special indicators
  static String getMimeType(String fileName, {bool isEmbed = false, bool isMarkdown = false}) {
    if (isEmbed) return mimeUriList;
    if (isMarkdown) return mimeMarkdown;

    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx == -1) return 'application/octet-stream';
    final ext = fileName.substring(dotIdx + 1).toLowerCase();

    switch (ext) {
      case 'pdf':
        return mimePdf;
      case 'doc':
        return mimeDoc;
      case 'docx':
        return mimeDocx;
      case 'ppt':
        return mimePpt;
      case 'pptx':
        return mimePptx;
      default:
        return 'application/octet-stream';
    }
  }

  /// Generates a fast, deterministic content fingerprint (64-bit FNV-1a hex)
  /// for deduplicated storage keys.
  static String computeContentFingerprint(Uint8List bytes) {
    // 64-bit FNV-1a hash implementation
    BigInt hash = BigInt.parse('14695981039346656037');
    final BigInt prime = BigInt.parse('1099511628211');
    final BigInt mask64 = BigInt.parse('18446744073709551615');

    // Sample head, mid, tail or entire file if <= 64KB for speed while remaining accurate
    final int step = bytes.length > 65536 ? (bytes.length ~/ 65536) : 1;
    for (int i = 0; i < bytes.length; i += step) {
      hash = hash ^ BigInt.from(bytes[i]);
      hash = (hash * prime) & mask64;
    }
    // Also include byte length in the hash to prevent length collisions
    hash = (hash ^ BigInt.from(bytes.length)) & mask64;
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Build collision-free, deterministic Supabase Storage key:
  /// `offerings/shared/<fingerprint>_<safeExt>`
  static String buildStorageKey({
    required Uint8List bytes,
    required String originalFileName,
  }) {
    final fingerprint = computeContentFingerprint(bytes);
    final dotIdx = originalFileName.lastIndexOf('.');
    final ext = dotIdx != -1 ? originalFileName.substring(dotIdx + 1).toLowerCase() : 'bin';
    return 'offerings/shared/${fingerprint}_$ext';
  }

  static bool _matchesBytes(Uint8List bytes, List<int> expected) {
    if (bytes.length < expected.length) return false;
    for (int i = 0; i < expected.length; i++) {
      if (bytes[i] != expected[i]) return false;
    }
    return true;
  }
}

class ClassRealmFolder {
  final String id;
  final String subjectOfferingId;
  final String? parentFolderId;
  final String folderName;
  final bool isArchived;
  final bool isVisibleToStudents;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int fileCount;

  ClassRealmFolder({
    required this.id,
    required this.subjectOfferingId,
    this.parentFolderId,
    required this.folderName,
    this.isArchived = false,
    this.isVisibleToStudents = true,
    required this.createdAt,
    this.updatedAt,
    this.fileCount = 0,
  });

  factory ClassRealmFolder.fromMap(Map<String, dynamic> map, {int count = 0}) {
    return ClassRealmFolder(
      id: map['id']?.toString() ?? '',
      subjectOfferingId: map['subject_offering_id']?.toString() ?? '',
      parentFolderId: map['parent_folder_id']?.toString(),
      folderName: map['folder_name']?.toString() ?? 'Untitled Folder',
      isArchived: map['is_archived'] == true,
      isVisibleToStudents: map['is_visible_to_students'] ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      fileCount: count,
    );
  }

  ClassRealmFolder copyWith({
    String? folderName,
    bool? isVisibleToStudents,
    bool? isArchived,
    int? fileCount,
    DateTime? updatedAt,
  }) {
    return ClassRealmFolder(
      id: id,
      subjectOfferingId: subjectOfferingId,
      parentFolderId: parentFolderId,
      folderName: folderName ?? this.folderName,
      isArchived: isArchived ?? this.isArchived,
      isVisibleToStudents: isVisibleToStudents ?? this.isVisibleToStudents,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fileCount: fileCount ?? this.fileCount,
    );
  }
}

class ClassRealmMaterial {
  final String id;
  final String folderId;
  final String fileName;
  final String storagePathUrl;
  final String? mimeType;
  final int fileSizeBytes;
  final bool isArchived;
  final bool isVisibleToStudents;
  final String? title;
  final String? description;
  final DateTime? availableFrom;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ClassRealmMaterial({
    required this.id,
    required this.folderId,
    required this.fileName,
    required this.storagePathUrl,
    this.mimeType,
    required this.fileSizeBytes,
    this.isArchived = false,
    this.isVisibleToStudents = true,
    this.title,
    this.description,
    this.availableFrom,
    required this.createdAt,
    this.updatedAt,
  });

  factory ClassRealmMaterial.fromMap(Map<String, dynamic> map) {
    return ClassRealmMaterial(
      id: map['id']?.toString() ?? '',
      folderId: map['folder_id']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? 'Unnamed Document',
      storagePathUrl: map['storage_path_url']?.toString() ?? '',
      mimeType: map['mime_type']?.toString(),
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      isArchived: map['is_archived'] == true,
      isVisibleToStudents: map['is_visible_to_students'] ?? true,
      title: map['title']?.toString(),
      description: map['description']?.toString(),
      availableFrom: map['available_from'] != null
          ? DateTime.tryParse(map['available_from'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  String get displayName =>
      (title != null && title!.trim().isNotEmpty) ? title! : fileName;

  String get fileExtension {
    if (isRichTextLesson) return 'LESSON';
    if (isEmbedUrl) return 'LINK';
    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < fileName.length - 1) {
      return fileName.substring(dotIdx + 1).toUpperCase();
    }
    return 'FILE';
  }

  bool get isPdf => fileExtension == 'PDF' || mimeType == MaterialFileValidator.mimePdf;
  bool get isWord =>
      ['DOC', 'DOCX'].contains(fileExtension) ||
      mimeType == MaterialFileValidator.mimeDoc ||
      mimeType == MaterialFileValidator.mimeDocx;
  bool get isPresentation =>
      ['PPT', 'PPTX'].contains(fileExtension) ||
      mimeType == MaterialFileValidator.mimePpt ||
      mimeType == MaterialFileValidator.mimePptx;

  bool get isRichTextLesson => mimeType == MaterialFileValidator.mimeMarkdown;
  bool get isEmbedUrl => mimeType == MaterialFileValidator.mimeUriList;
  bool get isLessonModule => isRichTextLesson || isEmbedUrl;

  String get formattedSize {
    if (isLessonModule || fileSizeBytes == 0) {
      return '0 B (Cloud-Free)';
    }
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  ClassRealmMaterial copyWith({
    String? folderId,
    String? fileName,
    String? storagePathUrl,
    String? mimeType,
    int? fileSizeBytes,
    bool? isArchived,
    bool? isVisibleToStudents,
    String? title,
    String? description,
    DateTime? availableFrom,
    DateTime? updatedAt,
  }) {
    return ClassRealmMaterial(
      id: id,
      folderId: folderId ?? this.folderId,
      fileName: fileName ?? this.fileName,
      storagePathUrl: storagePathUrl ?? this.storagePathUrl,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isArchived: isArchived ?? this.isArchived,
      isVisibleToStudents: isVisibleToStudents ?? this.isVisibleToStudents,
      title: title ?? this.title,
      description: description ?? this.description,
      availableFrom: availableFrom ?? this.availableFrom,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract class LearningMaterialRepository {
  Future<List<ClassRealmFolder>> getFolders({
    required String subjectOfferingId,
    String? parentFolderId,
  });

  Future<ClassRealmFolder> createFolder({
    required String subjectOfferingId,
    required String folderName,
    String? parentFolderId,
    bool isVisibleToStudents = true,
  });

  Future<void> updateFolder({
    required String folderId,
    String? folderName,
    bool? isVisibleToStudents,
  });

  Future<void> deleteFolder(String folderId);

  Future<void> archiveFolder(String folderId);

  Future<void> restoreFolder(String folderId);

  Future<List<ClassRealmFolder>> getArchivedFolders(String subjectOfferingId);

  Future<List<ClassRealmMaterial>> getMaterials({
    required String folderId,
    bool studentOnly = false,
  });

  Future<ClassRealmMaterial> uploadMaterial({
    required String folderId,
    required String subjectOfferingId,
    required String fileName,
    required Uint8List fileBytes,
    required int fileSizeBytes,
    String? mimeType,
    String? title,
    String? description,
    bool isVisibleToStudents = true,
  });

  Future<void> toggleMaterialVisibility({
    required String materialId,
    required bool isVisible,
  });

  Future<void> deleteMaterial(String materialId, String storagePathUrl);

  Future<void> archiveMaterial(String materialId);

  Future<void> restoreMaterial(String materialId);

  Future<List<ClassRealmMaterial>> getArchivedMaterials(String subjectOfferingId);

  Future<void> duplicateMaterialToOfferings({
    required ClassRealmMaterial material,
    required List<String> targetOfferingIds,
    required String targetFolderName,
  });

  Future<void> ensureDefaultTermFolders(String subjectOfferingId);

  // --- Extended Methods for Storage Deduplication & In-App Management ---

  /// Uploads the physical file only once to Supabase Storage and creates
  /// materials in multiple offerings' folders referencing the exact same storage URL.
  Future<List<ClassRealmMaterial>> uploadDeduplicatedMaterial({
    required String primaryFolderId,
    required String primaryOfferingId,
    required String fileName,
    required Uint8List fileBytes,
    required int fileSizeBytes,
    String? mimeType,
    String? title,
    String? description,
    bool isVisibleToStudents = true,
    required List<String> additionalOfferingIds,
    required String targetFolderName,
  });

  /// Deletes a material row with reference counting.
  /// If other rows in public.learning_materials still reference `storagePathUrl`,
  /// only this material's DB row is removed, preserving the physical storage file.
  Future<void> deleteMaterialReferenceCounted({
    required String materialId,
    required String storagePathUrl,
  });

  /// Replaces the file of a learning material.
  /// If `updateAllSharedSections == true`, updates all materials sharing the current storage URL.
  /// If `updateAllSharedSections == false`, updates only this material row with the new storage URL.
  Future<ClassRealmMaterial> replaceMaterialFile({
    required String materialId,
    required String currentStoragePathUrl,
    required String newFileName,
    required Uint8List newFileBytes,
    required int newFileSizeBytes,
    required String mimeType,
    required bool updateAllSharedSections,
  });

  /// Updates metadata and lesson notes on the fly (title, description, folder, visibility)
  Future<ClassRealmMaterial> updateMaterialDetails({
    required String materialId,
    String? title,
    String? description,
    String? folderId,
    bool? isVisibleToStudents,
  });

  /// Returns learning materials for a student verifying:
  /// 1. Material is_visible_to_students == true and is_archived == false
  /// 2. Every ancestor folder is_visible_to_students == true and is_archived == false
  /// 3. available_from <= serverUtcTime (if available_from is set)
  Future<List<ClassRealmMaterial>> getStudentMaterialsWithHierarchy({
    required String subjectOfferingId,
    String? folderId,
    DateTime? serverTime,
  });

  /// Fetches Supabase server time in UTC to avoid trusting student device clocks.
  Future<DateTime> getServerUtcTime();
}

