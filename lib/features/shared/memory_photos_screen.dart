import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

class MemoryPhotosScreen extends ConsumerStatefulWidget {
  final String patientId;
  final bool isCaregiver;

  const MemoryPhotosScreen({
    super.key,
    required this.patientId,
    this.isCaregiver = false,
  });

  @override
  ConsumerState<MemoryPhotosScreen> createState() => _MemoryPhotosScreenState();
}

class _MemoryPhotosScreenState extends ConsumerState<MemoryPhotosScreen> {
  final _picker = ImagePicker();
  bool _isUploading = false;

  String? _storagePathFromUrl(String url) {
    const marker = '/careconnect_media/';
    final index = url.indexOf(marker);
    if (index == -1) return null;
    return Uri.decodeComponent(url.substring(index + marker.length));
  }

  Future<Map<String, String>?> _showPhotoDetailsDialog({
    required String title,
    String personName = '',
    String relation = '',
    String description = '',
    required String confirmLabel,
  }) async {
    final nameController = TextEditingController(text: personName);
    final relationController = TextEditingController(text: relation);
    final descriptionController = TextEditingController(text: description);

    if (!mounted) return null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Person Name'),
              ),
              TextField(
                controller: relationController,
                decoration: const InputDecoration(labelText: 'Relation (e.g. Son)'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;

    return {
      'person_name': nameController.text.trim(),
      'relation': relationController.text.trim(),
      'description': descriptionController.text.trim(),
    };
  }

  Future<void> _uploadPhoto() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final details = await _showPhotoDetailsDialog(
      title: 'Add Memory Details',
      confirmLabel: 'Upload',
    );
    if (details == null) return;

    setState(() => _isUploading = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = '${widget.patientId}/$fileName';

      await client.storage.from('careconnect_media').uploadBinary(filePath, bytes);
      final imageUrl =
          client.storage.from('careconnect_media').getPublicUrl(filePath);

      await client.from('memory_photos').insert({
        'patient_id': widget.patientId,
        'uploader_id': client.auth.currentUser!.id,
        'image_url': imageUrl,
        ...details,
      });

      ref.invalidate(memoryPhotosProvider(widget.patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory photo uploaded!')),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(Object e) {
    final message = e.toString().contains('Bucket not found')
        ? 'Storage bucket missing. Run supabase_storage_memory_photos.sql in Supabase SQL Editor, then try again.'
        : 'Action failed: $e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onPhotoTap(Map<String, dynamic> photo) {
    if (widget.isCaregiver) {
      _showCaregiverPhotoOptions(photo);
    } else {
      _showPatientPhotoViewer(photo);
    }
  }

  void _showPatientPhotoViewer(Map<String, dynamic> photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MemoryPhotoDetailScreen(
          photo: photo,
          readOnly: true,
        ),
      ),
    );
  }

  Future<void> _showCaregiverPhotoOptions(Map<String, dynamic> photo) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View photo'),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit details'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Change photo'),
              onTap: () => Navigator.pop(context, 'replace'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete photo', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'view':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _MemoryPhotoDetailScreen(
              photo: photo,
              readOnly: false,
              onEdit: () => _editPhotoDetails(photo),
              onReplace: () => _replacePhoto(photo),
              onDelete: () => _deletePhoto(photo),
            ),
          ),
        );
      case 'edit':
        await _editPhotoDetails(photo);
      case 'replace':
        await _replacePhoto(photo);
      case 'delete':
        await _deletePhoto(photo);
    }
  }

  Future<void> _editPhotoDetails(Map<String, dynamic> photo) async {
    final details = await _showPhotoDetailsDialog(
      title: 'Edit Memory Details',
      personName: photo['person_name']?.toString() ?? '',
      relation: photo['relation']?.toString() ?? '',
      description: photo['description']?.toString() ?? '',
      confirmLabel: 'Save',
    );
    if (details == null) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('memory_photos').update(details).eq('id', photo['id']);
      ref.invalidate(memoryPhotosProvider(widget.patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory details updated.')),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _replacePhoto(Map<String, dynamic> photo) async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = '${widget.patientId}/$fileName';

      await client.storage.from('careconnect_media').uploadBinary(filePath, bytes);
      final newUrl =
          client.storage.from('careconnect_media').getPublicUrl(filePath);

      await client.from('memory_photos').update({
        'image_url': newUrl,
      }).eq('id', photo['id']);

      final oldPath = _storagePathFromUrl(photo['image_url']?.toString() ?? '');
      if (oldPath != null) {
        try {
          await client.storage.from('careconnect_media').remove([oldPath]);
        } catch (_) {}
      }

      ref.invalidate(memoryPhotosProvider(widget.patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated.')),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This memory photo will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('memory_photos').delete().eq('id', photo['id']);

      final oldPath = _storagePathFromUrl(photo['image_url']?.toString() ?? '');
      if (oldPath != null) {
        try {
          await client.storage.from('careconnect_media').remove([oldPath]);
        } catch (_) {}
      }

      ref.invalidate(memoryPhotosProvider(widget.patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted.')),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(memoryPhotosProvider(widget.patientId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Photos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (widget.isCaregiver)
            IconButton(
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add_a_photo),
              onPressed: _isUploading ? null : _uploadPhoto,
            ),
        ],
      ),
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading photos: $err')),
        data: (photos) {
          if (photos.isEmpty) {
            return Center(
              child: Text(
                widget.isCaregiver
                    ? 'No memory photos yet.\nTap + to add one.'
                    : 'No memory photos added yet.\nTap a photo when your caregiver adds one.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = Map<String, dynamic>.from(photos[index] as Map);
              return _MemoryPhotoCard(
                photo: photo,
                isCaregiver: widget.isCaregiver,
                onTap: () => _onPhotoTap(photo),
              );
            },
          );
        },
      ),
    );
  }
}

class _MemoryPhotoCard extends StatelessWidget {
  final Map<String, dynamic> photo;
  final bool isCaregiver;
  final VoidCallback onTap;

  const _MemoryPhotoCard({
    required this.photo,
    required this.isCaregiver,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Image.network(
                        photo['image_url']?.toString() ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    if (isCaregiver)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photo['person_name']?.toString() ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((photo['relation']?.toString() ?? '').isNotEmpty)
                      Text(
                        photo['relation'].toString(),
                        style: const TextStyle(
                          color: MedicalTheme.primaryTeal,
                          fontSize: 12,
                        ),
                      ),
                    if ((photo['description']?.toString() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          photo['description'].toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: MedicalTheme.lightSlate,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isCaregiver ? 'Tap to edit' : 'Tap to view',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryPhotoDetailScreen extends StatelessWidget {
  final Map<String, dynamic> photo;
  final bool readOnly;
  final VoidCallback? onEdit;
  final VoidCallback? onReplace;
  final VoidCallback? onDelete;

  const _MemoryPhotoDetailScreen({
    required this.photo,
    required this.readOnly,
    this.onEdit,
    this.onReplace,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(photo['person_name']?.toString() ?? 'Memory Photo'),
        actions: [
          if (!readOnly) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit details',
              onPressed: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
            IconButton(
              icon: const Icon(Icons.photo_camera_outlined),
              tooltip: 'Change photo',
              onPressed: () {
                Navigator.pop(context);
                onReplace?.call();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  photo['image_url']?.toString() ?? '',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    size: 80,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((photo['relation']?.toString() ?? '').isNotEmpty)
                  Text(
                    photo['relation'].toString(),
                    style: const TextStyle(
                      color: CareTheme.accentPinkSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if ((photo['description']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      photo['description'].toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
