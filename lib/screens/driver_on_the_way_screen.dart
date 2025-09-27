// import 'package:flutter/material.dart';

// class DriverOnTheWayScreen extends StatelessWidget {
//   const DriverOnTheWayScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Motorista a Caminho'),
//       ),
//       body: Column(
//         children: <Widget>[
//           Expanded(
//             child: Container(
//               color: Colors.grey[300],
//               child: const Center(
//                 child: Text(
//                   'Mapa com motorista e passageiro',
//                   style: TextStyle(color: Colors.grey, fontSize: 18),
//                 ),
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               children: <Widget>[
//                 const Text(
//                   'Seu motorista está a caminho!',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 10),
//                 const Text(
//                   'Tempo estimado de chegada: 5 minutos',
//                   style: TextStyle(fontSize: 16),
//                 ),
//                 const SizedBox(height: 20),
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: () {
//                       // TODO: Implementar cancelamento da carona
//                       print('Cancelar Carona');
//                     },
//                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                     child: const Text('Cancelar Carona', style: TextStyle(color: Colors.white)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
