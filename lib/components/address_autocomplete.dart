import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/nominatim_service.dart';

/// Componente de autocomplete para busca de endereços usando Nominatim
///
/// Funcionalidades:
/// - Campo de texto com sugestões em tempo real
/// - Debounce de 800ms para evitar requisições excessivas
/// - Lista de sugestões abaixo do campo
/// - Suporta filtro por país (opcional)
class AddressAutocomplete extends StatefulWidget {
  /// Título do campo (ex: "Origem", "Destino")
  final String? label;

  /// Texto de placeholder
  final String? hintText;

  /// Ícone prefixo
  final IconData? prefixIcon;

  /// Valor inicial do campo
  final String? initialValue;

  /// Callback quando um endereço é selecionado
  final Function(NominatimResult)? onAddressSelected;

  /// Callback quando o texto digitado muda
  final ValueChanged<String>? onQueryChanged;

  /// Callback quando o campo é limpo
  final VoidCallback? onClear;

  /// Códigos de país para filtrar resultados (ex: ['br'])
  final List<String>? countryCodes;

  /// Limite de resultados
  final int limit;

  /// Se deve mostrar ícone de busca
  final bool showSearchIcon;

  /// Se deve mostrar botão de limpar
  final bool showClearButton;

  /// Controlador de texto (opcional)
  final TextEditingController? controller;

  /// Habilita/Desabilita o campo
  final bool enabled;

  const AddressAutocomplete({
    super.key,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.initialValue,
    this.onAddressSelected,
    this.onQueryChanged,
    this.onClear,
    this.countryCodes,
    this.limit = 10,
    this.showSearchIcon = true,
    this.showClearButton = true,
    this.controller,
    this.enabled = true,
  });

  @override
  State<AddressAutocomplete> createState() => _AddressAutocompleteState();
}

class _AddressAutocompleteState extends State<AddressAutocomplete> {
  final NominatimService _nominatimService = NominatimService();
  late TextEditingController _controller;
  Timer? _debounceTimer;

  List<NominatimResult> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();

    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // Esconde sugestões ao perder foco
        setState(() {
          _showSuggestions = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  /// Busca endereços com debounce de 800ms
  void _onTextChanged(String value) {
    // Cancela timer anterior
    _debounceTimer?.cancel();
    widget.onQueryChanged?.call(value);

    // Se o campo estiver vazio, limpa sugestões
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoading = false;
      });
      return;
    }

    // Mostra loading
    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    // Cria novo timer com debounce de 800ms
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _performSearch(value);
    });
  }

  /// Executa a busca na API do Nominatim
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final results = await _nominatimService.searchAddress(
        query: query,
        limit: widget.limit,
        countryCodes: widget.countryCodes,
      );

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar endereços: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _suggestions = [];
        });
      }
    }
  }

  /// Seleciona um endereço da lista de sugestões
  void _selectAddress(NominatimResult result) {
    setState(() {
      _controller.text = result.displayName;
      _showSuggestions = false;
    });

    _focusNode.unfocus();

    // Chama callback
    widget.onAddressSelected?.call(result);
  }

  /// Limpa o campo
  void _clearField() {
    setState(() {
      _controller.clear();
      _suggestions = [];
      _showSuggestions = false;
    });
    _focusNode.requestFocus();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campo de texto
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          onChanged: _onTextChanged,
          onTap: () {
            if (_controller.text.isNotEmpty && _suggestions.isNotEmpty) {
              setState(() {
                _showSuggestions = true;
              });
            }
          },
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText ?? 'Digite o endereço',
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon)
                : (widget.showSearchIcon ? const Icon(Icons.search) : null),
            suffixIcon:
                widget.enabled &&
                    _controller.text.isNotEmpty &&
                    widget.showClearButton
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearField,
                  )
                : _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),

        // Lista de sugestões
        if (_showSuggestions && _controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _suggestions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Nenhum resultado encontrado',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                        ),
                        title: Text(
                          suggestion.displayName,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        dense: true,
                        onTap: () => _selectAddress(suggestion),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
