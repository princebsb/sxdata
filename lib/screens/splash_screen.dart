import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Aguardar um tempo mínimo para mostrar a splash screen
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        if (kDebugMode) {
          print('🚀 Verificando status de autenticação...');
        }
        
        // Verificar status de autenticação
        await authProvider.checkAuthStatus();
        
        if (mounted) {
          if (kDebugMode) {
            print('✅ Verificação concluída. Autenticado: ${authProvider.isAuthenticated}');
          }
          
          // Navegar baseado no status de autenticação
          _navigateToNextScreen(authProvider.isAuthenticated);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro na inicialização: $e');
      }
      
      if (mounted) {
        // Em caso de erro, ir para login
        _navigateToNextScreen(false);
      }
    }
  }

  void _navigateToNextScreen(bool isAuthenticated) {
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => isAuthenticated 
          ? const DashboardScreen() 
          : const LoginScreen(),
      ),
    );
    
    if (kDebugMode) {
      print('📱 Navegando para: ${isAuthenticated ? 'Dashboard' : 'Login'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF23345F),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo principal SOCIAL
              Image.asset(
                'assets/images/Logo_verde2.png',
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              
              // X logo
              Image.asset(
                'assets/images/X.png',
                width: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),
              
              // Texto descritivo
              const Text(
                'Sistema de Coleta de Dados',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8fae5d)),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              
              // Status text
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  String statusText = 'Carregando...';
                  
                  if (authProvider.isInitialized) {
                    statusText = authProvider.isAuthenticated 
                        ? 'Bem-vindo de volta!' 
                        : 'Redirecionando para login...';
                  } else {
                    statusText = 'Verificando autenticação...';
                  }
                  
                  return Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              
              const SizedBox(height: 80),
              
              // Versão (posicionada mais baixo)
              const Text(
                'Versão: 2.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}