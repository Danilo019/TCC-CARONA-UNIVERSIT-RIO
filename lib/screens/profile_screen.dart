import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;

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
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (user == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Usuário não autenticado',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
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
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade400,
          ],
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
          colors: [
            Colors.blue.shade300,
            Colors.blue.shade600,
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        size: 60,
        color: Colors.white,
      ),
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
          _buildInfoTile(
            icon: Icons.verified_user_outlined,
            label: 'Status',
            value: user.emailVerified ? 'Verificado' : 'Não verificado',
            valueColor: user.emailVerified ? Colors.green : Colors.orange,
          ),
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
            child: Icon(
              icon,
              color: Colors.blue.shade700,
              size: 24,
            ),
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
            icon: Icons.edit_outlined,
            label: 'Editar Perfil',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidade em breve'),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.settings_outlined,
            label: 'Configurações',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidade em breve'),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildActionTile(
            icon: Icons.help_outline,
            label: 'Ajuda & Suporte',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidade em breve'),
                ),
              );
            },
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
                applicationLegalese: 'Desenvolvido para a comunidade universitária',
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
        child: Icon(
          icon,
          color: Colors.blue.shade700,
          size: 22,
        ),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }

  /// Constrói botão de logout
  Widget _buildLogoutButton(BuildContext context, app_auth.AuthProvider authProvider) {
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
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Sair'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await authProvider.signOut();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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

