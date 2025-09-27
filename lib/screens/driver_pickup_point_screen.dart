// import 'package:flutter/material.dart';

// class DriverPickupPointScreen extends StatelessWidget {
//   const DriverPickupPointScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Ponto de Partida'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: <Widget>[
//             const Text(
//               'Defina seu ponto de partida para a carona:',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             TextFormField(
//               decoration: const InputDecoration(
//                 prefixIcon: Icon(Icons.location_on),
//                 labelText: 'Endereço de Partida',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 20),
//             Expanded(
//               child: Container(
//                 color: Colors.grey[300],
//                 child: const Center(
//                   child: Text(
//                     'Mapa para seleção do ponto de partida',
//                     style: TextStyle(color: Colors.grey, fontSize: 18),
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () {
//                   // TODO: Implementar a seleção do ponto de partida e navegação
//                   print('Confirmar Ponto de Partida');
//                 },
//                 child: const Text('Confirmar Ponto de Partida'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
