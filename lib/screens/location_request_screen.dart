import 'package:flutter/material.dart';
import '../services/location_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Tela de solicitação de permissão de localização
///
/// Exibida após o onboarding, solicita ao usuário permissão
/// para acessar a localização do dispositivo.
/// Após conceder permissão, navega para a tela de login.
class LocationRequestScreen extends StatefulWidget {
  const LocationRequestScreen({super.key});

  @override
  State<LocationRequestScreen> createState() => _LocationRequestScreenState();
}

class _LocationRequestScreenState extends State<LocationRequestScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Animação de pulso para o ícone de localização
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Botão de pular (opcional)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skipLocationRequest,
                  child: Text(
                    'Pular',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Ícone de localização animado
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 60,
                    color: Color(0xFF2196F3),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Título
              const Text(
                'Ativar Localização',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Descrição
              Text(
                'Para encontrar caronas próximas a você e oferecer rotas precisas, precisamos acessar sua localização.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Benefícios
              _buildBenefitItem(
                icon: Icons.near_me,
                title: 'Caronas Próximas',
                description: 'Encontre caronas na sua região',
              ),

              const SizedBox(height: 16),

              _buildBenefitItem(
                icon: Icons.route,
                title: 'Rotas Otimizadas',
                description: 'Sugestões de rotas mais eficientes',
              ),

              const SizedBox(height: 16),

              _buildBenefitItem(
                icon: Icons.security,
                title: 'Privacidade Garantida',
                description: 'Seus dados estão seguros conosco',
              ),

              const Spacer(),

              // Botão de ativar localização
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requestLocationPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Ativar Localização',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botão de continuar sem localização
              TextButton(
                onPressed: _skipLocationRequest,
                child: Text(
                  'Continuar sem localização',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói um item de benefício
  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2196F3), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Solicita permissão de localização
  void _requestLocationPermission() async {
    try {
      final locationService = LocationService();

      // Verifica se o serviço de localização está habilitado
      final isEnabled = await locationService.isLocationServiceEnabled();

      if (!isEnabled) {
        if (mounted) {
          _showLocationDisabledDialog();
        }
        return;
      }

      // Mostra loading apenas depois da verificação inicial
      if (mounted) {
        _showLoadingDialog();
      }

      // Solicita permissão
      final granted = await locationService.requestLocationPermission();

      if (mounted) {
        Navigator.of(context).pop(); // Fecha o diálogo de loading

        if (granted) {
          // Mostra sucesso antes de tentar obter localização
          _showSuccessSnackBar('Permissão concedida com sucesso!');

          // Tenta obter localização atual para validar
          final position = await locationService.getCurrentLocation();

          if (position != null) {
            if (kDebugMode) {
              print(
                '✓ Localização obtida: ${position.latitude}, ${position.longitude}',
              );
            }
          }

          // Navega independentemente de conseguir obter a localização
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            _navigateToLogin();
          }
        } else {
          // Verifica se foi negada permanentemente
          final hasPermission = await locationService.hasLocationPermission();

          if (!hasPermission) {
            _showPermissionDeniedDialog();
          } else {
            _navigateToLogin();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao solicitar permissão: $e');
      }

      if (mounted) {
        // Tenta fechar diálogo se estiver aberto
        try {
          Navigator.of(context).pop();
        } catch (_) {}

        _showErrorDialog('Erro ao solicitar permissão de localização');
      }
    }
  }

  /// Mostra um diálogo explicando porque o app precisa da permissão
  Future<bool> _showPermissionRationale() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permissão de Localização'),
            content: const Text(
              'Para encontrar caronas próximas e oferecer rotas precisas, precisamos acessar sua localização. Deseja permitir agora?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Permitir'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Pula a solicitação de localização
  void _skipLocationRequest() {
    _navigateToLogin();
  }

  /// Navega para a tela de login
  void _navigateToLogin() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  /// Exibe diálogo de carregamento
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Ativando localização...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Exibe diálogo quando serviço de localização está desabilitado
  void _showLocationDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Localização Desabilitada'),
        content: const Text(
          'O serviço de localização do dispositivo está desabilitado. '
          'Por favor, habilite nas configurações do dispositivo para usar esta funcionalidade.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final locationService = LocationService();
              await locationService.openLocationSettings();
            },
            child: const Text('Abrir Configurações'),
          ),
        ],
      ),
    );
  }

  /// Exibe diálogo quando permissão foi negada permanentemente
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissão Negada'),
        content: const Text(
          'A permissão de localização foi negada. Você pode habilitá-la nas configurações do aplicativo.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin(); // Continua mesmo sem permissão
            },
            child: const Text('Continuar Sem Localização'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final locationService = LocationService();
              await locationService.openLocationSettings();
            },
            child: const Text('Abrir Configurações'),
          ),
        ],
      ),
    );
  }

  /// Exibe diálogo de erro genérico
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Exibe diálogo quando há erro ao obter localização
  void _showPermissionErrorDialog() {
    _showErrorDialog(
      'Não foi possível obter sua localização. Você pode continuar usando o app sem localização.',
    );
  }

  /// Exibe mensagem de sucesso
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
