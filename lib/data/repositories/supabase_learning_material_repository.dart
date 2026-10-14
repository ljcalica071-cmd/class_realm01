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
          .select('id')
          .eq('subject_offering_id', subjectOfferingId)
          .eq('is_archived', false)
          .limit(1);

      if (existing == null || (existing as List).isEmpty) {
        final defaultFolders = [
          'Term 1 - First Quarter',
          'Term 2 - Second Quarter',
          'Term 3 - Third Quarter',
          'Supplementary Handouts & Reviewers',
        ];

        for (final name in defaultFolders) {
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

      return (response as List).map<ClassRealmFolder>((row) {
        final materials = (row['learning_materials'] as List?) ?? [];
        final activeCount = materials
            .where((m) => m is Map && m['is_archived'] != true)
            .length;
        return ClassRealmFolder.fromMap(row, count: activeCount);
      }).toList();
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
    // Soft-archive folder and its materials
    await _client.from('folders').update({
      'is_archived': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', folderId);

    await _client.from('learning_materials').update({
      'is_archived': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('folder_id', folderId);
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
    // 1. Upload to Supabase Storage
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        '$subjectOfferingId/$folderId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    try {
      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );
    } catch (storageErr) {
      debugPrint('Storage binary upload warning: $storageErr');
    }

    final publicUrl = _client.storage.from(_bucket).getPublicUrl(storagePath);

    // 2. Insert record in `learning_materials`
    final row = await _client
        .from('learning_materials')
        .insert({
          'folder_id': folderId,
          'file_name': fileName,
          'storage_path_url': publicUrl,
          'mime_type': mimeType,
          'file_size_bytes': fileSizeBytes,
          'title': (title != null && title.trim().isNotEmpty) ? title.trim() : fileName,
          'description': description?.trim(),
          'is_visible_to_students': isVisibleToStudents,
          'is_archived': false,
        })
        .select()
        .single();

    return ClassRealmMaterial.fromMap(row);
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
    await _client.from('learning_materials').update({
      'is_archived': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', materialId);

    // Extract path and attempt storage deletion
    try {
      final uri = Uri.tryParse(storagePathUrl);
      if (uri != null && uri.pathSegments.contains(_bucket)) {
        final bucketIndex = uri.pathSegments.indexOf(_bucket);
        if (bucketIndex != -1 && bucketIndex + 1 < uri.pathSegments.length) {
          final relativePath = uri.pathSegments.sublist(bucketIndex + 1).join('/');
          await _client.storage.from(_bucket).remove([relativePath]);
        }
      }
    } catch (e) {
      debugPrint('Storage file cleanup warning: $e');
    }
  }

  @override
  Future<void> duplicateMaterialToOfferings({
    required ClassRealmMaterial material,
    required List<String> targetOfferingIds,
    required String targetFolderName,
  }) async {
    for (final offeringId in targetOfferingIds) {
      try {
        // Find or create matching folder in target offering
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
}
