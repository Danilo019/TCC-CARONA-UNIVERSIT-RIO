import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_preferences.dart';

class PreferencesService {
  PreferencesService._internal();

  static final PreferencesService _instance = PreferencesService._internal();

  factory PreferencesService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _preferencesField = 'preferences';

  Future<UserPreferences> loadPreferences(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final preferencesMap = data != null
          ? data[_preferencesField] as Map<String, dynamic>?
          : null;
      return UserPreferences.fromMap(preferencesMap);
    } catch (error) {
      if (kDebugMode) {
        print('✗ Erro ao carregar preferências: $error');
      }
      rethrow;
    }
  }

  Future<void> updatePreferences(
    String userId,
    UserPreferences preferences,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        _preferencesField: preferences.toMap(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (kDebugMode) {
        print('✗ Erro ao salvar preferências: $error');
      }
      rethrow;
    }
  }
}
