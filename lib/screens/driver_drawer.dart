// import 'package:flutter/material.dart';

// class DriverDrawer extends StatelessWidget {
//   const DriverDrawer({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Drawer(
//       child: ListView(
//         padding: EdgeInsets.zero,
//         children: <Widget>[
//           const DrawerHeader(
//             decoration: BoxDecoration(
//               color: Colors.blue,
//             ),
//             child: Text(
//               'Menu Motorista',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 24,
//               ),
//             ),
//           ),
//           ListTile(
//             leading: const Icon(Icons.person),
//             title: const Text('Meu Perfil'),
//             onTap: () {
//               // TODO: Navegar para a tela de perfil
//               Navigator.pop(context);
//             },
//           ),
//           ListTile(
//             leading: const Icon(Icons.car_rental),
//             title: const Text('Meus Veículos'),
//             onTap: () {
//               // TODO: Navegar para a tela de veículos
//               Navigator.pop(context);
//             },
//           ),
//           ListTile(
//             leading: const Icon(Icons.history),
//             title: const Text('Minhas Viagens'),
//             onTap: () {
//               // TODO: Navegar para a tela de histórico de viagens
//               Navigator.pop(context);
//             },
//           ),
//           ListTile(
//             leading: const Icon(Icons.message),
//             title: const Text('Mensagens'),
//             onTap: () {
//               // TODO: Navegar para a tela de mensagens
//               Navigator.pop(context);
//             },
//           ),
//           ListTile(
//             leading: const Icon(Icons.settings),
//             title: const Text('Configurações'),
//             onTap: () {
//               // TODO: Navegar para a tela de configurações
//               Navigator.pop(context);
//             },
//           ),
//           ListTile(
//             leading: const Icon(Icons.logout),
//             title: const Text('Sair'),
//             onTap: () {
//               // TODO: Implementar logout
//               Navigator.pop(context);
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
