import 'package:flutter/material.dart';
import '../models/ai_models.dart';

/// Widget que exibe alertas de inconsistência para uma pergunta.
/// Mostra aviso discreto com opções de: corrigir, manter ou revisar depois.
class InconsistencyAlertWidget extends StatelessWidget {
  final List<InconsistencyAlert> alerts;
  final VoidCallback? onCorrect;
  final VoidCallback? onKeep;
  final VoidCallback? onReviewLater;

  const InconsistencyAlertWidget({
    super.key,
    required this.alerts,
    this.onCorrect,
    this.onKeep,
    this.onReviewLater,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.map((alert) => _buildAlertCard(context, alert)).toList(),
    );
  }

  Widget _buildAlertCard(BuildContext context, InconsistencyAlert alert) {
    final isError = alert.severity == InconsistencySeverity.error;
    final isInfo = alert.severity == InconsistencySeverity.info;

    final Color bgColor;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;

    if (isError) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      iconColor = Colors.red.shade700;
      icon = Icons.error_outline;
    } else if (isInfo) {
      bgColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade200;
      iconColor = Colors.blue.shade700;
      icon = Icons.info_outline;
    } else {
      bgColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade200;
      iconColor = Colors.amber.shade800;
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.message,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (alert.suggestion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Sugestão: ${alert.suggestion}',
                        style: TextStyle(
                          color: iconColor.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!isError) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCorrect != null)
                  _ActionChip(
                    label: 'Corrigir',
                    icon: Icons.edit,
                    onTap: onCorrect!,
                    color: Colors.green,
                  ),
                const SizedBox(width: 6),
                if (onKeep != null)
                  _ActionChip(
                    label: 'Manter',
                    icon: Icons.check,
                    onTap: onKeep!,
                    color: Colors.grey,
                  ),
                const SizedBox(width: 6),
                if (onReviewLater != null)
                  _ActionChip(
                    label: 'Revisar depois',
                    icon: Icons.schedule,
                    onTap: onReviewLater!,
                    color: Colors.blue,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
