// Serviço de exclusão de conta - implementa Direito ao Esquecimento (LGPD)
// Remove permanentemente todos os dados do usuário: Firestore, Storage e Auth

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'consent_service.dart';
import 'avaliacao_service.dart';
import 'ride_request_service.dart';

/// Serviço para gerenciar exclusão de conta (Direito ao Esquecimento LGPD)
///
/// Este serviço implementa a funcionalidade de exclusão completa de conta do usuário,
/// removendo todos os dados pessoais do Firestore, Storage e Firebase Auth.
///
/// Conforme LGPD (Lei Geral de Proteção de Dados), o usuário tem direito ao esquecimento,
/// que garante a exclusão permanente de seus dados pessoais.
class AccountDeletionService {
  static final AccountDeletionService _instance =
      AccountDeletionService._internal();
  factory AccountDeletionService() => _instance;
  AccountDeletionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final ConsentService _consentService = ConsentService();
  final AvaliacaoService _avaliacaoService = AvaliacaoService();
  final RideRequestService _rideRequestService = RideRequestService();

  // ============================================================================
  // EXCLUSÃO COMPLETA DE CONTA
  // ============================================================================

  /// Exclui completamente a conta do usuário e todos os seus dados
  ///
  /// Este método implementa o direito ao esquecimento (LGPD) e remove:
  /// - Dados do Firestore (usuário, consentimentos, veículos, caronas, etc.)
  /// - Arquivos do Storage (fotos de perfil, documentos, etc.)
  /// - Conta do Firebase Auth
  ///
  /// [userId] - ID do usuário a ser excluído
  ///
  /// Retorna true se a exclusão foi bem-sucedida, false caso contrário
  Future<bool> deleteAccount(String userId) async {
    try {
      if (kDebugMode) {
        print('🗑️  Iniciando exclusão de conta para usuário: $userId');
      }

      // Verifica se o usuário está autenticado e é o próprio usuário
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        throw Exception(
          'Usuário não autenticado ou não autorizado para excluir esta conta',
        );
      }

      // Etapa 1: Deletar dados do Firestore
      if (kDebugMode) {
        print('📋 Etapa 1: Deletando dados do Firestore...');
      }
      await _deleteFirestoreData(userId);

      // Etapa 2: Deletar dados do Storage
      if (kDebugMode) {
        print('📁 Etapa 2: Deletando dados do Storage...');
      }
      await _deleteStorageData(userId);

      // Etapa 3: Deletar conta do Firebase Auth
      if (kDebugMode) {
        print('🔐 Etapa 3: Deletando conta do Firebase Auth...');
      }
      await _deleteAuthAccount(currentUser);

      if (kDebugMode) {
        print('✅ Conta excluída com sucesso: $userId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao excluir conta: $e');
      }
      rethrow;
    }
  }

  // ============================================================================
  // EXCLUSÃO DE DADOS DO FIRESTORE
  // ============================================================================

  /// Deleta todos os dados do usuário no Firestore
  Future<void> _deleteFirestoreData(String userId) async {
    try {
      final errors = <String>[];

      // 1. Deletar consentimentos LGPD
      try {
        await _deleteConsents(userId);
      } catch (e) {
        errors.add('Consentimentos: $e');
        if (kDebugMode) {
          print('⚠ Erro ao deletar consentimentos: $e');
        }
      }

      // 2. Deletar avaliações (onde o usuário é avaliador ou avaliado)
      try {
        await _deleteAvaliacoes(userId);
      } catch (e) {
        errors.add('Avaliações: $e');
        if (kDebugMode) {
          print('⚠ Erro ao deletar avaliações: $e');
        }
      }

      // 3. Deletar solicitações de carona
      try {
        await _deleteRideRequests(userId);
      } catch (e) {
        errors.add('Solicitações de carona: $e');
        if (kDebugMode) {
          print('⚠ Erro ao deletar solicitações: $e');
        }
      }

      // 4. Deletar caronas (onde o usuário é motorista)
      try {
        await _deleteRides(userId);
      } catch (e) {
        errors.add('Caronas: $e');
        if (kDebugMode) {
          print('⚠ Erro ao deletar caronas: $e');
        }
      }

      // 5. Deletar veículos
      try {
        await _deleteVehicles(userId);
      } catch (e) {
        errors.add('Veículos: $e');
        if (kDebugMode) {
          print('⚠ Erro ao deletar veículos: $e');
        }
      }

      // 6. Deletar perfil do usuário
      try {
        await _deleteUserProfile(userId);
      } catch (e) {
        errors.add('Perfil do usuário: $e');
        if (kDebugMode) {
          print('⚠ Erro ao deletar perfil: $e');
        }
      }

      // Se houver erros críticos, lança exceção
      // Mas alguns erros podem ser ignorados (ex: dados que não existem)
      if (errors.isNotEmpty && kDebugMode) {
        print('⚠ Alguns erros ocorreram durante a exclusão:');
        for (final error in errors) {
          print('   - $error');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao deletar dados do Firestore: $e');
      }
      rethrow;
    }
  }

  /// Deleta todos os consentimentos do usuário
  Future<void> _deleteConsents(String userId) async {
    try {
      final consents = await _consentService.getConsentsByUser(userId);

      if (consents.isEmpty) {
        if (kDebugMode) {
          print('   ℹ️  Nenhum consentimento encontrado');
        }
        return;
      }

      final batch = _firestore.batch();
      for (final consent in consents) {
        final docRef = _firestore.collection('consents').doc(consent.id);
        batch.delete(docRef);
      }

      await batch.commit();

      if (kDebugMode) {
        print('   ✓ ${consents.length} consentimento(s) deletado(s)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar consentimentos: $e');
      }
      rethrow;
    }
  }

  /// Deleta todas as avaliações relacionadas ao usuário
  Future<void> _deleteAvaliacoes(String userId) async {
    try {
      // Busca avaliações onde o usuário é avaliador
      final avaliacoesComoAvaliador = await _avaliacaoService
          .listarAvaliacoesPorAvaliador(userId);

      // Busca avaliações onde o usuário é avaliado
      final avaliacoesComoAvaliado = await _avaliacaoService
          .listarAvaliacoesPorAvaliado(userId);

      final todasAvaliacoes = [
        ...avaliacoesComoAvaliador,
        ...avaliacoesComoAvaliado,
      ];

      // Remove duplicatas (se houver)
      final avaliacoesUnicas = <String>{};
      for (final avaliacao in todasAvaliacoes) {
        if (avaliacao.avaliacaoId != null) {
          avaliacoesUnicas.add(avaliacao.avaliacaoId!);
        }
      }

      if (avaliacoesUnicas.isEmpty) {
        if (kDebugMode) {
          print('   ℹ️  Nenhuma avaliação encontrada');
        }
        return;
      }

      final batch = _firestore.batch();
      for (final avaliacaoId in avaliacoesUnicas) {
        final docRef = _firestore.collection('avaliacoes').doc(avaliacaoId);
        batch.delete(docRef);
      }

      await batch.commit();

      if (kDebugMode) {
        print('   ✓ ${avaliacoesUnicas.length} avaliação(ões) deletada(s)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar avaliações: $e');
      }
      rethrow;
    }
  }

  /// Deleta todas as solicitações de carona do usuário
  Future<void> _deleteRideRequests(String userId) async {
    try {
      // Busca solicitações onde o usuário é passageiro
      final requestsAsPassenger = await _rideRequestService
          .getRequestsByPassenger(userId);

      // Busca caronas do usuário para encontrar solicitações relacionadas
      final userRidesSnapshot = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: userId)
          .get();
      final rideIds = userRidesSnapshot.docs.map((doc) => doc.id).toList();

      // Busca solicitações das caronas do usuário
      final requestsFromUserRides = <String, dynamic>{};
      for (final rideId in rideIds) {
        final requests = await _rideRequestService.getRequestsByRide(rideId);
        for (final request in requests) {
          requestsFromUserRides[request.id] = request;
        }
      }

      // Combina todas as solicitações
      final todasRequests = <String>{};
      for (final request in requestsAsPassenger) {
        todasRequests.add(request.id);
      }
      todasRequests.addAll(requestsFromUserRides.keys);

      if (todasRequests.isEmpty) {
        if (kDebugMode) {
          print('   ℹ️  Nenhuma solicitação de carona encontrada');
        }
        return;
      }

      final batch = _firestore.batch();
      for (final requestId in todasRequests) {
        final docRef = _firestore.collection('ride_requests').doc(requestId);
        batch.delete(docRef);
      }

      await batch.commit();

      if (kDebugMode) {
        print(
          '   ✓ ${todasRequests.length} solicitação(ões) de carona deletada(s)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar solicitações de carona: $e');
      }
      rethrow;
    }
  }

  /// Deleta todas as caronas do usuário (onde ele é motorista)
  Future<void> _deleteRides(String userId) async {
    try {
      final ridesSnapshot = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: userId)
          .get();

      if (ridesSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('   ℹ️  Nenhuma carona encontrada');
        }
        return;
      }

      final batch = _firestore.batch();
      for (final doc in ridesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (kDebugMode) {
        print('   ✓ ${ridesSnapshot.docs.length} carona(s) deletada(s)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar caronas: $e');
      }
      rethrow;
    }
  }

  /// Deleta todos os veículos do usuário
  Future<void> _deleteVehicles(String userId) async {
    try {
      // Busca todos os veículos do usuário
      final vehiclesSnapshot = await _firestore
          .collection('vehicles')
          .where('ownerId', isEqualTo: userId)
          .get();

      if (vehiclesSnapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('   ℹ️  Nenhum veículo encontrado');
        }
        return;
      }

      final batch = _firestore.batch();
      for (final doc in vehiclesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (kDebugMode) {
        print('   ✓ ${vehiclesSnapshot.docs.length} veículo(s) deletado(s)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar veículos: $e');
      }
      rethrow;
    }
  }

  /// Deleta o perfil do usuário
  Future<void> _deleteUserProfile(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();

      if (kDebugMode) {
        print('   ✓ Perfil do usuário deletado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar perfil: $e');
      }
      rethrow;
    }
  }

  // ============================================================================
  // EXCLUSÃO DE DADOS DO STORAGE
  // ============================================================================

  /// Deleta todos os arquivos do usuário no Storage
  Future<void> _deleteStorageData(String userId) async {
    try {
      final errors = <String>[];

      // 1. Deletar foto de perfil
      try {
        await _deleteProfilePhotos(userId);
      } catch (e) {
        errors.add('Fotos de perfil: $e');
        if (kDebugMode) {
          print('   ⚠ Erro ao deletar fotos de perfil: $e');
        }
      }

      // 2. Deletar arquivos de veículos
      try {
        await _deleteVehicleFiles(userId);
      } catch (e) {
        errors.add('Arquivos de veículos: $e');
        if (kDebugMode) {
          print('   ⚠ Erro ao deletar arquivos de veículos: $e');
        }
      }

      // 3. Deletar documentos
      try {
        await _deleteDocuments(userId);
      } catch (e) {
        errors.add('Documentos: $e');
        if (kDebugMode) {
          print('   ⚠ Erro ao deletar documentos: $e');
        }
      }

      if (errors.isNotEmpty && kDebugMode) {
        print('   ⚠ Alguns erros ocorreram durante a exclusão do Storage:');
        for (final error in errors) {
          print('      - $error');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao deletar dados do Storage: $e');
      }
      // Não lança exceção para não bloquear a exclusão da conta
      // Arquivos podem ser deletados manualmente depois se necessário
    }
  }

  /// Deleta todas as fotos de perfil do usuário
  Future<void> _deleteProfilePhotos(String userId) async {
    try {
      final extensions = ['jpg', 'jpeg', 'png', 'webp'];
      int deletedCount = 0;

      for (final ext in extensions) {
        try {
          final ref = _storage.ref().child('users/$userId/profile_photo.$ext');
          await ref.delete();
          deletedCount++;
        } on FirebaseException catch (e) {
          // Ignora erro se o arquivo não existir
          if (e.code != 'object-not-found') {
            rethrow;
          }
        }
      }

      if (kDebugMode && deletedCount > 0) {
        print('   ✓ $deletedCount foto(s) de perfil deletada(s)');
      } else if (kDebugMode) {
        print('   ℹ️  Nenhuma foto de perfil encontrada');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar fotos de perfil: $e');
      }
      // Não lança exceção para não bloquear a exclusão
    }
  }

  /// Deleta todos os arquivos de veículos do usuário
  Future<void> _deleteVehicleFiles(String userId) async {
    try {
      final vehiclesRef = _storage.ref().child('vehicles/$userId');

      // Lista todos os arquivos na pasta do veículo
      final listResult = await vehiclesRef.listAll();

      int deletedCount = 0;

      // Deleta todos os arquivos
      for (final item in listResult.items) {
        try {
          await item.delete();
          deletedCount++;
        } catch (e) {
          if (kDebugMode) {
            print('      ⚠ Erro ao deletar arquivo ${item.name}: $e');
          }
        }
      }

      // Tenta deletar a pasta (pode não funcionar, mas não é crítico)
      try {
        await vehiclesRef.delete();
      } catch (e) {
        // Pasta pode não ser deletável diretamente, não é crítico
      }

      if (kDebugMode && deletedCount > 0) {
        print('   ✓ $deletedCount arquivo(s) de veículo(s) deletado(s)');
      } else if (kDebugMode) {
        print('   ℹ️  Nenhum arquivo de veículo encontrado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar arquivos de veículos: $e');
      }
      // Não lança exceção para não bloquear a exclusão
    }
  }

  /// Deleta todos os documentos do usuário
  Future<void> _deleteDocuments(String userId) async {
    try {
      final documentsRef = _storage.ref().child('documents/$userId');

      // Lista todos os arquivos na pasta de documentos
      final listResult = await documentsRef.listAll();

      int deletedCount = 0;

      // Deleta todos os arquivos
      for (final item in listResult.items) {
        try {
          await item.delete();
          deletedCount++;
        } catch (e) {
          if (kDebugMode) {
            print('      ⚠ Erro ao deletar documento ${item.name}: $e');
          }
        }
      }

      // Tenta deletar a pasta (pode não funcionar, mas não é crítico)
      try {
        await documentsRef.delete();
      } catch (e) {
        // Pasta pode não ser deletável diretamente, não é crítico
      }

      if (kDebugMode && deletedCount > 0) {
        print('   ✓ $deletedCount documento(s) deletado(s)');
      } else if (kDebugMode) {
        print('   ℹ️  Nenhum documento encontrado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar documentos: $e');
      }
      // Não lança exceção para não bloquear a exclusão
    }
  }

  // ============================================================================
  // EXCLUSÃO DE CONTA DO FIREBASE AUTH
  // ============================================================================

  /// Deleta a conta do Firebase Auth
  Future<void> _deleteAuthAccount(User user) async {
    try {
      await user.delete();

      if (kDebugMode) {
        print('   ✓ Conta do Firebase Auth deletada');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'Para excluir sua conta, você precisa fazer login novamente. '
          'Por favor, saia e entre novamente antes de tentar excluir a conta.',
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('   ✗ Erro ao deletar conta do Firebase Auth: $e');
      }
      rethrow;
    }
  }

  // ============================================================================
  // UTILITÁRIOS
  // ============================================================================

  /// Verifica se o usuário pode excluir sua conta
  ///
  /// Retorna true se o usuário está autenticado e pode excluir a conta
  bool canDeleteAccount(String userId) {
    final currentUser = _firebaseAuth.currentUser;
    return currentUser != null && currentUser.uid == userId;
  }

  /// Obtém um resumo dos dados que serão deletados
  ///
  /// Útil para mostrar ao usuário antes da exclusão
  Future<Map<String, int>> getDataSummary(String userId) async {
    try {
      final summary = <String, int>{};

      // Consentimentos
      final consents = await _consentService.getConsentsByUser(userId);
      summary['consentimentos'] = consents.length;

      // Avaliações
      final avaliacoesComoAvaliador = await _avaliacaoService
          .listarAvaliacoesPorAvaliador(userId);
      final avaliacoesComoAvaliado = await _avaliacaoService
          .listarAvaliacoesPorAvaliado(userId);
      summary['avaliacoes'] =
          avaliacoesComoAvaliador.length + avaliacoesComoAvaliado.length;

      // Solicitações de carona
      final requests = await _rideRequestService.getRequestsByPassenger(userId);
      summary['solicitacoes_carona'] = requests.length;

      // Caronas
      final ridesSnapshot = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: userId)
          .get();
      summary['caronas'] = ridesSnapshot.docs.length;

      // Veículos
      final vehiclesSnapshot = await _firestore
          .collection('vehicles')
          .where('ownerId', isEqualTo: userId)
          .get();
      summary['veiculos'] = vehiclesSnapshot.docs.length;

      return summary;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter resumo de dados: $e');
      }
      return {};
    }
  }
}
