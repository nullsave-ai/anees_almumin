import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  LocationException(this.message);
  final String message;
}

class LocationService {
  Future<(double, double)> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('خدمة الموقع متوقفة. فعّلها أو اختر مدينتك يدويًا.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw LocationException('لم يتم منح إذن الموقع. اسمح به من الإعدادات أو اختر مدينتك يدويًا.');
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
      );
      return (p.latitude, p.longitude);
    } on TimeoutException {
      throw LocationException('تعذر تحديد الموقع الآن. حاول مرة أخرى أو اختر مدينتك يدويًا.');
    }
  }
}
