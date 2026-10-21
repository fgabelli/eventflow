class MapLocationParseResult {
  final bool isValid;
  final String? mapUrl;
  final double? lat;
  final double? lng;
  final String? errorKey;

  const MapLocationParseResult({
    required this.isValid,
    this.mapUrl,
    this.lat,
    this.lng,
    this.errorKey,
  });

  const MapLocationParseResult.empty()
      : isValid = true,
        mapUrl = null,
        lat = null,
        lng = null,
        errorKey = null;

  const MapLocationParseResult.invalid([this.errorKey = 'map_location_error'])
      : isValid = false,
        mapUrl = null,
        lat = null,
        lng = null;
}

class MapLocationParser {
  static final RegExp _decimalCoordsRegex = RegExp(
    r'^\s*([+-]?\d+(?:\.\d+)?)\s*(?:,\s*|\s+)\s*([+-]?\d+(?:\.\d+)?)\s*$',
  );

  static final RegExp _dmsCoordsRegex = RegExp(
    r'''^\s*(\d{1,2})\s*°\s*(\d{1,2})\s*'(?:\s*(\d{1,2}(?:[.,]\d+)?)\s*")?\s*([NS])\s*[,;\s]+\s*(\d{1,3})\s*°\s*(\d{1,2})\s*'(?:\s*(\d{1,2}(?:[.,]\d+)?)\s*")?\s*([EWO])\s*$''',
    caseSensitive: false,
  );

  /// Parses user input from the optional "Posizione su mappa" field.
  ///
  /// Accepts:
  /// 1. Empty string -> valid, no custom mapUrl/lat/lng (fallback to address query at display time)
  /// 2. Google Maps URL (`https://maps.app.goo.gl/...`, `https://www.google.com/maps/...`, `https://goo.gl/maps/...`)
  /// 3. Decimal coordinates (`44.75325, 11.453306`)
  /// 4. DMS coordinates (`44°45'11.7"N 11°27'11.9"E`), including typographic quotes
  static MapLocationParseResult parse(String? rawInput) {
    final trimmed = rawInput?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const MapLocationParseResult.empty();
    }

    // 1. Check if it's a Google Maps URL
    if (_looksLikeUrl(trimmed)) {
      if (_isValidGoogleMapsUrl(trimmed)) {
        return MapLocationParseResult(
          isValid: true,
          mapUrl: trimmed,
          lat: null,
          lng: null,
        );
      }
      return const MapLocationParseResult.invalid();
    }

    // 2. Check if it's decimal coordinates (e.g. 44.75325, 11.453306)
    final decMatch = _decimalCoordsRegex.firstMatch(trimmed);
    if (decMatch != null) {
      final latRaw = double.tryParse(decMatch.group(1)!);
      final lngRaw = double.tryParse(decMatch.group(2)!);
      if (latRaw != null &&
          lngRaw != null &&
          latRaw >= -90.0 &&
          latRaw <= 90.0 &&
          lngRaw >= -180.0 &&
          lngRaw <= 180.0) {
        final lat = _round6(latRaw);
        final lng = _round6(lngRaw);
        return MapLocationParseResult(
          isValid: true,
          mapUrl: buildCoordsMapsUrl(lat, lng),
          lat: lat,
          lng: lng,
        );
      }
      return const MapLocationParseResult.invalid();
    }

    // 3. Check if it's DMS coordinates (e.g. 44°45'11.7"N 11°27'11.9"E)
    final normalizedDms = _normalizeDmsQuotes(trimmed);
    final dmsMatch = _dmsCoordsRegex.firstMatch(normalizedDms);
    if (dmsMatch != null) {
      final latDeg = int.tryParse(dmsMatch.group(1)!);
      final latMin = int.tryParse(dmsMatch.group(2)!);
      final latSecStr = dmsMatch.group(3)?.replaceAll(',', '.') ?? '0';
      final latSec = double.tryParse(latSecStr);
      final latDir = dmsMatch.group(4)!.toUpperCase();

      final lngDeg = int.tryParse(dmsMatch.group(5)!);
      final lngMin = int.tryParse(dmsMatch.group(6)!);
      final lngSecStr = dmsMatch.group(7)?.replaceAll(',', '.') ?? '0';
      final lngSec = double.tryParse(lngSecStr);
      final lngDir = dmsMatch.group(8)!.toUpperCase();

      if (latDeg != null &&
          latMin != null &&
          latSec != null &&
          lngDeg != null &&
          lngMin != null &&
          lngSec != null &&
          latMin >= 0 &&
          latMin < 60 &&
          latSec >= 0 &&
          latSec < 60 &&
          lngMin >= 0 &&
          lngMin < 60 &&
          lngSec >= 0 &&
          lngSec < 60) {
        double latVal = latDeg + (latMin / 60.0) + (latSec / 3600.0);
        if (latDir == 'S') latVal = -latVal;

        double lngVal = lngDeg + (lngMin / 60.0) + (lngSec / 3600.0);
        if (lngDir == 'W' || lngDir == 'O') lngVal = -lngVal;

        if (latVal >= -90.0 &&
            latVal <= 90.0 &&
            lngVal >= -180.0 &&
            lngVal <= 180.0) {
          final lat = _round6(latVal);
          final lng = _round6(lngVal);
          return MapLocationParseResult(
            isValid: true,
            mapUrl: buildCoordsMapsUrl(lat, lng),
            lat: lat,
            lng: lng,
          );
        }
      }
      return const MapLocationParseResult.invalid();
    }

    return const MapLocationParseResult.invalid();
  }

  static bool _looksLikeUrl(String input) {
    final lower = input.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.') ||
        lower.startsWith('maps.');
  }

  static bool _isValidGoogleMapsUrl(String input) {
    if (input.contains(' ')) return false;
    final uri = Uri.tryParse(input);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    final host = uri.host.toLowerCase();
    final path = uri.path;

    // https://maps.app.goo.gl/...
    if (host == 'maps.app.goo.gl') {
      return path.length > 1;
    }

    // https://goo.gl/maps/...
    if (host == 'goo.gl') {
      return path.startsWith('/maps/') && path.length > '/maps/'.length;
    }

    // https://www.google.com/maps/... (and google.com/maps/..., google.it/maps/..., maps.google.com/...)
    if (host == 'www.google.com' ||
        host == 'google.com' ||
        host == 'www.google.it' ||
        host == 'google.it') {
      return path.startsWith('/maps') && path.length > '/maps'.length;
    }

    if (host == 'maps.google.com' || host == 'maps.google.it') {
      return path.isNotEmpty;
    }

    return false;
  }

  static String _normalizeDmsQuotes(String input) {
    return input
        .replaceAll("''", '"')
        .replaceAll('’’', '"')
        .replaceAll('‘’', '"')
        .replaceAll('′′', '"')
        .replaceAll(RegExp(r'[“”″«»]'), '"')
        .replaceAll(RegExp(r"[‘’′´`]"), "'")
        .replaceAll(RegExp(r'[º˚]'), '°');
  }

  static double _round6(double value) {
    return double.parse(value.toStringAsFixed(6));
  }

  static String buildCoordsMapsUrl(double lat, double lng) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  static String buildAddressMapsUrl(String address) {
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.trim())}';
  }

  /// Resolves the best Google Maps URL for an event given its stored fields.
  static String? resolveEventMapUrl({
    required bool isOnline,
    String? mapUrl,
    double? lat,
    double? lng,
    String? location,
  }) {
    if (isOnline) return null;
    if (mapUrl != null && mapUrl.trim().isNotEmpty) {
      return mapUrl.trim();
    }
    if (lat != null && lng != null) {
      return buildCoordsMapsUrl(lat, lng);
    }
    if (location != null && location.trim().isNotEmpty) {
      return buildAddressMapsUrl(location);
    }
    return null;
  }

  /// Returns the initial text to populate the "Posizione su mappa" field when editing an event.
  static String initialInputForEdit({
    String? mapUrl,
    double? lat,
    double? lng,
    String? location,
  }) {
    if (lat != null && lng != null) {
      return '$lat, $lng';
    }
    if (mapUrl != null && mapUrl.trim().isNotEmpty) {
      final trimmedUrl = mapUrl.trim();
      if (location != null &&
          location.trim().isNotEmpty &&
          trimmedUrl == buildAddressMapsUrl(location)) {
        return '';
      }
      return trimmedUrl;
    }
    return '';
  }
}
