import 'package:flutter/material.dart';
import '../models/ai_models.dart';

/// Widget que exibe sugestão de padronização de dados.
/// Mostra o valor original vs sugerido com opções de aceitar/manter/editar.
class StandardizationSuggestionWidget extends StatelessWidget {
  final DataStandardization suggestion;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final ValueChanged<String>? onEdit;

  const StandardizationSuggestionWidget({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onReject,
    this.onEdit,
  });

  String get _typeLabel {
    switch (suggestion.standardizationType) {
      case 'capitalization':
        return 'Capitalização';
      case 'phone_mask':
        return 'Telefone';
      case 'address':
        return 'Endereço';
      case 'city_state':
        return 'Cidade/UF';
      case 'spelling':
        return 'Ortografia';
      case 'cleanup':
        return 'Limpeza';
      default:
        return 'Padronização';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!suggestion.hasDifference || suggestion.accepted) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high,
                  color: Colors.indigo.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                _typeLabel,
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.originalValue,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suggestion.suggestedValue,
                      style: TextStyle(
                        color: Colors.indigo.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Botão aceitar
              IconButton(
                onPressed: onAccept,
                icon: const Icon(Icons.check_circle_outline),
                color: Colors.green,
                iconSize: 24,
                tooltip: 'Aceitar sugestão',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              // Botão manter original
              IconButton(
                onPressed: onReject,
                icon: const Icon(Icons.close),
                color: Colors.grey,
                iconSize: 20,
                tooltip: 'Manter original',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
