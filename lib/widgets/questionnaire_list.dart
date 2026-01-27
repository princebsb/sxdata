import 'package:flutter/material.dart';
import '../models/questionnaire.dart';

class QuestionnaireList extends StatelessWidget {
  final List<Questionnaire> questionnaires;
  final Function(Questionnaire) onQuestionnaireSelected;

  const QuestionnaireList({
    super.key,
    required this.questionnaires,
    required this.onQuestionnaireSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (questionnaires.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Importante: não expandir
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            Text(
              'Nenhum questionário disponível',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Importante: não expandir
        children: questionnaires.asMap().entries.map((entry) {
          final index = entry.key;
          final questionnaire = entry.value;
          
          return _buildQuestionnaireItem(
            questionnaire,
            isLast: index == questionnaires.length - 1,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuestionnaireItem(Questionnaire questionnaire, {required bool isLast}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onQuestionnaireSelected(questionnaire),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: isLast ? null : const Border(
              bottom: BorderSide(color: Color(0xFFF0F0F0)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Conteúdo principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Não expandir
                  children: [
                    Text(
                      questionnaire.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF23345F),
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${questionnaire.questions.length} pergunta${questionnaire.questions.length != 1 ? 's' : ''} • Criado em ${_formatDate(questionnaire.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Badge de status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: questionnaire.status == 'active' 
                    ? const Color(0xFFe8f5e8)
                    : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      questionnaire.status == 'active' 
                        ? Icons.check_circle 
                        : Icons.pause_circle,
                      size: 14,
                      color: questionnaire.status == 'active' 
                        ? const Color(0xFF2e7d32)
                        : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      questionnaire.status == 'active' ? 'Ativo' : 'Pausado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: questionnaire.status == 'active' 
                          ? const Color(0xFF2e7d32)
                          : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}