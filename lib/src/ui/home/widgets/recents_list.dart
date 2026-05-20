import 'package:flutter/material.dart';
import 'package:folio/src/services/draft.dart';
import 'package:folio/src/services/recent_file.dart';
import 'package:folio/src/ui/home/widgets/draft_banner.dart';
import 'package:folio/src/ui/home/widgets/recent_file_card.dart';

/// Lista della Home: eventuale banner bozza in cima, titolo "Recenti" e le
/// card dei documenti recenti.
class RecentsList extends StatelessWidget {
  const RecentsList({
    super.key,
    required this.recents,
    required this.draft,
    required this.isOpening,
    required this.onResumeDraft,
    required this.onDiscardDraft,
    required this.onOpenRecent,
  });

  final List<RecentFile> recents;

  /// Bozza non salvata da proporre in cima, oppure `null`.
  final Draft? draft;

  /// Un'apertura è in corso: disabilita i tap (anti doppio-tocco).
  final bool isOpening;

  final VoidCallback onResumeDraft;
  final VoidCallback onDiscardDraft;
  final void Function(RecentFile) onOpenRecent;

  @override
  Widget build(BuildContext context) {
    final hasDraft = draft != null;

    final headerCount = hasDraft ? 1 : 0;
    final sectionTitle = recents.isNotEmpty ? 1 : 0;
    final totalCount = headerCount + sectionTitle + recents.length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: totalCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        var i = index;
        if (hasDraft && i == 0) {
          return DraftBanner(
            draft: draft!,
            onResume: isOpening ? null : onResumeDraft,
            onDiscard: isOpening ? null : onDiscardDraft,
          );
        }
        if (hasDraft) i--;
        if (sectionTitle == 1 && i == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4, left: 4),
            child: Text(
              'Recenti',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          );
        }
        if (sectionTitle == 1) i--;
        final file = recents[i];
        return RecentFileCard(
          file: file,
          onTap: isOpening ? null : () => onOpenRecent(file),
        );
      },
    );
  }
}
