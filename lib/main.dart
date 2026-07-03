import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'utils/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ¡ATENCIÓN! Usando las claves del archivo temporal antiguo
  await Supabase.initialize(
    url: 'https://gbcjixxmxfjldfbwwxvm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiY2ppeHhteGZqbGRmYnd3eHZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNDQyNzYsImV4cCI6MjA5MTkyMDI3Nn0.RPbo_pwzJbmWfq38hvZbHRWx_qxhejFR4NvNyjrQbHw',
  );

  runApp(const PrestamosApp());
}

class PrestamosApp extends StatelessWidget {
  const PrestamosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => DatabaseService()),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, child) {
          final appRouter = AppRouter(authService).router;
          
          return MaterialApp.router(
            title: 'Capital Vivo',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                centerTitle: true,
              ),
            ),
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
