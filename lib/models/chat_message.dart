/// Modelo para representar uma mensagem de chat
/// Compatível com Realtime Database e Firestore
class ChatMessage {
  final String id;
  final String rideId; // ID da carona
  final String senderId; // ID do remetente (motorista ou passageiro)
  final String senderName; // Nome do remetente
  final String? senderPhotoURL; // Foto do remetente
  final String message; // Conteúdo da mensagem
  final bool isDriver; // Se o remetente é o motorista
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoURL,
    required this.message,
    required this.isDriver,
    required this.timestamp,
  });

  /// Cria uma ChatMessage a partir de um Map (compatível com Realtime Database e Firestore)
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    try {
      DateTime parseDateTime(dynamic value) {
        if (value == null) return DateTime.now();
        if (value is DateTime) return value;
        if (value is int) {
          // Realtime Database: timestamp em milissegundos
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
        if (value is String) {
          try {
            // Tenta parsear como ISO string
            return DateTime.parse(value);
          } catch (e) {
            // Tenta como timestamp em milissegundos
            return DateTime.fromMillisecondsSinceEpoch(int.parse(value));
          }
        }
        // Para Firestore Timestamp (se ainda houver algum uso)
        if (value.toString().contains('Timestamp')) {
          return (value as dynamic).toDate();
        }
        return DateTime.now();
      }
      
      return ChatMessage(
        id: map['id'] ?? '',
        rideId: map['rideId'] ?? '',
        senderId: map['senderId'] ?? '',
        senderName: map['senderName'] ?? '',
        senderPhotoURL: map['senderPhotoURL'],
        message: map['message'] ?? '',
        isDriver: map['isDriver'] ?? false,
        timestamp: parseDateTime(map['timestamp']),
      );
    } catch (e) {
      throw Exception('Erro ao converter mensagem: $e');
    }
  }

  /// Converte ChatMessage para Map (compatível com Realtime Database)
  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoURL': senderPhotoURL,
      'message': message,
      'isDriver': isDriver,
      'timestamp': timestamp.millisecondsSinceEpoch, // Realtime Database usa int
    };
  }

  /// Converte para Map compatível com Firestore (caso necessário)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'rideId': rideId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoURL': senderPhotoURL,
      'message': message,
      'isDriver': isDriver,
      'timestamp': timestamp, // Firestore aceita DateTime diretamente
    };
  }

  @override
  String toString() {
    return 'ChatMessage($senderName: $message)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
