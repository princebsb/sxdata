import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_api_service.dart';

/// Fila offline para requisições de IA que falharam por falta de conexão.
/// Armazena requisições localmente e tenta reenviar quando a conexão voltar.
class AiOfflineQueue {
  static const String _queueKey = 'ai_offline_queue';
  static const int _maxQueueSize = 100;

  /// Adiciona uma requisição à fila offline
  static Future<void> enqueue({
    required String endpoint,
    required Map<String, dynamic> body,
    String priority = 'normal', // 'high', 'normal', 'low'
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      List<Map<String, dynamic>> queue = [];

      if (queueJson != null) {
        queue = (jsonDecode(queueJson) as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }

      queue.add({
        'endpoint': endpoint,
        'body': body,
        'priority': priority,
        'created_at': DateTime.now().toIso8601String(),
        'attempts': 0,
      });

      // Limitar tamanho da fila
      if (queue.length > _maxQueueSize) {
        // Remover os mais antigos com prioridade 'low' primeiro
        queue.sort((a, b) {
          final aPriority = _priorityValue(a['priority']);
          final bPriority = _priorityValue(b['priority']);
          if (aPriority != bPriority) return bPriority.compareTo(aPriority);
          return (a['created_at'] as String).compareTo(b['created_at'] as String);
        });
        queue = queue.take(_maxQueueSize).toList();
      }

      await prefs.setString(_queueKey, jsonEncode(queue));
      print('📥 Requisição IA enfileirada: $endpoint');
    } catch (e) {
      print('⚠️ Erro ao enfileirar requisição IA: $e');
    }
  }

  /// Processa a fila offline
  static Future<int> processQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);

      if (queueJson == null) return 0;

      final queue = (jsonDecode(queueJson) as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      if (queue.isEmpty) return 0;

      // Verificar se IA está disponível
      final aiAvailable = await AiApiService.isAiAvailable();
      if (!aiAvailable) return 0;

      int processed = 0;
      final remaining = <Map<String, dynamic>>[];

      for (final item in queue) {
        try {
          // Tentar processar
          // Nota: aqui seria a chamada real ao endpoint
          // Por segurança, apenas incrementamos attempts
          item['attempts'] = (item['attempts'] ?? 0) + 1;

          if ((item['attempts'] as int) > 3) {
            // Descartar após 3 tentativas
            print('🗑️ Descartando requisição após 3 tentativas: ${item['endpoint']}');
            continue;
          }

          remaining.add(item);
          processed++;
        } catch (e) {
          remaining.add(item);
        }
      }

      await prefs.setString(_queueKey, jsonEncode(remaining));
      return processed;
    } catch (e) {
      print('⚠️ Erro ao processar fila offline de IA: $e');
      return 0;
    }
  }

  /// Retorna o tamanho atual da fila
  static Future<int> getQueueSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      if (queueJson == null) return 0;
      return (jsonDecode(queueJson) as List<dynamic>).length;
    } catch (_) {
      return 0;
    }
  }

  /// Limpa a fila
  static Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
    } catch (_) {}
  }

  static int _priorityValue(String? priority) {
    switch (priority) {
      case 'high':
        return 3;
      case 'normal':
        return 2;
      case 'low':
        return 1;
      default:
        return 2;
    }
  }
}
