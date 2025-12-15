import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/ride.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../services/nominatim_service.dart';
import '../models/location.dart';

/// Tela de chat entre motorista e passageiro para uma carona específica
class ChatScreen extends StatefulWidget {
  final Ride ride;
  final bool isDriver;
  final String? otherUserName; // Nome do outro participante (motorista ou passageiro)
  final String? otherUserPhotoURL; // Foto do outro participante
  final String? otherUserId; // ID do outro participante (para identificar quem está no chat)

  const ChatScreen({
    super.key,
    required this.ride,
    required this.isDriver,
    this.otherUserName,
    this.otherUserPhotoURL,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final LocationService _locationService = LocationService();
  final NominatimService _nominatimService = NominatimService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Scroll automático quando novas mensagens chegarem
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      // Marca mensagens como lidas ao abrir o chat
      _markMessagesAsRead();
    });
  }

  /// Marca mensagens como lidas para o usuário atual
  Future<void> _markMessagesAsRead() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null) {
      await _chatService.markAsRead(widget.ride.id, user.uid);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll automático para a última mensagem
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Envia uma mensagem de texto
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: usuário não autenticado'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Usa displayName, se não tiver usa o email sem @dominio, se não tiver usa 'Usuário'
      final senderName = user.displayName?.isNotEmpty == true 
          ? user.displayName! 
          : (user.email.isNotEmpty ? user.email.split('@')[0] : 'Usuário');
      
      if (kDebugMode) {
        print('📤 Enviando mensagem: "$message" de $senderName');
      }
      
      final messageId = await _chatService.sendMessage(
        rideId: widget.ride.id,
        senderId: user.uid,
        senderName: senderName,
        senderPhotoURL: user.photoURL,
        message: message,
        isDriver: widget.isDriver,
      );

      if (messageId != null) {
        if (mounted) {
          _messageController.clear();
          _scrollToBottom();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao enviar mensagem'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar mensagem: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  /// Envia localização atual como mensagem
  Future<void> _sendLocation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: usuário não autenticado'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Mostra loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final position = await _locationService.getCurrentLocation();
      
      if (position == null) {
        if (mounted) {
          Navigator.pop(context); // Fecha loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível obter a localização'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Cria mensagem com localização
      final locationMessage = '📍 Minha localização:\nLat: ${position.latitude.toStringAsFixed(6)}, Long: ${position.longitude.toStringAsFixed(6)}';
      
      // Formata mensagem mais amigável usando reverse geocoding
      final location = Location(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );
      
      final geocodeResult = await _nominatimService.reverseGeocode(location);
      final addressMessage = geocodeResult?.displayName;

      final messageText = addressMessage != null && addressMessage.isNotEmpty
          ? '📍 Ponto de embarque sugerido:\n$addressMessage\n\n(Coordenadas: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)})'
          : locationMessage;

      // Usa displayName, se não tiver usa o email sem @dominio, se não tiver usa 'Usuário'
      final senderName = user.displayName?.isNotEmpty == true 
          ? user.displayName! 
          : (user.email.isNotEmpty ? user.email.split('@')[0] : 'Usuário');

      final messageId = await _chatService.sendMessage(
        rideId: widget.ride.id,
        senderId: user.uid,
        senderName: senderName,
        senderPhotoURL: user.photoURL,
        message: messageText,
        isDriver: widget.isDriver,
      );

      if (mounted) {
        Navigator.pop(context); // Fecha loading
        
        if (messageId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Localização enviada!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          _scrollToBottom();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao enviar localização'),
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
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (kDebugMode) {
        print('✗ Erro ao enviar localização: $e');
      }
    }
  }

  /// Formata hora da mensagem
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // Hoje: mostra só a hora
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Ontem
      return 'Ontem ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      // Outra data
      return DateFormat('dd/MM HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    // Determina nome e foto do outro participante
    final otherName = widget.otherUserName ?? 
                     (widget.isDriver ? widget.ride.driverName : 'Passageiro');
    final otherPhoto = widget.otherUserPhotoURL ?? widget.ride.driverPhotoURL;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: otherPhoto != null
                  ? NetworkImage(otherPhoto)
                  : null,
              child: otherPhoto == null
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    otherName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!widget.isDriver) ...[
                    Text(
                      'Carona para ${widget.ride.destination.address?.split(',').first ?? "destino"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Área de informações da carona (opcional, pode ser minimizada)
          _buildRideInfoHeader(),

          // Lista de mensagens
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.watchMessages(widget.ride.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
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
                          'Erro ao carregar mensagens',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma mensagem ainda',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Comece uma conversa!',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll para a última mensagem quando lista é atualizada
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = currentUser?.uid == message.senderId;
                    final showAvatar = index == 0 ||
                        index > 0 && messages[index - 1].senderId != message.senderId;

                    return _buildMessageBubble(
                      message,
                      isCurrentUser,
                      showAvatar: showAvatar,
                    );
                  },
                );
              },
            ),
          ),

          // Campo de entrada de mensagem
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Header com informações da carona
  Widget _buildRideInfoHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.ride.origin.address?.split(',').first ?? "Origem"} → ${widget.ride.destination.address?.split(',').first ?? "Destino"}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            DateFormat('dd/MM HH:mm').format(widget.ride.dateTime),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Bolha de mensagem
  Widget _buildMessageBubble(
    ChatMessage message,
    bool isCurrentUser, {
    bool showAvatar = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (esquerda, apenas para mensagens do outro usuário)
          if (!isCurrentUser) ...[
            if (showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundImage: message.senderPhotoURL != null
                    ? NetworkImage(message.senderPhotoURL!)
                    : null,
                child: message.senderPhotoURL == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],

          // Mensagem
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? const Color(0xFF2196F3)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                  bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome do remetente (apenas se não for o usuário atual)
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),

                  // Texto da mensagem
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 15,
                      color: isCurrentUser ? Colors.white : Colors.black87,
                    ),
                  ),

                  // Timestamp
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: isCurrentUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar (direita, apenas para mensagens do usuário atual)
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            if (showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundImage: message.senderPhotoURL != null
                    ? NetworkImage(message.senderPhotoURL!)
                    : null,
                child: message.senderPhotoURL == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              )
            else
              const SizedBox(width: 32),
          ],
        ],
      ),
    );
  }

  /// Campo de entrada de mensagem
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Botão de localização
            IconButton(
              icon: const Icon(Icons.location_on),
              color: const Color(0xFF2196F3),
              onPressed: _sendLocation,
              tooltip: 'Enviar localização',
            ),

            // Campo de texto
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Digite sua mensagem...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),

            const SizedBox(width: 8),

            // Botão enviar
            Container(
              decoration: BoxDecoration(
                color: _isSending
                    ? Colors.grey
                    : const Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending ? null : _sendMessage,
                tooltip: 'Enviar mensagem',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

