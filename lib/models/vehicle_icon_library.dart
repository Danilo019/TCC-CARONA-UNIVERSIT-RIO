import 'package:flutter/material.dart';

class VehicleIconLibrary {
  static const Map<String, IconData> icons = {
    'sedan': Icons.directions_car_filled,
    'hatch': Icons.directions_car,
    'suv': Icons.sports_motorsports,
    'pickup': Icons.local_shipping,
    'motorcycle': Icons.two_wheeler,
    'van': Icons.airport_shuttle,
  };

  static const String defaultKey = 'sedan';

  static IconData resolve(String? key) {
    if (key != null && icons.containsKey(key)) {
      return icons[key]!;
    }
    return icons[defaultKey]!;
  }

  static List<String> get keys => icons.keys.toList();
}
