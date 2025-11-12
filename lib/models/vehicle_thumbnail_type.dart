enum VehicleThumbnailType { photo, icon }

extension VehicleThumbnailTypeX on VehicleThumbnailType {
  static VehicleThumbnailType fromString(String? value) {
    switch (value) {
      case 'icon':
        return VehicleThumbnailType.icon;
      case 'photo':
      default:
        return VehicleThumbnailType.photo;
    }
  }

  String get asString {
    switch (this) {
      case VehicleThumbnailType.photo:
        return 'photo';
      case VehicleThumbnailType.icon:
        return 'icon';
    }
  }
}
