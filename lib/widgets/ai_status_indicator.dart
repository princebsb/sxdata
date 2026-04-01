import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';

/// Indicador visual de disponibilidade dos serviços de IA.
/// Mostra ícone discreto quando IA está disponível ou indisponível.
/// Toque longo ativa modo de demonstração para testar UI.
class AiStatusIndicator extends StatelessWidget {
  final bool compact;

  const AiStatusIndicator({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    return Consumer<AiProvider>(
      builder: (context, aiProvider, _) {
        if (aiProvider.isCheckingAvailability) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          );
        }

        final isAvailable = aiProvider.isAiAvailable;
        final isDemo = aiProvider.isDemoMode;

        if (compact) {
          return GestureDetector(
            onLongPress: () => _showDemoToggle(context, aiProvider),
            child: Tooltip(
              message: isDemo
                  ? 'Modo demonstração IA (toque longo para desativar)'
                  : isAvailable
                      ? 'Recursos de IA disponíveis'
                      : 'IA indisponível (toque longo para modo demo)',
              child: Icon(
                isDemo
                    ? Icons.science
                    : isAvailable
                        ? Icons.auto_awesome
                        : Icons.auto_awesome_outlined,
                size: 18,
                color: isDemo
                    ? Colors.purple.shade400
                    : isAvailable
                        ? Colors.amber.shade700
                        : Colors.grey.shade400,
              ),
            ),
          );
        }

        return GestureDetector(
          onLongPress: () => _showDemoToggle(context, aiProvider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDemo
                  ? Colors.purple.shade50
                  : isAvailable
                      ? Colors.amber.shade50
                      : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDemo
                    ? Colors.purple.shade200
                    : isAvailable
                        ? Colors.amber.shade200
                        : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDemo
                      ? Icons.science
                      : isAvailable
                          ? Icons.auto_awesome
                          : Icons.cloud_off,
                  size: 14,
                  color: isDemo
                      ? Colors.purple.shade600
                      : isAvailable
                          ? Colors.amber.shade700
                          : Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  isDemo
                      ? 'IA Demo'
                      : isAvailable
                          ? 'IA Ativa'
                          : 'IA Offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDemo
                        ? Colors.purple.shade700
                        : isAvailable
                            ? Colors.amber.shade800
                            : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDemoToggle(BuildContext context, AiProvider aiProvider) {
    final isDemo = aiProvider.isDemoMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isDemo ? Icons.science_outlined : Icons.science,
              color: Colors.purple,
            ),
            const SizedBox(width: 8),
            const Text('Modo Demonstração IA'),
          ],
        ),
        content: Text(
          isDemo
              ? 'O modo de demonstração está ativado. Os widgets de IA estão exibindo dados simulados.\n\nDeseja desativar?'
              : 'O backend de IA ainda não está disponível.\n\nAtivar o modo de demonstração para visualizar os recursos de IA com dados simulados?\n\nIsso permite testar a interface sem conexão com o servidor de IA.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              aiProvider.toggleDemoMode();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isDemo
                        ? 'Modo demonstração desativado'
                        : 'Modo demonstração ativado - widgets de IA visíveis',
                  ),
                  backgroundColor: isDemo ? Colors.grey : Colors.purple,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDemo ? Colors.grey : Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: Text(isDemo ? 'Desativar' : 'Ativar Demo'),
          ),
        ],
      ),
    );
  }
}
