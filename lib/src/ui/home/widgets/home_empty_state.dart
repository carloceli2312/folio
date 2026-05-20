import 'package:flutter/material.dart';
import 'package:folio/src/app/app_theme.dart';
import 'package:folio/src/ui/widgets/animated_folio_logo.dart';

/// Stato vuoto della Home: mostrato quando non ci sono né recenti né bozza.
/// Logo animato + invito ad aprire un documento.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.isOpening,
    required this.onOpen,
  });

  /// Un'apertura è in corso: disabilita il bottone.
  final bool isOpening;

  /// Callback del bottone "Apri documento" (file picker).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedFolioLogo(size: 80),
            const SizedBox(height: 20),
            Text(
              'Nessun documento recente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Apri un file .odt esistente o crea\nun nuovo documento per iniziare.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: isOpening ? null : onOpen,
              icon: const Icon(Icons.folder_open_outlined, size: 16),
              label: const Text('Apri documento'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.divider),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
