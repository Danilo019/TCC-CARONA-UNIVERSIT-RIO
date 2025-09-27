// import 'package:flutter/material.dart';

// class EmailInputScreen extends StatelessWidget {
//   const EmailInputScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Email'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: <Widget>[
//             const Text(
//               'Enter your email address',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             TextFormField(
//               decoration: const InputDecoration(
//                 prefixIcon: Icon(Icons.email),
//                 labelText: 'Email',
//                 hintText: 'seu.email.academico@cs.udf.br',
//                 border: OutlineInputBorder(),
//               ),
//               keyboardType: TextInputType.emailAddress,
//             ),
//             const Spacer(),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: () {
//                   // TODO: Implementar validação e navegação
//                   print('Próximo');
//                 },
//                 child: const Text('Próximo'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
