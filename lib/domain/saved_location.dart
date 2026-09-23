import 'models.dart';

/// A user-named location saved on this device, independently of login details.
class SavedLocation {
  const SavedLocation({required this.name, required this.location});

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final longitude = json['longitude'];
    final latitude = json['latitude'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.length > 40 ||
        longitude is! num ||
        latitude is! num) {
      throw const FormatException('Invalid saved location');
    }
    final location = SignLocation(
      longitude: longitude.toDouble(),
      latitude: latitude.toDouble(),
    );
    if (!location.isValid) throw const FormatException('Invalid coordinates');
    return SavedLocation(name: name.trim(), location: location);
  }

  final String name;
  final SignLocation location;

  Map<String, Object> toJson() => {
    'name': name,
    'longitude': location.longitude,
    'latitude': location.latitude,
  };
}
