import 'package:flutter/material.dart';
import '../services/local_validation_service.dart';

/// Widget que exibe alertas de validação em tempo real.
/// Mostra avisos discretos e úteis quando detecta possíveis erros na resposta.
/// Funciona 100% offline - não depende do backend.
class RealtimeValidationWidget extends StatelessWidget {
  final List<ValidationAlert> alerts;

  const RealtimeValidationWidget({
    super.key,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: alerts.map((alert) => _buildAlertCard(alert)).toList(),
      ),
    );
  }

  Widget _buildAlertCard(ValidationAlert alert) {
    final colors = _getColors(alert.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              colors.icon,
              color: colors.iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: TextStyle(
                    color: colors.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                if (alert.suggestion != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    alert.suggestion!,
                    style: TextStyle(
                      color: colors.textColor.withValues(alpha: 0.8),
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
    );
  }

  _AlertColors _getColors(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.error:
        return _AlertColors(
          background: const Color(0xFFFFF0F0),
          border: const Color(0xFFFFCDD2),
          icon: Icons.error_outline,
          iconColor: const Color(0xFFD32F2F),
          textColor: const Color(0xFFC62828),
        );
      case AlertSeverity.warning:
        return _AlertColors(
          background: const Color(0xFFFFF8E1),
          border: const Color(0xFFFFE082),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFF57F17),
          textColor: const Color(0xFFE65100),
        );
      case AlertSeverity.info:
        return _AlertColors(
          background: const Color(0xFFF3F8FF),
          border: const Color(0xFFBBDEFB),
          icon: Icons.info_outline,
          iconColor: const Color(0xFF1976D2),
          textColor: const Color(0xFF1565C0),
        );
    }
  }
}

class _AlertColors {
  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final Color textColor;

  const _AlertColors({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.textColor,
  });
}
