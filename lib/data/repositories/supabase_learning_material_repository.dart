import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'learning_material_repository.dart';

class SupabaseLearningMaterialRepository implements LearningMaterialRepository {
  final SupabaseClient _client;

  SupabaseLearningMaterialRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static final SupabaseLearningMaterialRepository instance =
      SupabaseLearningMaterialRepository();

  static const String _bucket = 'learning_materials';

  @override
  Future<void> ensureDefaultTermFolders(String subjectOfferingId) async {
    try {
      final existing = await _client
          .from('folders')
          .select('id, folder_name')
          .eq('subject_offering_id', subjectOfferingId);

      final existingNames = (existing as List?)
              ?.map((e) => e['folder_name']?.toString())
              .whereType<String>()
              .toSet() ??
          <String>{};

      final defaultFolders = [
        'Term 1 - First Quarter',
        'Term 2 - Second Quarter',
        'Term 3 - Third Quarter',
        'Supplementary Handouts & Reviewers',
      ];

      for (final name in defaultFolders) {
        if (!existingNames.contains(name)) {
          await _client.from('folders').insert({
            'subject_offering_id': subjectOfferingId,
            'folder_name': name,
            'is_visible_to_students': true,
            'is_archived': false,
          });
        }
      }
    } catch (e) {
      debugPrint('Error ensuring default folders: $e');
    }
  }

  @override
  Future<List<ClassRealmFolder>> getFolders({
    required String subjectOfferingId,
    String? parentFolderId,
  }) async {
    try {
      var query = _client
          .from('folders')
          .select('''
            id,
            subject_offering_id,
            parent_folder_id,
            folder_name,
            is_visible_to_students,
            is_archived,
            created_at,
            updated_at,
            learning_materials ( id, is_archived )
          ''')
          .eq('subject_offering_id', subjectOfferingId)
          .eq('is_archived', false);

      if (parentFolderId == null) {
        query = query.filter('parent_folder_id', 'is', null);
      } else {
        query = query.eq('parent_folder_id', parentFolderId);
      }

      final response = await query.order('folder_name', ascending: true);

      final defaultOrder = {
        'Term 1 - First Quarter': 1,
        'Term 2 - Second Quarter': 2,
        'Term 3 - Third Quarter': 3,
        'Supplementary Handouts & Reviewers': 4,
      };

      final folders = (response as List).map<ClassRealmFolder>((row) {
        final materials = (row['learning_materials'] as List?) ?? [];
        final activeCount = materials
            .where((m) => m is Map && m['is_archived'] != true)
            .length;
        return ClassRealmFolder.fromMap(row, count: activeCount);
      }).toList();

      if (parentFolderId == null) {
        folders.sort((a, b) {
          final orderA = defaultOrder[a.folderName] ?? 99;
          final orderB = defaultOrder[b.folderName] ?? 99;
          if (orderA != orderB) return orderA.compareTo(orderB);
          return a.folderName.compareTo(b.folderName);
        });
      }

      return folders;
    } catch (e) {
      debugPrint('Error getting folders: $e');
      return [];
    }
  }

  @override
  Future<ClassRealmFolder> createFolder({
    required String subjectOfferingId,
    required String folderName,
    String? parentFolderId,
    bool isVisibleToStudents = true,
  }) async {
    final response = await _client
        .from('folders')
        .insert({
          'subject_offering_id': subjectOfferingId,
          'folder_name': folderName.trim(),
          'parent_folder_id': parentFolderId,
          'is_visible_to_students': isVisibleToStudents,
          'is_archived': false,
        })
        .select()
        .single();

    return ClassRealmFolder.fromMap(response);
  }

  @override
  Future<void> updateFolder({
    required String folderId,
    String? folderName,
    bool? isVisibleToStudents,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (folderName != null) updates['folder_name'] = folderName.trim();
    if (isVisibleToStudents != null) {
      updates['is_visible_to_students'] = isVisibleToStudents;
    }

    await _client.from('folders').update(updates).eq('id', folderId);
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    try {
      // 1. Delete all learning_materials in this folder from Supabase DB
      await _client.from('learning_materials').delete().eq('folder_id', folderId);

      // 2. Delete all sub-folders from Supabase DB
      await _client.from('folders').delete().eq('parent_folder_id', folderId);

      // 3. Delete the folder itself from Supabase DB
      await _client.from('folders').delete().eq('id', folderId);
      debugPrint('Folder $folderId and child contents hard-deleted from Supabase.');
    } catch (e) {
      debugPrint('Error hard-deleting folder $folderId: $e');
      rethrow;
    }
  }

  @override
  Future<void> archiveFolder(String folderId) async {
    final nowIso = DateTime.now().toIso8601String();
    await _client.from('folders').update({
      'is_archived': true,
      'updated_at': nowIso,
    }).eq('id', folderId);

    await _client.from('learning_materials').update({
      'is_archived': true,
      'updated_at': nowIso,
    }).eq('folder_id', folderId);

    await _client.from('folders').update({
      'is_archived': true,
      'updated_at': nowIso,
    }).eq('parent_folder_id', folderId);
  }

  @override
  Future<void> restoreFolder(String folderId) async {
    final nowIso = DateTime.now().toIso8601String();
    await _client.from('folders').update({
      'is_archived': false,
      'updated_at': nowIso,
    }).eq('id', folderId);

    await _client.from('learning_materials').update({
      'is_archived': false,
      'updated_at': nowIso,
    }).eq('folder_id', folderId);

    await _client.from('folders').update({
      'is_archived': false,
      'updated_at': nowIso,
    }).eq('parent_folder_id', folderId);
  }

  @override
  Future<List<ClassRealmFolder>> getArchivedFolders(String subjectOfferingId) async {
    try {
      final response = await _client
          .from('folders')
          .select('''
            id,
            subject_offering_id,
            parent_folder_id,
            folder_name,
            is_visible_to_students,
            is_archived,
            created_at,
            updated_at,
            learning_materials ( id, is_archived )
          ''')
          .eq('subject_offering_id', subjectOfferingId)
          .eq('is_archived', true)
          .order('folder_name', ascending: true);

      return (response as List).map<ClassRealmFolder>((row) {
        final materials = (row['learning_materials'] as List?) ?? [];
        return ClassRealmFolder.fromMap(
          row,
          count: materials.length,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting archived folders: $e');
      return [];
    }
  }

  @override
  Future<List<ClassRealmMaterial>> getMaterials({
    required String folderId,
    bool studentOnly = false,
  }) async {
    try {
      var query = _client
          .from('learning_materials')
          .select()
          .eq('folder_id', folderId)
          .eq('is_archived', false);

      if (studentOnly) {
        query = query.eq('is_visible_to_students', true);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map<ClassRealmMaterial>((row) => ClassRealmMaterial.fromMap(row))
          .toList();
    } catch (e) {
      debugPrint('Error getting materials: $e');
      return [];
    }
  }

  @override
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
  }) async {
    final results = await uploadDeduplicatedMaterial(
      primaryFolderId: folderId,
      primaryOfferingId: subjectOfferingId,
      fileName: fileName,
      fileBytes: fileBytes,
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
      title: title,
      description: description,
      isVisibleToStudents: isVisibleToStudents,
      additionalOfferingIds: const [],
      targetFolderName: '',
    );
    return results.first;
  }

  @override
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
  }) async {
    final sanitizedFileName = MaterialFileValidator.sanitizeFileName(fileName);
    final effectiveMimeType = mimeType ??
        MaterialFileValidator.getMimeType(sanitizedFileName);

    String storageUrl;

    // Rich-text or embed link consumes 0 cloud storage bytes
    if (effectiveMimeType == MaterialFileValidator.mimeMarkdown) {
      storageUrl = 'lesson://embedded_markdown';
    } else if (effectiveMimeType == MaterialFileValidator.mimeUriList) {
      storageUrl = description?.trim() ?? '';
    } else {
      // 1. Upload file ONLY ONCE using deterministic collision-free key
      final storagePath = MaterialFileValidator.buildStorageKey(
        bytes: fileBytes,
        originalFileName: sanitizedFileName,
      );

      // Atomic upload: if this throws, caller catches it, zero broken DB rows!
      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: effectiveMimeType,
              upsert: true,
            ),
          );

      storageUrl = _client.storage.from(_bucket).getPublicUrl(storagePath);
    }

    final createdMaterials = <ClassRealmMaterial>[];

    // 2. Insert primary row in public.learning_materials
    final primaryRow = await _client
        .from('learning_materials')
        .insert({
          'folder_id': primaryFolderId,
          'file_name': sanitizedFileName,
          'storage_path_url': storageUrl,
          'mime_type': effectiveMimeType,
          'file_size_bytes': fileSizeBytes,
          'title': (title != null && title.trim().isNotEmpty)
              ? title.trim()
              : sanitizedFileName,
          'description': description?.trim(),
          'is_visible_to_students': isVisibleToStudents,
          'is_archived': false,
        })
        .select()
        .single();

    createdMaterials.add(ClassRealmMaterial.fromMap(primaryRow));

    // 3. Insert rows for additional offerings pointing to the EXACT SAME storage_path_url
    for (final otherOfferingId in additionalOfferingIds) {
      if (otherOfferingId == primaryOfferingId) continue;
      try {
        final folderRes = await _client
            .from('folders')
            .select('id')
            .eq('subject_offering_id', otherOfferingId)
            .eq('folder_name', targetFolderName)
            .eq('is_archived', false)
            .maybeSingle();

        String targetFolderId;
        if (folderRes != null && folderRes['id'] != null) {
          targetFolderId = folderRes['id'].toString();
        } else {
          final newFolder = await _client
              .from('folders')
              .insert({
                'subject_offering_id': otherOfferingId,
                'folder_name': targetFolderName,
                'is_visible_to_students': isVisibleToStudents,
                'is_archived': false,
              })
              .select('id')
              .single();
          targetFolderId = newFolder['id'].toString();
        }

        final sharedRow = await _client
            .from('learning_materials')
            .insert({
              'folder_id': targetFolderId,
              'file_name': sanitizedFileName,
              'storage_path_url': storageUrl,
              'mime_type': effectiveMimeType,
              'file_size_bytes': fileSizeBytes,
              'title': (title != null && title.trim().isNotEmpty)
                  ? title.trim()
                  : sanitizedFileName,
              'description': description?.trim(),
              'is_visible_to_students': isVisibleToStudents,
              'is_archived': false,
            })
            .select()
            .single();

        createdMaterials.add(ClassRealmMaterial.fromMap(sharedRow));
      } catch (e) {
        debugPrint('Error linking material to additional offering $otherOfferingId: $e');
      }
    }

    return createdMaterials;
  }

  @override
  Future<void> toggleMaterialVisibility({
    required String materialId,
    required bool isVisible,
  }) async {
    await _client.from('learning_materials').update({
      'is_visible_to_students': isVisible,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', materialId);
  }

  @override
  Future<void> deleteMaterial(String materialId, String storagePathUrl) async {
    await deleteMaterialReferenceCounted(
      materialId: materialId,
      storagePathUrl: storagePathUrl,
    );
  }

  @override
  Future<void> deleteMaterialReferenceCounted({
    required String materialId,
    required String storagePathUrl,
  }) async {
    // 1. HARD DELETE Section's material row from Supabase database
    await _client.from('learning_materials').delete().eq('id', materialId);
    debugPrint('Material $materialId hard-deleted from Supabase database.');

    // If virtual lesson or empty link, no physical file exists
    if (storagePathUrl.isEmpty ||
        storagePathUrl.startsWith('lesson://') ||
        !storagePathUrl.startsWith('http')) {
      return;
    }

    // 2. Count active rows still referencing that storage_path_url
    try {
      final activeRefs = await _client
          .from('learning_materials')
          .select('id')
          .eq('storage_path_url', storagePathUrl);

      final remainingCount = (activeRefs as List).length;

      // 3. Only delete physical file if no other sections reference it
      if (remainingCount == 0) {
        final relativePath = _extractStorageRelativePath(storagePathUrl);
        if (relativePath != null && relativePath.isNotEmpty) {
          await _client.storage.from(_bucket).remove([relativePath]);
          debugPrint('Physical storage file purged from Supabase: $relativePath');
        }
      } else {
        debugPrint(
          'Physical storage file preserved. Rows still referencing: $remainingCount',
        );
      }
    } catch (e) {
      debugPrint('Error in reference-counted storage deletion: $e');
    }
  }

  @override
  Future<void> archiveMaterial(String materialId) async {
    await _client.from('learning_materials').update({
      'is_archived': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', materialId);
  }

  @override
  Future<void> restoreMaterial(String materialId) async {
    await _client.from('learning_materials').update({
      'is_archived': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', materialId);
  }

  @override
  Future<List<ClassRealmMaterial>> getArchivedMaterials(String subjectOfferingId) async {
    try {
      final foldersRes = await _client
          .from('folders')
          .select('id')
          .eq('subject_offering_id', subjectOfferingId);

      final folderIds = (foldersRes as List).map((f) => f['id'].toString()).toList();
      if (folderIds.isEmpty) return [];

      final response = await _client
          .from('learning_materials')
          .select()
          .inFilter('folder_id', folderIds)
          .eq('is_archived', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map<ClassRealmMaterial>((row) => ClassRealmMaterial.fromMap(row))
          .toList();
    } catch (e) {
      debugPrint('Error getting archived materials: $e');
      return [];
    }
  }

  @override
  Future<ClassRealmMaterial> replaceMaterialFile({
    required String materialId,
    required String currentStoragePathUrl,
    required String newFileName,
    required Uint8List newFileBytes,
    required int newFileSizeBytes,
    required String mimeType,
    required bool updateAllSharedSections,
  }) async {
    final sanitizedFileName = MaterialFileValidator.sanitizeFileName(newFileName);
    final effectiveMimeType = mimeType.isNotEmpty
        ? mimeType
        : MaterialFileValidator.getMimeType(sanitizedFileName);

    // 1. Upload new file to deterministic storage path
    final newStoragePath = MaterialFileValidator.buildStorageKey(
      bytes: newFileBytes,
      originalFileName: sanitizedFileName,
    );

    await _client.storage.from(_bucket).uploadBinary(
          newStoragePath,
          newFileBytes,
          fileOptions: FileOptions(
            contentType: effectiveMimeType,
            upsert: true,
          ),
        );

    final newPublicUrl = _client.storage.from(_bucket).getPublicUrl(newStoragePath);
    final nowIso = DateTime.now().toIso8601String();

    if (updateAllSharedSections) {
      // Update ALL active rows that shared the old URL
      await _client.from('learning_materials').update({
        'storage_path_url': newPublicUrl,
        'file_name': sanitizedFileName,
        'file_size_bytes': newFileSizeBytes,
        'mime_type': effectiveMimeType,
        'updated_at': nowIso,
      }).eq('storage_path_url', currentStoragePathUrl).eq('is_archived', false);

      // Clean up old storage object if URL changed
      if (currentStoragePathUrl != newPublicUrl &&
          currentStoragePathUrl.startsWith('http')) {
        final oldRelativePath = _extractStorageRelativePath(currentStoragePathUrl);
        if (oldRelativePath != null) {
          try {
            await _client.storage.from(_bucket).remove([oldRelativePath]);
          } catch (e) {
            debugPrint('Cleanup old storage file error: $e');
          }
        }
      }
    } else {
      // Update THIS section row only
      await _client.from('learning_materials').update({
        'storage_path_url': newPublicUrl,
        'file_name': sanitizedFileName,
        'file_size_bytes': newFileSizeBytes,
        'mime_type': effectiveMimeType,
        'updated_at': nowIso,
      }).eq('id', materialId);

      // Check if other sections still reference old URL; if not, clean it up
      if (currentStoragePathUrl != newPublicUrl &&
          currentStoragePathUrl.startsWith('http')) {
        try {
          final otherRefs = await _client
              .from('learning_materials')
              .select('id')
              .eq('storage_path_url', currentStoragePathUrl)
              .eq('is_archived', false);

          if ((otherRefs as List).isEmpty) {
            final oldRelativePath =
                _extractStorageRelativePath(currentStoragePathUrl);
            if (oldRelativePath != null) {
              await _client.storage.from(_bucket).remove([oldRelativePath]);
            }
          }
        } catch (e) {
          debugPrint('Check other references on replace warning: $e');
        }
      }
    }

    final updatedRow = await _client
        .from('learning_materials')
        .select()
        .eq('id', materialId)
        .single();

    return ClassRealmMaterial.fromMap(updatedRow);
  }

  @override
  Future<ClassRealmMaterial> updateMaterialDetails({
    required String materialId,
    String? title,
    String? description,
    String? folderId,
    bool? isVisibleToStudents,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null) updates['title'] = title.trim();
    if (description != null) updates['description'] = description.trim();
    if (folderId != null) updates['folder_id'] = folderId;
    if (isVisibleToStudents != null) {
      updates['is_visible_to_students'] = isVisibleToStudents;
    }

    final row = await _client
        .from('learning_materials')
        .update(updates)
        .eq('id', materialId)
        .select()
        .single();

    return ClassRealmMaterial.fromMap(row);
  }

  @override
  Future<List<ClassRealmMaterial>> getStudentMaterialsWithHierarchy({
    required String subjectOfferingId,
    String? folderId,
    DateTime? serverTime,
  }) async {
    final effectiveServerTime = serverTime ?? await getServerUtcTime();

    // 1. Fetch all folders for this offering to reconstruct complete hierarchy
    final allFoldersResp = await _client
        .from('folders')
        .select('id, parent_folder_id, folder_name, is_visible_to_students, is_archived')
        .eq('subject_offering_id', subjectOfferingId);

    final folderMap = <String, Map<String, dynamic>>{};
    for (final f in (allFoldersResp as List)) {
      folderMap[f['id'].toString()] = f as Map<String, dynamic>;
    }

    // Helper: checks if folder and ALL its ancestor folders are visible & not archived
    bool isFolderHierarchyVisible(String? fId) {
      var currentId = fId;
      final visited = <String>{};
      while (currentId != null) {
        if (visited.contains(currentId)) break; // Prevent infinite loops
        visited.add(currentId);

        final folder = folderMap[currentId];
        if (folder == null) return false;
        if (folder['is_archived'] == true) return false;
        if (folder['is_visible_to_students'] != true) return false;

        currentId = folder['parent_folder_id']?.toString();
      }
      return true;
    }

    // 2. Fetch materials
    var query = _client
        .from('learning_materials')
        .select()
        .eq('is_archived', false)
        .eq('is_visible_to_students', true);

    if (folderId != null) {
      query = query.eq('folder_id', folderId);
    }

    final rows = await query.order('created_at', ascending: false);

    final result = <ClassRealmMaterial>[];
    for (final row in (rows as List)) {
      final material = ClassRealmMaterial.fromMap(row);

      // Verify folder belongs to this offering and is hierarchically visible
      final folder = folderMap[material.folderId];
      if (folder == null) continue;

      if (!isFolderHierarchyVisible(material.folderId)) {
        continue;
      }

      // Check available_from against server UTC time
      if (material.availableFrom != null) {
        if (material.availableFrom!.isAfter(effectiveServerTime)) {
          continue; // Hidden until release time
        }
      }

      result.add(material);
    }

    return result;
  }

  @override
  Future<DateTime> getServerUtcTime() async {
    try {
      final res = await _client.rpc('get_server_time');
      if (res != null) {
        final parsed = DateTime.tryParse(res.toString());
        if (parsed != null) {
          return parsed.toUtc();
        }
      }
    } catch (e) {
      debugPrint('Warning: get_server_time RPC call unfulfilled ($e). Falling back to client UTC clock.');
    }
    return DateTime.now().toUtc();
  }

  @override
  Future<void> duplicateMaterialToOfferings({
    required ClassRealmMaterial material,
    required List<String> targetOfferingIds,
    required String targetFolderName,
  }) async {
    for (final offeringId in targetOfferingIds) {
      try {
        final folderRes = await _client
            .from('folders')
            .select('id')
            .eq('subject_offering_id', offeringId)
            .eq('folder_name', targetFolderName)
            .eq('is_archived', false)
            .maybeSingle();

        String targetFolderId;
        if (folderRes != null && folderRes['id'] != null) {
          targetFolderId = folderRes['id'].toString();
        } else {
          final newFolder = await _client
              .from('folders')
              .insert({
                'subject_offering_id': offeringId,
                'folder_name': targetFolderName,
                'is_visible_to_students': true,
                'is_archived': false,
              })
              .select('id')
              .single();
          targetFolderId = newFolder['id'].toString();
        }

        // Insert material pointing to same URL (consumes 0 additional cloud bytes)
        await _client.from('learning_materials').insert({
          'folder_id': targetFolderId,
          'file_name': material.fileName,
          'storage_path_url': material.storagePathUrl,
          'mime_type': material.mimeType,
          'file_size_bytes': material.fileSizeBytes,
          'title': material.title,
          'description': material.description,
          'is_visible_to_students': material.isVisibleToStudents,
          'is_archived': false,
        });
      } catch (e) {
        debugPrint('Error sharing material to offering $offeringId: $e');
      }
    }
  }

  String? _extractStorageRelativePath(String url) {
    if (!url.startsWith('http')) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final idx = segments.indexOf(_bucket);
    if (idx != -1 && idx + 1 < segments.length) {
      return segments.sublist(idx + 1).join('/');
    }
    return null;
  }
}
