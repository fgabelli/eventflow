import 'package:flutter_test/flutter_test.dart';
import 'package:eventflow/core/utils/map_location_parser.dart';

void main() {
  group('MapLocationParser', () {
    test('converts DMS 44°45\'11.7"N 11°27\'11.9"E to 44.75325, 11.453306', () {
      final result = MapLocationParser.parse('44°45\'11.7"N 11°27\'11.9"E');
      expect(result.isValid, isTrue);
      expect(result.lat, 44.75325);
      expect(result.lng, 11.453306);
      expect(
        result.mapUrl,
        'https://www.google.com/maps/search/?api=1&query=44.75325,11.453306',
      );
    });

    test('accepts typographic quotes in DMS coordinates', () {
      final result = MapLocationParser.parse('44°45’11.7”N 11°27‘11.9“E');
      expect(result.isValid, isTrue);
      expect(result.lat, 44.75325);
      expect(result.lng, 11.453306);
      expect(
        result.mapUrl,
        'https://www.google.com/maps/search/?api=1&query=44.75325,11.453306',
      );
    });

    test('accepts decimal coordinates', () {
      final result = MapLocationParser.parse('44.75325, 11.453306');
      expect(result.isValid, isTrue);
      expect(result.lat, 44.75325);
      expect(result.lng, 11.453306);
      expect(
        result.mapUrl,
        'https://www.google.com/maps/search/?api=1&query=44.75325,11.453306',
      );
    });

    test('accepts valid Google Maps URLs', () {
      final r1 = MapLocationParser.parse('https://maps.app.goo.gl/abc123XYZ');
      expect(r1.isValid, isTrue);
      expect(r1.mapUrl, 'https://maps.app.goo.gl/abc123XYZ');
      expect(r1.lat, isNull);
      expect(r1.lng, isNull);

      final r2 = MapLocationParser.parse('https://www.google.com/maps/place/Bologna');
      expect(r2.isValid, isTrue);
      expect(r2.mapUrl, 'https://www.google.com/maps/place/Bologna');

      final r3 = MapLocationParser.parse('https://goo.gl/maps/xyz987');
      expect(r3.isValid, isTrue);
      expect(r3.mapUrl, 'https://goo.gl/maps/xyz987');
    });

    test('rejects invalid URLs and unrecognized formats', () {
      expect(MapLocationParser.parse('https://example.com/maps').isValid, isFalse);
      expect(MapLocationParser.parse('Campagne di Terre del Reno').isValid, isFalse);
      expect(MapLocationParser.parse('95.000, 11.000').isValid, isFalse);
    });

    test('empty input is valid and resolves fallback from address', () {
      final parsed = MapLocationParser.parse('   ');
      expect(parsed.isValid, isTrue);
      expect(parsed.mapUrl, isNull);

      final fallback = MapLocationParser.resolveEventMapUrl(
        isOnline: false,
        mapUrl: parsed.mapUrl,
        lat: parsed.lat,
        lng: parsed.lng,
        location: 'Campagne di Terre del Reno',
      );
      expect(
        fallback,
        'https://www.google.com/maps/search/?api=1&query=Campagne%20di%20Terre%20del%20Reno',
      );
    });
  });
}
