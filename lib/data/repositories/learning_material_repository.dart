import 'dart:typed_data';

class ClassRealmFolder {
  final String id;
  final String subjectOfferingId;
  final String? parentFolderId;
  final String folderName;
  final bool isArchived;
  final bool isVisibleToStudents;
  final DateTime createdAt;
  final int fileCount;

  ClassRealmFolder({
    required this.id,
    required this.subjectOfferingId,
    this.parentFolderId,
    required this.folderName,
    this.isArchived = false,
    this.isVisibleToStudents = true,
    required this.createdAt,
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
      fileCount: count,
    );
  }

  ClassRealmFolder copyWith({
    String? folderName,
    bool? isVisibleToStudents,
    int? fileCount,
  }) {
    return ClassRealmFolder(
      id: id,
      subjectOfferingId: subjectOfferingId,
      parentFolderId: parentFolderId,
      folderName: folderName ?? this.folderName,
      isArchived: isArchived,
      isVisibleToStudents: isVisibleToStudents ?? this.isVisibleToStudents,
      createdAt: createdAt,
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
  final DateTime createdAt;

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
    required this.createdAt,
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
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get displayName => (title != null && title!.trim().isNotEmpty) ? title! : fileName;

  String get fileExtension {
    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < fileName.length - 1) {
      return fileName.substring(dotIdx + 1).toUpperCase();
    }
    return 'FILE';
  }

  bool get isPdf => fileExtension == 'PDF';
  bool get isWord => ['DOC', 'DOCX'].contains(fileExtension);
  bool get isPresentation => ['PPT', 'PPTX'].contains(fileExtension);
  bool get isSpreadsheet => ['XLS', 'XLSX', 'CSV'].contains(fileExtension);

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  ClassRealmMaterial copyWith({
    bool? isVisibleToStudents,
    String? title,
    String? description,
  }) {
    return ClassRealmMaterial(
      id: id,
      folderId: folderId,
      fileName: fileName,
      storagePathUrl: storagePathUrl,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      isArchived: isArchived,
      isVisibleToStudents: isVisibleToStudents ?? this.isVisibleToStudents,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
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

  Future<void> duplicateMaterialToOfferings({
    required ClassRealmMaterial material,
    required List<String> targetOfferingIds,
    required String targetFolderName,
  });

  Future<void> ensureDefaultTermFolders(String subjectOfferingId);
}
