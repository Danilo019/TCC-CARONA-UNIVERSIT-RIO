import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/consent.dart';

/// Serviço para gerenciar consentimentos LGPD
class ConsentService {
  static final ConsentService _instance = ConsentService._internal();
  factory ConsentService() => _instance;
  ConsentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection reference para consentimentos
  CollectionReference get _consentsCollection => _firestore.collection('consents');

  // ============================================================================
  // OPERAÇÕES DE ESCRITA
  // ============================================================================

  /// Salva um consentimento no Firestore
  Future<String?> saveConsent(Consent consent) async {
    try {
      // Verifica se já existe consentimento para este usuário e tipo
      final existingQuery = await _consentsCollection
          .where('userId', isEqualTo: consent.userId)
          .where('consentType', isEqualTo: consent.consentType)
          .where('version', isEqualTo: consent.version)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Atualiza consentimento existente
        await existingQuery.docs.first.reference.update(consent.toMap());
        
        if (kDebugMode) {
          print('✓ Consentimento atualizado: ${consent.consentType} para ${consent.userId}');
        }
        
        return existingQuery.docs.first.id;
      } else {
        // Cria novo consentimento
        final docRef = await _consentsCollection.add(consent.toMap());
        
        if (kDebugMode) {
          print('✓ Consentimento salvo: ${consent.consentType} para ${consent.userId}');
        }
        
        return docRef.id;
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao salvar consentimento: $e');
      }
      return null;
    }
  }

  /// Salva consentimento de política de privacidade
  Future<bool> savePrivacyPolicyConsent({
    required String userId,
    required String email,
    required bool accepted,
    required String version,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final consent = Consent(
        id: '',
        userId: userId,
        email: email,
        consentType: 'privacy_policy',
        accepted: accepted,
        version: version,
        acceptedAt: DateTime.now(),
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      final consentId = await saveConsent(consent);
      return consentId != null;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao salvar consentimento de política: $e');
      }
      return false;
    }
  }

  /// Salva consentimento de termos de serviço
  Future<bool> saveTermsOfServiceConsent({
    required String userId,
    required String email,
    required bool accepted,
    required String version,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final consent = Consent(
        id: '',
        userId: userId,
        email: email,
        consentType: 'terms_of_service',
        accepted: accepted,
        version: version,
        acceptedAt: DateTime.now(),
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      final consentId = await saveConsent(consent);
      return consentId != null;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao salvar consentimento de termos: $e');
      }
      return false;
    }
  }

  /// Salva consentimento de processamento de dados
  Future<bool> saveDataProcessingConsent({
    required String userId,
    required String email,
    required bool accepted,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final consent = Consent(
        id: '',
        userId: userId,
        email: email,
        consentType: 'data_processing',
        accepted: accepted,
        version: '1.0',
        acceptedAt: DateTime.now(),
        ipAddress: ipAddress,
        userAgent: userAgent,
      );

      final consentId = await saveConsent(consent);
      return consentId != null;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao salvar consentimento de processamento: $e');
      }
      return false;
    }
  }

  // ============================================================================
  // OPERAÇÕES DE LEITURA
  // ============================================================================

  /// Busca consentimentos de um usuário
  Future<List<Consent>> getConsentsByUser(String userId) async {
    try {
      final snapshot = await _consentsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('acceptedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Consent.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar consentimentos: $e');
      }
      return [];
    }
  }

  /// Verifica se o usuário aceitou a política de privacidade
  Future<bool> hasAcceptedPrivacyPolicy(String userId, String version) async {
    try {
      final snapshot = await _consentsCollection
          .where('userId', isEqualTo: userId)
          .where('consentType', isEqualTo: 'privacy_policy')
          .where('version', isEqualTo: version)
          .where('accepted', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao verificar consentimento: $e');
      }
      return false;
    }
  }

  /// Verifica se o usuário aceitou os termos de serviço
  Future<bool> hasAcceptedTermsOfService(String userId, String version) async {
    try {
      final snapshot = await _consentsCollection
          .where('userId', isEqualTo: userId)
          .where('consentType', isEqualTo: 'terms_of_service')
          .where('version', isEqualTo: version)
          .where('accepted', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao verificar termos: $e');
      }
      return false;
    }
  }

  /// Busca última versão aceita de um tipo de consentimento
  Future<Consent?> getLastConsent(String userId, String consentType) async {
    try {
      final snapshot = await _consentsCollection
          .where('userId', isEqualTo: userId)
          .where('consentType', isEqualTo: consentType)
          .orderBy('acceptedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return Consent.fromFirestore(snapshot.docs.first);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar último consentimento: $e');
      }
      return null;
    }
  }

  // ============================================================================
  // UTILITÁRIOS
  // ============================================================================

  /// Versão atual da política de privacidade
  static const String currentPrivacyPolicyVersion = '1.0';

  /// Versão atual dos termos de serviço
  static const String currentTermsOfServiceVersion = '1.0';
}

