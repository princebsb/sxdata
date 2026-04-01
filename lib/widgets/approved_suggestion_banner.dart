import 'package:flutter/material.dart';
import '../models/ai_models.dart';

/// Banner exibido abaixo de um campo de pergunta quando existe uma
/// sugestão de preenchimento aprovada pelo painel administrativo.
///
/// Exibe: [ícone IA]  Sugestão: "valor"   [Usar] [✕]
///
/// Ao tocar em "Usar" chama [onApply] com o valor sugerido.
/// Ao tocar em "✕"   chama [onIgnore].
/// Ambas as ações escondem o banner (gerenciado pelo AiProvider).
class ApprovedSuggestionBanner extends StatelessWidget {
  final ApprovedSuggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback onIgnore;

  const ApprovedSuggestionBanner({
    super.key,
    required this.suggestion,
    required this.onApply,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final isHighConfidence = suggestion.isHighConfidence;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isHighConfidence
            ? const Color(0xFFEFF6FB)
            : const Color(0xFFFFFBEA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighConfidence
              ? const Color(0xFFB3D9F2)
              : const Color(0xFFFFE082),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ícone de IA
            Icon(
              Icons.auto_awesome,
              size: 18,
              color: isHighConfidence
                  ? const Color(0xFF1976D2)
                  : const Color(0xFFF57F17),
            ),
            const SizedBox(width: 8),

            // Texto da sugestão
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sugestão: "${suggestion.suggestedValue}"',
                    style: TextStyle(
                      fontSize: isHighConfidence ? 13 : 12,
                      fontWeight: FontWeight.w500,
                      color: isHighConfidence
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF795548),
                    ),
                  ),
                  if (suggestion.rationale != null &&
                      suggestion.rationale!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        suggestion.rationale!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isHighConfidence
                              ? const Color(0xFF1976D2).withValues(alpha: 0.8)
                              : const Color(0xFF795548).withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Botão "Usar"
            TextButton(
              onPressed: onApply,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: isHighConfidence
                    ? const Color(0xFF1976D2)
                    : const Color(0xFFF57F17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Usar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Botão "Ignorar"
            IconButton(
              onPressed: onIgnore,
              icon: const Icon(Icons.close, size: 16),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              color: Colors.grey.shade500,
              tooltip: 'Ignorar sugestão',
            ),
          ],
        ),
      ),
    );
  }
}
