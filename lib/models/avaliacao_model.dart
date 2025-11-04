import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para representar uma avaliação entre usuários
class AvaliacaoModel {
  final String? avaliacaoId; // ID do documento no Firestore (gerado automaticamente)
  final String caronaId; // Referência (FK) para o documento da coleção caronas
  final String avaliadorUsuarioId; // Referência (FK) para o documento da coleção usuarios (quem avalia)
  final String avaliadoUsuarioId; // Referência (FK) para o documento da coleção usuarios (quem é avaliado)
  final double? nota; // Pontuação da avaliação (opcional)
  final String? comentario; // Texto da avaliação (opcional)
  final DateTime dataAvaliacao; // Data da avaliação (criado automaticamente)

  const AvaliacaoModel({
    this.avaliacaoId,
    required this.caronaId,
    required this.avaliadorUsuarioId,
    required this.avaliadoUsuarioId,
    this.nota,
    this.comentario,
    required this.dataAvaliacao,
  });

  /// Cria uma AvaliacaoModel a partir de um DocumentSnapshot do Firestore
  factory AvaliacaoModel.fromFirestore(dynamic doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      // Helper para converter Timestamp para DateTime
      DateTime parseDateTime(dynamic value) {
        if (value == null) return DateTime.now();
        if (value is DateTime) return value;
        if (value is Timestamp) return value.toDate();
        if (value.toString().contains('Timestamp')) {
          return (value as dynamic).toDate();
        }
        return DateTime.now();
      }
      
      return AvaliacaoModel(
        avaliacaoId: doc.id,
        caronaId: data['carona_id'] ?? '',
        avaliadorUsuarioId: data['avaliador_usuario_id'] ?? '',
        avaliadoUsuarioId: data['avaliado_usuario_id'] ?? '',
        nota: data['nota']?.toDouble(),
        comentario: data['comentario'],
        dataAvaliacao: parseDateTime(data['data_avaliacao'] ?? FieldValue.serverTimestamp()),
      );
    } catch (e) {
      throw Exception('Erro ao converter documento ${doc.id}: $e');
    }
  }

  /// Cria uma AvaliacaoModel a partir de um Map
  factory AvaliacaoModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return AvaliacaoModel(
      avaliacaoId: map['avaliacao_id'],
      caronaId: map['carona_id'] ?? '',
      avaliadorUsuarioId: map['avaliador_usuario_id'] ?? '',
      avaliadoUsuarioId: map['avaliado_usuario_id'] ?? '',
      nota: map['nota']?.toDouble(),
      comentario: map['comentario'],
      dataAvaliacao: parseDateTime(map['data_avaliacao']),
    );
  }

  /// Converte AvaliacaoModel para Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'carona_id': caronaId,
      'avaliador_usuario_id': avaliadorUsuarioId,
      'avaliado_usuario_id': avaliadoUsuarioId,
      'nota': nota,
      'comentario': comentario,
      'data_avaliacao': dataAvaliacao,
    };
  }

  /// Cria uma cópia da avaliação com campos atualizados
  AvaliacaoModel copyWith({
    String? avaliacaoId,
    String? caronaId,
    String? avaliadorUsuarioId,
    String? avaliadoUsuarioId,
    double? nota,
    String? comentario,
    DateTime? dataAvaliacao,
  }) {
    return AvaliacaoModel(
      avaliacaoId: avaliacaoId ?? this.avaliacaoId,
      caronaId: caronaId ?? this.caronaId,
      avaliadorUsuarioId: avaliadorUsuarioId ?? this.avaliadorUsuarioId,
      avaliadoUsuarioId: avaliadoUsuarioId ?? this.avaliadoUsuarioId,
      nota: nota ?? this.nota,
      comentario: comentario ?? this.comentario,
      dataAvaliacao: dataAvaliacao ?? this.dataAvaliacao,
    );
  }

  @override
  String toString() {
    return 'AvaliacaoModel(avaliacaoId: $avaliacaoId, caronaId: $caronaId, avaliadorUsuarioId: $avaliadorUsuarioId, avaliadoUsuarioId: $avaliadoUsuarioId, nota: $nota, comentario: $comentario, dataAvaliacao: $dataAvaliacao)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AvaliacaoModel &&
        other.avaliacaoId == avaliacaoId &&
        other.caronaId == caronaId &&
        other.avaliadorUsuarioId == avaliadorUsuarioId &&
        other.avaliadoUsuarioId == avaliadoUsuarioId;
  }

  @override
  int get hashCode {
    return avaliacaoId.hashCode ^
        caronaId.hashCode ^
        avaliadorUsuarioId.hashCode ^
        avaliadoUsuarioId.hashCode;
  }
}
