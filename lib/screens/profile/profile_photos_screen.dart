import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/profile_media_service.dart';

class ProfilePhotosScreen extends StatefulWidget {
  const ProfilePhotosScreen({super.key});

  @override
  State<ProfilePhotosScreen> createState() => _ProfilePhotosScreenState();
}

class _ProfilePhotosScreenState extends State<ProfilePhotosScreen> {
  final _service = ProfileMediaService();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _uploading = false;
  List<ProfileMediaStatus> _photos = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    try {
      final photos = await _service.listMyPhotos();
      if (mounted) setState(() => _photos = photos);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not load profile photos right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _contentTypeFor(XFile file) {
    final mime = file.mimeType?.trim().toLowerCase();
    if (mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp') {
      return mime;
    }

    final lower = file.name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;

    final contentType = _contentTypeFor(picked);
    if (contentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a JPEG, PNG, or WebP image.')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw ArgumentError('Photo must be 10 MB or smaller.');
      }

      final authorization = await _service.beginUpload(contentType);
      await _service.uploadBytes(authorization: authorization, bytes: bytes);
      await _service.confirmUpload(authorization.photoId);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Photo uploaded securely. It will appear after processing and safety review.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not upload that photo. Please try another image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'awaiting_upload':
        return 'Waiting for upload';
      case 'pending_processing':
        return 'Processing securely';
      case 'processed_pending_review':
        return 'Awaiting safety review';
      case 'active':
        return 'Visible on your profile';
      case 'rejected':
        return 'Not approved';
      case 'removed':
        return 'Removed';
      default:
        return 'Status unavailable';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle_outline;
      case 'rejected':
      case 'removed':
        return Icons.remove_circle_outline;
      case 'processed_pending_review':
        return Icons.verified_user_outlined;
      default:
        return Icons.hourglass_top;
    }
  }

  Future<void> _viewPhoto(ProfileMediaStatus photo) async {
    if (photo.status != 'active') return;
    try {
      final url = await _service.getAccessUrl(photo.photoId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(
                      url.toString(),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(32),
                        child:
                            Text('This protected photo could not be loaded.'),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                            'This viewing link is temporary and is not stored in your public profile.'),
                      ),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this protected photo.')),
        );
      }
    }
  }

  Future<void> _deletePhoto(ProfileMediaStatus photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text(
            'This removes the photo from Polycircle. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.deletePhoto(photo.photoId);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo deleted.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not delete this photo right now.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile photos')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text('Protected profile photos',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Uploads go to a private quarantine area first. Polycircle validates and re-encodes them before review, and approved photos are delivered through short-lived protected links rather than permanent public URLs.',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label:
                  Text(_uploading ? 'Uploading securely…' : 'Choose a photo'),
            ),
            const SizedBox(height: 8),
            const Text('JPEG, PNG, or WebP • 10 MB maximum'),
            const SizedBox(height: 22),
            if (_loading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_photos.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(Icons.photo_library_outlined, size: 48),
                      SizedBox(height: 10),
                      Text('No profile photos yet'),
                      SizedBox(height: 6),
                      Text(
                          'Add a photo when you are ready. Nothing is made visible until processing and review are complete.',
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            else
              ..._photos.map((photo) => Card(
                    child: ListTile(
                      leading: Icon(_statusIcon(photo.status)),
                      title: Text(_statusLabel(photo.status)),
                      subtitle: Text(
                        photo.status == 'active'
                            ? 'Approved and available through protected delivery.'
                            : 'Photo ID ${photo.photoId.substring(0, photo.photoId.length.clamp(0, 8))}',
                      ),
                      onTap: photo.status == 'active'
                          ? () => _viewPhoto(photo)
                          : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'view') _viewPhoto(photo);
                          if (value == 'delete') _deletePhoto(photo);
                        },
                        itemBuilder: (_) => [
                          if (photo.status == 'active')
                            const PopupMenuItem(
                                value: 'view', child: Text('View securely')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Profile photos are separate from the Private Vault. Intimate/private media sharing remains disabled while its additional consent and safety controls are being completed.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
