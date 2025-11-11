import 'dart:math';

/// Utilidades para trabalhar com geohash, usadas para consultas geoespaciais
/// de caronas próximas.
class GeohashUtils {
  GeohashUtils._();

  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  static const _bits = [16, 8, 4, 2, 1];

  static final Map<String, List<String>> _borders = {
    'even': ['prxz', '028b', 'bcfguvyz', '0145hjnp'],
    'odd': ['bcfguvyz', '0145hjnp', 'prxz', '028b'],
  };

  static final Map<String, List<String>> _neighbors = {
    'even': ['bc01fg45238967deuvhjyznpkmstqrwx', '238967debc01fg45kmstqrwxuvhjyznp', 'p0r21436x8zb9dcf5h7kjnmqesgutwvy', '14365h7k9dcfesgujnmqp0r2twvyx8zb'],
    'odd': ['p0r21436x8zb9dcf5h7kjnmqesgutwvy', '14365h7k9dcfesgujnmqp0r2twvyx8zb', 'bc01fg45238967deuvhjyznpkmstqrwx', '238967debc01fg45kmstqrwxuvhjyznp'],
  };

  /// Codifica latitude/longitude em geohash.
  static String encode(
    double latitude,
    double longitude, {
    int precision = 7,
  }) {
    assert(precision > 0, 'Precisão deve ser maior que zero');

    double latMin = -90.0;
    double latMax = 90.0;
    double lonMin = -180.0;
    double lonMax = 180.0;

    final buffer = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (buffer.length < precision) {
      if (isEven) {
        final mid = (lonMin + lonMax) / 2;
        if (longitude > mid) {
          ch |= _bits[bit];
          lonMin = mid;
        } else {
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude > mid) {
          ch |= _bits[bit];
          latMin = mid;
        } else {
          latMax = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  /// Determina precisão recomendada baseada no raio (km).
  static int precisionForRadius(double radiusKm) {
    if (radiusKm >= 78) return 4; // ~39km
    if (radiusKm >= 20) return 5; // ~5km
    if (radiusKm >= 2.4) return 6; // ~1.2km
    if (radiusKm >= 0.6) return 7; // ~150m
    return 8; // <150m
  }

  /// Retorna geohash base + vizinhos imediatos.
  static Set<String> hashesForRadius(
    double latitude,
    double longitude,
    double radiusKm,
  ) {
    final precision = precisionForRadius(radiusKm);
    final center = encode(latitude, longitude, precision: precision);
    final results = <String>{center};
    results.addAll(_neighborsOf(center));
    return results;
  }

  static Set<String> _neighborsOf(String geohash) {
    final north = _adjacent(geohash, _Direction.top);
    final south = _adjacent(geohash, _Direction.bottom);
    final east = _adjacent(geohash, _Direction.right);
    final west = _adjacent(geohash, _Direction.left);

    return {
      north,
      south,
      east,
      west,
      _adjacent(north, _Direction.right),
      _adjacent(north, _Direction.left),
      _adjacent(south, _Direction.right),
      _adjacent(south, _Direction.left),
    };
  }

  static String _adjacent(String geohash, _Direction direction) {
    if (geohash.isEmpty) return geohash;

    final lastChar = geohash[geohash.length - 1];
    final type = geohash.length.isOdd ? 'odd' : 'even';
    final base = geohash.substring(0, geohash.length - 1);

    final dirIndex = direction.index;
    final neighborTable = _neighbors[type]![dirIndex];
    final borderTable = _borders[type]![dirIndex];
    final neighborIndex = neighborTable.indexOf(lastChar);

    if (neighborIndex == -1) {
      return geohash;
    }

    if (borderTable.contains(lastChar) && base.isNotEmpty) {
      final newBase = _adjacent(base, direction);
      return '$newBase${_base32[neighborIndex]}';
    }

    return '$base${_base32[neighborIndex]}';
  }

  /// Calcula limite superior (exclusive) para uma busca com prefixo.
  static String upperBoundForHash(String hash) {
    final sb = StringBuffer(hash);
    for (int i = sb.length - 1; i >= 0; i--) {
      final index = _base32.indexOf(sb.toString()[i]);
      if (index == -1) break;
      if (index < _base32.length - 1) {
        final prefix = hash.substring(0, i);
        final nextChar = _base32[index + 1];
        return '$prefix$nextChar';
      }
    }
    return hash;
  }

  /// Calcula um bounding box simples (latitude/longitude) para raio (km).
  static _BoundingBox boundingBox(
    double latitude,
    double longitude,
    double radiusKm,
  ) {
    const earthRadiusKm = 6371.0;
    final latRad = latitude * pi / 180;
    final angularDistance = radiusKm / earthRadiusKm;

    final minLat = latitude - (angularDistance * 180 / pi);
    final maxLat = latitude + (angularDistance * 180 / pi);

    final minLon = longitude -
        (angularDistance * 180 / pi) / cos(latRad.clamp(-pi / 2 + 1e-6, pi / 2 - 1e-6));
    final maxLon = longitude +
        (angularDistance * 180 / pi) / cos(latRad.clamp(-pi / 2 + 1e-6, pi / 2 - 1e-6));

    return _BoundingBox(
      minLat: min(max(minLat, -90), 90),
      maxLat: min(max(maxLat, -90), 90),
      minLon: min(max(minLon, -180), 180),
      maxLon: min(max(maxLon, -180), 180),
    );
  }
}

enum _Direction {
  top,
  bottom,
  right,
  left,
}

class _BoundingBox {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  const _BoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });
}

