import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/avaliacao_model.dart';
import '../services/avaliacao_service.dart';

/// Widget de diálogo para avaliar um usuário após uma carona
class AvaliacaoDialog extends StatefulWidget {
  final String caronaId;
  final String avaliadorUsuarioId;
  final String avaliadoUsuarioId;
  final String avaliadoNome;

  const AvaliacaoDialog({
    super.key,
    required this.caronaId,
    required this.avaliadorUsuarioId,
    required this.avaliadoUsuarioId,
    required this.avaliadoNome,
  });

  @override
  State<AvaliacaoDialog> createState() => _AvaliacaoDialogState();
}

class _AvaliacaoDialogState extends State<AvaliacaoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _comentarioController = TextEditingController();
  final AvaliacaoService _avaliacaoService = AvaliacaoService();
  
  int _notaSelecionada = 0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _salvarAvaliacao() async {
    if (_notaSelecionada == 0) {
      setState(() {
        _errorMessage = 'Por favor, selecione uma nota';
      });
      return;
    }

    // Validação: não pode avaliar a si mesmo
    if (widget.avaliadorUsuarioId == widget.avaliadoUsuarioId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não pode avaliar a si mesmo'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    // Verifica se já existe uma avaliação para esta carona e usuários
    final jaAvaliado = await _avaliacaoService.verificarAvaliacaoExistente(
      caronaId: widget.caronaId,
      avaliadorUsuarioId: widget.avaliadorUsuarioId,
      avaliadoUsuarioId: widget.avaliadoUsuarioId,
    );

    if (jaAvaliado) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você já avaliou este usuário nesta carona'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Valida IDs antes de criar a avaliação
      if (widget.avaliadorUsuarioId.isEmpty || widget.avaliadoUsuarioId.isEmpty) {
        setState(() {
          _errorMessage = 'Erro: IDs de usuário inválidos';
          _isLoading = false;
        });
        return;
      }

      if (widget.avaliadorUsuarioId == widget.avaliadoUsuarioId) {
        setState(() {
          _errorMessage = 'Erro: Você não pode se avaliar';
          _isLoading = false;
        });
        return;
      }

      if (kDebugMode) {
        print('📝 Salvando avaliação:');
        print('  Avaliador: ${widget.avaliadorUsuarioId}');
        print('  Avaliado: ${widget.avaliadoUsuarioId}');
        print('  Carona: ${widget.caronaId}');
      }

      final avaliacao = AvaliacaoModel(
        caronaId: widget.caronaId,
        avaliadorUsuarioId: widget.avaliadorUsuarioId,
        avaliadoUsuarioId: widget.avaliadoUsuarioId,
        nota: _notaSelecionada.toDouble(),
        comentario: _comentarioController.text.trim().isEmpty
            ? null
            : _comentarioController.text.trim(),
        dataAvaliacao: DateTime.now(),
      );

      await _avaliacaoService.criarAvaliacao(avaliacao);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avaliação enviada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Retorna true para indicar sucesso
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao salvar avaliação: ${e.toString()}';
        _isLoading = false;
      });

      if (kDebugMode) {
        print('✗ Erro ao salvar avaliação: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Avaliar ${widget.avaliadoNome}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Como foi sua experiência?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              
              // Seleção de nota (estrelas)
              _buildStarRating(),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Campo de comentário
              TextFormField(
                controller: _comentarioController,
                decoration: InputDecoration(
                  labelText: 'Comentário (opcional)',
                  hintText: 'Deixe um comentário sobre a experiência...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.comment_outlined),
                ),
                maxLines: 4,
                maxLength: 500,
              ),
              
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _salvarAvaliacao,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Enviar Avaliação'),
        ),
      ],
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return GestureDetector(
          onTap: () {
            setState(() {
              _notaSelecionada = starNumber;
              _errorMessage = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              starNumber <= _notaSelecionada ? Icons.star : Icons.star_border,
              color: starNumber <= _notaSelecionada
                  ? Colors.amber
                  : Colors.grey,
              size: 40,
            ),
          ),
        );
      }),
    );
  }
}

/// Widget de botão para abrir o diálogo de avaliação
class AvaliarButton extends StatelessWidget {
  final String caronaId;
  final String avaliadorUsuarioId;
  final String avaliadoUsuarioId;
  final String avaliadoNome;
  final VoidCallback? onAvaliacaoEnviada;

  const AvaliarButton({
    super.key,
    required this.caronaId,
    required this.avaliadorUsuarioId,
    required this.avaliadoUsuarioId,
    required this.avaliadoNome,
    this.onAvaliacaoEnviada,
  });

  Future<void> _abrirDialog(BuildContext context) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AvaliacaoDialog(
        caronaId: caronaId,
        avaliadorUsuarioId: avaliadorUsuarioId,
        avaliadoUsuarioId: avaliadoUsuarioId,
        avaliadoNome: avaliadoNome,
      ),
    );

    if (resultado == true && onAvaliacaoEnviada != null) {
      onAvaliacaoEnviada!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _abrirDialog(context),
      icon: const Icon(Icons.star_outline, size: 18),
      label: const Text('Avaliar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2196F3),
        side: const BorderSide(color: Color(0xFF2196F3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Widget de diálogo para avaliar o sistema
class AvaliacaoSistemaDialog extends StatefulWidget {
  const AvaliacaoSistemaDialog({super.key});

  @override
  State<AvaliacaoSistemaDialog> createState() => _AvaliacaoSistemaDialogState();
}

class _AvaliacaoSistemaDialogState extends State<AvaliacaoSistemaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _comentarioController = TextEditingController();
  
  int _notaSelecionada = 0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _salvarAvaliacaoSistema() async {
    if (_notaSelecionada == 0) {
      setState(() {
        _errorMessage = 'Por favor, selecione uma nota';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Para avaliação do sistema, usamos uma coleção separada 'avaliacoes_sistema'
      final firestore = FirebaseFirestore.instance;
      
      await firestore.collection('avaliacoes_sistema').add({
        'nota': _notaSelecionada.toDouble(),
        'comentario': _comentarioController.text.trim().isEmpty
            ? null
            : _comentarioController.text.trim(),
        'data_avaliacao': FieldValue.serverTimestamp(),
        'tipo': 'sistema',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avaliação do sistema enviada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao salvar avaliação: ${e.toString()}';
        _isLoading = false;
      });

      if (kDebugMode) {
        print('✗ Erro ao salvar avaliação do sistema: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Avaliar Sistema',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Como está sua experiência com o aplicativo?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              
              // Seleção de nota (estrelas)
              _buildStarRating(),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Campo de comentário
              TextFormField(
                controller: _comentarioController,
                decoration: InputDecoration(
                  labelText: 'Comentário (opcional)',
                  hintText: 'O que podemos melhorar? Suas sugestões são muito importantes!',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.feedback_outlined),
                ),
                maxLines: 4,
                maxLength: 500,
              ),
              
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _salvarAvaliacaoSistema,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Enviar Avaliação'),
        ),
      ],
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return GestureDetector(
          onTap: () {
            setState(() {
              _notaSelecionada = starNumber;
              _errorMessage = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              starNumber <= _notaSelecionada ? Icons.star : Icons.star_border,
              color: starNumber <= _notaSelecionada
                  ? Colors.amber
                  : Colors.grey,
              size: 40,
            ),
          ),
        );
      }),
    );
  }
}
