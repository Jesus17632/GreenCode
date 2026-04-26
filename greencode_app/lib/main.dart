import 'package:flutter/material.dart';
import 'Views/welcome_view.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/greenbot_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // ← Carga la key
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenCode',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const MapView(),
      },
    );
  }
}