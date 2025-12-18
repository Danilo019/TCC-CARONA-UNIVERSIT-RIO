// Modelo de dados do usuário autenticado
// Abstrai informações do Firebase User para uso interno do app

class AuthUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final bool emailVerified;
  final DateTime? creationTime;
  final DateTime? lastSignInTime;

  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.emailVerified = false,
    this.creationTime,
    this.lastSignInTime,
  });

  /// Cria AuthUser a partir de dados do Firebase User
  factory AuthUser.fromFirebaseUser(dynamic firebaseUser) {
    return AuthUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoURL: firebaseUser.photoURL,
      emailVerified: firebaseUser.emailVerified,
      creationTime: firebaseUser.metadata.creationTime,
      lastSignInTime: firebaseUser.metadata.lastSignInTime,
    );
  }

  /// Cria AuthUser a partir de Map
  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      emailVerified: map['emailVerified'] ?? false,
      creationTime: map['creationTime'] != null
          ? DateTime.parse(map['creationTime'])
          : null,
      lastSignInTime: map['lastSignInTime'] != null
          ? DateTime.parse(map['lastSignInTime'])
          : null,
    );
  }

  /// Converte AuthUser para Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'emailVerified': emailVerified,
      'creationTime': creationTime?.toIso8601String(),
      'lastSignInTime': lastSignInTime?.toIso8601String(),
    };
  }

  /// Verifica se o email é da UDF
  bool get isUDFEmail {
    return email.endsWith('@udf.edu.br') || email.endsWith('@cs.udf.edu.br');
  }

  /// Obtém o nome de exibição ou email como fallback
  String get displayNameOrEmail {
    return displayName ?? email.split('@').first;
  }

  /// Cria uma cópia do usuário com campos atualizados
  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    bool? emailVerified,
    DateTime? creationTime,
    DateTime? lastSignInTime,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      emailVerified: emailVerified ?? this.emailVerified,
      creationTime: creationTime ?? this.creationTime,
      lastSignInTime: lastSignInTime ?? this.lastSignInTime,
    );
  }

  @override
  String toString() {
    return 'AuthUser(uid: $uid, email: $email, displayName: $displayName, emailVerified: $emailVerified)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthUser && other.uid == uid && other.email == email;
  }

  @override
  int get hashCode {
    return uid.hashCode ^ email.hashCode;
  }
}
