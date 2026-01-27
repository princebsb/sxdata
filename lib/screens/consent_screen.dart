import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/questionnaire.dart';
import '../providers/form_provider.dart';
import '../providers/auth_provider.dart';
import 'question_screen.dart';

class ConsentScreen extends StatefulWidget {
  final Questionnaire questionnaire;

  const ConsentScreen({super.key, required this.questionnaire});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _consentGiven = false;

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
                  // Ícone de consentimento
                  const Icon(
                    Icons.assignment,
                    color: Color(0xFF8fae5d),
                    size: 24,
                  ),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Termo de Consentimento',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF23345F),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.questionnaire.title,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),
                            
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.questionnaire.description ?? 
                                    'Esta pesquisa tem como objetivo coletar informações sobre práticas ambientais, sociais e de governança. Seus dados serão tratados de forma confidencial e utilizados apenas para fins estatísticos.',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF23345F),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  const Text(
                                    'Ao aceitar este termo, você autoriza:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF23345F),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '• O uso das informações coletadas para fins de pesquisa\n'
                                    '• A coleta de dados de localização durante a aplicação\n'
                                    '• O armazenamento seguro dos dados conforme LGPD',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF23345F),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _consentGiven,
                                  onChanged: (value) {
                                    setState(() {
                                      _consentGiven = value ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF8fae5d),
                                ),
                                const Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Text(
                                      'Concordo em participar desta pesquisa e autorizo o uso dos dados conforme descrito.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF23345F),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFe8f5e8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.security,
                                    color: Color(0xFF2e7d32),
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Suas informações pessoais são protegidas pela LGPD (Lei Geral de Proteção de Dados Pessoais – Lei 13.709/2018). Os dados coletados serão utilizados exclusivamente para os fins desta pesquisa.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2e7d32),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
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
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _consentGiven ? _acceptAndContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8fae5d),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Aceitar e Continuar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _acceptAndContinue() {
    print('🚀 === INICIANDO FORMULÁRIO COM CONSENTIMENTO ===');
    
    try {
      final formProvider = Provider.of<FormProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final userId = authProvider.user?.id ?? 1;
      final questionnaireId = widget.questionnaire.id;
      final questions = widget.questionnaire.questions;
      
      print('📋 Dados do formulário:');
      print('   - Questionário ID: $questionnaireId');
      print('   - Usuário ID: $userId');
      print('   - Questões: ${questions.length}');
      print('   - Consentimento: true');
      
      // CORREÇÃO: Usar startForm com 3 parâmetros (incluindo questions)
      formProvider.startForm(questionnaireId, authProvider.user!.id, questions);
      formProvider.setConsent(true);
      
      print('✅ FormProvider inicializado com sucesso');
      print('📝 Questões com lógica condicional:');
      int questionsWithLogic = 0;
      for (int i = 0; i < questions.length; i++) {
        if (questions[i].hasConditionalLogic) {
          questionsWithLogic++;
          print('   - Questão $i: ${questions[i].conditionalLogicSummary}');
        }
      }
      print('🔧 Total com lógica: $questionsWithLogic de ${questions.length}');
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuestionScreen(
            questionnaire: widget.questionnaire,
            currentQuestionIndex: 0,
          ),
        ),
      );
      
    } catch (e, stackTrace) {
      print('❌ Erro ao iniciar formulário: $e');
      print('📋 Stack trace: $stackTrace');
      
      // Mostrar erro para o usuário
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar formulário: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}