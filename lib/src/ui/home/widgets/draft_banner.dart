import 'package:flutter/material.dart';
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
                      'Bozza non salvata',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tocca per riprendere ${_safeName(draft.fileName)}',
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
                tooltip: 'Scarta bozza',
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onDiscard,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _safeName(String fileName) {
    final stripped = fileName.replaceAll(
      RegExp(r'\.odt$', caseSensitive: false),
      '',
    );
    return stripped.isEmpty ? 'documento' : stripped;
  }
}
