import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../components/map_widget.dart';
import '../models/ride.dart';
import '../models/location.dart';
import '../models/ride_request.dart';
import '../models/chat_message.dart';
import '../services/location_service.dart';
import '../services/google_maps_service.dart';
import '../services/rides_service.dart';
import '../services/ride_request_service.dart';
import '../services/chat_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'trip_history_screen.dart';

/// Tela principal do aplicativo após o onboarding
/// 
/// Exibe:
/// - Saudação personalizada com botão de perfil
/// - Dois botões de ação: "Motorista" e "Passageiro"
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
  final RideRequestService _rideRequestService = RideRequestService();
  final ChatService _chatService = ChatService();
  Location? _userLocation;
  bool _isLoadingLocation = false;
  StreamSubscription<Position>? _locationSubscription;
  List<Ride> _rides = [];
  List<Ride> _myRides = []; // Caronas do motorista
  List<RideRequest> _acceptedRequests = []; // Solicitações aceitas (passageiro)
  int _totalUnreadMessages = 0; // Total de mensagens não lidas

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadRides();
    _loadChats();
    // Atualiza contador de mensagens não lidas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateUnreadCount();
    });
  }

  /// Carrega conversas (caronas com solicitações aceitas)
  Future<void> _loadChats() async {
    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) return;

      // Carrega caronas do motorista
      try {
        final ridesStream = _ridesService.watchRidesByDriver(user.uid);
        ridesStream.listen(
          (rides) {
            if (mounted) {
              setState(() {
                _myRides = rides;
              });
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('⚠ Erro no stream de caronas do motorista: $error');
            }
          },
        );
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Erro ao carregar stream de caronas: $e');
        }
      }

      // Carrega primeira vez - com fallback
      List<Ride> myRides = [];
      try {
        final rides = await _ridesService.getActiveRides();
        myRides = rides.where((r) => r.driverId == user.uid).toList();
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Erro ao carregar caronas ativas: $e');
        }
        // Usa lista vazia como fallback
        myRides = [];
      }
      
      // Carrega solicitações aceitas do passageiro - com tratamento de erro
      List<RideRequest> acceptedRequests = [];
      try {
        final requests = await _rideRequestService.getRequestsByPassenger(user.uid);
        acceptedRequests = requests.where((r) => r.isAccepted).toList();
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Erro ao carregar solicitações (permissão negada): $e');
          print('💡 Configure as regras do Firestore para permitir leitura de ride_requests');
        }
        // Continua sem solicitações, não quebra a aplicação
      }

      if (mounted) {
        setState(() {
          _myRides = myRides;
          _acceptedRequests = acceptedRequests;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao carregar conversas: $e');
      }
      // Não quebra a aplicação, apenas mostra estado vazio
      if (mounted) {
        setState(() {
          _myRides = [];
          _acceptedRequests = [];
        });
      }
    }
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
        child: _selectedIndex == 0
            ? Column(
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
              )
            : _selectedIndex == 2
                ? _buildMessagesScreen()
                : _selectedIndex == 1
                    ? _buildTripsScreen()
                    : const SizedBox.shrink(),
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
          // Botão "Motorista"
          Expanded(
            child: _buildActionButton(
              label: 'Motorista',
              icon: Icons.directions_car,
              color: const Color(0xFF2196F3),
              textColor: Colors.white,
              onTap: () async {
                // Navega para tela de motorista
                final result = await Navigator.of(context).pushNamed('/motorist');
                // Atualiza o mapa se uma carona foi criada
                if (result == true && mounted) {
                  await _loadRides();
                }
              },
            ),
          ),

          const SizedBox(width: 16),

          // Botão "Passageiro"
          Expanded(
            child: _buildActionButton(
              label: 'Passageiro',
              icon: Icons.person,
              color: Colors.white,
              textColor: Colors.black87,
              onTap: () async {
                // Navega para tela de passageiro
                await Navigator.of(context).pushNamed('/passenger');
                // Recarrega caronas quando voltar
                if (mounted) {
                  await _loadRides();
                }
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
            // Mensagens - já carrega na tela
            _loadChats();
            // Atualiza contador de não lidas
            _updateUnreadCount();
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
                if (_totalUnreadMessages > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _totalUnreadMessages > 99 ? '99+' : _totalUnreadMessages.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: Stack(
              children: [
                const Icon(Icons.mail),
                if (_totalUnreadMessages > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _totalUnreadMessages > 99 ? '99+' : _totalUnreadMessages.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
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

  /// Constrói a tela de mensagens
  Widget _buildMessagesScreen() {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      return const Center(
        child: Text('Faça login para ver suas mensagens'),
      );
    }

    // Usa StreamBuilder para atualizar conversas em tempo real
    return StreamBuilder<List<_ChatListItemWithStream>>(
      stream: _watchChatList(user.uid),
      builder: (context, snapshot) {
        // Mostra loading apenas na primeira vez
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Se há erro e não há dados, mostra mensagem
        if (snapshot.hasError && !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar conversas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Verifique se os índices do Firestore estão configurados corretamente.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final chatList = snapshot.data ?? [];

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Row(
                children: [
                  const Text(
                    'Mensagens',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _loadChats();
                      setState(() {});
                    },
                    tooltip: 'Atualizar',
                  ),
                ],
              ),
            ),

            // Lista de conversas
            Expanded(
              child: chatList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma conversa ainda',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Inicie uma conversa através de uma carona!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadChats();
                        setState(() {});
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: chatList.length,
                        itemBuilder: (context, index) {
                          final chat = chatList[index];
                          return _buildChatItemWithStream(chat, user.uid);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Carrega lista completa de conversas
  Future<List<_ChatListItem>> _loadChatList(String userId) async {
    List<_ChatListItem> chatList = [];

    try {
      // Carrega todas as caronas ativas primeiro - com fallback
      List<Ride> allRides = [];
      try {
        allRides = await _ridesService.getActiveRides();
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Erro ao carregar caronas ativas, usando lista local: $e');
        }
        // Usa lista local como fallback
        allRides = _rides;
      }

      // Adiciona conversas como passageiro (solicitações aceitas)
      for (final request in _acceptedRequests) {
        try {
          final ride = allRides.firstWhere(
            (r) => r.id == request.rideId,
            orElse: () => Ride(
              id: '',
              driverId: '',
              driverName: '',
              origin: Location(latitude: 0, longitude: 0, timestamp: DateTime.now()),
              destination: Location(latitude: 0, longitude: 0, timestamp: DateTime.now()),
              dateTime: DateTime.now(),
              maxSeats: 1,
              availableSeats: 0,
              createdAt: DateTime.now(),
            ),
          );

          if (ride.id.isNotEmpty) {
            chatList.add(_ChatListItem(
              ride: ride,
              isDriver: false,
              otherUserName: ride.driverName,
              otherUserPhotoURL: ride.driverPhotoURL,
              otherUserId: ride.driverId,
            ));
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠ Erro ao processar solicitação ${request.id}: $e');
          }
        }
      }

      // Adiciona conversas como motorista (caronas com passageiros aceitos)
      for (final ride in _myRides) {
        try {
          // Usa timeout para evitar travamento quando há erro de índice
          final requests = await _rideRequestService
              .getRequestsByRide(ride.id)
              .timeout(const Duration(seconds: 3), onTimeout: () {
            if (kDebugMode) {
              print('⚠ Timeout ao buscar solicitações da carona ${ride.id}');
            }
            return <RideRequest>[];
          });
          
          final accepted = requests.where((r) => r.isAccepted).toList();
          
          for (final request in accepted) {
            if (!chatList.any((item) => item.ride.id == ride.id && item.otherUserId == request.passengerId)) {
              chatList.add(_ChatListItem(
                ride: ride,
                isDriver: true,
                otherUserName: request.passengerName,
                otherUserPhotoURL: request.passengerPhotoURL,
                otherUserId: request.passengerId,
              ));
            }
          }
        } catch (e) {
          if (kDebugMode) {
            final errorMsg = e.toString();
            if (errorMsg.contains('index')) {
              print('⚠ Índice do Firestore faltando para carona ${ride.id}. Crie o índice necessário.');
            } else {
              print('⚠ Erro ao carregar solicitações da carona ${ride.id}: $e');
            }
          }
          // Continua sem quebrar, apenas não mostra esta conversa
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro geral ao carregar lista de conversas: $e');
      }
    }

    return chatList;
  }

  /// Stream de lista de conversas atualizada em tempo real
  Stream<List<_ChatListItemWithStream>> _watchChatList(String userId) async* {
    // Carrega lista inicial de conversas com timeout
    List<_ChatListItem> initialList = [];
    try {
      initialList = await _loadChatList(userId)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        if (kDebugMode) {
          print('⚠ Timeout ao carregar lista inicial de conversas');
        }
        return <_ChatListItem>[];
      });
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao carregar lista inicial de conversas: $e');
      }
      // Emite lista vazia em caso de erro
      initialList = [];
    }

    // Converte para lista com streams
    List<_ChatListItemWithStream> chatListWithStreams = initialList.map((chat) {
      return _ChatListItemWithStream(
        ride: chat.ride,
        isDriver: chat.isDriver,
        otherUserName: chat.otherUserName,
        otherUserPhotoURL: chat.otherUserPhotoURL,
        otherUserId: chat.otherUserId,
      );
    }).toList();

    // Emite lista inicial
    yield chatListWithStreams;

    // Observa mudanças nas caronas e solicitações
    // Quando há mudanças, recarrega a lista
    try {
      final ridesStream = _ridesService.watchRidesByDriver(userId);
      await for (final rides in ridesStream.timeout(const Duration(seconds: 30))) {
        if (!mounted) break;
        
        try {
          setState(() {
            _myRides = rides;
          });
          
          // Recarrega lista de conversas com timeout
          final updatedList = await _loadChatList(userId)
              .timeout(const Duration(seconds: 5), onTimeout: () {
            if (kDebugMode) {
              print('⚠ Timeout ao atualizar lista de conversas');
            }
            return <_ChatListItem>[];
          });
          
          chatListWithStreams = updatedList.map((chat) {
            return _ChatListItemWithStream(
              ride: chat.ride,
              isDriver: chat.isDriver,
              otherUserName: chat.otherUserName,
              otherUserPhotoURL: chat.otherUserPhotoURL,
              otherUserId: chat.otherUserId,
            );
          }).toList();
          
          yield chatListWithStreams;
        } catch (e) {
          if (kDebugMode) {
            print('✗ Erro ao atualizar lista de conversas: $e');
          }
          // Emite lista vazia em caso de erro
          yield [];
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro no stream de caronas: $e');
      }
      // Emite lista vazia em caso de erro no stream
      yield [];
    }
  }

  /// Constrói item de conversa com stream em tempo real
  Widget _buildChatItemWithStream(_ChatListItemWithStream chat, String userId) {
    return StreamBuilder<ChatMessage?>(
      stream: _chatService.watchLastMessage(chat.ride.id),
      builder: (context, lastMessageSnapshot) {
        final lastMessage = lastMessageSnapshot.data;
        
        return StreamBuilder<int>(
          stream: _chatService.watchUnreadCount(chat.ride.id, userId),
          builder: (context, unreadSnapshot) {
            final unreadCount = unreadSnapshot.data ?? 0;
            
            // Atualiza contador total de não lidas (será atualizado pela função _updateUnreadCount)
            
            final lastMessageText = lastMessage?.message ?? 'Nenhuma mensagem ainda';
            final lastMessageTime = lastMessage?.timestamp ?? chat.ride.dateTime;
            
            String timeStr;
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final messageDate = DateTime(lastMessageTime.year, lastMessageTime.month, lastMessageTime.day);
            
            if (messageDate == today) {
              timeStr = DateFormat('HH:mm').format(lastMessageTime);
            } else if (messageDate == today.subtract(const Duration(days: 1))) {
              timeStr = 'Ontem ${DateFormat('HH:mm').format(lastMessageTime)}';
            } else {
              timeStr = DateFormat('dd/MM HH:mm').format(lastMessageTime);
            }
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: unreadCount > 0 ? 2 : 0,
              child: ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: chat.otherUserPhotoURL != null
                      ? NetworkImage(chat.otherUserPhotoURL!)
                      : null,
                  child: chat.otherUserPhotoURL == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.otherUserName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${chat.ride.origin.address?.split(',').first ?? "Origem"} → ${chat.ride.destination.address?.split(',').first ?? "Destino"}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessageText,
                            style: TextStyle(
                              fontSize: 13,
                              color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                              fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  // Marca mensagens como lidas ao abrir o chat
                  await _chatService.markAsRead(chat.ride.id, userId);
                  
                  Navigator.pushNamed(
                    context,
                    '/chat',
                    arguments: {
                      'ride': chat.ride,
                      'isDriver': chat.isDriver,
                      'otherUserName': chat.otherUserName,
                      'otherUserPhotoURL': chat.otherUserPhotoURL,
                      'otherUserId': chat.otherUserId,
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Constrói a tela de viagens (placeholder)
  Widget _buildTripsScreen() {
    return const TripHistoryScreen();
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
              _requestRide(ride);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
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

  /// Solicita uma carona
  Future<void> _requestRide(Ride ride) async {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      _showError('Você precisa estar logado para solicitar uma carona');
      return;
    }

    // Verifica se há vagas disponíveis
    if (ride.availableSeats <= 0) {
      _showError('Não há vagas disponíveis nesta carona');
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
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Cria solicitação de carona
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

      final requestId = await _rideRequestService.createRequest(request);

      if (mounted) {
        Navigator.pop(context); // Fecha loading

        if (requestId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitação enviada com sucesso! Aguarde a aprovação do motorista.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          _showError('Erro ao enviar solicitação. Tente novamente.');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fecha loading
        _showError('Erro ao solicitar carona: $e');
      }
    }
  }

  /// Exibe mensagem de erro
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Atualiza contador total de mensagens não lidas
  Future<void> _updateUnreadCount() async {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user == null || !mounted) return;
    
    try {
      // Carrega lista de conversas
      final chatList = await _loadChatList(user.uid);
      int total = 0;
      
      // Para cada conversa, conta mensagens não lidas
      for (final chat in chatList) {
        try {
          final lastRead = await _chatService.getLastReadTimestamp(chat.ride.id, user.uid);
          final unreadStream = _chatService.watchUnreadCount(chat.ride.id, user.uid, lastReadTimestamp: lastRead);
          
          // Pega o primeiro valor do stream com timeout de 2 segundos
          int unreadCount = 0;
          try {
            unreadCount = await unreadStream
                .timeout(const Duration(seconds: 2))
                .first;
          } catch (timeoutError) {
            // Se timeout, assume 0 mensagens não lidas
            if (kDebugMode) {
              print('⚠ Timeout ao contar não lidas para ${chat.ride.id}');
            }
            unreadCount = 0;
          }
          
          total += unreadCount;
        } catch (e) {
          if (kDebugMode) {
            print('⚠ Erro ao contar não lidas para ${chat.ride.id}: $e');
          }
          // Continua para próxima conversa (assume 0 não lidas)
        }
      }
      
      if (mounted) {
        setState(() {
          _totalUnreadMessages = total;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao atualizar contador de não lidas: $e');
      }
    }
  }
}

/// Modelo para item de conversa na lista
class _ChatListItem {
  final Ride ride;
  final bool isDriver;
  final String otherUserName;
  final String? otherUserPhotoURL;
  final String otherUserId;

  _ChatListItem({
    required this.ride,
    required this.isDriver,
    required this.otherUserName,
    this.otherUserPhotoURL,
    required this.otherUserId,
  });
}

/// Modelo para item de conversa com suporte a streams em tempo real
class _ChatListItemWithStream {
  final Ride ride;
  final bool isDriver;
  final String otherUserName;
  final String? otherUserPhotoURL;
  final String otherUserId;

  _ChatListItemWithStream({
    required this.ride,
    required this.isDriver,
    required this.otherUserName,
    this.otherUserPhotoURL,
    required this.otherUserId,
  });
}


