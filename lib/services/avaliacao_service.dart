// Serviço de avaliações - gerencia sistema de reputação de usuários
// Valida referências, impede autoavaliação e calcula médias de notas

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/avaliacao_model.dart';
import '../models/carona_pendente_avaliacao.dart';

/// Serviço para gerenciar avaliações no Firestore
class AvaliacaoService {
  static final AvaliacaoService _instance = AvaliacaoService._internal();
  factory AvaliacaoService() => _instance;
  AvaliacaoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection references
  CollectionReference get _avaliacoesCollection =>
      _firestore.collection('avaliacoes');
  CollectionReference get _caronasCollection => _firestore.collection('rides');
  CollectionReference get _usuariosCollection => _firestore.collection('users');

  // ===========================================================================
  // VALIDAÇÕES
  // ===========================================================================

  /// Valida se a carona existe na coleção caronas
  Future<bool> _validarCaronaExiste(String caronaId) async {
    try {
      final doc = await _caronasCollection.doc(caronaId).get();
      return doc.exists;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao validar carona: $e');
      }
      return false;
    }
  }

  /// Valida se o usuário existe na coleção usuarios
  Future<bool> _validarUsuarioExiste(String usuarioId) async {
    try {
      final doc = await _usuariosCollection.doc(usuarioId).get();
      return doc.exists;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao validar usuário: $e');
      }
      return false;
    }
  }

  /// Valida todas as referências antes de criar uma avaliação
  Future<void> _validarReferencias({
    required String caronaId,
    required String avaliadorUsuarioId,
    required String avaliadoUsuarioId,
  }) async {
    // Valida que os IDs não estão vazios
    if (caronaId.isEmpty) {
      throw Exception('ID da carona não pode estar vazio');
    }
    if (avaliadorUsuarioId.isEmpty) {
      throw Exception('ID do avaliador não pode estar vazio');
    }
    if (avaliadoUsuarioId.isEmpty) {
      throw Exception('ID do avaliado não pode estar vazio');
    }

    // Valida que o avaliador não está se avaliando
    if (avaliadorUsuarioId.trim() == avaliadoUsuarioId.trim()) {
      if (kDebugMode) {
        print(
          '⚠ Tentativa de autoavaliação detectada: avaliador=$avaliadorUsuarioId, avaliado=$avaliadoUsuarioId',
        );
      }
      throw Exception('Um usuário não pode se avaliar');
    }

    // Valida carona (com tratamento de erro de permissão)
    try {
      final caronaExiste = await _validarCaronaExiste(caronaId);
      if (!caronaExiste) {
        throw Exception('A carona especificada não existe');
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Permissão negada: Verifique as regras do Firestore para a coleção "rides"',
        );
      }
      rethrow;
    }

    // Valida avaliador (com tratamento de erro de permissão)
    try {
      final avaliadorExiste = await _validarUsuarioExiste(avaliadorUsuarioId);
      if (!avaliadorExiste) {
        throw Exception('O usuário avaliador não existe');
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Permissão negada: Verifique as regras do Firestore para a coleção "users"',
        );
      }
      rethrow;
    }

    // Valida avaliado (com tratamento de erro de permissão)
    try {
      final avaliadoExiste = await _validarUsuarioExiste(avaliadoUsuarioId);
      if (!avaliadoExiste) {
        throw Exception('O usuário avaliado não existe');
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'Permissão negada: Verifique as regras do Firestore para a coleção "users"',
        );
      }
      rethrow;
    }
  }

  // ===========================================================================
  // OPERAÇÕES CRUD
  // ===========================================================================

  /// Cria uma nova avaliação no Firestore
  /// Valida todas as referências antes de criar
  Future<String> criarAvaliacao(AvaliacaoModel avaliacao) async {
    try {
      if (kDebugMode) {
        print('📝 Criando avaliação:');
        print('  - Carona ID: ${avaliacao.caronaId}');
        print('  - Avaliador ID: ${avaliacao.avaliadorUsuarioId}');
        print('  - Avaliado ID: ${avaliacao.avaliadoUsuarioId}');
        print('  - Nota: ${avaliacao.nota}');
      }

      // Valida todas as referências
      await _validarReferencias(
        caronaId: avaliacao.caronaId,
        avaliadorUsuarioId: avaliacao.avaliadorUsuarioId,
        avaliadoUsuarioId: avaliacao.avaliadoUsuarioId,
      );

      // Prepara os dados para salvar
      final avaliacaoData = avaliacao.toMap();
      avaliacaoData['data_avaliacao'] = FieldValue.serverTimestamp();

      if (kDebugMode) {
        print('💾 Salvando avaliação no Firestore...');
      }

      // Cria o documento no Firestore
      final docRef = await _avaliacoesCollection.add(avaliacaoData);

      // Atualiza a média de avaliações do usuário avaliado
      if (avaliacao.nota != null) {
        try {
          await _atualizarMediaAvaliacoes(avaliacao.avaliadoUsuarioId);
        } catch (e) {
          if (kDebugMode) {
            print('⚠ Erro ao atualizar média de avaliações (não crítico): $e');
          }
          // Não bloqueia a criação da avaliação se falhar ao atualizar a média
        }
      }

      if (kDebugMode) {
        print('✓ Avaliação criada com sucesso: ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar avaliação: $e');
        if (e.toString().contains('permission-denied')) {
          print(
            '💡 Configure as regras do Firestore para permitir escrita na coleção "avaliacoes"',
          );
        }
      }
      rethrow;
    }
  }

  /// Lista todas as avaliações de uma carona específica
  Future<List<AvaliacaoModel>> listarAvaliacoesPorCarona(
    String caronaId,
  ) async {
    try {
      final querySnapshot = await _avaliacoesCollection
          .where('carona_id', isEqualTo: caronaId)
          .orderBy('data_avaliacao', descending: true)
          .get();

      final avaliacoes = <AvaliacaoModel>[];

      for (var doc in querySnapshot.docs) {
        try {
          final avaliacao = AvaliacaoModel.fromFirestore(doc);
          avaliacoes.add(avaliacao);
        } catch (e) {
          if (kDebugMode) {
            print('✗ Erro ao converter avaliação ${doc.id}: $e');
          }
        }
      }

      if (kDebugMode) {
        print(
          '✓ ${avaliacoes.length} avaliações encontradas para carona: $caronaId',
        );
      }

      return avaliacoes;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao listar avaliações por carona: $e');
      }
      return [];
    }
  }

  /// Lista todas as avaliações feitas por um usuário (avaliador)
  Future<List<AvaliacaoModel>> listarAvaliacoesPorAvaliador(
    String usuarioId,
  ) async {
    try {
      final querySnapshot = await _avaliacoesCollection
          .where('avaliador_usuario_id', isEqualTo: usuarioId)
          .orderBy('data_avaliacao', descending: true)
          .get();

      final avaliacoes = <AvaliacaoModel>[];

      for (var doc in querySnapshot.docs) {
        try {
          final avaliacao = AvaliacaoModel.fromFirestore(doc);
          avaliacoes.add(avaliacao);
        } catch (e) {
          if (kDebugMode) {
            print('✗ Erro ao converter avaliação ${doc.id}: $e');
          }
        }
      }

      if (kDebugMode) {
        print(
          '✓ ${avaliacoes.length} avaliações encontradas feitas por: $usuarioId',
        );
      }

      return avaliacoes;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao listar avaliações por avaliador: $e');
      }
      return [];
    }
  }

  /// Lista todas as avaliações recebidas por um usuário (avaliado)
  Future<List<AvaliacaoModel>> listarAvaliacoesPorAvaliado(
    String usuarioId,
  ) async {
    try {
      final querySnapshot = await _avaliacoesCollection
          .where('avaliado_usuario_id', isEqualTo: usuarioId)
          .orderBy('data_avaliacao', descending: true)
          .get();

      final avaliacoes = <AvaliacaoModel>[];

      for (var doc in querySnapshot.docs) {
        try {
          final avaliacao = AvaliacaoModel.fromFirestore(doc);
          avaliacoes.add(avaliacao);
        } catch (e) {
          if (kDebugMode) {
            print('✗ Erro ao converter avaliação ${doc.id}: $e');
          }
        }
      }

      if (kDebugMode) {
        print(
          '✓ ${avaliacoes.length} avaliações encontradas recebidas por: $usuarioId',
        );
      }

      return avaliacoes;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao listar avaliações por avaliado: $e');
      }
      return [];
    }
  }

  /// Deleta uma avaliação pelo ID
  Future<void> deletarAvaliacao(String avaliacaoId) async {
    try {
      // Busca a avaliação antes de deletar para atualizar a média
      final doc = await _avaliacoesCollection.doc(avaliacaoId).get();

      if (!doc.exists) {
        throw Exception('Avaliação não encontrada');
      }

      final data = doc.data() as Map<String, dynamic>;
      final avaliadoUsuarioId = data['avaliado_usuario_id'] as String;

      // Deleta a avaliação
      await _avaliacoesCollection.doc(avaliacaoId).delete();

      // Atualiza a média de avaliações do usuário
      await _atualizarMediaAvaliacoes(avaliadoUsuarioId);

      if (kDebugMode) {
        print('✓ Avaliação deletada com sucesso: $avaliacaoId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao deletar avaliação: $e');
      }
      rethrow;
    }
  }

  /// Busca uma avaliação específica pelo ID
  Future<AvaliacaoModel?> buscarAvaliacaoPorId(String avaliacaoId) async {
    try {
      final doc = await _avaliacoesCollection.doc(avaliacaoId).get();

      if (!doc.exists) {
        return null;
      }

      return AvaliacaoModel.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar avaliação: $e');
      }
      return null;
    }
  }

  /// Verifica se o avaliador já avaliou o avaliado nesta carona
  Future<bool> verificarAvaliacaoExistente({
    required String caronaId,
    required String avaliadorUsuarioId,
    required String avaliadoUsuarioId,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 Verificando avaliação existente:');
        print('  - Carona ID: $caronaId');
        print('  - Avaliador ID: $avaliadorUsuarioId');
        print('  - Avaliado ID: $avaliadoUsuarioId');
      }

      final querySnapshot = await _avaliacoesCollection
          .where('carona_id', isEqualTo: caronaId)
          .where('avaliador_usuario_id', isEqualTo: avaliadorUsuarioId)
          .where('avaliado_usuario_id', isEqualTo: avaliadoUsuarioId)
          .limit(1)
          .get();

      final existe = querySnapshot.docs.isNotEmpty;

      if (kDebugMode) {
        print(
          '${existe ? "✓" : "✗"} Avaliação ${existe ? "já existe" : "não existe"}',
        );
      }

      return existe;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao verificar avaliação existente: $e');
        if (e.toString().contains('permission-denied')) {
          print(
            '💡 Configure as regras do Firestore para permitir leitura na coleção "avaliacoes"',
          );
        }
      }
      // Retorna false em caso de erro para não bloquear o fluxo
      return false;
    }
  }

  // ===========================================================================
  // MÉDIA DE AVALIAÇÕES
  // ===========================================================================

  /// Calcula e atualiza a média de avaliações de um usuário
  Future<void> _atualizarMediaAvaliacoes(String usuarioId) async {
    try {
      // Busca todas as avaliações recebidas pelo usuário que têm nota
      final avaliacoes = await listarAvaliacoesPorAvaliado(usuarioId);

      // Filtra apenas avaliações com nota
      final avaliacoesComNota = avaliacoes
          .where((a) => a.nota != null)
          .toList();

      if (avaliacoesComNota.isEmpty) {
        // Se não há avaliações com nota, remove o campo mediaAvaliacoes
        await _usuariosCollection.doc(usuarioId).update({
          'mediaAvaliacoes': FieldValue.delete(),
          'totalAvaliacoes': 0,
        });
        return;
      }

      // Calcula a média
      final somaNotas = avaliacoesComNota
          .map((a) => a.nota!)
          .reduce((a, b) => a + b);
      final media = somaNotas / avaliacoesComNota.length;

      // Atualiza no Firestore
      await _usuariosCollection.doc(usuarioId).update({
        'mediaAvaliacoes': double.parse(media.toStringAsFixed(2)),
        'totalAvaliacoes': avaliacoesComNota.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print(
          '✓ Média de avaliações atualizada para $usuarioId: $media (${avaliacoesComNota.length} avaliações)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao atualizar média de avaliações: $e');
      }
      // Não lança exceção para não quebrar o fluxo principal
    }
  }

  /// Obtém a média de avaliações de um usuário
  Future<double?> obterMediaAvaliacoes(String usuarioId) async {
    try {
      final doc = await _usuariosCollection.doc(usuarioId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        return null;
      }

      final media = data['mediaAvaliacoes'];
      if (media == null) {
        return null;
      }

      return (media as num).toDouble();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter média de avaliações: $e');
      }
      return null;
    }
  }

  /// Obtém o total de avaliações de um usuário
  Future<int> obterTotalAvaliacoes(String usuarioId) async {
    try {
      final doc = await _usuariosCollection.doc(usuarioId).get();

      if (!doc.exists) {
        return 0;
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        return 0;
      }

      final total = data['totalAvaliacoes'];
      if (total == null) {
        return 0;
      }

      return (total as num).toInt();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter total de avaliações: $e');
      }
      return 0;
    }
  }

  // ===========================================================================
  // CARONAS PENDENTES DE AVALIAÇÃO
  // ===========================================================================

  /// Busca caronas concluídas onde o usuário é motorista e precisa avaliar passageiros
  /// Retorna lista de passageiros que ainda não foram avaliados
  Future<List<CaronaPendenteAvaliacao>> buscarCaronasPendentesComoMotorista(
    String motoristaId,
  ) async {
    try {
      // Busca caronas concluídas onde o usuário é motorista
      final ridesSnapshot = await _caronasCollection
          .where('driverId', isEqualTo: motoristaId)
          .where('status', isEqualTo: 'completed')
          .get();

      final pendentes = <CaronaPendenteAvaliacao>[];

      for (final rideDoc in ridesSnapshot.docs) {
        final rideData = rideDoc.data() as Map<String, dynamic>;
        final rideId = rideDoc.id;

        // Busca solicitações aceitas desta carona
        final requestsSnapshot = await _firestore
            .collection('ride_requests')
            .where('rideId', isEqualTo: rideId)
            .where('status', isEqualTo: 'accepted')
            .get();

        for (final requestDoc in requestsSnapshot.docs) {
          final requestData = requestDoc.data();
          final passengerId = requestData['passengerId'] as String;

          // Verifica se já avaliou este passageiro
          final jaAvaliado = await verificarAvaliacaoExistente(
            caronaId: rideId,
            avaliadorUsuarioId: motoristaId,
            avaliadoUsuarioId: passengerId,
          );

          if (!jaAvaliado) {
            pendentes.add(
              CaronaPendenteAvaliacao(
                caronaId: rideId,
                avaliadoUsuarioId: passengerId,
                avaliadoNome:
                    requestData['passengerName'] as String? ?? 'Passageiro',
                avaliadoPhotoURL: requestData['passengerPhotoURL'] as String?,
                tipo: 'passageiro',
                dataCarona:
                    (rideData['dateTime'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                origem:
                    (rideData['origin'] as Map<String, dynamic>?)?['address'] ??
                    'Origem não informada',
                destino:
                    (rideData['destination']
                        as Map<String, dynamic>?)?['address'] ??
                    'Destino não informado',
              ),
            );
          }
        }
      }

      if (kDebugMode) {
        print(
          '✓ ${pendentes.length} caronas pendentes encontradas como motorista',
        );
      }

      return pendentes;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar caronas pendentes como motorista: $e');
      }
      return [];
    }
  }

  /// Busca caronas concluídas onde o usuário é passageiro e precisa avaliar o motorista
  Future<List<CaronaPendenteAvaliacao>> buscarCaronasPendentesComoPassageiro(
    String passageiroId,
  ) async {
    try {
      // Busca solicitações aceitas do passageiro
      final requestsSnapshot = await _firestore
          .collection('ride_requests')
          .where('passengerId', isEqualTo: passageiroId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final pendentes = <CaronaPendenteAvaliacao>[];

      for (final requestDoc in requestsSnapshot.docs) {
        final requestData = requestDoc.data();
        final rideId = requestData['rideId'] as String;

        // Busca a carona
        final rideDoc = await _caronasCollection.doc(rideId).get();
        if (!rideDoc.exists) continue;

        final rideData = rideDoc.data() as Map<String, dynamic>;
        final status = rideData['status'] as String?;

        // Só considera caronas concluídas
        if (status != 'completed') continue;

        final driverId = rideData['driverId'] as String;

        // Verifica se já avaliou o motorista
        final jaAvaliado = await verificarAvaliacaoExistente(
          caronaId: rideId,
          avaliadorUsuarioId: passageiroId,
          avaliadoUsuarioId: driverId,
        );

        if (!jaAvaliado) {
          pendentes.add(
            CaronaPendenteAvaliacao(
              caronaId: rideId,
              avaliadoUsuarioId: driverId,
              avaliadoNome: rideData['driverName'] as String? ?? 'Motorista',
              avaliadoPhotoURL: rideData['driverPhotoURL'] as String?,
              tipo: 'motorista',
              dataCarona:
                  (rideData['dateTime'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              origem:
                  (rideData['origin'] as Map<String, dynamic>?)?['address'] ??
                  'Origem não informada',
              destino:
                  (rideData['destination']
                      as Map<String, dynamic>?)?['address'] ??
                  'Destino não informado',
            ),
          );
        }
      }

      if (kDebugMode) {
        print(
          '✓ ${pendentes.length} caronas pendentes encontradas como passageiro',
        );
      }

      return pendentes;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar caronas pendentes como passageiro: $e');
      }
      return [];
    }
  }

  /// Busca todas as caronas pendentes de avaliação (motorista + passageiro)
  Future<List<CaronaPendenteAvaliacao>> buscarTodasCaronasPendentes(
    String usuarioId,
  ) async {
    try {
      final comoMotorista = await buscarCaronasPendentesComoMotorista(
        usuarioId,
      );
      final comoPassageiro = await buscarCaronasPendentesComoPassageiro(
        usuarioId,
      );

      final todas = [...comoMotorista, ...comoPassageiro];

      // Ordena por data mais recente
      todas.sort((a, b) => b.dataCarona.compareTo(a.dataCarona));

      return todas;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar todas as caronas pendentes: $e');
      }
      return [];
    }
  }
}
