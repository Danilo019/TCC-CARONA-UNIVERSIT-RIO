import 'package:flutter/material.dart';
import 'package:app_carona_novo/screens/insert_destination_screen.dart'; // Importar InsertDestinationScreen

class LocationRequestScreen extends StatefulWidget {
  const LocationRequestScreen({super.key});

  @override
  LocationRequestScreenState createState() => LocationRequestScreenState();
}

class LocationRequestScreenState extends State<LocationRequestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header com menu hambúrguer
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.menu,
                      color: Colors.black,
                      size: 28,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, 
                        '/messages'); // Abrir a tela de mensagens
                    },
                  ),
                ],
              ),
            ),

            // Seção azul com solicitação de localização
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF4A90E2),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ícone de localização
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Texto explicativo
                  const Text(
                    "Para encontrar sua localização automaticamente, aceite em serviços de localização",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Botão Ativar Localização
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Solicitar permissão de localização
                        _requestLocationPermission();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4A90E2),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        "Ativar localização",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Campo Ponto de Coleta
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Insira o ponto de coleta",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Campo de busca
                  GestureDetector(
                    onTap: () {
                      // Navegar para tela de inserir destino
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InsertDestinationScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_searching,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Perto de você",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Preview do Mapa
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      children: [
                        // Simulação de mapa (substitua por GoogleMap quando integrar)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue[50]!,
                                Colors.blue[100]!,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.map,
                                  size: 60,
                                  color: Colors.blue[300],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Preview do Mapa",
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Marcador central
                        const Center(
                          child: Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _requestLocationPermission() {
    // TODO: Implementar solicitação de permissão de localização aqui
    // Exemplo de como seria:
    // final permission = await Permission.location.request();
    // if (permission.isGranted) {
    //   // Localização concedida
    // }

    // Mostrar feedback ao usuário
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Permissão de localização solicitada"),
        backgroundColor: Color(0xFF4A90E2),
      ),
    );
  }
}
