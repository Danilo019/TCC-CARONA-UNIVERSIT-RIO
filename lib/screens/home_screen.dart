import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../components/map_widget.dart';
import '../models/ride.dart';
import '../models/location.dart';
import '../services/location_service.dart';
import '../services/google_maps_service.dart';
import '../services/rides_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Tela principal do aplicativo após o onboarding
/// 
/// Exibe:
/// - Saudação personalizada com botão de perfil
/// - Dois botões de ação: "Oferecer Carona" e "Procurar Carona"
/// - Mapa interativo com marcadores de caronas disponíveis
/// - Navegação inferior com 4 opções: Início, Viagens, Mensagens, Perfil
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final LocationService _locationService = LocationService();
  final GoogleMapsService _googleMapsService = GoogleMapsService();
  final RidesService _ridesService = RidesService();
  Location? _userLocation;
  bool _isLoadingLocation = false;
  StreamSubscription<Position>? _locationSubscription;
  List<Ride> _rides = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadRides();
  }
  
  /// Carrega caronas do Firestore
  Future<void> _loadRides() async {
    try {
      final rides = await _ridesService.getActiveRides();
      if (mounted) {
        setState(() {
          _rides = rides;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao carregar caronas: $e');
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Inicializa e monitora localização do usuário
  Future<void> _initializeLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Verifica se já tem permissão
      final hasPermission = await _locationService.hasLocationPermission();
      
      if (hasPermission) {
        // Obtém localização atual
        await _getCurrentLocation();

        // Inicia monitoramento em tempo real
        _startLocationMonitoring();
      } else {
        // Tenta solicitar permissão
        final granted = await _locationService.requestLocationPermission();
        if (granted) {
          await _getCurrentLocation();
          _startLocationMonitoring();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao inicializar localização: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// Obtém localização atual do usuário
  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        final location = Location(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );

        // Faz reverse geocoding para obter endereço
        final geocodeResult = await _googleMapsService.reverseGeocode(location);
        
        if (mounted) {
          setState(() {
            _userLocation = geocodeResult?.location ?? location;
          });
          
          if (kDebugMode) {
            print('✓ Localização atualizada: ${_userLocation!.latitude}, ${_userLocation!.longitude}');
            if (geocodeResult != null) {
              print('✓ Endereço: ${geocodeResult.formattedAddress}');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter localização: $e');
      }
    }
  }

  /// Inicia monitoramento de localização em tempo real
  void _startLocationMonitoring() {
    _locationSubscription?.cancel();
    
    _locationSubscription = _locationService.watchPosition().listen(
      (Position position) async {
        final location = Location(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );

        // Atualiza localização (sem fazer geocoding a cada atualização para economizar API calls)
        if (mounted) {
          setState(() {
            _userLocation = location;
          });
          
          if (kDebugMode) {
            print('📍 Localização atualizada em tempo real: ${location.latitude}, ${location.longitude}');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('✗ Erro no stream de localização: $error');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header com saudação e botão de perfil
            _buildHeader(),

            // Botões de ação principais
            _buildActionButtons(),

            const SizedBox(height: 20),

            // Mapa com caronas disponíveis
            Expanded(
              child: _buildMapSection(),
            ),
          ],
        ),
      ),
      // Navegação inferior
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// Constrói o header com saudação e botão de perfil
  Widget _buildHeader() {
    return Consumer<app_auth.AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;
        final displayName = user?.displayNameOrEmail ?? "Usuário";
        final photoURL = user?.photoURL;
        
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Saudação
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bem-vindo(a) de volta,',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Olá, $displayName!',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              // Botão de perfil com foto
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: photoURL != null && photoURL.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            photoURL,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person_outline, size: 28);
                            },
                          ),
                        )
                      : const Icon(Icons.person_outline, size: 28, color: Colors.black87),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Constrói os botões de ação principais
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Botão "Oferecer Carona"
          Expanded(
            child: _buildActionButton(
              label: 'Oferecer Carona',
              icon: Icons.add_road,
              color: const Color(0xFF2196F3),
              textColor: Colors.white,
              onTap: () async {
                // Navega para tela de oferecer carona
                final result = await Navigator.of(context).pushNamed('/offer-ride');
                // Atualiza o mapa se uma carona foi criada
                if (result == true && mounted) {
                  await _loadRides();
                }
              },
            ),
          ),

          const SizedBox(width: 16),

          // Botão "Procurar Carona"
          Expanded(
            child: _buildActionButton(
              label: 'Procurar Carona',
              icon: Icons.search,
              color: Colors.white,
              textColor: Colors.black87,
              onTap: () {
                // Navega para tela de procurar carona
                Navigator.of(context).pushNamed('/search-ride');
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói um botão de ação personalizado
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color == Colors.white
                  ? Colors.black.withValues(alpha: 0.08)
                  : color.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color: textColor,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói a seção do mapa com marcadores de caronas
  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _isLoadingLocation
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : MapWidget(
                  // Usa localização do usuário se disponível
                  initialLocation: _userLocation,
                  rides: _rides,
                  onRideTap: (ride) {
                    _showRideDetailsDialog(ride);
                  },
                  onMapTap: (location) {
                    if (kDebugMode) {
                      print('Mapa tocado em: ${location.latitude}, ${location.longitude}');
                    }
                  },
                  showUserLocation: true,
                  showRideMarkers: true,
                ),
        ),
      ),
    );
  }


  /// Constrói a barra de navegação inferior
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Navegação baseada no índice
          if (index == 3) {
            // Perfil - navegar para tela de perfil
            Navigator.of(context).pushNamed('/profile');
          } else if (index == 2) {
            // Mensagens
            _showComingSoonDialog('Mensagens');
          } else if (index == 1) {
            // Viagens
            _showComingSoonDialog('Viagens');
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2196F3),
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Início',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Viagens',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.mail_outline),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            activeIcon: const Icon(Icons.mail),
            label: 'Mensagens',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  /// Exibe diálogo de "Em breve"
  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: const Text('Esta funcionalidade estará disponível em breve!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Exibe detalhes de uma carona
  void _showRideDetailsDialog(Ride ride) {
    final timeStr = ride.dateTime.toString().substring(11, 16); // HH:mm
    
    // Calcula distância antecipadamente (fora do StatefulBuilder para evitar múltiplas chamadas)
    Future<DistanceMatrixResult?>? distanceFuture;
    if (_userLocation != null) {
      distanceFuture = _googleMapsService.getDistanceMatrix(
        origin: _userLocation!,
        destination: ride.origin,
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Carona Disponível'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Motorista: ${ride.driverName}'),
              const SizedBox(height: 8),
              Text('Origem: ${ride.origin.address ?? "Indefinida"}'),
              const SizedBox(height: 8),
              Text('Destino: ${ride.destination.address ?? "Indefinido"}'),
              const SizedBox(height: 8),
              Text('Horário: $timeStr'),
              const SizedBox(height: 8),
              Text('Vagas: ${ride.availableSeats} disponíveis de ${ride.maxSeats}'),
              if (_userLocation != null && distanceFuture != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                FutureBuilder<DistanceMatrixResult?>(
                  future: distanceFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Calculando distância...'),
                        ],
                      );
                    } else if (snapshot.hasError || 
                               snapshot.data == null || 
                               (snapshot.data == null && snapshot.connectionState == ConnectionState.done)) {
                      return Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Habilite Distance Matrix API no Google Cloud Console',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      );
                    } else if (snapshot.hasData) {
                      final result = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.straighten, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Distância: ${result.distanceKm.toStringAsFixed(1)} km',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Tempo: ${_formatDuration(result.duration)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ],
              if (ride.description != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text('Descrição: ${ride.description}'),
              ],
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
              _showComingSoonDialog('Solicitar Carona');
            },
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );
  }

  /// Formata duração para exibição
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
    } else {
      return '${duration.inMinutes}min';
    }
  }
}

