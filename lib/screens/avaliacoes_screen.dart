import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/avaliacao_service.dart';
import '../models/carona_pendente_avaliacao.dart';
import '../widgets/avaliacao_dialog.dart';

/// Tela dedicada para avaliações
/// Permite que motoristas e passageiros avaliem uns aos outros e o sistema
class AvaliacoesScreen extends StatefulWidget {
  const AvaliacoesScreen({super.key});

  @override
  State<AvaliacoesScreen> createState() => _AvaliacoesScreenState();
}

class _AvaliacoesScreenState extends State<AvaliacoesScreen> {
  final AvaliacaoService _avaliacaoService = AvaliacaoService();
  List<CaronaPendenteAvaliacao> _caronasPendentes = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Pendentes, 1: Sistema

  @override
  void initState() {
    super.initState();
    _carregarCaronasPendentes();
  }

  /// Carrega caronas pendentes de avaliação
  Future<void> _carregarCaronasPendentes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final pendentes = await _avaliacaoService.buscarTodasCaronasPendentes(user.uid);

      if (mounted) {
        setState(() {
          _caronasPendentes = pendentes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao carregar caronas pendentes: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar avaliações pendentes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Abre o diálogo de avaliação
  Future<void> _abrirDialogoAvaliacao(CaronaPendenteAvaliacao carona) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) return;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AvaliacaoDialog(
        caronaId: carona.caronaId,
        avaliadorUsuarioId: user.uid,
        avaliadoUsuarioId: carona.avaliadoUsuarioId,
        avaliadoNome: carona.avaliadoNome,
      ),
    );

      if (resultado == true && mounted) {
        // Recarrega a lista após avaliar
        await _carregarCaronasPendentes();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avaliação enviada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }

  /// Abre o diálogo de avaliação do sistema
  Future<void> _abrirDialogoAvaliacaoSistema() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) return;

    // Para avaliação do sistema, usamos um ID especial
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AvaliacaoSistemaDialog(),
    );

    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avaliação do sistema enviada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Avaliações'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Pendentes',
                    index: 0,
                    icon: Icons.pending_actions,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'Avaliar Sistema',
                    index: 1,
                    icon: Icons.star_rate,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Conteúdo
          Expanded(
            child: _selectedTab == 0
                ? _buildPendentesTab()
                : _buildSistemaTab(),
          ),
        ],
      ),
    );
  }

  /// Botão de tab
  Widget _buildTabButton({
    required String label,
    required int index,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3).withValues(alpha: 0.1) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF2196F3) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF2196F3) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab de avaliações pendentes
  Widget _buildPendentesTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_caronasPendentes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma avaliação pendente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Todas as suas caronas já foram avaliadas!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarCaronasPendentes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _caronasPendentes.length,
        itemBuilder: (context, index) {
          final carona = _caronasPendentes[index];
          return _buildCaronaCard(carona);
        },
      ),
    );
  }

  /// Tab de avaliação do sistema
  Widget _buildSistemaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.star_rate,
                    size: 60,
                    color: Colors.amber[600],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Avalie o Sistema',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sua opinião é muito importante para melhorarmos o aplicativo!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _abrirDialogoAvaliacaoSistema,
                    icon: const Icon(Icons.star),
                    label: const Text('Avaliar Sistema'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      const Text(
                        'Sobre as Avaliações',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    Icons.people,
                    'Avalie outros usuários',
                    'Avalie motoristas e passageiros após suas caronas para ajudar a comunidade.',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    Icons.star,
                    'Avalie o sistema',
                    'Compartilhe sua experiência com o aplicativo para que possamos melhorar.',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    Icons.feedback,
                    'Feedback construtivo',
                    'Suas avaliações ajudam todos a terem uma experiência melhor.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Item de informação
  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Card de carona pendente
  Widget _buildCaronaCard(CaronaPendenteAvaliacao carona) {
    final tipoLabel = carona.tipo == 'motorista' ? 'Motorista' : 'Passageiro';
    final tipoIcon = carona.tipo == 'motorista' ? Icons.directions_car : Icons.person;
    final tipoColor = carona.tipo == 'motorista' ? Colors.blue : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _abrirDialogoAvaliacao(carona),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: carona.avaliadoPhotoURL != null
                        ? NetworkImage(carona.avaliadoPhotoURL!)
                        : null,
                    radius: 24,
                    child: carona.avaliadoPhotoURL == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          carona.avaliadoNome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(tipoIcon, size: 16, color: tipoColor),
                            const SizedBox(width: 4),
                            Text(
                              tipoLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: tipoColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending, size: 16, color: Colors.orange[800]),
                        const SizedBox(width: 4),
                        Text(
                          'Pendente',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      carona.origem,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      carona.destino,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(carona.dataCarona),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Avaliar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

