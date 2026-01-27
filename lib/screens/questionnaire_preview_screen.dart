import 'package:flutter/material.dart';
import '../models/questionnaire.dart';
import '../widgets/app_header.dart';
import 'consent_screen.dart';
import 'question_screen.dart';

class QuestionnairePreviewScreen extends StatelessWidget {
  final Questionnaire questionnaire;

  const QuestionnairePreviewScreen({
    super.key,
    required this.questionnaire,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header customizado com logo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(35, 52, 95, 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botão voltar
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  // Logo centralizado
                  Image.asset(
                    'assets/images/Logo_verde2.png',
                    width: 120,             
                    fit: BoxFit.contain,
                  ),
                  // Espaço para manter simetria
                  const SizedBox(width: 48), // Mesmo tamanho do IconButton
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildPreviewCard(),
                            const SizedBox(height: 20),
                            _buildInfoCard(),
                          ],
                        ),
                      ),
                    ),
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionnaire.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 15),
          
          // Meta info grid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL DE PERGUNTAS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${questionnaire.questions.length} questões',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TEMPO ESTIMADO',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${questionnaire.estimatedTime ?? 10}-${(questionnaire.estimatedTime ?? 10) + 2} min',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ÚLTIMA ATUALIZAÇÃO',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${questionnaire.createdAt.day.toString().padLeft(2, '0')}/${questionnaire.createdAt.month.toString().padLeft(2, '0')}/${questionnaire.createdAt.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      questionnaire.status == 'active' ? '✓ Ativo' : '⏸ Pausado',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: questionnaire.status == 'active' 
                          ? const Color(0xFF8fae5d) 
                          : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          ...[
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visão Geral:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF23345F),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  questionnaire.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    List<String> requirements = [];
    
    if (questionnaire.requiresConsent) requirements.add('Consentimento obrigatório');
    if (questionnaire.requiresLocation) requirements.add('Geolocalização ativa');
    if (questionnaire.requiresPhoto) requirements.add('Foto requerida');
    
    if (requirements.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFe8f5e8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info,
            color: Color(0xFF2e7d32),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirements.join(' • '),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2e7d32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.grey),
              ),
              child: const Text(
                'Voltar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _startQuestionnaire(context),
              child: const Text(
                'Iniciar Questionário',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _startQuestionnaire(BuildContext context) {
    if (questionnaire.requiresConsent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConsentScreen(questionnaire: questionnaire),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuestionScreen(
            questionnaire: questionnaire,
            currentQuestionIndex: 0,
          ),
        ),
      );
    }
  }
}