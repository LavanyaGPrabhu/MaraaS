// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// void main() async{
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(const MaraaS());
// }
// class MaraaS extends StatelessWidget {
//   const MaraaS({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'MaraaS',
//       theme: ThemeData(primarySwatch: Colors.indigo),
//       home: const AuthGate(),
//     );
//   }
// }

// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (snapshot.hasData) {
//           return const MapScreen();
//         } else {
//           return const LoginScreen();
//         }
//       },
//     );
//   }
// }

// // placeholder screens (we’ll fill later)
// class LoginScreen extends StatelessWidget {
//   const LoginScreen({super.key});
//   @override
//   Widget build(BuildContext context) =>
//       Scaffold(body: Center(child: Text("Login Screen")));
// }

// class MapScreen extends StatelessWidget {
//   const MapScreen({super.key});
//   @override
//   Widget build(BuildContext context) =>
//       Scaffold(body: Center(child: Text("Map Screen")));
// }

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/login_screen.dart';
import 'screens/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // works with google-services.json on Android
  runApp(const MaraaSApp());
}

class MaraaSApp extends StatelessWidget {
  const MaraaSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaraaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasData) return const MapScreen();
        return const LoginScreen();
      },
    );
  }
}
