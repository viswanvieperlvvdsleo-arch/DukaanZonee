// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<LatLng?> getDeviceLocation() async {
  try {
    final position = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
    );
    final coords = position.coords;
    if (coords == null) return null;
    final latitude = coords.latitude;
    final longitude = coords.longitude;
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude.toDouble(), longitude.toDouble());
  } catch (_) {
    return null;
  }
}
