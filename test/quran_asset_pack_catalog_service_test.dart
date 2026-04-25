import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_asset_pack_catalog_service.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_settings.dart';

void main() {
  group('QuranAssetPackCatalogService', () {
    test('default packs include every supported edition', () {
      final packs = QuranAssetPackCatalogService.defaultPacks();

      expect(packs.map((pack) => pack.edition), MushafEdition.values);
      expect(
        packs.every((pack) => pack.url.startsWith('https://')),
        isTrue,
      );
    });

    test('partial server catalogs are merged with fallback ZIP URLs', () {
      final packs = QuranAssetPackCatalogService.packsFromUrls(
        const <String, String>{
          '10_line': 'https://cdn.example.com/10_line.zip',
          'kanzul_iman': 'https://cdn.example.com/kanzul_iman.zip',
        },
        fillMissingWithFallback: true,
      );

      expect(packs.map((pack) => pack.edition), MushafEdition.values);
      expect(
        packs.singleWhere((pack) => pack.edition == MushafEdition.lines10).url,
        'https://cdn.example.com/10_line.zip',
      );
      expect(
        packs.singleWhere((pack) => pack.edition == MushafEdition.lines16).url,
        QuranAssetPackCatalogService.fallbackZipUrls['16_line'],
      );
    });

    test('invalid catalog entries are ignored', () {
      final packs = QuranAssetPackCatalogService.packsFromUrls(
        const <String, String>{
          '10_line': 'not-a-url',
          '13_line': 'file:///tmp/13_line.zip',
          '16_line': 'https://cdn.example.com/16_line.zip',
        },
      );

      expect(packs.map((pack) => pack.edition), <MushafEdition>[
        MushafEdition.lines16,
      ]);
    });
  });
}
