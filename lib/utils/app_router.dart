import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/clients_screen.dart';
import '../screens/create_loan_screen.dart';
import '../screens/loan_detail_screen.dart';
import '../screens/paid_loans_screen.dart';

class AppRouter {
  final AuthService authService;

  AppRouter(this.authService);

  late final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: authService, // Refresca las rutas si el usuario inicia/cierra sesión
    redirect: (context, state) {
      final isAuthenticated = authService.isAuthenticated;
      final isGoingToLogin = state.uri.toString() == '/login';

      if (!isAuthenticated && !isGoingToLogin) {
        return '/login';
      }
      if (isAuthenticated && isGoingToLogin) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/clients',
        builder: (context, state) => const ClientsScreen(),
      ),
      GoRoute(
        path: '/create-loan',
        builder: (context, state) => const CreateLoanScreen(),
      ),
      GoRoute(
        path: '/loan/:id',
        builder: (context, state) {
          final loanData = state.extra as Map<String, dynamic>;
          return LoanDetailScreen(loan: loanData);
        },
      ),
      GoRoute(
        path: '/paid-loans',
        builder: (context, state) => const PaidLoansScreen(),
      )
    ],
  );
}
