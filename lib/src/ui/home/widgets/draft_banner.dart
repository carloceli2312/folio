import 'package:flutter/material.dart';
import 'package:folio/l10n/app_localizations.dart';
import 'package:folio/src/app/app_theme.dart';
import 'package:folio/src/services/draft.dart';

/// Banner che propone di riprendere una bozza non salvata.
class DraftBanner extends StatelessWidget {
  const DraftBanner({
    super.key,
    required this.draft,
    required this.onResume,
    required this.onDiscard,
  });

  final Draft draft;
  final VoidCallback? onResume;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: AppTheme.darkChrome,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.history_edu_outlined,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.unsavedDraft,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.tapToResume(_safeName(context, draft.fileName)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.discardDraft,
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onDiscard,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _safeName(BuildContext context, String fileName) {
    final stripped = fileName.replaceAll(
      RegExp(r'\.odt$', caseSensitive: false),
      '',
    );
    return stripped.isEmpty
        ? AppLocalizations.of(context)!.documentFallbackName
        : stripped;
  }
}
