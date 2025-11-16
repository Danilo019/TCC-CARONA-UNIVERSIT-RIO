enum VehicleValidationStatus { pending, approved, rejected }

extension VehicleValidationStatusX on VehicleValidationStatus {
  static VehicleValidationStatus fromString(String? value) {
    switch (value) {
      case 'approved':
        return VehicleValidationStatus.approved;
      case 'rejected':
        return VehicleValidationStatus.rejected;
      case 'pending':
      default:
        return VehicleValidationStatus.pending;
    }
  }

  String get asString {
    switch (this) {
      case VehicleValidationStatus.pending:
        return 'pending';
      case VehicleValidationStatus.approved:
        return 'approved';
      case VehicleValidationStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case VehicleValidationStatus.pending:
        return 'Em análise';
      case VehicleValidationStatus.approved:
        return 'Aprovado';
      case VehicleValidationStatus.rejected:
        return 'Reprovado';
    }
  }
}
