class Pharmacy {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? distanceMeters;
  final bool? isOpen;
  final double? rating;
  final String? phone;

  Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
    this.isOpen,
    this.rating,
    this.phone,
  });

  String get formattedDistance {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()} m';
    }
    final km = distanceMeters! / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  factory Pharmacy.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return Pharmacy(
      id: id.isNotEmpty ? id : (data['id']?.toString() ?? ''),
      name: data['name'] as String? ?? 'Pharmacy',
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
      isOpen: data['isOpen'] as bool?,
      rating: (data['rating'] as num?)?.toDouble(),
      phone: data['phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'isOpen': isOpen,
      'rating': rating,
      'phone': phone,
    };
  }
}
