import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../services/user_data_service.dart';
import '../utils/date_utils.dart' as app_date_utils;

/// Tela que permite visualizar e exportar os dados pessoais do usuário.
///
/// Atende aos direitos de acesso e portabilidade previstos no Art. 18 da LGPD.
class UserDataScreen extends StatefulWidget {
  const UserDataScreen({super.key});

  @override
  State<UserDataScreen> createState() => _UserDataScreenState();
}

class _UserDataScreenState extends State<UserDataScreen> {
  final UserDataService _userDataService = UserDataService();

  Future<Map<String, dynamic>>? _dataFuture;
  bool _isExporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dataFuture == null) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;

    if (currentUser == null) {
      setState(() {
        _dataFuture = Future<Map<String, dynamic>>.error(
          'Usuário não autenticado. Faça login para acessar seus dados.',
        );
      });
      return;
    }

    setState(() {
      _dataFuture = _userDataService.buildUserDataSnapshot(currentUser.uid);
    });

    try {
      await _dataFuture;
    } catch (_) {
      // Erros já são tratados na FutureBuilder.
    }
  }

  Future<void> _handleExport() async {
    if (_isExporting) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;

    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login para exportar seus dados.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isExporting = true;
      });

      final filePath = await _userDataService.exportUserData(
        userId: currentUser.uid,
        email: currentUser.email,
      );

      if (!mounted) {
        return;
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            'Exportação de dados do aplicativo Carona Universitária. Arquivo gerado conforme solicitação de portabilidade.',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exportação concluída. Verifique o arquivo compartilhado.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao exportar dados: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Dados')),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final data = snapshot.data;
            if (data == null) {
              return _buildErrorState(
                'Não foi possível carregar seus dados. Tente novamente.',
              );
            }

            return _buildContent(data);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExporting ? null : _handleExport,
        icon: _isExporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined),
        label: Text(_isExporting ? 'Exportando...' : 'Exportar Dados'),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                'Central de Dados',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final metadata =
        (data['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final warnings = (metadata['errors'] as List<dynamic>? ?? <dynamic>[])
        .cast<String>();
    final profile =
        (data['profile'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final vehicles = (data['vehicles'] as List<dynamic>? ?? <dynamic>[]);
    final rides =
        (data['rides'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final rideRequests =
        (data['rideRequests'] as List<dynamic>? ?? <dynamic>[]);
    final evaluations =
        (data['evaluations'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final consents = (data['consents'] as List<dynamic>? ?? <dynamic>[]);

    final ridesAsDriver = (rides['asDriver'] as List<dynamic>? ?? <dynamic>[]);
    final ridesAsPassenger =
        (rides['asPassenger'] as List<dynamic>? ?? <dynamic>[]);
    final evaluationsAsAuthor =
        (evaluations['asAuthor'] as List<dynamic>? ?? <dynamic>[]);
    final evaluationsAsTarget =
        (evaluations['asTarget'] as List<dynamic>? ?? <dynamic>[]);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(profile, metadata),
        const SizedBox(height: 16),
        if (warnings.isNotEmpty) ...[
          _buildWarningsCard(warnings),
          const SizedBox(height: 16),
        ],
        _buildSummaryCard(
          title: 'Resumo dos Dados',
          items: [
            _SummaryItem(
              label: 'Veículos cadastrados',
              value: vehicles.length.toString(),
              icon: Icons.directions_car_outlined,
            ),
            _SummaryItem(
              label: 'Caronas oferecidas',
              value: ridesAsDriver.length.toString(),
              icon: Icons.drive_eta,
            ),
            _SummaryItem(
              label: 'Caronas participadas',
              value: ridesAsPassenger.length.toString(),
              icon: Icons.handshake_outlined,
            ),
            _SummaryItem(
              label: 'Solicitações de carona',
              value: rideRequests.length.toString(),
              icon: Icons.request_page_outlined,
            ),
            _SummaryItem(
              label: 'Avaliações feitas',
              value: evaluationsAsAuthor.length.toString(),
              icon: Icons.rate_review_outlined,
            ),
            _SummaryItem(
              label: 'Avaliações recebidas',
              value: evaluationsAsTarget.length.toString(),
              icon: Icons.star_border_outlined,
            ),
            _SummaryItem(
              label: 'Consentimentos registrados',
              value: consents.length.toString(),
              icon: Icons.verified_user_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildConsentsSection(consents),
        const SizedBox(height: 16),
        _buildGuidanceCard(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildWarningsCard(List<String> warnings) {
    return Card(
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Dados não retornados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• $warning',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.orange[800]),
                ),
              ),
            ),
            Text(
              'Caso precise de acesso completo, contate o administrador para revisar as permissões.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.orange[800]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    Map<String, dynamic> profile,
    Map<String, dynamic> metadata,
  ) {
    final displayName = profile['displayName'] as String? ?? 'Usuário';
    final email = profile['email'] as String? ?? 'Email não disponível';
    final generatedAt = metadata['generatedAt'] as String?;
    final formattedDate = generatedAt != null
        ? app_date_utils.formatDateTimeIso(generatedAt)
        : 'Data não disponível';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Última extração: $formattedDate',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              'Versão da política de privacidade: ${metadata['privacyPolicyVersion'] ?? '1.0'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required List<_SummaryItem> items,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.map(_buildSummaryTile).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile(_SummaryItem item) {
    return Container(
      width: MediaQuery.of(context).size.width > 360 ? 160 : double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            item.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentsSection(List<dynamic> consents) {
    if (consents.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Consentimentos',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhum consentimento encontrado. Caso tenha dúvidas, entre em contato com o suporte.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }

    final latest = consents.first as Map<String, dynamic>;
    final acceptedAt = latest['acceptedAt'] as String?;
    final formattedAcceptedAt = acceptedAt != null
        ? app_date_utils.formatDateTimeIso(acceptedAt)
        : 'Data não disponível';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Consentimentos Registrados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'A última aceitação registrada foi em $formattedAcceptedAt.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Todos os consentimentos podem ser exportados pelo botão "Exportar Dados".',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip_outlined, color: Colors.blueGrey[700]),
                const SizedBox(width: 8),
                Text(
                  'Orientações LGPD',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '• Você pode solicitar uma nova exportação a qualquer momento.\n'
              '• Para solicitar exclusão de dados, utilize a opção "Excluir Conta" no perfil.\n'
              '• Em caso de dúvidas, contate suporte@carona-universitaria.udf.edu.br.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.blueGrey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}
