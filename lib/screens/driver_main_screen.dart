// import 'package:flutter/material.dart';

// class DriverMainScreen extends StatelessWidget {
//   const DriverMainScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Tela Principal (Motorista)'),
//         leading: Builder(
//           builder: (BuildContext context) {
//             return IconButton(
//               icon: const Icon(Icons.menu), // Ícone de hambúrguer
//               onPressed: () { Scaffold.of(context).openDrawer(); },
//               tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
//             );
//           },
//         ),
//       ),
//       drawer: const Text('Drawer aqui'), // Substituir por DriverDrawer
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text(
//               'Bem-vindo, Motorista!',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () {
//                 // TODO: Navegar para a tela de oferecer carona
//                 print('Oferecer Carona');
//               },
//               child: const Text('Oferecer Carona'),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () {
//                 // TODO: Navegar para a tela de minhas caronas
//                 print('Minhas Caronas');
//               },
//               child: const Text('Minhas Caronas'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
