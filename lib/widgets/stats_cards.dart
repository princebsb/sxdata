import 'package:flutter/material.dart';
import '../models/questionnaire.dart';

class StatsCards extends StatelessWidget {
  final List<Questionnaire> questionnaires;
  
  const StatsCards({
    super.key,
    required this.questionnaires,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            _getQuestionnairesTodayCount().toString(),
            'Formulários Disponibilizados Hoje',
            const Color(0xFF8fae5d),
          ),
        ),
        /*const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            _getPendingSyncCount().toString(),
            'Pendentes de Sincronizar',
            Colors.orange,
          ),
        ), */
      ],
    );
  }

  /// Conta quantos questionários foram criados hoje
  int _getQuestionnairesTodayCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    return questionnaires.where((questionnaire) {
      final createdDate = DateTime(
        questionnaire.createdAt.year,
        questionnaire.createdAt.month,
        questionnaire.createdAt.day,
      );
      return createdDate.isAtSameMomentAs(today) || 
             (createdDate.isAfter(today) && createdDate.isBefore(tomorrow));
    }).length;
  }

  /// Conta quantos questionários estão pendentes de sincronização
  /// (você pode ajustar esta lógica conforme sua necessidade)
  int _getPendingSyncCount() {
    // Exemplo: considerando questionários com status diferente de 'active' como pendentes
    // Ajuste conforme sua lógica de negócio
    return questionnaires.where((questionnaire) {
      return questionnaire.status != 'active';
    }).length;
  }

  Widget _buildStatCard(String number, String label, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}