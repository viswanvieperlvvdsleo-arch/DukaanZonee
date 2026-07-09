import 'package:dukaan_zone_flutter/dukaan.dart';

class AddressService {
  Future<List<Map<String, dynamic>>> getAddresses() async {
    final res = await apiClient.getJson('/api/user/addresses');
    return List<Map<String, dynamic>>.from(res['addresses'] as List? ?? []);
  }

  Future<Map<String, dynamic>> addAddress({
    required String title,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    final res = await apiClient.postJson('/api/user/addresses', {
      'title': title,
      'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return Map<String, dynamic>.from(res['address'] as Map);
  }

  Future<void> removeAddress(String id) async {
    await apiClient.deleteJson('/api/user/addresses/$id');
  }
}

final addressService = AddressService();
