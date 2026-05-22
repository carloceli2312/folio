import 'package:flutter/material.dart';
import 'package:folio/l10n/app_localizations.dart';
import 'package:folio/src/app/app_theme.dart';
import 'package:folio/src/services/recent_file.dart';

/// Card per un singolo documento recente.
class RecentFileCard extends StatelessWidget {
  const RecentFileCard({super.key, required this.file, required this.onTap});

  final RecentFile file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = file.name.replaceAll(
      RegExp(r'\.odt$', caseSensitive: false),
      '',
    );
    return Material(
      color: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.pageBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 22,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (file.preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        file.preview,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _formatRelativeDate(context, file.openedAt),
                      style: theme.textTheme.labelSmall,
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

/// Returns a locale-aware relative date label (e.g. "Today", "Yesterday",
/// "3 days ago", "12 Mar 2026") for [date].
String _formatRelativeDate(BuildContext context, DateTime date) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(date.year, date.month, date.day);
  final days = today.difference(that).inDays;
  if (days <= 0) return l10n.dateToday;
  if (days == 1) return l10n.dateYesterday;
  if (days < 7) return l10n.dateDaysAgo(days);
  return MaterialLocalizations.of(context).formatShortDate(date);
}
