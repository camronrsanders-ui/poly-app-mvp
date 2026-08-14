import 'package:flutter/material.dart';

import '../../services/profile_photo_moderation_service.dart';

class ProfilePhotoModerationScreen extends StatefulWidget {
  const ProfilePhotoModerationScreen({super.key});

  @override
  State<ProfilePhotoModerationScreen> createState() =>
      _ProfilePhotoModerationScreenState();
}

class _ProfilePhotoModerationScreenState
    extends State<ProfilePhotoModerationScreen> {
  final _service = ProfilePhotoModerationService();
  late Future<List<ModerationProfilePhoto>> _future;
  final Set<String> _working = {};

  @override
  void initState() {
    super.initState();
    _future = _loadSecurely();
  }

  Future<List<ModerationProfilePhoto>> _loadSecurely() async {
    if (!await _service.hasLocalModeratorAccess(forceRefresh: true)) {
      throw StateError('Local moderator access is unavailable.');
    }
    return _service.listPending();
  }

  Future<void> _refresh() async {
    final next = _loadSecurely();
    if (mounted) setState(() => _future = next);
    await next;
  }

  Future<void> _review(ModerationProfilePhoto photo, String decision) async {
    if (_working.contains(photo.photoId)) return;
    final approving = decision == 'approve';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approving ? 'Approve this photo?' : 'Reject this photo?'),
        content: Text(
          approving
              ? 'This makes the processed profile photo eligible for protected profile viewing.'
              : 'This permanently removes the processed photo from member access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approving ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working.add(photo.photoId));
    try {
      final status = await _service.review(
        photoId: photo.photoId,
        decision: decision,
        reason: approving ? null : 'local_moderation_qa',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                status == 'active' ? 'Photo approved.' : 'Photo rejected.')),
      );
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not complete this review.')),
        );
      }
    } finally {
      if (mounted) setState(() => _working.remove(photo.photoId));
    }
  }

  Widget _preview(ModerationProfilePhoto photo) {
    final bytes = photo.previewBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        height: 320,
        width: double.infinity,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
    final url = photo.previewUrl;
    if (url != null) {
      return Image.network(
        url.toString(),
        height: 320,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 180,
          child: Center(child: Text('Preview unavailable.')),
        ),
      );
    }
    return const SizedBox(
      height: 180,
      child: Center(child: Text('Preview unavailable.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local photo moderation')),
      body: FutureBuilder<List<ModerationProfilePhoto>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_outlined, size: 52),
                    const SizedBox(height: 12),
                    const Text(
                      'Local moderator access is unavailable or the queue could not be loaded.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                        onPressed: _refresh, child: const Text('Try again')),
                  ],
                ),
              ),
            );
          }

          final photos = snapshot.data ?? const <ModerationProfilePhoto>[];
          if (photos.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.verified_outlined, size: 56),
                  SizedBox(height: 14),
                  Text('No photos awaiting review',
                      textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  Text(
                    'This emulator-only queue exercises the same App-Check-protected moderation callables used by the backend.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                final working = _working.contains(photo.photoId);
                final shortId = photo.photoId.length > 8
                    ? photo.photoId.substring(0, 8)
                    : photo.photoId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 18),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          photo.ownerDisplayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text('Photo ID $shortId'),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _preview(photo),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: working
                                    ? null
                                    : () => _review(photo, 'reject'),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: working
                                    ? null
                                    : () => _review(photo, 'approve'),
                                icon: working
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.check),
                                label: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
