import 'package:flutter/material.dart';
import '../models/ai_models.dart';

/// Widget que exibe sugestão de preenchimento inteligente.
/// Permite aplicar, editar ou ignorar a sugestão.
class SmartSuggestionWidget extends StatelessWidget {
  final SmartFieldSuggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback onIgnore;
  final ValueChanged<String>? onEdit;

  const SmartSuggestionWidget({
    super.key,
    required this.suggestion,
    required this.onApply,
    required this.onIgnore,
    this.onEdit,
  });

  String get _sourceLabel {
    switch (suggestion.source) {
      case 'context':
        return 'Baseado no contexto';
      case 'history':
        return 'Baseado em respostas anteriores';
      case 'pattern':
        return 'Padrão detectado';
      case 'metadata':
        return 'Informação complementar';
      default:
        return 'Sugestão inteligente';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (suggestion.applied) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: Colors.teal.shade700, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _sourceLabel,
                  style: TextStyle(
                    color: Colors.teal.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              suggestion.suggestedValue,
              style: TextStyle(
                color: Colors.teal.shade900,
                fontSize: 13,
              ),
            ),
          ),
          if (suggestion.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              suggestion.reason,
              style: TextStyle(
                color: Colors.teal.shade600,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onIgnore,
                child: Text(
                  'Ignorar',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Usar sugestão', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
