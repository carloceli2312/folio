import 'package:flutter/material.dart';
import 'package:folio/l10n/app_localizations.dart';
import 'package:folio/src/app/app_theme.dart';

/// Header della Home: titolo "Folio" + sottotitolo, e a destra il bottone
/// "Apri" (che diventa uno spinner mentre un'apertura è in corso).
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.isOpening, required this.onOpen});

  /// Un'apertura è in corso: mostra lo spinner al posto del bottone.
  final bool isOpening;

  /// Callback del bottone "Apri" (file picker).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Folio', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 4),
                Text(
                  l10n.appSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          isOpening
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: Text(l10n.open),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
