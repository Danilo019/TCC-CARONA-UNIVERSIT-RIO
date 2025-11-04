import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';

/// Serviço para gerenciar chat em tempo real usando Realtime Database
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  /// Reference para mensagens de chat
  DatabaseReference get _messagesRef => _database.child('chat_messages');

  // ===========================================================================
  // OPERAÇÕES DE LEITURA
  // ===========================================================================

  /// Stream de mensagens de uma carona (tempo real)
  /// 
  /// Seguindo as melhores práticas da documentação do Firebase Realtime Database:
  /// - Usa orderByChild para filtrar por rideId
  /// - Limita a última quantidade de mensagens para melhor performance
  /// - Ordena por timestamp usando o índice definido nas regras
  Stream<List<ChatMessage>> watchMessages(String rideId) {
    try {
      // Realtime Database: busca por rideId usando índice
      // limitToLast(100) garante que apenas as últimas 100 mensagens sejam carregadas
      // Isso melhora a performance e reduz o uso de banda
      return _messagesRef
          .orderByChild('rideId')
          .equalTo(rideId)
          .limitToLast(100) // Limita para melhor performance
          .onValue
          .map((event) {
        if (event.snapshot.value == null) {
          return <ChatMessage>[];
        }

        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data == null) {
          return <ChatMessage>[];
        }

        final messages = <ChatMessage>[];
        
        data.forEach((key, value) {
          try {
            if (value is Map) {
              final messageMap = Map<String, dynamic>.from(value);
              messageMap['id'] = key.toString();
              
              // Converte timestamp (pode ser int ou String)
              if (messageMap['timestamp'] != null) {
                if (messageMap['timestamp'] is int) {
                  messageMap['timestamp'] = DateTime.fromMillisecondsSinceEpoch(messageMap['timestamp'] as int);
                } else if (messageMap['timestamp'] is String) {
                  messageMap['timestamp'] = DateTime.parse(messageMap['timestamp'] as String);
                }
              }
              
              final message = ChatMessage.fromMap(messageMap);
              messages.add(message);
            }
          } catch (e) {
            if (kDebugMode) {
              print('✗ Erro ao converter mensagem $key: $e');
            }
          }
        });

        // Ordena por timestamp (mesmo com limitToLast, ordem pode não estar garantida)
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        return messages;
      });
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao observar mensagens: $e');
      }
      // Se a query falhar, retorna stream vazio
      return Stream.value(<ChatMessage>[]);
    }
  }

  /// Busca mensagens de uma carona (uma vez)
  /// 
  /// Seguindo as melhores práticas: limita resultados para melhor performance
  Future<List<ChatMessage>> getMessages(String rideId) async {
    try {
      final snapshot = await _messagesRef
          .orderByChild('rideId')
          .equalTo(rideId)
          .limitToLast(100) // Limita para melhor performance
          .get();

      if (snapshot.value == null) {
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final messages = <ChatMessage>[];
      
      data.forEach((key, value) {
        try {
          if (value is Map) {
            final messageMap = Map<String, dynamic>.from(value);
            messageMap['id'] = key.toString();
            
            if (messageMap['timestamp'] != null) {
              if (messageMap['timestamp'] is int) {
                messageMap['timestamp'] = DateTime.fromMillisecondsSinceEpoch(messageMap['timestamp'] as int);
              } else if (messageMap['timestamp'] is String) {
                messageMap['timestamp'] = DateTime.parse(messageMap['timestamp'] as String);
              }
            }
            
            final message = ChatMessage.fromMap(messageMap);
            messages.add(message);
          }
        } catch (e) {
          if (kDebugMode) {
            print('✗ Erro ao converter mensagem $key: $e');
          }
        }
      });

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar mensagens: $e');
      }
      return [];
    }
  }

  // ===========================================================================
  // OPERAÇÕES DE ESCRITA
  // ===========================================================================

  /// Envia uma mensagem
  Future<String?> sendMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    String? senderPhotoURL,
    required String message,
    required bool isDriver,
  }) async {
    try {
      if (message.trim().isEmpty) {
        return null;
      }

      final messageMap = {
        'rideId': rideId,
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoURL': senderPhotoURL,
        'message': message.trim(),
        'isDriver': isDriver,
        'timestamp': DateTime.now().millisecondsSinceEpoch, // Realtime Database usa int
      };

      // Cria referência para nova mensagem
      final messageRef = _messagesRef.push();
      await messageRef.set(messageMap);

      if (kDebugMode) {
        print('✓ Mensagem enviada: ${messageRef.key}');
      }

      return messageRef.key;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar mensagem: $e');
      }
      return null;
    }
  }

  /// Deleta uma mensagem
  Future<bool> deleteMessage(String messageId) async {
    try {
      await _messagesRef.child(messageId).remove();
      
      if (kDebugMode) {
        print('✓ Mensagem deletada: $messageId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao deletar mensagem: $e');
      }
      return false;
    }
  }
}
