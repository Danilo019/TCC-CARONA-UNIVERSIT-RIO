import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/ride.dart';
import '../models/ride_request.dart';
import '../providers/auth_provider.dart';
import '../services/ride_request_service.dart';
import '../services/rides_service.dart';

/// Tela/tab responsável por exibir o histórico de viagens do usuário
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final RidesService _ridesService = RidesService();
  final RideRequestService _rideRequestService = RideRequestService();

  StreamSubscription<List<Ride>>? _driverSubscription;
  StreamSubscription<List<RideRequest>>? _passengerSubscription;

  List<Ride> _driverRides = [];
  List<_PassengerRideData> _passengerRides = [];

  bool _isLoading = true;
  String? _errorMessage;
  int _passengerSyncVersion = 0;

  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormatter = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeHistory();
    });
  }

  @override
  void dispose() {
    _driverSubscription?.cancel();
    _passengerSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      setState(() {
        _errorMessage = 'Não foi possível identificar o usuário autenticado.';
        _isLoading = false;
      });
      return;
    }

    _driverSubscription = _ridesService.watchRidesByDriver(user.uid).listen(
      (rides) {
        if (!mounted) return;

        final sorted = List<Ride>.from(rides)
          ..sort(
            (a, b) => b.dateTime.compareTo(a.dateTime),
          );

        setState(() {
          _driverRides = sorted;
          _isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Erro ao carregar caronas como motorista.';
          _isLoading = false;
        });
      },
    );

    _passengerSubscription =
        _rideRequestService.watchRequestsByPassenger(user.uid).listen(
      (requests) {
        _updatePassengerHistory(requests);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Erro ao carregar caronas como passageiro.';
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _updatePassengerHistory(List<RideRequest> requests) async {
    final syncId = ++_passengerSyncVersion;

    if (requests.isEmpty) {
      if (!mounted || syncId != _passengerSyncVersion) return;
      setState(() {
        _passengerRides = [];
        _isLoading = false;
      });
      return;
    }

    final rideIds = requests.map((request) => request.rideId).toSet().toList();

    try {
      final rides = await _ridesService.getRidesByIds(rideIds);
      final rideMap = {for (final ride in rides) ride.id: ride};

      final historyEntries = <_PassengerRideData>[];

      for (final request in requests) {
        final ride = rideMap[request.rideId];
        if (ride != null) {
          historyEntries.add(
            _PassengerRideData(ride: ride, request: request),
          );
        }
      }

      historyEntries.sort(
        (a, b) => b.ride.dateTime.compareTo(a.ride.dateTime),
      );

      if (!mounted || syncId != _passengerSyncVersion) {
        return;
      }

      setState(() {
        _passengerRides = historyEntries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || syncId != _passengerSyncVersion) {
        return;
      }
      setState(() {
        _errorMessage =
            'Erro ao carregar histórico de caronas como passageiro.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      setState(() {
        _errorMessage = 'Não foi possível identificar o usuário autenticado.';
      });
      return;
    }

    try {
      final rides = await _ridesService.watchRidesByDriver(user.uid).first;
      final requests =
          await _rideRequestService.getRequestsByPassenger(user.uid);

      if (mounted) {
        setState(() {
          _driverRides = List<Ride>.from(rides)
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        });
      }

      await _updatePassengerHistory(requests);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro ao atualizar histórico de viagens.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2196F3),
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: const Color(0xFF2196F3),
          tabs: const [
            Tab(text: 'Motorista'),
            Tab(text: 'Passageiro'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDriverTab(),
              _buildPassengerTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Histórico de viagens',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Acompanhe suas caronas como motorista e passageiro.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverTab() {
    if (_isLoading && _driverRides.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_driverRides.isEmpty) {
      return _buildEmptyState(
        title: 'Nenhuma carona encontrada',
        description:
            'Quando você criar ou finalizar caronas, elas aparecerão aqui.',
        icon: Icons.directions_car,
      );
    }

    final upcoming = _driverRides.where(_isRideUpcoming).toList();
    final past = _driverRides.where((ride) => !_isRideUpcoming(ride)).toList();

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (upcoming.isNotEmpty) ...[
            _buildSectionTitle('Próximas caronas'),
            const SizedBox(height: 8),
            for (final ride in upcoming) _buildDriverRideCard(ride),
            const SizedBox(height: 24),
          ],
          if (past.isNotEmpty) ...[
            _buildSectionTitle('Histórico'),
            const SizedBox(height: 8),
            for (final ride in past) _buildDriverRideCard(ride),
          ],
          if (upcoming.isEmpty && past.isEmpty)
            _buildEmptyState(
              title: 'Nenhum registro disponível',
              description:
                  'Suas caronas como motorista aparecerão assim que forem finalizadas.',
              icon: Icons.history,
            ),
        ],
      ),
    );
  }

  Widget _buildDriverRideCard(Ride ride) {
    final dateLabel = '${_dateFormatter.format(ride.dateTime)} • '
        '${_timeFormatter.format(ride.dateTime)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildStatusChip(_mapRideStatus(ride.status)),
            ],
          ),
          const SizedBox(height: 12),
          _buildRouteInfo(
            origin: ride.origin.address ?? 'Origem não informada',
            destination: ride.destination.address ?? 'Destino não informado',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_seat, size: 16, color: Color(0xFF2196F3)),
              const SizedBox(width: 4),
              Text(
                '${ride.availableSeats}/${ride.maxSeats} vagas disponíveis',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (ride.description != null && ride.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                ride.description!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPassengerTab() {
    if (_isLoading && _passengerRides.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_passengerRides.isEmpty) {
      return _buildEmptyState(
        title: 'Nenhuma carona encontrada',
        description:
            'Aceite convites ou faça solicitações para ver seu histórico aqui.',
        icon: Icons.hail,
      );
    }

    final upcoming = _passengerRides.where(_isPassengerUpcoming).toList();
    final past = _passengerRides
        .where((entry) => !_isPassengerUpcoming(entry))
        .toList();

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (upcoming.isNotEmpty) ...[
            _buildSectionTitle('Próximas viagens'),
            const SizedBox(height: 8),
            for (final entry in upcoming) _buildPassengerRideCard(entry),
            const SizedBox(height: 24),
          ],
          if (past.isNotEmpty) ...[
            _buildSectionTitle('Histórico'),
            const SizedBox(height: 8),
            for (final entry in past) _buildPassengerRideCard(entry),
          ],
          if (upcoming.isEmpty && past.isEmpty)
            _buildEmptyState(
              title: 'Nenhum registro disponível',
              description:
                  'Suas caronas aparecerão assim que tiverem um status definido.',
              icon: Icons.history,
            ),
        ],
      ),
    );
  }

  Widget _buildPassengerRideCard(_PassengerRideData data) {
    final ride = data.ride;
    final request = data.request;
    final dateLabel = '${_dateFormatter.format(ride.dateTime)} • '
        '${_timeFormatter.format(ride.dateTime)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildStatusChip(_mapPassengerStatus(ride, request)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Motorista: ${ride.driverName}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          _buildRouteInfo(
            origin: ride.origin.address ?? 'Origem não informada',
            destination: ride.destination.address ?? 'Destino não informado',
          ),
          if (request.message != null && request.message!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Mensagem: ${request.message}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
    );
  }

  Widget _buildRouteInfo({
    required String origin,
    required String destination,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.radio_button_checked,
                size: 14, color: Color(0xFF2196F3)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                origin,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          height: 16,
          width: 2,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(
          children: [
            const Icon(Icons.location_on,
                size: 14, color: Color(0xFFEF5350)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                destination,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(_StatusInfo statusInfo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusInfo.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusInfo.label,
        style: TextStyle(
          color: statusInfo.textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isRideUpcoming(Ride ride) {
    final now = DateTime.now();
    final isFuture = ride.dateTime.isAfter(now);
    final isActiveStatus = ride.status == 'active' || ride.status == 'in_progress';
    return isFuture && isActiveStatus;
  }

  bool _isPassengerUpcoming(_PassengerRideData entry) {
    if (entry.request.status == 'cancelled' || entry.request.status == 'rejected') {
      return false;
    }
    return _isRideUpcoming(entry.ride);
  }

  _StatusInfo _mapRideStatus(String status) {
    switch (status) {
      case 'completed':
        return _StatusInfo(
          label: 'Concluída',
          backgroundColor: const Color(0x3327AE60),
          textColor: const Color(0xFF2E7D32),
        );
      case 'cancelled':
        return _StatusInfo(
          label: 'Cancelada',
          backgroundColor: const Color(0x33EF5350),
          textColor: const Color(0xFFD32F2F),
        );
      case 'in_progress':
        return _StatusInfo(
          label: 'Em andamento',
          backgroundColor: const Color(0x332196F3),
          textColor: const Color(0xFF1565C0),
        );
      default:
        return _StatusInfo(
          label: 'Ativa',
          backgroundColor: const Color(0x332196F3),
          textColor: const Color(0xFF0D47A1),
        );
    }
  }

  _StatusInfo _mapPassengerStatus(Ride ride, RideRequest request) {
    if (request.status == 'cancelled') {
      return _StatusInfo(
        label: 'Solicitação cancelada',
        backgroundColor: const Color(0x33EF5350),
        textColor: const Color(0xFFD32F2F),
      );
    }

    if (request.status == 'rejected') {
      return _StatusInfo(
        label: 'Solicitação rejeitada',
        backgroundColor: const Color(0x33F57F17),
        textColor: const Color(0xFFEF6C00),
      );
    }

    if (ride.status == 'completed') {
      return _StatusInfo(
        label: 'Viagem concluída',
        backgroundColor: const Color(0x3327AE60),
        textColor: const Color(0xFF2E7D32),
      );
    }

    if (ride.status == 'cancelled') {
      return _StatusInfo(
        label: 'Viagem cancelada',
        backgroundColor: const Color(0x33EF5350),
        textColor: const Color(0xFFD32F2F),
      );
    }

    if (_isRideUpcoming(ride)) {
      return _StatusInfo(
        label: request.status == 'pending' ? 'Aguardando confirmação' : 'Viagem agendada',
        backgroundColor: const Color(0x332196F3),
        textColor: const Color(0xFF0D47A1),
      );
    }

    return _StatusInfo(
      label: 'Status indefinido',
      backgroundColor: Colors.grey.withOpacity(0.2),
      textColor: Colors.grey[700] ?? Colors.grey,
    );
  }
}

class _PassengerRideData {
  const _PassengerRideData({
    required this.ride,
    required this.request,
  });

  final Ride ride;
  final RideRequest request;
}

class _StatusInfo {
  const _StatusInfo({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
}

