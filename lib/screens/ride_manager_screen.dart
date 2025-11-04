import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';

import '../services/rides_service.dart';
import '../services/ride_request_service.dart';
import '../services/avaliacao_service.dart';
import '../widgets/avaliacao_dialog.dart';

/// Tela de gerenciamento de caronas do motorista
class RideManagerScreen extends StatefulWidget {
  const RideManagerScreen({super.key});

  @override
  State<RideManagerScreen> createState() => _RideManagerScreenState();
}

class _RideManagerScreenState extends State<RideManagerScreen> {
  final RidesService _ridesService = RidesService();
  final RideRequestService _requestService = RideRequestService();

  List<Ride> _myRides = [];
  final Map<String, List<RideRequest>> _requestsByRide = {};
  final Map<String, bool> _avaliacaoVerificada = {}; // Cache para verificar se já avaliou
  bool _isLoading = true;
  int _selectedFilter = 0; // 0: Todas, 1: Ativas, 2: Concluídas, 3: Canceladas
  final AvaliacaoService _avaliacaoService = AvaliacaoService();

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  /// Carrega caronas do motorista
  Future<void> _loadRides() async {
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

      // Busca todas as caronas do motorista
      final ridesStream = _ridesService.watchRidesByDriver(user.uid);
      
      ridesStream.listen((rides) {
        if (mounted) {
          setState(() {
            _myRides = rides;
            _loadRequestsForRides(rides);
          });
        }
      });

      // Carrega primeira vez
      final rides = await _ridesService.getActiveRides();
      final myRides = rides.where((r) => r.driverId == user.uid).toList();
      
      if (mounted) {
        setState(() {
          _myRides = myRides;
          _isLoading = false;
        });
        _loadRequestsForRides(myRides);
        // Verificar avaliações após um delay para garantir que as requests foram carregadas
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _verificarAvaliacoesExistentes();
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao carregar caronas: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Carrega solicitações para cada carona
  void _loadRequestsForRides(List<Ride> rides) {
    for (final ride in rides) {
      _requestService.watchRequestsByRide(ride.id).listen((requests) {
        if (mounted) {
          setState(() {
            _requestsByRide[ride.id] = requests;
          });
          // Verifica avaliações após carregar as requests
          _verificarAvaliacoesExistentes();
        }
      });
    }
  }

  /// Filtra caronas baseado no filtro selecionado
  List<Ride> _getFilteredRides() {
    List<Ride> filtered = List.from(_myRides);

    switch (_selectedFilter) {
      case 1: // Ativas
        filtered = filtered.where((r) => r.status == 'active').toList();
        break;
      case 2: // Concluídas
        filtered = filtered.where((r) => r.status == 'completed').toList();
        break;
      case 3: // Canceladas
        filtered = filtered.where((r) => r.status == 'cancelled').toList();
        break;
    }

    // Ordena por data (mais recente primeiro)
    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return filtered;
  }

  /// Aceita uma solicitação
  Future<void> _acceptRequest(RideRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aceitar Solicitação'),
        content: Text('Deseja aceitar a solicitação de ${request.passengerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceitar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _requestService.acceptRequest(request.id);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitação aceita com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao aceitar solicitação'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Rejeita uma solicitação
  Future<void> _rejectRequest(RideRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar Solicitação'),
        content: Text('Deseja rejeitar a solicitação de ${request.passengerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _requestService.rejectRequest(request.id);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitação rejeitada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  /// Finaliza uma carona
  Future<void> _completeRide(Ride ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Carona'),
        content: const Text('Deseja finalizar esta carona? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _ridesService.completeRide(ride.id);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Carona finalizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao finalizar carona'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Minhas Caronas'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRides,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          _buildFilters(),

          // Lista de caronas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _getFilteredRides().isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadRides,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _getFilteredRides().length,
                          itemBuilder: (context, index) {
                            final ride = _getFilteredRides()[index];
                            return _buildRideCard(ride);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Filtros
  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(0, 'Todas', Icons.all_inclusive),
            const SizedBox(width: 8),
            _buildFilterChip(1, 'Ativas', Icons.check_circle),
            const SizedBox(width: 8),
            _buildFilterChip(2, 'Concluídas', Icons.done_all),
            const SizedBox(width: 8),
            _buildFilterChip(3, 'Canceladas', Icons.cancel),
          ],
        ),
      ),
    );
  }

  /// Chip de filtro
  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _selectedFilter == index;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card de carona
  Widget _buildRideCard(Ride ride) {
    final timeStr = DateFormat('dd/MM/yyyy às HH:mm').format(ride.dateTime);
    final requests = _requestsByRide[ride.id] ?? [];
    final pendingRequests = requests.where((r) => r.isPending).toList();
    final acceptedRequests = requests.where((r) => r.isAccepted).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(ride.status).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatusIcon(ride.status),
            color: _getStatusColor(ride.status),
          ),
        ),
        title: Text(
          '${ride.origin.address?.split(',').first ?? 'Origem'} → ${ride.destination.address?.split(',').first ?? 'Destino'}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(timeStr),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detalhes da carona
                _buildDetailRow(
                  Icons.location_on,
                  Colors.green,
                  'Origem',
                  ride.origin.address ?? 'Não informada',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.location_city,
                  Colors.red,
                  'Destino',
                  ride.destination.address ?? 'Não informado',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.people, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${ride.availableSeats}/${ride.maxSeats} vagas disponíveis',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Solicitações pendentes
                if (pendingRequests.isNotEmpty) ...[
                  const Text(
                    'Solicitações Pendentes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...pendingRequests.map((request) => _buildRequestCard(
                    request,
                    onAccept: () => _acceptRequest(request),
                    onReject: () => _rejectRequest(request),
                  )),
                  const SizedBox(height: 16),
                ],

                // Passageiros confirmados
                if (acceptedRequests.isNotEmpty) ...[
                  const Text(
                    'Passageiros Confirmados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...acceptedRequests.map((request) => _buildPassengerCard(
                    request,
                    ride: ride,
                  )),
                  const SizedBox(height: 16),
                ],

                // Ações
                if (ride.status == 'active') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _completeRide(ride),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Finalizar Carona'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Linha de detalhe
  Widget _buildDetailRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Card de solicitação
  Widget _buildRequestCard(
    RideRequest request, {
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.orange[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: request.passengerPhotoURL != null
              ? NetworkImage(request.passengerPhotoURL!)
              : null,
          child: request.passengerPhotoURL == null
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(request.passengerName),
        subtitle: request.message != null
            ? Text(request.message!)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: onAccept,
              tooltip: 'Aceitar',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: onReject,
              tooltip: 'Rejeitar',
            ),
          ],
        ),
      ),
    );
  }

  /// Card de passageiro confirmado
  Widget _buildPassengerCard(RideRequest request, {required Ride ride}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? '';
    final isCompleted = ride.status == 'completed';
    
    // Chave para verificar avaliação
    final avaliacaoKey = '${ride.id}_${currentUserId}_${request.passengerId}';
    final jaAvaliado = _avaliacaoVerificada[avaliacaoKey] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.green[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: request.passengerPhotoURL != null
              ? NetworkImage(request.passengerPhotoURL!)
              : null,
          child: request.passengerPhotoURL == null
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(request.passengerName),
        subtitle: isCompleted && !jaAvaliado
            ? const Text(
                'Avalie este passageiro',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCompleted && !jaAvaliado)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AvaliarButton(
                  caronaId: ride.id,
                  avaliadorUsuarioId: currentUserId,
                  avaliadoUsuarioId: request.passengerId,
                  avaliadoNome: request.passengerName,
                  onAvaliacaoEnviada: () {
                    setState(() {
                      _avaliacaoVerificada[avaliacaoKey] = true;
                    });
                  },
                ),
              ),
            IconButton(
              icon: const Icon(Icons.chat, color: Color(0xFF2196F3)),
              onPressed: ride.id.isNotEmpty ? () => _openChat(ride, request) : null,
              tooltip: 'Conversar',
            ),
            const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  /// Verifica se já avaliou um passageiro (carrega do cache ou do Firestore)
  Future<void> _verificarAvaliacoesExistentes() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? '';
    
    if (currentUserId.isEmpty) return;

    for (final ride in _myRides) {
      if (ride.status != 'completed') continue;
      
      final requests = _requestsByRide[ride.id] ?? [];
      final acceptedRequests = requests.where((r) => r.isAccepted).toList();

      for (final request in acceptedRequests) {
        final avaliacaoKey = '${ride.id}_${currentUserId}_${request.passengerId}';
        
        if (!_avaliacaoVerificada.containsKey(avaliacaoKey)) {
          final jaAvaliado = await _avaliacaoService.verificarAvaliacaoExistente(
            caronaId: ride.id,
            avaliadorUsuarioId: currentUserId,
            avaliadoUsuarioId: request.passengerId,
          );
          
          _avaliacaoVerificada[avaliacaoKey] = jaAvaliado;
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Abre a tela de chat com um passageiro
  void _openChat(Ride ride, RideRequest request) {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'ride': ride,
        'isDriver': true,
        'otherUserName': request.passengerName,
        'otherUserPhotoURL': request.passengerPhotoURL,
        'otherUserId': request.passengerId,
      },
    );
  }

  /// Estado vazio
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma carona encontrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ofereça sua primeira carona!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Cor do status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Ícone do status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}
