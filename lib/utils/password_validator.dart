/// Validador de força de senha
/// Implementa regras de segurança e validação conforme requisitos
class PasswordValidator {
  /// Valida se a senha atende aos requisitos mínimos
  /// - Mínimo de 8 caracteres
  /// - Pelo menos 1 letra maiúscula
  /// - Pelo menos 1 número
  /// - Pelo menos 1 caractere especial (!@#$%&*)
  static ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult(
        isValid: false,
        strength: PasswordStrength.veryWeak,
        errors: ['A senha não pode estar vazia'],
      );
    }

    final List<String> errors = [];
    PasswordStrength strength = PasswordStrength.veryWeak;

    // Verifica comprimento mínimo
    if (password.length < 8) {
      errors.add('A senha deve ter no mínimo 8 caracteres');
    }

    // Verifica letra maiúscula
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('A senha deve conter pelo menos 1 letra maiúscula');
    }

    // Verifica número
    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('A senha deve conter pelo menos 1 número');
    }

    // Verifica caractere especial
    if (!password.contains(RegExp(r'[!@#$%&*]'))) {
      errors.add('A senha deve conter pelo menos 1 caractere especial (!@#\$%&*)');
    }

    // Calcula força da senha
    if (errors.isEmpty) {
      strength = _calculateStrength(password);
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      strength: strength,
      errors: errors,
      message: errors.isEmpty ? null : _getErrorMessage(),
    );
  }

  /// Calcula a força da senha baseado em critérios adicionais
  static PasswordStrength _calculateStrength(String password) {
    int score = 0;

    // Comprimento
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;

    // Complexidade
    if (password.contains(RegExp(r'[a-z]')) && password.contains(RegExp(r'[A-Z]'))) {
      score++;
    }
    if (password.contains(RegExp(r'[0-9]'))) {
      score++;
    }
    if (password.contains(RegExp(r'[!@#$%&*]'))) {
      score++;
    }
    if (password.contains(RegExp(r'[^a-zA-Z0-9!@#$%&*]'))) {
      score++;
    }

    // Determina força
    if (score <= 2) {
      return PasswordStrength.weak;
    } else if (score <= 4) {
      return PasswordStrength.medium;
    } else if (score <= 6) {
      return PasswordStrength.strong;
    } else {
      return PasswordStrength.veryStrong;
    }
  }

  /// Retorna mensagem de erro padronizada
  static String _getErrorMessage() {
    return 'A senha deve conter pelo menos 8 caracteres, incluindo uma letra maiúscula, um número e um caractere especial (!@#\$%&*).';
  }

  /// Verifica se a senha contém informações pessoais (básico)
  static bool containsPersonalInfo(String password, String email) {
    final emailParts = email.split('@')[0].toLowerCase();
    return password.toLowerCase().contains(emailParts);
  }
}

/// Resultado da validação de senha
class ValidationResult {
  final bool isValid;
  final PasswordStrength strength;
  final List<String> errors;
  final String? message;

  ValidationResult({
    required this.isValid,
    required this.strength,
    required this.errors,
    this.message,
  });

  String get strengthText {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return 'Muito fraca';
      case PasswordStrength.weak:
        return 'Fraca';
      case PasswordStrength.medium:
        return 'Média';
      case PasswordStrength.strong:
        return 'Forte';
      case PasswordStrength.veryStrong:
        return 'Muito forte';
    }
  }
}

/// Níveis de força da senha
enum PasswordStrength {
  veryWeak,
  weak,
  medium,
  strong,
  veryStrong,
}

