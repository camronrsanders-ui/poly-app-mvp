import 'package:flutter/material.dart';

class ConversationSpaceHeader extends StatelessWidget {
  const ConversationSpaceHeader({
    super.key,
    required this.otherDisplayName,
  });

  final String otherDisplayName;

  String get _initial {
    final trimmed = otherDisplayName.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = otherDisplayName.trim().isEmpty
        ? 'your connection'
        : otherDisplayName.trim();

    return Semantics(
      container: true,
      label: 'Private conversation space with $name.',
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 2,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: colors.secondaryContainer,
                      foregroundColor: colors.onSecondaryContainer,
                      child: Text(
                        _initial,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your conversation space',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'A private space for you and $name to build the connection at your own pace.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.3,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
