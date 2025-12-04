// Modelo que representa um veículo cadastrado no sistema
// Inclui dados do veículo, documentação e status de validação

import 'package:cloud_firestore/cloud_firestore.dart';

import 'vehicle_validation_status.dart';
import 'vehicle_thumbnail_type.dart';

// Classe que armazena informações completas do veículo
// Suporta foto, documentação (CNH/CRLV) e sistema de validação administrativa
class Vehicle {
  final String id;
  final String driverId; // ID do motorista proprietário
  final String brand; // Marca
  final String model; // Modelo
  final int year; // Ano
  final String color; // Cor
  final String plate; // Placa (AAA-0A00 ou Mercosul)
  final String? vehiclePhotoURL; // URL da foto do veículo no Storage
  final bool hasCnhDocument; // Indica que a CNH foi entregue/validada
  final bool hasCrlvDocument; // Indica que o CRLV foi entregue/validado
  final String? documentNote; // Observações sobre entrega de documentos
  final VehicleValidationStatus validationStatus;
  final VehicleThumbnailType thumbnailType;
  final String? iconName;
  final int? iconColorValue;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Vehicle({
    required this.id,
    required this.driverId,
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.plate,
    this.vehiclePhotoURL,
    this.hasCnhDocument = false,
    this.hasCrlvDocument = false,
    this.documentNote,
    this.validationStatus = VehicleValidationStatus.pending,
    this.thumbnailType = VehicleThumbnailType.photo,
    this.iconName,
    this.iconColorValue,
    required this.createdAt,
    this.updatedAt,
  });

  /// Cria um Vehicle a partir de um DocumentSnapshot do Firestore
  factory Vehicle.fromFirestore(dynamic doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;

      DateTime parseDateTime(dynamic value) {
        if (value == null) return DateTime.now();
        if (value is DateTime) return value;
        if (value is Timestamp) return value.toDate();
        if (value.toString().contains('Timestamp')) {
          return (value as dynamic).toDate();
        }
        return DateTime.now();
      }

      return Vehicle(
        id: doc.id,
        driverId: data['driverId'] ?? '',
        brand: data['brand'] ?? '',
        model: data['model'] ?? '',
        year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
        color: data['color'] ?? '',
        plate: data['plate'] ?? '',
        vehiclePhotoURL: data['vehiclePhotoURL'],
        hasCnhDocument: data['hasCnhDocument'] as bool? ?? false,
        hasCrlvDocument: data['hasCrlvDocument'] as bool? ?? false,
        documentNote: data['documentNote'],
        validationStatus: VehicleValidationStatusX.fromString(
          data['validationStatus'] as String?,
        ),
        thumbnailType: VehicleThumbnailTypeX.fromString(
          data['thumbnailType'] as String?,
        ),
        iconName: data['iconName'],
        iconColorValue: (data['iconColorValue'] as num?)?.toInt(),
        createdAt: parseDateTime(data['createdAt']),
        updatedAt: data['updatedAt'] != null
            ? parseDateTime(data['updatedAt'])
            : null,
      );
    } catch (e) {
      throw Exception('Erro ao converter documento ${doc.id}: $e');
    }
  }

  /// Converte Vehicle para Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'plate': plate,
      'vehiclePhotoURL': vehiclePhotoURL,
      'hasCnhDocument': hasCnhDocument,
      'hasCrlvDocument': hasCrlvDocument,
      'documentNote': documentNote,
      'validationStatus': validationStatus.asString,
      'thumbnailType': thumbnailType.asString,
      'iconName': iconName,
      'iconColorValue': iconColorValue,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Cria uma cópia do veículo com campos atualizados
  Vehicle copyWith({
    String? id,
    String? driverId,
    String? brand,
    String? model,
    int? year,
    String? color,
    String? plate,
    String? vehiclePhotoURL,
    bool? hasCnhDocument,
    bool? hasCrlvDocument,
    String? documentNote,
    VehicleValidationStatus? validationStatus,
    VehicleThumbnailType? thumbnailType,
    String? iconName,
    int? iconColorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      plate: plate ?? this.plate,
      vehiclePhotoURL: vehiclePhotoURL ?? this.vehiclePhotoURL,
      hasCnhDocument: hasCnhDocument ?? this.hasCnhDocument,
      hasCrlvDocument: hasCrlvDocument ?? this.hasCrlvDocument,
      documentNote: documentNote ?? this.documentNote,
      validationStatus: validationStatus ?? this.validationStatus,
      thumbnailType: thumbnailType ?? this.thumbnailType,
      iconName: iconName ?? this.iconName,
      iconColorValue: iconColorValue ?? this.iconColorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verifica se o veículo está completamente cadastrado
  /// (tem todos os documentos obrigatórios)
  bool get isComplete {
    final hasVisual = thumbnailType == VehicleThumbnailType.icon
        ? iconName != null && iconColorValue != null
        : vehiclePhotoURL != null;

    return hasVisual &&
        hasCnhDocument &&
        hasCrlvDocument &&
        brand.isNotEmpty &&
        model.isNotEmpty &&
        color.isNotEmpty &&
        plate.isNotEmpty;
  }

  /// Valida formato de placa brasileira
  /// Aceita: AAA-0A00 (antiga) ou AAA0A00 (Mercosul)
  static bool isValidPlate(String plate) {
    if (plate.isEmpty) return false;

    // Remove espaços e converte para maiúsculo
    final cleanPlate = plate.replaceAll(' ', '').toUpperCase();

    // Formato antigo: AAA-0000 ou AAA0000
    final oldPattern = RegExp(r'^[A-Z]{3}[-]?[0-9]{4}$');

    // Formato Mercosul: AAA0A00 ou AAA0A00 (sem hífen opcional)
    final mercosulPattern = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$');

    return oldPattern.hasMatch(cleanPlate) ||
        mercosulPattern.hasMatch(cleanPlate);
  }

  /// Formata a placa para exibição (AAA-0A00)
  static String formatPlate(String plate) {
    final cleanPlate = plate
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .toUpperCase();

    if (cleanPlate.length == 7) {
      // Formato antigo: AAA-0000
      if (RegExp(r'^[A-Z]{3}[0-9]{4}$').hasMatch(cleanPlate)) {
        return '${cleanPlate.substring(0, 3)}-${cleanPlate.substring(3)}';
      }
      // Formato Mercosul: AAA0A00
      if (RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$').hasMatch(cleanPlate)) {
        return '${cleanPlate.substring(0, 3)}-${cleanPlate.substring(3)}';
      }
    }

    return plate; // Retorna original se não conseguir formatar
  }

  /// Valida o ano do veículo
  static bool isValidYear(int year) {
    final currentYear = DateTime.now().year;
    return year >= 1980 && year <= currentYear;
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, $brand $model $year, placa: $plate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
