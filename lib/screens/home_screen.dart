import 'package:flutter/material.dart';

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

  // Nome do usuário (pode vir de autenticação/banco de dados)
  final String userName = "Nome";

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
                'Olá, $userName!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          // Botão de perfil
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.person_outline, size: 28),
              color: Colors.black87,
              onPressed: () {
                // Navegar para perfil
                setState(() {
                  _selectedIndex = 3;
                });
              },
            ),
          ),
        ],
      ),
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
              onTap: () {
                // Navegar para tela de oferecer carona
                _showComingSoonDialog('Oferecer Carona');
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
                // Navegar para tela de procurar carona
                _showComingSoonDialog('Procurar Carona');
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
                  ? Colors.black.withOpacity(0.08)
                  : color.withOpacity(0.3),
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
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Simulação de mapa (substitua por GoogleMap quando integrar)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF81C9E8),
                      Color(0xFF9FD9E9),
                      Color(0xFFB8E6D5),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Simulação de ruas (linhas brancas)
                    CustomPaint(
                      size: Size.infinite,
                      painter: MapStreetsPainter(),
                    ),

                    // Marcadores de caronas disponíveis
                    _buildCarMarker(top: 100, left: 80),
                    _buildCarMarker(top: 250, left: 200),
                    _buildCarMarker(top: 400, left: 50),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói um marcador de carro no mapa
  Widget _buildCarMarker({required double top, required double left}) {
    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onTap: () {
          _showCaronaDetailsDialog();
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_car,
            color: Colors.white,
            size: 28,
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
            color: Colors.black.withOpacity(0.1),
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
            // Perfil - navegar para login
            Navigator.of(context).pushNamed('/login');
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
  void _showCaronaDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Carona Disponível'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Motorista: João Silva'),
            SizedBox(height: 8),
            Text('Destino: Campus Universitário'),
            SizedBox(height: 8),
            Text('Horário: 14:30'),
            SizedBox(height: 8),
            Text('Vagas: 2 disponíveis'),
          ],
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
}

/// CustomPainter para desenhar ruas no mapa simulado
class MapStreetsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Linhas horizontais
    for (double y = 0; y < size.height; y += 80) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Linhas verticais
    for (double x = 0; x < size.width; x += 80) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

