// Tela de busca de caronas - permite filtrar e visualizar caronas disponíveis
// Suporta filtros por localização, data e busca textual

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/ride.dart';
import '../models/location.dart';
import '../models/ride_request.dart';
import '../services/rides_service.dart';
import '../services/google_maps_service.dart';
import '../services/location_service.dart';
import '../services/ride_request_service.dart';
import '../components/map_widget.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// Widget stateful que gerencia busca e exibição de caronas
// Alterna entre visualização em lista e mapa
class SearchRideScreen extends StatefulWidget {
  const SearchRideScreen({super.key});

  @override
  State<SearchRideScreen> createState() => _SearchRideScreenState();

  /// Recarrega as caronas quando volta para esta tela
  static void reloadOnReturn(BuildContext context) {
    // Será chamado quando voltar de outra tela
    final state = context.findAncestorStateOfType<_SearchRideScreenState>();
    state?._loadRides();
  }
}

class _SearchRideScreenState extends State<SearchRideScreen> {
  final RidesService _ridesService = RidesService();
  final LocationService _locationService = LocationService();
  final RideRequestService _requestService = RideRequestService();

  List<Ride> _allRides = [];
  List<Ride> _filteredRides = [];
  Location? _userLocation;
  bool _isLoading = false;
  String _searchQuery = '';
  int _selectedFilter = 0; // 0: Todas, 1: Próximas, 2: Hoje, 3: Amanhã

  // Índice para alternar entre visualizações
  int _viewMode = 0; // 0: Lista, 1: Mapa

  @override
  void initState() {
    super.initState();
    _loadRides();
    _loadCurrentLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega caronas quando a tela é exibida novamente
    // Isso garante que novas caronas apareçam imediatamente
  }

  /// Carrega caronas do Firestore
  Future<void> _loadRides() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        print('🔍 Buscando caronas ativas...');
      }

      final rides = await _ridesService.getActiveRides();

      if (kDebugMode) {
        print('✓ ${rides.length} caronas carregadas');
        for (var ride in rides) {
          print(
            '  - ${ride.driverName}: ${ride.origin.address ?? 'Sem endereço'} → ${ride.destination.address ?? 'Sem endereço'}',
          );
        }
      }

      if (mounted) {
        setState(() {
          _allRides = rides;
          _filteredRides = rides;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('✗ Erro ao carregar caronas: $e');
        print('  Stack trace: $stackTrace');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Carrega localização atual do usuário
  Future<void> _loadCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();

      if (position != null) {
        _userLocation = Location(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      // Erro ao carregar localização é ignorado silenciosamente
    }
  }

  /// Aplica filtros de busca
  void _applyFilters() {
    List<Ride> filtered = List.from(_allRides);

    // Filtro por busca de texto
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((ride) {
        final query = _searchQuery.toLowerCase();
        return ride.origin.address?.toLowerCase().contains(query) == true ||
            ride.destination.address?.toLowerCase().contains(query) == true ||
            ride.driverName.toLowerCase().contains(query);
      }).toList();
    }

    // Filtros de data
    if (_selectedFilter == 1) {
      // Próximas (raio de 10km)
      if (_userLocation != null) {
        filtered = _filterNearbyRides(filtered, radius: 10.0);
      }
    } else if (_selectedFilter == 2) {
      // Hoje
      final today = DateTime.now();
      filtered = filtered.where((ride) {
        return ride.dateTime.year == today.year &&
            ride.dateTime.month == today.month &&
            ride.dateTime.day == today.day;
      }).toList();
    } else if (_selectedFilter == 3) {
      // Amanhã
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      filtered = filtered.where((ride) {
        return ride.dateTime.year == tomorrow.year &&
            ride.dateTime.month == tomorrow.month &&
            ride.dateTime.day == tomorrow.day;
      }).toList();
    }

    setState(() {
      _filteredRides = filtered;
    });
  }

  /// Filtra caronas próximas
  List<Ride> _filterNearbyRides(List<Ride> rides, {double radius = 10.0}) {
    if (_userLocation == null) return rides;

    return rides.where((ride) {
      final distance = LocationService.calculateDistance(
        _userLocation!.latitude,
        _userLocation!.longitude,
        ride.origin.latitude,
        ride.origin.longitude,
      );
      return distance <= radius;
    }).toList();
  }

  /// Solicita uma vaga na carona (cria solicitação para o motorista aceitar/rejeitar)
  Future<void> _reserveRide(Ride ride) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para solicitar uma carona'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Verifica se há vagas disponíveis
    if (ride.availableSeats <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há vagas disponíveis nesta carona'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostra diálogo para confirmar solicitação
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar Carona'),
        content: Text(
          'Deseja solicitar uma vaga na carona de ${ride.driverName}?\n\n'
          'Origem: ${ride.origin.address ?? 'Não informada'}\n'
          'Destino: ${ride.destination.address ?? 'Não informado'}\n'
          'Horário: ${DateFormat('dd/MM/yyyy às HH:mm').format(ride.dateTime)}',
        ),
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
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Cria solicitação de carona (não reserva diretamente)
      final request = RideRequest(
        id: '', // Será gerado pelo Firestore
        rideId: ride.id,
        passengerId: user.uid,
        passengerName: user.displayNameOrEmail,
        passengerPhotoURL: user.photoURL,
        status: 'pending',
        message: null,
        createdAt: DateTime.now(),
      );

      final requestId = await _requestService.createRequest(request);

      if (mounted) {
        Navigator.pop(context); // Fecha loading

        if (requestId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Solicitação enviada com sucesso! Aguarde a aprovação do motorista.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Atualiza lista
          await _loadRides();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao enviar solicitação. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fecha loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao solicitar carona: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exibe detalhes da carona
  Future<void> _showRideDetails(Ride ride) async {
    // Verifica se o usuário tem solicitação aceita para esta carona
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    RideRequest? acceptedRequest;
    if (user != null) {
      final requests = await _requestService.getRequestsByPassenger(user.uid);
      acceptedRequest = requests.firstWhere(
        (r) => r.rideId == ride.id && r.isAccepted,
        orElse: () => RideRequest(
          id: '',
          rideId: '',
          passengerId: '',
          passengerName: '',
          createdAt: DateTime.now(),
        ),
      );
      if (acceptedRequest.id.isEmpty) {
        acceptedRequest = null;
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RideDetailsBottomSheet(
        ride: ride,
        userLocation: _userLocation,
        onReserve: () => _reserveRide(ride),
        acceptedRequest: acceptedRequest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Procurar Carona'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Botão de atualizar
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadRides();
            },
            tooltip: 'Atualizar lista',
          ),
          IconButton(
            icon: Icon(_viewMode == 0 ? Icons.map : Icons.list),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 0 ? 1 : 0;
              });
            },
            tooltip: _viewMode == 0 ? 'Ver mapa' : 'Ver lista',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca e filtros
          _buildSearchAndFilters(),

          // Conteúdo principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRides.isEmpty
                ? _buildEmptyState()
                : _viewMode == 0
                ? _buildListView()
                : _buildMapView(),
          ),
        ],
      ),
    );
  }

  /// Barra de busca e filtros
  Widget _buildSearchAndFilters() {
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
      child: Column(
        children: [
          // Barra de busca
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Buscar origem ou destino...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, 'Todas', Icons.all_inclusive),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Próximas', Icons.near_me),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Hoje', Icons.today),
                const SizedBox(width: 8),
                _buildFilterChip(3, 'Amanhã', Icons.calendar_today),
              ],
            ),
          ),
        ],
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
        _applyFilters();
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

  /// Lista de caronas
  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _loadRides,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredRides.length,
        itemBuilder: (context, index) {
          return _buildRideCard(_filteredRides[index]);
        },
      ),
    );
  }

  /// Vista de mapa
  Widget _buildMapView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: MapWidget(
            initialLocation: _userLocation,
            rides: _filteredRides,
            onRideTap: _showRideDetails,
            showUserLocation: true,
            showRideMarkers: true,
          ),
        ),
      ),
    );
  }

  /// Card de carona
  Widget _buildRideCard(Ride ride) {
    final timeStr = DateFormat('dd/MM HH:mm').format(ride.dateTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showRideDetails(ride),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com motorista e horário
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: ride.driverPhotoURL != null
                        ? NetworkImage(ride.driverPhotoURL!)
                        : null,
                    child: ride.driverPhotoURL == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.driverName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
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
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${ride.availableSeats}/${ride.maxSeats}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Origem
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.origin.address ?? 'Origem não informada',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Destino
              Row(
                children: [
                  const Icon(Icons.location_city, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.destination.address ?? 'Destino não informado',
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (ride.description != null && ride.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ride.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Botão de solicitar carona
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: ride.availableSeats > 0
                      ? () => _reserveRide(ride)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ride.availableSeats > 0
                        ? const Color(0xFF2196F3)
                        : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    ride.availableSeats > 0 ? 'Solicitar Carona' : 'Sem Vagas',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Estado vazio
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Nenhuma carona encontrada'
                : 'Nenhuma carona disponível',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tente outra busca'
                : 'Ofereça a primeira carona!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet com detalhes da carona
class _RideDetailsBottomSheet extends StatelessWidget {
  final Ride ride;
  final Location? userLocation;
  final VoidCallback onReserve;
  final RideRequest? acceptedRequest;

  const _RideDetailsBottomSheet({
    required this.ride,
    this.userLocation,
    required this.onReserve,
    this.acceptedRequest,
  });

  /// Abre a tela de chat
  void _openChat(BuildContext context) {
    Navigator.pop(context); // Fecha o bottom sheet
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'ride': ride,
        'isDriver': false,
        'otherUserName': ride.driverName,
        'otherUserPhotoURL': ride.driverPhotoURL,
        'otherUserId': ride.driverId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat("dd/MM/yyyy 'às' HH:mm").format(ride.dateTime);

    // Calcula distância se tiver localização do usuário
    Future<String?>? distanceFuture;
    if (userLocation != null) {
      final service = GoogleMapsService();
      distanceFuture = service
          .getDistanceMatrix(origin: userLocation!, destination: ride.origin)
          .then((result) {
            if (result != null) {
              return '${result.distanceKm.toStringAsFixed(1)} km - ${result.duration.inMinutes} min';
            }
            return null;
          })
          .catchError((_) => null);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Motorista
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: ride.driverPhotoURL != null
                    ? NetworkImage(ride.driverPhotoURL!)
                    : null,
                child: ride.driverPhotoURL == null
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.driverName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${ride.availableSeats}/${ride.maxSeats} vagas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),

          const SizedBox(height: 24),

          // Origem
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: Colors.green,
            label: 'Origem',
            address: ride.origin.address ?? 'Não informada',
          ),

          const SizedBox(height: 20),

          // Destino
          _buildLocationRow(
            icon: Icons.location_city,
            iconColor: Colors.red,
            label: 'Destino',
            address: ride.destination.address ?? 'Não informado',
          ),

          // Distância (se disponível)
          if (distanceFuture != null) ...[
            const SizedBox(height: 16),
            FutureBuilder<String?>(
              future: distanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Calculando distância...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  );
                }

                if (snapshot.hasData && snapshot.data != null) {
                  return Row(
                    children: [
                      const Icon(
                        Icons.straighten,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        snapshot.data!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ],

          if (ride.description != null && ride.description!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Descrição',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(ride.description!, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ],

          const SizedBox(height: 32),

          // Botão de chat (se tem solicitação aceita)
          if (acceptedRequest != null) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _openChat(context),
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text(
                  'Conversar com Motorista',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Botão de solicitar carona
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: ride.availableSeats > 0 && acceptedRequest == null
                  ? onReserve
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    ride.availableSeats > 0 && acceptedRequest == null
                    ? const Color(0xFF2196F3)
                    : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                acceptedRequest != null
                    ? 'Solicitação Aceita'
                    : ride.availableSeats > 0
                    ? 'Solicitar Carona'
                    : 'Sem Vagas',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
