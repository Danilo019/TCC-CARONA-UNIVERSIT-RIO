class AuthToken {
  final String token;
  final String email;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isUsed;
  final String? userId;

  const AuthToken({
    required this.token,
    required this.email,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
    this.userId,
  });

  /// Cria um token a partir de um Map
  factory AuthToken.fromMap(Map<String, dynamic> map) {
    return AuthToken(
      token: map['token'] ?? '',
      email: map['email'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      expiresAt: DateTime.parse(map['expiresAt']),
      isUsed: map['isUsed'] ?? false,
      userId: map['userId'],
    );
  }

  /// Converte o token para Map
  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isUsed': isUsed,
      'userId': userId,
    };
  }

  /// Verifica se o token está expirado
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  /// Verifica se o token é válido (não usado e não expirado)
  bool get isValid {
    return !isUsed && !isExpired;
  }

  /// Verifica se o email é da UDF
  bool get isUDFEmail {
    return email.endsWith('@cs.udf.edu.br');
  }

  /// Cria uma cópia do token com campos atualizados
  AuthToken copyWith({
    String? token,
    String? email,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isUsed,
    String? userId,
  }) {
    return AuthToken(
      token: token ?? this.token,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isUsed: isUsed ?? this.isUsed,
      userId: userId ?? this.userId,
    );
  }

  @override
  String toString() {
    return 'AuthToken(token: $token, email: $email, expiresAt: $expiresAt, isUsed: $isUsed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthToken && other.token == token;
  }

  @override
  int get hashCode {
    return token.hashCode;
  }
}
