import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../services/auth_service.dart';

/// Tela de perfil do usuário
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Consumer<app_auth.AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.user;

            // Mostra loading enquanto inicializa
            if (authProvider.status == app_auth.AuthStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (user == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Usuário não autenticado',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      child: const Text('Ir para Login'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Header com foto e informações básicas
                  _buildProfileHeader(context, user),

                  const SizedBox(height: 20),

                  // Informações do perfil
                  _buildProfileInfo(context, user),

                  const SizedBox(height: 30),

                  // Ações rápidas
                  _buildQuickActions(context),

                  const SizedBox(height: 30),

                  // Direito ao Esquecimento
                  _buildAccountDeletionSection(context, authProvider),

                  const SizedBox(height: 30),

                  // Botão de logout
                  _buildLogoutButton(context, authProvider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Constrói o header do perfil com foto
  Widget _buildProfileHeader(BuildContext context, dynamic user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade700, Colors.blue.shade400],
        ),
      ),
      child: Column(
        children: [
          // Foto de perfil
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: user.photoURL != null && user.photoURL!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          user.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultAvatar(),
                        ),
                      )
                    : _buildDefaultAvatar(),
              ),
              // Botão de editar foto
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Nome do usuário
          Text(
            user.displayNameOrEmail,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 5),

          // Email
          Text(
            user.email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// Avatar padrão quando não há foto
  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade300, Colors.blue.shade600],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  /// Constrói informações do perfil
  Widget _buildProfileInfo(BuildContext context, dynamic user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
          ),
          _buildDivider(),
          _buildVerificationTile(context, user),
          // Alerta se não verificado
          if (!user.emailVerified) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Seu email ainda não foi verificado. Verifique sua caixa de entrada e clique no link enviado.',
                      style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildDivider(),
          _buildInfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Membro desde',
            value: user.creationTime != null
                ? _formatDate(user.creationTime!)
                : 'Não disponível',
          ),
          _buildDivider(),
          _buildInfoTile(
            icon: Icons.login_outlined,
            label: 'Último acesso',
            value: user.lastSignInTime != null
                ? _formatDate(user.lastSignInTime!)
                : 'Nunca',
          ),
        ],
      ),
    );
  }

  /// Constrói tile de verificação de email com botão de ação
  Widget _buildVerificationTile(BuildContext context, dynamic user) {
    final isVerified = user.emailVerified;
    final authService = AuthService();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isVerified ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isVerified ? Icons.verified_user : Icons.verified_user_outlined,
              color: isVerified ? Colors.green[700] : Colors.orange[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status do Email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      isVerified ? 'Verificado' : 'Não verificado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isVerified
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green[700],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isVerified)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      _handleSendVerificationEmail(context, authService),
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Enviar Verificação'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _handleRefreshVerificationStatus(context),
                  child: const Text(
                    'Atualizar Status',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Atualiza o status de verificação (útil após verificar email no navegador)
  Future<void> _handleRefreshVerificationStatus(BuildContext context) async {
    final authProvider = Provider.of<app_auth.AuthProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await authProvider.refreshUser();

      if (context.mounted) {
        Navigator.pop(context); // Fecha loading

        final user = authProvider.user;
        if (user != null && user.emailVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Email verificado com sucesso!')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email ainda não verificado. Verifique sua caixa de entrada.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Envia email de verificação
  Future<void> _handleSendVerificationEmail(
    BuildContext context,
    AuthService authService,
  ) async {
    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await authService.sendEmailVerification();

      // Recarrega o usuário no provider
      final authProvider = Provider.of<app_auth.AuthProvider>(
        context,
        listen: false,
      );
      await authProvider.refreshUser();

      if (context.mounted) {
        Navigator.pop(context); // Fecha loading

        // Mostra sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Email de verificação enviado! Verifique sua caixa de entrada.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Fecha loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Constrói um item de informação
  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói divisor
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
      indent: 84,
    );
  }

  /// Constrói ações rápidas
  Widget _buildQuickActions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.directions_car,
            label: 'Meus Veículos',
            onTap: () {
              Navigator.of(context).pushNamed('/vehicle-register');
            },
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.edit_outlined,
            label: 'Editar Perfil',
            onTap: () async {
              final result = await Navigator.pushNamed(
                context,
                '/edit-profile',
              );
              // Recarrega dados do usuário após editar perfil
              if (result == true) {
                final authProvider = Provider.of<app_auth.AuthProvider>(
                  context,
                  listen: false,
                );
                await authProvider.refreshUser();
              }
            },
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.star_rate,
            label: 'Avaliações',
            onTap: () {
              Navigator.of(context).pushNamed('/avaliacoes');
            },
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.settings_outlined,
            label: 'Configuração e privacidade',
            onTap: () => _showSettingsPrivacySheet(context),
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.info_outline,
            label: 'Sobre o App',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Carona Universitária',
                applicationVersion: '1.0.0',
                applicationLegalese:
                    'Desenvolvido para a comunidade universitária',
              );
            },
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.help_outline,
            label: 'Ajuda',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funcionalidade em breve')),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Constrói um item de ação
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.blue.shade700, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  void _showSettingsPrivacySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Central de privacidade (Meus Dados)'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pushNamed('/user-data');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Configurações'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pushNamed('/settings');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Política de Privacidade'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pushNamed('/privacy-policy');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: const Text('Termos de condições'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pushNamed('/terms-of-service');
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Constrói seção de exclusão de conta (Direito ao Esquecimento)
  Widget _buildAccountDeletionSection(
    BuildContext context,
    app_auth.AuthProvider authProvider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direito ao Esquecimento',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Excluir definitivamente sua conta, dados pessoais, histórico de caronas e arquivos armazenados.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _handleDeleteAccount(context, authProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.shield_outlined),
            label: const Text(
              'Excluir Conta',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Esta ação é irreversível.',
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }

  /// Constrói botão de logout
  Widget _buildLogoutButton(
    BuildContext context,
    app_auth.AuthProvider authProvider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ElevatedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirmar Logout'),
              content: const Text('Tem certeza que deseja sair?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Sair'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await authProvider.signOut();
            if (context.mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_outlined),
            SizedBox(width: 8),
            Text(
              'Sair da Conta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  /// Fluxo de exclusão de conta
  Future<void> _handleDeleteAccount(
    BuildContext context,
    app_auth.AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir conta?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Esta ação removerá permanentemente:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('• Dados pessoais e perfil'),
              Text('• Histórico de caronas e avaliações'),
              Text('• Solicitações, veículos e consentimentos'),
              Text('• Arquivos armazenados (documentos e fotos)'),
              SizedBox(height: 12),
              Text(
                'Ao confirmar você aceita excluir sua conta definitivamente conforme a LGPD.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    // Mostra loading durante a exclusão
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await authProvider.deleteAccount();

      if (!context.mounted) {
        return;
      }

      Navigator.pop(context); // Fecha loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta excluída com sucesso.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      Navigator.pop(context); // Fecha loading

      final message = e.toString().replaceFirst('Exception: ', '');
      final requiresRecentLogin = message.toLowerCase().contains(
        'login novamente',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requiresRecentLogin
                ? 'Faça login novamente e tente excluir a conta.'
                : 'Erro ao excluir conta: $message',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Formata data para exibição
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoje';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 30) {
      return 'Há ${difference.inDays} dias';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Há $months ${months == 1 ? 'mês' : 'meses'}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Há $years ${years == 1 ? 'ano' : 'anos'}';
    }
  }
}
