import 'package:flutter/material.dart';
import '../utils/password_validator.dart';

/// Widget que exibe indicador visual da força da senha
class PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;
  final bool showLabel;

  const PasswordStrengthIndicator({
    super.key,
    required this.strength,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Força da senha:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                _getStrengthText(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getStrengthColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // Barra de força
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _getStrengthValue(),
            minHeight: 6,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(_getStrengthColor()),
          ),
        ),
      ],
    );
  }

  double _getStrengthValue() {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return 0.2;
      case PasswordStrength.weak:
        return 0.4;
      case PasswordStrength.medium:
        return 0.6;
      case PasswordStrength.strong:
        return 0.8;
      case PasswordStrength.veryStrong:
        return 1.0;
    }
  }

  Color _getStrengthColor() {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return Colors.red;
      case PasswordStrength.weak:
        return Colors.orange;
      case PasswordStrength.medium:
        return Colors.yellow[700]!;
      case PasswordStrength.strong:
        return Colors.lightGreen;
      case PasswordStrength.veryStrong:
        return Colors.green;
    }
  }

  String _getStrengthText() {
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

