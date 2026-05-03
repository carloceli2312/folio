import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/draft_service.dart';

void main() {
  late Directory tmpDir;
  late DraftService service;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('folio_draft_test_');
    service = DraftService(directory: tmpDir);
  });

  tearDown(() async {
    if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
  });

  group('DraftService', () {
    test('exists/load su directory vuota → false/null', () async {
      expect(await service.exists(), isFalse);
      expect(await service.load(), isNull);
    });

    test('save → load preserva i campi', () async {
      final draft = Draft(
        fileName: 'doc.odt',
        deltaOps: [
          {'insert': 'Ciao\n'},
        ],
        savedAt: DateTime.utc(2026, 4, 30, 12),
      );
      await service.save(draft);

      expect(await service.exists(), isTrue);
      final loaded = await service.load();
      expect(loaded, isNotNull);
      expect(loaded!.fileName, 'doc.odt');
      expect(loaded.deltaOps, [
        {'insert': 'Ciao\n'},
      ]);
      expect(loaded.savedAt, DateTime.utc(2026, 4, 30, 12));
    });

    test('save su bozza già esistente la sovrascrive', () async {
      await service.save(
        Draft(
          fileName: 'a.odt',
          deltaOps: [
            {'insert': 'old\n'},
          ],
          savedAt: DateTime.utc(2026, 4, 1),
        ),
      );
      await service.save(
        Draft(
          fileName: 'b.odt',
          deltaOps: [
            {'insert': 'new\n'},
          ],
          savedAt: DateTime.utc(2026, 4, 30),
        ),
      );
      final loaded = await service.load();
      expect(loaded!.fileName, 'b.odt');
      expect(loaded.deltaOps, [
        {'insert': 'new\n'},
      ]);
    });

    test('clear rimuove la bozza', () async {
      await service.save(
        Draft(
          fileName: 'x.odt',
          deltaOps: const [],
          savedAt: DateTime.utc(2026, 4, 30),
        ),
      );
      await service.clear();
      expect(await service.exists(), isFalse);
      expect(await service.load(), isNull);
    });

    test('clear su directory vuota non lancia', () async {
      await service.clear();
      expect(await service.exists(), isFalse);
    });

    test('file con JSON corrotto → load restituisce null senza crash',
        () async {
      final file = File('${tmpDir.path}/draft.json');
      await file.writeAsString('{ not valid json');
      expect(await service.load(), isNull);
    });

    test('file con JSON valido ma campi mancanti → load restituisce null',
        () async {
      final file = File('${tmpDir.path}/draft.json');
      await file.writeAsString('{"fileName": "x.odt"}');
      expect(await service.load(), isNull);
    });
  });
}
