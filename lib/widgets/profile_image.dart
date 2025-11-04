import 'dart:convert';
import 'package:flutter/material.dart';

/// Widget para exibir imagem de perfil suportando múltiplos formatos:
/// - URL HTTP/HTTPS (normal)
/// - Data URL Base64 (data:image/...)
/// - Placeholder quando não há imagem
class ProfileImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final IconData? placeholderIcon;

  const ProfileImage({
    super.key,
    this.imageUrl,
    this.size = 100,
    this.backgroundColor,
    this.iconColor,
    this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    // Se não tem URL, mostra placeholder
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    // Se é data URL (Base64), decodifica
    if (imageUrl!.startsWith('data:image')) {
      return _buildBase64Image();
    }

    // Se é URL normal, mostra com Image.network
    return _buildNetworkImage();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.blue.shade300,
        shape: BoxShape.circle,
      ),
      child: Icon(
        placeholderIcon ?? Icons.person,
        size: size * 0.6,
        color: iconColor ?? Colors.white,
      ),
    );
  }

  Widget _buildBase64Image() {
    try {
      // Extrai a parte Base64 do data URL
      final base64String = imageUrl!.split(',')[1];
      final bytes = base64Decode(base64String);
      
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          ),
        ),
      );
    } catch (e) {
      // Se der erro ao decodificar Base64, mostra placeholder
      return _buildPlaceholder();
    }
  }

  Widget _buildNetworkImage() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        ),
      ),
    );
  }
}

