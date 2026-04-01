import 'package:flutter/material.dart';
import '../models/ai_models.dart';

/// Widget que exibe sugestões de perguntas de follow-up.
/// Aparece após uma resposta relevante, com opção de aplicar ou ignorar.
class FollowUpSuggestionWidget extends StatelessWidget {
  final List<FollowUpSuggestion> suggestions;
  final ValueChanged<int> onApply;
  final ValueChanged<int> onIgnore;

  const FollowUpSuggestionWidget({
    super.key,
    required this.suggestions,
    required this.onApply,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final activeSuggestions =
        suggestions.where((s) => !s.applied).toList();

    if (activeSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.question_answer_outlined,
                  color: Colors.purple.shade700, size: 18),
              const SizedBox(width: 6),
              Text(
                'Perguntas complementares sugeridas',
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...activeSuggestions.asMap().entries.map((entry) {
            final index =
                suggestions.indexOf(entry.value);
            return _buildSuggestionItem(context, entry.value, index);
          }),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(
      BuildContext context, FollowUpSuggestion suggestion, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.questionText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (suggestion.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              suggestion.reason,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => onIgnore(index),
                child: const Text('Pular', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => onApply(index),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Adicionar',
                    style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
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
