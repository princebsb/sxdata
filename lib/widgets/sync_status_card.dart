import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncStatusCard extends StatefulWidget {
  const SyncStatusCard({super.key});

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  @override
  void dispose() {
    // IMPORTANTE: Cancelar subscription antes do dispose
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivity = Connectivity();
      
      // Verificar status inicial
      final result = await connectivity.checkConnectivity();
      
      // CORREÇÃO: Verificar se widget ainda está montado antes de setState
      if (mounted) {
        setState(() {
          _connectionStatus = result;
          _isOnline = result != ConnectivityResult.none;
        });
      }
      
      // Escutar mudanças de conectividade
      _connectivitySubscription = connectivity.onConnectivityChanged.listen(
        (ConnectivityResult result) {
          // CORREÇÃO: Sempre verificar se mounted antes de setState
          if (mounted) {
            setState(() {
              _connectionStatus = result;
              _isOnline = result != ConnectivityResult.none;
            });
          }
        },
        onError: (error) {
          print('⚠️ Erro na verificação de conectividade: $error');
          // CORREÇÃO: Verificar mounted mesmo em caso de erro
          if (mounted) {
            setState(() {
              _connectionStatus = ConnectivityResult.none;
              _isOnline = false;
            });
          }
        },
      );
      
    } catch (e) {
      print('❌ Erro ao verificar conectividade: $e');
      // CORREÇÃO: Verificar mounted em catch também
      if (mounted) {
        setState(() {
          _connectionStatus = ConnectivityResult.none;
          _isOnline = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isOnline 
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              color: _isOnline ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'Conectado' : 'Offline',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF23345F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getConnectionDescription(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline 
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isOnline ? Icons.check_circle : Icons.error,
              size: 16,
              color: _isOnline ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _getConnectionDescription() {
    if (!_isOnline) {
      return 'Dados serão sincronizados quando conectar';
    }
    
    switch (_connectionStatus) {
      case ConnectivityResult.wifi:
        return 'Conectado via Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Conectado via dados móveis';
      case ConnectivityResult.ethernet:
        return 'Conectado via Ethernet';
      default:
        return 'Status de conexão desconhecido';
    }
  }
}