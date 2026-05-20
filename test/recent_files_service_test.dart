import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folio/folio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RecentFilesService.load/addOrPromote', () {
    test('load su storage vuoto → lista vuota', () async {
      final service = RecentFilesService();
      expect(await service.load(), isEmpty);
    });

    test('addOrPromote inserisce in cima', () async {
      final service = RecentFilesService();
      final entry = RecentFile(
        name: 'doc.odt',
        preview: 'Hello',
        openedAt: DateTime.utc(2026, 4, 30, 10),
      );
      final result = await service.addOrPromote(entry);
      expect(result, hasLength(1));
      expect(result.first.name, 'doc.odt');

      final reloaded = await service.load();
      expect(reloaded, hasLength(1));
      expect(reloaded.first.name, 'doc.odt');
      expect(reloaded.first.preview, 'Hello');
    });

    test('voce duplicata viene promossa, non duplicata', () async {
      final service = RecentFilesService();
      await service.addOrPromote(
        RecentFile(
          name: 'a.odt',
          preview: 'old',
          openedAt: DateTime.utc(2026, 4, 1),
        ),
      );
      await service.addOrPromote(
        RecentFile(
          name: 'b.odt',
          preview: 'b',
          openedAt: DateTime.utc(2026, 4, 2),
        ),
      );
      final result = await service.addOrPromote(
        RecentFile(
          name: 'a.odt',
          preview: 'new',
          openedAt: DateTime.utc(2026, 4, 30),
        ),
      );
      expect(result.map((e) => e.name).toList(), ['a.odt', 'b.odt']);
      expect(result.first.preview, 'new');
    });

    test('lista è capata a maxEntries', () async {
      final service = RecentFilesService();
      for (var i = 0; i < RecentFilesService.maxEntries + 5; i++) {
        await service.addOrPromote(
          RecentFile(
            name: 'file_$i.odt',
            preview: 'p$i',
            openedAt: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
          ),
        );
      }
      final list = await service.load();
      expect(list, hasLength(RecentFilesService.maxEntries));
      // Il più recente (indice più alto) è in cima.
      expect(list.first.name, 'file_${RecentFilesService.maxEntries + 4}.odt');
    });

    test('clear svuota lo storage', () async {
      final service = RecentFilesService();
      await service.addOrPromote(
        RecentFile(
          name: 'x.odt',
          preview: '',
          openedAt: DateTime.utc(2026, 4, 30),
        ),
      );
      await service.clear();
      expect(await service.load(), isEmpty);
    });

    test('storage corrotto → lista vuota, nessun crash', () async {
      SharedPreferences.setMockInitialValues({
        'recent_files_v1': '{not valid json}',
      });
      final service = RecentFilesService();
      expect(await service.load(), isEmpty);
    });

    test(
      'voci JSON con campi mancanti vengono scartate, le altre preservate',
      () async {
        SharedPreferences.setMockInitialValues({
          'recent_files_v1':
              '[{"name":"ok.odt","preview":"p","openedAt":"2026-04-30T10:00:00.000Z"},'
              '{"name":42},'
              '{"openedAt":"2026-04-30T10:00:00.000Z"}]',
        });
        final service = RecentFilesService();
        final list = await service.load();
        expect(list, hasLength(1));
        expect(list.single.name, 'ok.odt');
      },
    );
  });

  group('RecentFilesService.previewFromDeltaOps', () {
    test('estrae solo stringhe e ignora gli embed', () {
      final ops = [
        {'insert': 'Ciao mondo'},
        {
          'insert': {'image': 'data:...'},
        },
        {'insert': '!'},
      ];
      expect(RecentFilesService.previewFromDeltaOps(ops), 'Ciao mondo!');
    });

    test('comprime whitespace e newline in singoli spazi', () {
      final ops = [
        {'insert': 'Riga 1\n\n\nRiga   2'},
      ];
      expect(RecentFilesService.previewFromDeltaOps(ops), 'Riga 1 Riga 2');
    });

    test('tronca con ellissi se più lungo del limite', () {
      final long = 'a' * 200;
      final preview = RecentFilesService.previewFromDeltaOps([
        {'insert': long},
      ]);
      expect(preview.endsWith('…'), isTrue);
      expect(
        preview.length,
        lessThanOrEqualTo(RecentFilesService.previewMaxLength + 1),
      );
    });

    test('lista vuota → stringa vuota', () {
      expect(RecentFilesService.previewFromDeltaOps([]), '');
    });
  });

  group('RecentFilesService — cache binaria', () {
    late Directory tmpDir;
    late RecentFilesService service;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('folio_recents_cache_');
      service = RecentFilesService(cacheDir: tmpDir);
    });

    tearDown(() async {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    });

    Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

    test(
      'addOrPromote con bytes scrive la cache e popola cachedPath',
      () async {
        final result = await service.addOrPromote(
          RecentFile(
            name: 'doc.odt',
            preview: 'p',
            openedAt: DateTime.utc(2026, 4, 30),
          ),
          bytes: bytes('hello'),
        );
        expect(result, hasLength(1));
        expect(result.first.cachedPath, isNotNull);
        expect(File(result.first.cachedPath!).existsSync(), isTrue);
      },
    );

    test('readCached restituisce i bytes salvati', () async {
      final result = await service.addOrPromote(
        RecentFile(
          name: 'doc.odt',
          preview: 'p',
          openedAt: DateTime.utc(2026, 4, 30),
        ),
        bytes: bytes('hello'),
      );
      final read = await service.readCached(result.first);
      expect(read, isNotNull);
      expect(String.fromCharCodes(read!), 'hello');
    });

    test('readCached su entry senza cachedPath → null', () async {
      final entry = RecentFile(
        name: 'no-cache.odt',
        preview: '',
        openedAt: DateTime.utc(2026, 4, 30),
      );
      expect(await service.readCached(entry), isNull);
    });

    test('readCached su path inesistente → null (no crash)', () async {
      final entry = RecentFile(
        name: 'gone.odt',
        preview: '',
        openedAt: DateTime.utc(2026, 4, 30),
        cachedPath: '${tmpDir.path}/recents/non-esiste.odt',
      );
      expect(await service.readCached(entry), isNull);
    });

    test('promozione di un file esistente sovrascrive la cache', () async {
      await service.addOrPromote(
        RecentFile(
          name: 'doc.odt',
          preview: 'old',
          openedAt: DateTime.utc(2026, 4, 1),
        ),
        bytes: bytes('old-content'),
      );
      final result = await service.addOrPromote(
        RecentFile(
          name: 'doc.odt',
          preview: 'new',
          openedAt: DateTime.utc(2026, 4, 30),
        ),
        bytes: bytes('new-content'),
      );
      expect(result, hasLength(1));
      final read = await service.readCached(result.first);
      expect(String.fromCharCodes(read!), 'new-content');
    });

    test('promozione senza bytes preserva il cachedPath precedente', () async {
      final first = await service.addOrPromote(
        RecentFile(
          name: 'doc.odt',
          preview: 'p',
          openedAt: DateTime.utc(2026, 4, 1),
        ),
        bytes: bytes('content'),
      );
      final initialPath = first.first.cachedPath;
      expect(initialPath, isNotNull);

      final result = await service.addOrPromote(
        RecentFile(
          name: 'doc.odt',
          preview: 'p',
          openedAt: DateTime.utc(2026, 4, 30),
        ),
      );
      expect(result.first.cachedPath, initialPath);
      final read = await service.readCached(result.first);
      expect(String.fromCharCodes(read!), 'content');
    });

    test('eviction per superamento del cap cancella i file di cache', () async {
      // Riempio oltre il cap.
      final paths = <String>[];
      for (var i = 0; i < RecentFilesService.maxEntries + 3; i++) {
        final result = await service.addOrPromote(
          RecentFile(
            name: 'file_$i.odt',
            preview: 'p',
            openedAt: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
          ),
          bytes: bytes('x'),
        );
        paths.add(result.first.cachedPath!);
      }
      // I primi 3 path devono essere stati cancellati (sono usciti dalla
      // top-N).
      for (var i = 0; i < 3; i++) {
        expect(
          File(paths[i]).existsSync(),
          isFalse,
          reason: 'cache di file_$i.odt non cancellata',
        );
      }
      // Gli ultimi maxEntries devono ancora esistere.
      for (var i = 3; i < paths.length; i++) {
        expect(File(paths[i]).existsSync(), isTrue);
      }
    });

    test('remove rimuove la voce e cancella il file di cache', () async {
      final result = await service.addOrPromote(
        RecentFile(
          name: 'doc.odt',
          preview: 'p',
          openedAt: DateTime.utc(2026, 4, 30),
        ),
        bytes: bytes('content'),
      );
      final cached = result.first.cachedPath!;
      expect(File(cached).existsSync(), isTrue);

      final after = await service.remove(result.first);
      expect(after, isEmpty);
      expect(File(cached).existsSync(), isFalse);
    });

    test('clear cancella sia la lista che tutti i file di cache', () async {
      final r1 = await service.addOrPromote(
        RecentFile(
          name: 'a.odt',
          preview: '',
          openedAt: DateTime.utc(2026, 4, 1),
        ),
        bytes: bytes('a'),
      );
      final r2 = await service.addOrPromote(
        RecentFile(
          name: 'b.odt',
          preview: '',
          openedAt: DateTime.utc(2026, 4, 2),
        ),
        bytes: bytes('b'),
      );
      final pa = r1.first.cachedPath!;
      // r2 contiene anche la entry a; prendi b da r2.first.
      final pb = r2.first.cachedPath!;

      await service.clear();
      expect(await service.load(), isEmpty);
      expect(File(pa).existsSync(), isFalse);
      expect(File(pb).existsSync(), isFalse);
    });
  });

  group('RecentFilesService — userPath', () {
    test('userPath sopravvive a save → load (round-trip JSON)', () async {
      final service = RecentFilesService();
      await service.addOrPromote(
        RecentFile(
          name: 'doc.odt',
          preview: 'p',
          openedAt: DateTime.utc(2026, 4, 30),
          userPath: '/storage/emulated/0/Folio/doc.odt',
        ),
      );
      final loaded = await service.load();
      expect(loaded.single.userPath, '/storage/emulated/0/Folio/doc.odt');
    });

    test(
      'entry legacy senza userPath → load la accetta con userPath null',
      () async {
        SharedPreferences.setMockInitialValues({
          'recent_files_v1':
              '[{"name":"legacy.odt","preview":"p",'
              '"openedAt":"2026-04-30T10:00:00.000Z",'
              '"cachedPath":"/cache/abc.odt"}]',
        });
        final service = RecentFilesService();
        final list = await service.load();
        expect(list, hasLength(1));
        expect(list.single.userPath, isNull);
        expect(list.single.cachedPath, '/cache/abc.odt');
      },
    );

    test('promozione senza userPath preserva quello precedente', () async {
      final service = RecentFilesService();
      await service.addOrPromote(
        RecentFile(
          name: 'doc.odt',
          preview: 'p',
          openedAt: DateTime.utc(2026, 4, 1),
          userPath: '/storage/emulated/0/Folio/doc.odt',
        ),
      );
      // Seconda promozione senza userPath: lo deve EREDITARE dalla
      // precedente (stesso pattern di cachedPath).
      final result = await service.addOrPromote(
        RecentFile(
          name: 'doc.odt',
          preview: 'p',
          openedAt: DateTime.utc(2026, 4, 30),
        ),
      );
      expect(result.single.userPath, '/storage/emulated/0/Folio/doc.odt');
    });
  });
}
