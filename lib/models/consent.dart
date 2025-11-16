import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para representar consentimento LGPD
class Consent {
  final String id;
  final String userId;
  final String email;
  final String consentType; // 'privacy_policy', 'terms_of_service', 'data_processing', etc.
  final bool accepted;
  final String version; // Versão da política aceita
  final DateTime acceptedAt;
  final String? ipAddress; // Opcional: IP do usuário
  final String? userAgent; // Opcional: User agent do dispositivo

  const Consent({
    required this.id,
    required this.userId,
    required this.email,
    required this.consentType,
    required this.accepted,
    required this.version,
    required this.acceptedAt,
    this.ipAddress,
    this.userAgent,
  });

  /// Cria Consent a partir de um DocumentSnapshot do Firestore
  factory Consent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Consent(
      id: doc.id,
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      consentType: data['consentType'] ?? '',
      accepted: data['accepted'] ?? false,
      version: data['version'] ?? '1.0',
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ipAddress: data['ipAddress'],
      userAgent: data['userAgent'],
    );
  }

  /// Converte Consent para Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'consentType': consentType,
      'accepted': accepted,
      'version': version,
      'acceptedAt': Timestamp.fromDate(acceptedAt),
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (userAgent != null) 'userAgent': userAgent,
    };
  }

  /// Cria uma cópia do consentimento com campos atualizados
  Consent copyWith({
    String? id,
    String? userId,
    String? email,
    String? consentType,
    bool? accepted,
    String? version,
    DateTime? acceptedAt,
    String? ipAddress,
    String? userAgent,
  }) {
    return Consent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      consentType: consentType ?? this.consentType,
      accepted: accepted ?? this.accepted,
      version: version ?? this.version,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  @override
  String toString() {
    return 'Consent(id: $id, userId: $userId, type: $consentType, accepted: $accepted, version: $version)';
  }
}

