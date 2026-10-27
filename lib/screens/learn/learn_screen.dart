import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../content/learn_content.dart';

/// Stage 1 Learn tab: static educational content from
/// [LearnContent] — the Get Help card first, a searchable glossary,
/// learning paths, and a book shelf. No backend surface and no
/// progress tracking; term proposals and per-path progress are
/// Stage 2.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens a tel:, sms:, or https: URI outside the app (dialer, the
  /// member's messaging app, or their browser). If the device cannot
  /// handle it, say so plainly — the contact text and URLs stay
  /// visible on screen either way.
  Future<void> _launchUri(String uri) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(uri),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open that on this device.'),
        ),
      );
    }
  }

  bool _matches(GlossaryTerm term) {
    if (_category != null && term.category != _category) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return term.term.toLowerCase().contains(query) ||
        term.definition.toLowerCase().contains(query) ||
        term.example.toLowerCase().contains(query);
  }

  Widget _sectionHeading(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }

  Widget _helpCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_outline, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LearnContent.helpCardHeading,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(LearnContent.helpCardIntro),
            const Divider(height: 24),
            for (var i = 0; i < LearnContent.crisisResources.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _crisisRow(context, LearnContent.crisisResources[i]),
            ],
            const SizedBox(height: 10),
            Text(
              'Tap a button to call or text. You can also tap and hold '
              'a contact to copy it. In an emergency, call your local '
              'emergency number.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _crisisRow(BuildContext context, CrisisResource resource) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(resource.name, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        SelectableText(
          resource.contact,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(resource.note, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final action in resource.actions)
              FilledButton.tonalIcon(
                onPressed: () => _launchUri(action.uri),
                icon: Icon(
                  action.uri.startsWith('sms:')
                      ? Icons.sms_outlined
                      : Icons.call_outlined,
                  size: 18,
                ),
                label: Text(action.label),
              ),
          ],
        ),
      ],
    );
  }

  Widget _supportCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var g = 0; g < LearnContent.supportGroups.length; g++) ...[
              if (g > 0) const Divider(height: 24),
              Text(
                LearnContent.supportGroups[g].heading,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final entry in LearnContent.supportGroups[g].entries) ...[
                InkWell(
                  onTap: () => _launchUri(entry.url),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.name,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(entry.detail),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.open_in_new, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _glossary(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <String, List<GlossaryTerm>>{};
    for (final term in LearnContent.glossary.where(_matches)) {
      groups.putIfAbsent(term.category, () => []).add(term);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('learn-glossary-search'),
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            labelText: 'Look up any relationship term',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All terms'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              for (final category in LearnContent.glossaryCategories) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (selected) =>
                      setState(() => _category = selected ? category : null),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No terms match yet. Try a different word, or browse a '
              'category above.',
            ),
          )
        else
          for (final category in LearnContent.glossaryCategories)
            if (groups[category] != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Text(category, style: theme.textTheme.titleMedium),
              ),
              for (final term in groups[category]!)
                ExpansionTile(
                  title: Text(term.term),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(term.definition),
                    const SizedBox(height: 8),
                    Text('Example: ${term.example}'),
                  ],
                ),
            ],
      ],
    );
  }

  Widget _pathCard(BuildContext context, LearningPath path) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.route_outlined, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    path.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(path.promise),
            const SizedBox(height: 6),
            for (var i = 0; i < path.reads.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}.'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            path.reads[i].title,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(path.reads[i].description),
                        ],
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

  Widget _booksCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < LearnContent.books.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.menu_book_outlined, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LearnContent.books[i].title,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          LearnContent.books[i].author,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Read this if… '
                          '${LearnContent.books[i].readThisIf}.',
                        ),
                        if (LearnContent.books[i].blurb != null) ...[
                          const SizedBox(height: 4),
                          Text(LearnContent.books[i].blurb!),
                        ],
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                _launchUri(LearnContent.books[i].libraryUrl),
                            icon: const Icon(
                              Icons.local_library_outlined,
                              size: 18,
                            ),
                            label: Text(
                              LearnContent.books[i].libraryActionLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The Get Help card leads the page: it is the first thing rendered
    // when the Learn tab opens, above search and all learning content.
    // It is not fixed in place — the full card is ~800px tall, which
    // cannot stay pinned on short viewports or at large text scales
    // without crowding out everything else. Persistent one-tap access
    // is instead provided by the shell app bar's help action, which
    // switches to this tab from Messages and Profile.
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        _helpCard(context),
        _supportCard(context),
        const SizedBox(height: 10),
        _sectionHeading(context, 'Look up a term'),
        _glossary(context),
        const SizedBox(height: 24),
        _sectionHeading(context, 'Start learning'),
        for (final path in LearnContent.learningPaths) _pathCard(context, path),
        const SizedBox(height: 10),
        _sectionHeading(context, 'Books & voices'),
        _booksCard(context),
      ],
    );
  }
}
