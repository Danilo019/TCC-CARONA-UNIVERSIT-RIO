import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../services/user_data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PreferencesService _preferencesService = PreferencesService();
  final UserDataService _userDataService = UserDataService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  UserPreferences _preferences = const UserPreferences();
  bool _isLoading = true;
  bool _isSavingPreferences = false;
  bool _isExportingData = false;
  bool _isSendingReset = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final loaded = await _preferencesService.loadPreferences(user.uid);
      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = loaded;
        _isLoading = false;
      });
      try {
        await _notificationService.applyPreferences(user.uid, loaded);
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao sincronizar notificações: $error'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar preferências: $error')),
      );
    }
  }

  Future<void> _updatePreferences(
    UserPreferences Function(UserPreferences current) updater,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar autenticado para alterar opções.'),
        ),
      );
      return;
    }

    final previous = _preferences;
    final updated = updater(previous);

    setState(() {
      _preferences = updated;
      _isSavingPreferences = true;
    });

    try {
      await _preferencesService.updatePreferences(user.uid, updated);
      await _notificationService.applyPreferences(user.uid, updated);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = previous;
        _isSavingPreferences = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar preferências: $error'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingPreferences = false;
    });
  }

  Future<void> _handleExportData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum usuário autenticado.')),
      );
      return;
    }

    setState(() {
      _isExportingData = true;
    });

    try {
      final path = await _userDataService.exportUserData(
        userId: user.uid,
        email: user.email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dados exportados para: $path')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar dados: $error'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingData = false;
        });
      }
    }
  }

  Future<void> _handleSendResetEmail() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
      );
      return;
    }

    setState(() {
      _isSendingReset = true;
    });

    try {
      await _authService.sendPasswordResetEmail(user.email);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email de redefinição enviado para ${user.email}.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar email: $error'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReset = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração e Privacidade')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPreferences,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isSavingPreferences) const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Notificações'),
                  _buildNotificationTiles(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Privacidade e LGPD'),
                  _buildPrivacyTiles(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Segurança'),
                  _buildSecurityTiles(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Experiência'),
                  _buildExperienceTiles(),
                  const SizedBox(height: 32),
                  Text(
                    'Alterações são salvas automaticamente e podem levar alguns instantes para serem aplicadas em todos os dispositivos.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildNotificationTiles() {
    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Receber notificações push'),
            subtitle: const Text(
              'Mensagens importantes sobre caronas e avisos',
            ),
            value: _preferences.receivePushNotifications,
            onChanged: _isSavingPreferences
                ? null
                : (value) => _updatePreferences(
                    (current) =>
                        current.copyWith(receivePushNotifications: value),
                  ),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('Alertar sobre novas caronas'),
            subtitle: const Text(
              'Receba avisos quando surgirem vagas compatíveis',
            ),
            value: _preferences.alertNewRides,
            onChanged: _isSavingPreferences
                ? null
                : (value) => _updatePreferences(
                    (current) => current.copyWith(alertNewRides: value),
                  ),
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('Lembrar saída com antecedência'),
            subtitle: const Text(
              'Notificações 15 minutos antes do horário combinado',
            ),
            value: _preferences.remindUpcomingRide,
            onChanged: _isSavingPreferences
                ? null
                : (value) => _updatePreferences(
                    (current) => current.copyWith(remindUpcomingRide: value),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTiles() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Exportar meus dados'),
            subtitle: const Text('Gera um arquivo JSON com todo o histórico'),
            trailing: _isExportingData
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isExportingData ? null : _handleExportData,
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: const Text('Ocultar meu nome em avaliações futuras'),
            subtitle: const Text(
              'Usa apenas iniciais quando você avaliar ou for avaliado.',
            ),
            value: _preferences.hideIdentityInReviews,
            onChanged: _isSavingPreferences
                ? null
                : (value) => _updatePreferences(
                    (current) => current.copyWith(hideIdentityInReviews: value),
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Rever Política de Privacidade'),
            onTap: () => Navigator.of(context).pushNamed('/privacy-policy'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Ver Termos de Uso'),
            onTap: () => Navigator.of(context).pushNamed('/terms-of-service'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTiles() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Enviar email para redefinir senha'),
            subtitle: const Text(
              'Receba um link/código para atualizar sua senha',
            ),
            trailing: _isSendingReset
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isSendingReset ? null : _handleSendResetEmail,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Encerrar sessão neste dispositivo'),
            subtitle: const Text('Faz logout imediato e limpa dados locais'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Confirmar saída'),
                    content: const Text(
                      'Deseja realmente encerrar a sessão neste dispositivo?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Encerrar sessão'),
                      ),
                    ],
                  );
                },
              );

              if (confirmed != true || !mounted) {
                return;
              }

              final authProvider = context.read<AuthProvider>();
              await authProvider.signOut();
              if (!mounted) {
                return;
              }

              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceTiles() {
    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Receber resumo semanal por e-mail'),
            subtitle: const Text('Resumo das caronas oferecidas e solicitadas'),
            value: _preferences.emailSummaries,
            onChanged: _isSavingPreferences
                ? null
                : (value) => _updatePreferences(
                    (current) => current.copyWith(emailSummaries: value),
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Enviar feedback'),
            subtitle: const Text(
              'Conte o que podemos melhorar na experiência do app',
            ),
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (sheetContext) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Envie seu feedback',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Envie um email para suporte@carona-universitaria.app '
                          'ou fale com o time pelo canal interno da faculdade.',
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Fechar'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
