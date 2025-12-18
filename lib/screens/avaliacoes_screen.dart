import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/avaliacao_service.dart';
import '../models/carona_pendente_avaliacao.dart';
import '../models/avaliacao_model.dart';
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
  List<AvaliacaoModel> _avaliacoesRecebidas = [];
  bool _isLoading = true;
  bool _isLoadingRecebidas = false;
  int _selectedTab = 0; // 0: Pendentes, 1: Recebidas, 2: Sistema

  @override
  void initState() {
    super.initState();
    _carregarCaronasPendentes();
    _carregarAvaliacoesRecebidas();
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

      final pendentes = await _avaliacaoService.buscarTodasCaronasPendentes(
        user.uid,
      );

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

  // Cache local de nomes para evitar múltiplas requisições
  final Map<String, String> _cacheNomes = {};

  /// Busca o nome de um usuário pelo ID com cache local
  Future<String> _buscarNomeUsuario(String usuarioId) async {
    if (kDebugMode) {
      print('🔍 _buscarNomeUsuario chamado para: $usuarioId');
    }

    // Valida ID
    if (usuarioId.isEmpty) {
      if (kDebugMode) {
        print('⚠️ ID vazio fornecido');
      }
      return 'Usuário Desconhecido';
    }

    // Retorna do cache se já existe
    if (_cacheNomes.containsKey(usuarioId)) {
      if (kDebugMode) {
        print('✓ Nome encontrado no cache: ${_cacheNomes[usuarioId]}');
      }
      return _cacheNomes[usuarioId]!;
    }

    try {
      if (kDebugMode) {
        print('📡 Buscando nome no Firestore...');
      }

      final nome = await _avaliacaoService.buscarNomeUsuarioPorId(usuarioId);

      if (kDebugMode) {
        print('✓ Nome retornado do serviço: $nome');
      }

      // Salva no cache
      _cacheNomes[usuarioId] = nome;

      return nome;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar nome do usuário $usuarioId: $e');
        print('   Stack trace: ${StackTrace.current}');
      }

      // Retorna fallback mas não salva no cache para tentar novamente depois
      return 'Usuário (Erro: ${e.toString().substring(0, 20)}...)';
    }
  }

  /// Carrega avaliações recebidas pelo usuário
  Future<void> _carregarAvaliacoesRecebidas() async {
    setState(() {
      _isLoadingRecebidas = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        if (kDebugMode) {
          print('⚠️ Usuário não autenticado ao carregar avaliações recebidas');
        }
        setState(() {
          _isLoadingRecebidas = false;
        });
        return;
      }

      if (kDebugMode) {
        print('🔄 Carregando avaliações recebidas para: ${user.uid}');
      }

      final recebidas = await _avaliacaoService.listarAvaliacoesPorAvaliado(
        user.uid,
      );

      if (kDebugMode) {
        print('✓ ${recebidas.length} avaliações recebidas carregadas');
      }

      if (mounted) {
        setState(() {
          _avaliacoesRecebidas = recebidas;
          _isLoadingRecebidas = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao carregar avaliações recebidas: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingRecebidas = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar avaliações recebidas: $e'),
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

  /// Mostra informações de debug (apenas em modo debug)
  void _mostrarInfoDebug() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug - Avaliações'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '👤 Usuário Atual:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('  UID: ${user?.uid ?? "N/A"}'),
              Text('  Email: ${user?.email ?? "N/A"}'),
              Text('  Nome: ${user?.displayName ?? "N/A"}'),
              const Divider(),
              Text(
                '📊 Estatísticas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('  Avaliações recebidas: ${_avaliacoesRecebidas.length}'),
              Text('  Nomes em cache: ${_cacheNomes.length}'),
              const Divider(),
              Text(
                '🔍 IDs dos Avaliadores:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._avaliacoesRecebidas
                  .take(5)
                  .map(
                    (av) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID: ${av.avaliadorUsuarioId}',
                            style: TextStyle(fontSize: 10),
                          ),
                          Text(
                            'Nome cache: ${_cacheNomes[av.avaliadorUsuarioId] ?? "não carregado"}',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Copia info para clipboard seria útil aqui
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Verifique o console para logs detalhados'),
                ),
              );
            },
            child: const Text('Ver Logs'),
          ),
        ],
      ),
    );
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
        actions: [
          // Botão de debug/refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar e Limpar Cache',
            onPressed: () async {
              // Limpa cache local
              setState(() {
                _cacheNomes.clear();
              });

              // Limpa cache do serviço
              _avaliacaoService.limparCacheNomes();

              // Recarrega dados
              await _carregarAvaliacoesRecebidas();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache limpo e dados atualizados!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          // Botão de debug detalhado (apenas em modo debug)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Debug Info',
              onPressed: _mostrarInfoDebug,
            ),
        ],
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
                    label: 'Recebidas',
                    index: 1,
                    icon: Icons.star,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: 'Sistema',
                    index: 2,
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
                : _selectedTab == 1
                ? _buildRecebidasTab()
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
        // Recarrega os dados quando mudar para a aba de recebidas
        if (index == 1) {
          _carregarAvaliacoesRecebidas();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2196F3).withValues(alpha: 0.1)
              : Colors.transparent,
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_caronasPendentes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
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
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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

  /// Tab de avaliações recebidas
  Widget _buildRecebidasTab() {
    if (_isLoadingRecebidas) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_avaliacoesRecebidas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhuma avaliação recebida',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete caronas para receber avaliações',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _carregarAvaliacoesRecebidas,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarAvaliacoesRecebidas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _avaliacoesRecebidas.length,
        itemBuilder: (context, index) {
          final avaliacao = _avaliacoesRecebidas[index];
          return _buildAvaliacaoRecebidaCard(avaliacao);
        },
      ),
    );
  }

  /// Card de avaliação recebida
  Widget _buildAvaliacaoRecebidaCard(AvaliacaoModel avaliacao) {
    final nota = avaliacao.nota ?? 0;
    final comentario = avaliacao.comentario ?? '';
    final dataAvaliacao = avaliacao.dataAvaliacao;

    // Define cor baseada na nota
    Color notaColor;
    if (nota >= 4) {
      notaColor = Colors.green;
    } else if (nota >= 3) {
      notaColor = Colors.orange;
    } else {
      notaColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: _buscarNomeUsuario(
                                avaliacao.avaliadorUsuarioId,
                              ),
                              builder: (context, snapshot) {
                                if (kDebugMode) {
                                  print(
                                    '📝 FutureBuilder - Estado: ${snapshot.connectionState}',
                                  );
                                  print(
                                    '   AvaliadorId: ${avaliacao.avaliadorUsuarioId}',
                                  );
                                  print('   Nome: ${snapshot.data}');
                                  print('   Erro: ${snapshot.error}');
                                }

                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.grey[400]!,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Carregando...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                if (snapshot.hasError) {
                                  return const Text(
                                    'Erro ao carregar nome',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  );
                                }

                                final nomeExibido = snapshot.data ?? 'Usuário';

                                return Text(
                                  nomeExibido,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                            Text(
                              DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(dataAvaliacao),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
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
                    color: notaColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, size: 18, color: notaColor),
                      const SizedBox(width: 4),
                      Text(
                        nota.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: notaColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (comentario.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        comentario,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < nota ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
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
                  Icon(Icons.star_rate, size: 60, color: Colors.amber[600]),
                  const SizedBox(height: 16),
                  const Text(
                    'Avalie o Sistema',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sua opinião é muito importante para melhorarmos o aplicativo!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
    final tipoIcon = carona.tipo == 'motorista'
        ? Icons.directions_car
        : Icons.person;
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
                        Icon(
                          Icons.pending,
                          size: 16,
                          color: Colors.orange[800],
                        ),
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
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
