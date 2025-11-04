import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Serviço para upload de arquivos
/// Suporta múltiplas estratégias:
/// 1. Firebase Storage (quando habilitado)
/// 2. Base64 no Firestore (para imagens pequenas)
/// 3. Serviços gratuitos de imagem (Imgur, etc.)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Flag para controlar qual método usar
  static const bool useFirebaseStorage = false; // Altere para true quando tiver faturamento
  static const bool useExternalService = true; // Usa Imgur como fallback

  // ===========================================================================
  // UPLOAD DE FOTOS DE PERFIL
  // ===========================================================================

  /// Faz upload da foto de perfil do usuário
  /// Tenta múltiplas estratégias: Firebase Storage > Base64 > Serviço externo
  Future<String?> uploadProfilePhoto(File file, String userId) async {
    try {
      // Verifica se o arquivo existe
      if (!await file.exists()) {
        throw Exception('Arquivo de imagem não encontrado');
      }

      final fileSize = await file.length();
      const maxSize = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxSize) {
        throw Exception('Arquivo muito grande. Máximo permitido: 5MB');
      }

      // Estratégia 1: Firebase Storage (se habilitado)
      if (useFirebaseStorage) {
        try {
          return await _uploadToFirebaseStorage(file, userId);
        } catch (e) {
          if (kDebugMode) {
            print('⚠ Firebase Storage falhou, tentando alternativa: $e');
          }
          // Continua para próxima estratégia
        }
      }

      // Estratégia 2: Base64 no Firestore (para imagens pequenas - até 300KB)
      const maxBase64Size = 300 * 1024; // 300KB
      if (fileSize <= maxBase64Size) {
        try {
          return await _uploadAsBase64(file, userId);
        } catch (e) {
          if (kDebugMode) {
            print('⚠ Base64 falhou, tentando serviço externo: $e');
          }
          // Continua para próxima estratégia
        }
      }

      // Estratégia 3: Serviço externo gratuito (Imgur)
      if (useExternalService) {
        try {
          return await _uploadToImgur(file);
        } catch (e) {
          if (kDebugMode) {
            print('⚠ Serviço externo falhou: $e');
          }
        }
      }

      throw Exception('Não foi possível fazer upload da imagem. Tente novamente mais tarde.');
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao fazer upload da foto de perfil: $e');
      }
      rethrow;
    }
  }

  /// Upload para Firebase Storage (original)
  Future<String?> _uploadToFirebaseStorage(File file, String userId) async {
    try {
      // Verifica autenticação
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception('Usuário não autenticado ou não autorizado');
      }

      await currentUser.getIdToken(true);

      final path = 'users/$userId/profile_photo.jpg';
      final ref = _storage.ref().child(path);

      if (kDebugMode) {
        print('📤 [Firebase Storage] Iniciando upload para: $path');
      }

      // Define metadata para o upload
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000', // Cache por 1 ano
      );

      final uploadTask = ref.putFile(file, metadata);
      
      // Monitora o progresso do upload
      uploadTask.snapshotEvents.listen((taskSnapshot) {
        if (kDebugMode) {
          final progress = (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
          print('📤 Upload progresso: ${progress.toStringAsFixed(1)}%');
        }
      });
      
      // Aguarda o upload completar completamente
      final snapshot = await uploadTask;
      
      // Verifica se o upload foi bem-sucedido
      if (snapshot.state == TaskState.success) {
        if (kDebugMode) {
          print('✓ Upload concluído. Obtendo URL de download...');
        }
        
        // Aguarda um breve momento para garantir que o objeto está disponível
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Tenta obter a URL de download com retry
        String? downloadUrl;
        int retries = 3;
        
        for (int i = 0; i < retries; i++) {
          try {
            downloadUrl = await snapshot.ref.getDownloadURL();
            break; // Sucesso, sai do loop
          } catch (e) {
            if (kDebugMode) {
              print('⚠ Tentativa ${i + 1}/$retries falhou ao obter URL: $e');
            }
            
            if (i < retries - 1) {
              // Aguarda um pouco antes de tentar novamente
              await Future.delayed(Duration(milliseconds: 1000 * (i + 1)));
            } else {
              // Última tentativa falhou
              throw Exception('Não foi possível obter URL após $retries tentativas: $e');
            }
          }
        }

        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          if (kDebugMode) {
            print('✓ Foto de perfil enviada com sucesso: $downloadUrl');
          }
          return downloadUrl;
        } else {
          if (kDebugMode) {
            print('✗ URL de download está vazia');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('✗ Upload falhou. Estado: ${snapshot.state}');
        }
        return null;
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print('✗ Erro Firebase ao fazer upload: ${e.code} - ${e.message}');
        
        // Mensagens específicas por código de erro
        String userMessage = 'Erro ao fazer upload da foto';
        
        if (e.code == 'object-not-found' || e.code == 'unauthorized') {
          userMessage = 'Acesso negado. Verifique se as regras do Storage estão configuradas corretamente.';
          print('⚠ Erro de acesso: Verifique se:');
          print('   1. As regras do Firebase Storage estão PUBLICADAS (não apenas salvas)');
          print('   2. O Storage está habilitado no Firebase Console');
          print('   3. O usuário está autenticado corretamente');
          print('   4. O userId na regra corresponde ao usuário autenticado');
        } else if (e.code == 'unauthenticated') {
          userMessage = 'Usuário não autenticado. Faça login novamente.';
        } else if (e.code == 'quota-exceeded') {
          userMessage = 'Limite de armazenamento excedido.';
        } else if (e.code == 'canceled') {
          userMessage = 'Upload cancelado.';
        }
        
        throw Exception(userMessage);
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao fazer upload da foto de perfil: $e');
      }
      rethrow;
    }
  }

  /// Upload como Base64 no Firestore (para imagens pequenas)
  Future<String> _uploadAsBase64(File file, String userId) async {
    if (kDebugMode) {
      print('📤 [Base64] Convertendo imagem para Base64...');
    }

    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);
    final dataUrl = 'data:image/jpeg;base64,$base64String';

    // Salva no Firestore como string Base64
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(userId).update({
      'photoURLBase64': dataUrl,
      'photoURL': dataUrl, // Também atualiza photoURL para compatibilidade
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    });

    if (kDebugMode) {
      print('✓ [Base64] Imagem salva no Firestore');
    }

    return dataUrl;
  }

  /// Upload para Imgur (serviço gratuito)
  Future<String> _uploadToImgur(File file) async {
    if (kDebugMode) {
      print('📤 [Imgur] Fazendo upload para Imgur...');
    }

    try {
      // Imgur Client ID (gratuito - você precisa criar em https://api.imgur.com/oauth2/addclient)
      // Para desenvolvimento, pode usar o client ID anônimo, mas tem limites
      const clientId = '546c25a59c58ad7'; // Client ID público do Imgur (tem limites de rate)
      
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {
          'Authorization': 'Client-ID $clientId',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image': base64Image,
          'type': 'base64',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final imageData = data['data'] as Map<String, dynamic>;
        final imageUrl = imageData['link'] as String;

        if (kDebugMode) {
          print('✓ [Imgur] Upload bem-sucedido: $imageUrl');
        }

        return imageUrl;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Imgur API error: ${error['data']['error'] ?? response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ [Imgur] Erro no upload: $e');
        print('   💡 Dica: Você pode criar uma conta gratuita em https://api.imgur.com/oauth2/addclient');
        print('   💡 E obter seu próprio Client ID para remover limites de rate');
      }
      rethrow;
    }
  }

  /// Deleta a foto de perfil antiga (se existir)
  Future<void> deleteProfilePhoto(String userId) async {
    try {
      // Remove Base64 do Firestore se existir
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userId).update({
        'photoURLBase64': FieldValue.delete(),
        'photoURL': FieldValue.delete(),
      });

      // Tenta deletar do Firebase Storage se habilitado
      if (useFirebaseStorage) {
        try {
          final path = 'users/$userId/profile_photo.jpg';
          final ref = _storage.ref().child(path);
          await ref.delete();
        } catch (e) {
          // Ignora erros de Storage
        }
      }

      if (kDebugMode) {
        print('✓ Foto de perfil deletada');
      }
    } catch (e) {
      // Não é crítico se a foto não existir
      if (kDebugMode) {
        print('⚠ Erro ao deletar foto de perfil (pode não existir): $e');
      }
    }
  }

  // ===========================================================================
  // UPLOAD DE IMAGENS GENÉRICAS
  // ===========================================================================

  /// Faz upload de uma imagem genérica para um caminho específico
  Future<String?> uploadImage(File file, String path) async {
    if (useFirebaseStorage) {
      try {
        final ref = _storage.ref().child(path);
        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        if (kDebugMode) {
          print('✗ Erro ao fazer upload da imagem: $e');
        }
        return null;
      }
    }
    // Para outras imagens, use o mesmo método de perfil
    return await uploadProfilePhoto(file, FirebaseAuth.instance.currentUser?.uid ?? 'unknown');
  }

  /// Deleta uma imagem do storage
  Future<void> deleteImage(String path) async {
    if (useFirebaseStorage) {
      try {
        final ref = _storage.ref().child(path);
        await ref.delete();
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Erro ao deletar imagem: $e');
        }
      }
    }
  }
}

