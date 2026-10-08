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
    final textTheme = Theme.of(context).textTheme;
    final name = otherDisplayName.trim().isEmpty
        ? 'Your connection'
        : otherDisplayName.trim();

    return Semantics(
      container: true,
      label: 'Conversation space with $name. Create a world together.',
      child: SizedBox(
        key: const Key('conversation-space-identity'),
        height: 52,
        child: Row(
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 62,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 17,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: colors.secondaryContainer,
                        foregroundColor: colors.onSecondaryContainer,
                        child: Text(
                          _initial,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surface,
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Icon(
                        Icons.public_rounded,
                        size: 12,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Conversation space · Create a world together',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.05,
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
