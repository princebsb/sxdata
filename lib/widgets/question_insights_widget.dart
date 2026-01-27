import 'package:flutter/material.dart';
import '../providers/question_analysis_provider.dart';

class QuestionInsightsWidget extends StatelessWidget {
  final QuestionnaireDetail questionnaireDetail;

  const QuestionInsightsWidget({
    super.key,
    required this.questionnaireDetail,
  });

  @override
  Widget build(BuildContext context) {
    final insights = _generateInsights();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insights Estatísticos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF23345F),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Análise automática dos dados coletados',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Métricas principais
            _buildMetricsRow(),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Insights principais
            const Text(
              'Principais Observações:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF23345F),
              ),
            ),
            const SizedBox(height: 12),

            ...insights.map((insight) => _buildInsightItem(insight)),

            const SizedBox(height: 16),

            // Recomendações
            _buildRecommendations(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow() {
    final completionRate = _calculateCompletionRate();
    final engagementLevel = _calculateEngagementLevel();
    final qualityScore = _calculateQualityScore();

    print('🔍 DEBUG Metrics - CompletionRate: $completionRate, EngagementLevel: $engagementLevel, QualityScore: $qualityScore');

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Taxa de Conclusão',
            '${completionRate.toStringAsFixed(1)}%',
            _getCompletionIcon(completionRate),
            _getCompletionColor(completionRate),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Engajamento',
            _getEngagementLabel(engagementLevel),
            _getEngagementIcon(engagementLevel),
            _getEngagementColor(engagementLevel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Qualidade',
            '${qualityScore.toStringAsFixed(0)}/100',
            _getQualityIcon(qualityScore),
            _getQualityColor(qualityScore),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(QuestionInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: insight.type.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: insight.type.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            insight.type.icon,
            size: 16,
            color: insight.type.color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              insight.message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF23345F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = _generateRecommendations();
    
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recomendações:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF23345F),
          ),
        ),
        const SizedBox(height: 8),
        ...recommendations.map((rec) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF8fae5d).withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF8fae5d).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.tips_and_updates,
                size: 14,
                color: Color(0xFF8fae5d),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rec,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF23345F),
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // Métodos de cálculo de métricas (VERSÃO MELHORADA)
  double _calculateCompletionRate() {
    if (questionnaireDetail.questions.isEmpty) {
      print('🔍 DEBUG CompletionRate: No questions available');
      return 0.0;
    }
    
    print('🔍 DEBUG CompletionRate: Calculating for ${questionnaireDetail.questions.length} questions');
    
    // Método 1: Usar responseRate se estiver disponível
    double totalFromResponseRates = 0.0;
    int questionsWithResponseRate = 0;
    
    for (final question in questionnaireDetail.questions) {
      if (question.responseRate > 0) {
        totalFromResponseRates += question.responseRate;
        questionsWithResponseRate++;
        print('   - Question ${question.id}: responseRate = ${question.responseRate}%');
      }
    }
    
    if (questionsWithResponseRate > 0) {
      double avgFromResponseRates = totalFromResponseRates / questionsWithResponseRate;
      print('   - Average from responseRates: $avgFromResponseRates% (${questionsWithResponseRate} questions)');
      return avgFromResponseRates;
    }
    
    // Método 2: Calcular baseado nos dados de análise
    double totalCalculated = 0.0;
    int validQuestions = 0;
    
    for (final question in questionnaireDetail.questions) {
      if (question.totalResponses > 0 && question.data.isNotEmpty) {
        double questionRate = 0.0;
        
        // Para questões com dados de análise
        for (var data in question.data) {
          String label = data.label.toLowerCase();
          if (label.contains('preenchidas') || label.contains('filled')) {
            questionRate = data.percentage ?? 0.0;
            print('   - Question ${question.id}: calculated rate = $questionRate% from "$label"');
            break;
          }
        }
        
        // Se não encontrou dados de preenchimento, calcular manualmente
        if (questionRate == 0.0) {
          int validResponses = 0;
          for (var data in question.data) {
            if (!data.label.toLowerCase().contains('vazias') && 
                !data.label.toLowerCase().contains('empty')) {
              validResponses += data.count;
            }
          }
          if (question.totalResponses > 0) {
            questionRate = (validResponses / question.totalResponses) * 100;
            print('   - Question ${question.id}: manual calculation = $questionRate% ($validResponses/${question.totalResponses})');
          }
        }
        
        totalCalculated += questionRate;
        validQuestions++;
      }
    }
    
    double result = validQuestions > 0 ? totalCalculated / validQuestions : 0.0;
    print('🔍 DEBUG CompletionRate: Final result = $result% (from ${validQuestions} questions)');
    return result;
  }

  EngagementLevel _calculateEngagementLevel() {
    final avgTime = questionnaireDetail.avgCompletionTime;
    final completionRate = _calculateCompletionRate();
    final totalResponses = questionnaireDetail.totalResponses;
    final totalQuestions = questionnaireDetail.totalQuestions;
    
    print('🔍 DEBUG Engagement calculation:');
    print('   - avgTime: $avgTime minutes');
    print('   - completionRate: $completionRate%');
    print('   - totalResponses: $totalResponses');
    print('   - totalQuestions: $totalQuestions');
    
    // Sistema de pontuação mais preciso
    int score = 0;
    
    // Fator 1: Tempo de preenchimento (máximo 3 pontos)
    if (avgTime >= 2 && avgTime <= 12) {
      score += 3; // Tempo ideal
      print('   - Time score: +3 (ideal time)');
    } else if (avgTime >= 1 && avgTime <= 20) {
      score += 2; // Tempo aceitável
      print('   - Time score: +2 (acceptable time)');
    } else if (avgTime > 0.5) {
      score += 1; // Tempo mínimo
      print('   - Time score: +1 (minimum time)');
    } else {
      print('   - Time score: +0 (too fast/invalid)');
    }
    
    // Fator 2: Taxa de conclusão (máximo 3 pontos)
    if (completionRate >= 90) {
      score += 3;
      print('   - Completion score: +3 (excellent completion)');
    } else if (completionRate >= 75) {
      score += 2;
      print('   - Completion score: +2 (good completion)');
    } else if (completionRate >= 50) {
      score += 1;
      print('   - Completion score: +1 (fair completion)');
    } else {
      print('   - Completion score: +0 (poor completion)');
    }
    
    // Fator 3: Volume de respostas (máximo 2 pontos)
    if (totalResponses >= 50) {
      score += 2;
      print('   - Volume score: +2 (high volume)');
    } else if (totalResponses >= 20) {
      score += 1;
      print('   - Volume score: +1 (medium volume)');
    } else {
      print('   - Volume score: +0 (low volume)');
    }
    
    // Fator 4: Complexidade do questionário (máximo 1 ponto)
    if (totalQuestions >= 5 && avgTime > 3) {
      score += 1; // Bonus para questionários mais complexos com tempo adequado
      print('   - Complexity bonus: +1');
    }
    
    print('   - Total engagement score: $score/9');
    
    // Determinar nível baseado na pontuação
    if (score >= 7) {
      return EngagementLevel.high;
    } else if (score >= 4) {
      return EngagementLevel.medium;
    } else {
      return EngagementLevel.low;
    }
  }

  double _calculateQualityScore() {
    print('🔍 DEBUG Quality calculation:');
    
    double score = 0.0;
    final completionRate = _calculateCompletionRate();
    
    // Fator 1: Taxa de conclusão (35% do score)
    double completionScore = (completionRate / 100) * 35;
    score += completionScore;
    print('   - Completion score: $completionScore/35 (rate: $completionRate%)');
    
    // Fator 2: Distribuição de respostas (25% do score)
    double distributionScore = 0.0;
    int questionsAnalyzed = 0;
    
    for (final question in questionnaireDetail.questions) {
      if (question.data.isNotEmpty && question.totalResponses > 0) {
        questionsAnalyzed++;
        bool hasGoodDistribution = false;
        
        if (question.type == 'radio' || question.type == 'checkbox') {
          // Para questões de escolha múltipla
          int optionsWithResponses = 0;
          double maxPercentage = 0.0;
          
          for (var data in question.data) {
            if (data.count > 0 && data.percentage != null) {
              optionsWithResponses++;
              maxPercentage = maxPercentage > data.percentage! ? maxPercentage : data.percentage!;
            }
          }
          
          // Boa distribuição se há múltiplas opções e nenhuma domina completamente
          hasGoodDistribution = optionsWithResponses > 1 && maxPercentage < 95;
        } else {
          // Para outros tipos, verificar se há respostas válidas
          for (var data in question.data) {
            if (data.label.toLowerCase().contains('preenchidas') && data.count > 0) {
              hasGoodDistribution = true;
              break;
            }
          }
        }
        
        if (hasGoodDistribution) distributionScore += 1.0;
      }
    }
    
    if (questionsAnalyzed > 0) {
      distributionScore = (distributionScore / questionsAnalyzed) * 25;
      score += distributionScore;
    }
    print('   - Distribution score: $distributionScore/25 (${questionsAnalyzed} questions analyzed)');
    
    // Fator 3: Tempo médio adequado (20% do score)
    double timeScore = 0.0;
    if (questionnaireDetail.avgCompletionTime >= 3 && 
        questionnaireDetail.avgCompletionTime <= 15) {
      timeScore = 20;
    } else if (questionnaireDetail.avgCompletionTime >= 1 && 
               questionnaireDetail.avgCompletionTime <= 25) {
      timeScore = 15;
    } else if (questionnaireDetail.avgCompletionTime > 0.5) {
      timeScore = 10;
    }
    score += timeScore;
    print('   - Time score: $timeScore/20 (${questionnaireDetail.avgCompletionTime} min)');
    
    // Fator 4: Volume de respostas (20% do score)
    double volumeScore = 0.0;
    if (questionnaireDetail.totalResponses >= 100) {
      volumeScore = 20;
    } else if (questionnaireDetail.totalResponses >= 50) {
      volumeScore = 15;
    } else if (questionnaireDetail.totalResponses >= 20) {
      volumeScore = 10;
    } else if (questionnaireDetail.totalResponses >= 5) {
      volumeScore = 5;
    }
    score += volumeScore;
    print('   - Volume score: $volumeScore/20 (${questionnaireDetail.totalResponses} responses)');
    
    final finalScore = score.clamp(0.0, 100.0);
    print('   - Total quality score: $finalScore/100');
    
    return finalScore;
  }

  // Métodos de geração de insights (MELHORADOS)
  List<QuestionInsight> _generateInsights() {
    final insights = <QuestionInsight>[];
    
    // Insight sobre taxa de resposta
    final completionRate = _calculateCompletionRate();
    if (completionRate > 90) {
      insights.add(QuestionInsight(
        'Excelente taxa de resposta! ${completionRate.toStringAsFixed(1)}% das questões são bem respondidas.',
        InsightType.positive,
      ));
    } else if (completionRate < 60) {
      insights.add(QuestionInsight(
        'Taxa de resposta baixa (${completionRate.toStringAsFixed(1)}%). Algumas questões podem estar confusas.',
        InsightType.warning,
      ));
    }
    
    // Insight sobre tempo de preenchimento
    if (questionnaireDetail.avgCompletionTime < 1) {
      insights.add(QuestionInsight(
        'Questionário muito rápido (${questionnaireDetail.avgCompletionTime.toStringAsFixed(1)}min). Usuários podem estar respondendo automaticamente.',
        InsightType.warning,
      ));
    } else if (questionnaireDetail.avgCompletionTime > 20) {
      insights.add(QuestionInsight(
        'Questionário longo (${questionnaireDetail.avgCompletionTime.toStringAsFixed(1)}min). Considere reduzir o número de questões.',
        InsightType.info,
      ));
    } else if (questionnaireDetail.avgCompletionTime >= 3 && questionnaireDetail.avgCompletionTime <= 10) {
      insights.add(QuestionInsight(
        'Tempo de preenchimento ideal (${questionnaireDetail.avgCompletionTime.toStringAsFixed(1)}min).',
        InsightType.positive,
      ));
    }
    
    // Insight sobre questões problemáticas
    final problematicQuestions = questionnaireDetail.questions.where((q) {
      // Calcular taxa real da questão
      double questionRate = 0.0;
      for (var data in q.data) {
        if (data.label.toLowerCase().contains('preenchidas') && data.percentage != null) {
          questionRate = data.percentage!;
          break;
        }
      }
      return questionRate < 70;
    }).length;
    
    if (problematicQuestions > 0) {
      insights.add(QuestionInsight(
        '$problematicQuestions questão(ões) com baixa taxa de resposta. Verifique clareza e relevância.',
        InsightType.warning,
      ));
    }
    
    // Insight sobre volume de dados
    if (questionnaireDetail.totalResponses > 100) {
      insights.add(QuestionInsight(
        'Excelente volume de dados coletados (${questionnaireDetail.totalResponses} respostas).',
        InsightType.positive,
      ));
    } else if (questionnaireDetail.totalResponses < 20) {
      insights.add(QuestionInsight(
        'Volume baixo de respostas (${questionnaireDetail.totalResponses}). Considere ampliar a divulgação.',
        InsightType.info,
      ));
    }
    
    // Insight sobre tipos de questão
    final textQuestions = questionnaireDetail.questions.where(
      (q) => q.type == 'textarea' || q.type == 'text'
    ).length;
    if (textQuestions > questionnaireDetail.questions.length * 0.6) {
      insights.add(QuestionInsight(
        'Muitas questões abertas ($textQuestions). Considere usar mais questões objetivas para facilitar análise.',
        InsightType.info,
      ));
    }
    
    return insights;
  }

  List<String> _generateRecommendations() {
    final recommendations = <String>[];
    final completionRate = _calculateCompletionRate();
    
    if (completionRate < 70) {
      recommendations.add('Revisar questões com baixa taxa de resposta para melhorar clareza');
    }
    
    if (questionnaireDetail.avgCompletionTime > 15) {
      recommendations.add('Considerar dividir o questionário em seções menores');
    }
    
    if (questionnaireDetail.totalResponses < 30) {
      recommendations.add('Aumentar divulgação para obter mais respostas e dados estatisticamente significativos');
    }
    
    final qualityScore = _calculateQualityScore();
    if (qualityScore < 60) {
      recommendations.add('Implementar testes A/B para otimizar estrutura do questionário');
    }
    
    if (questionnaireDetail.avgCompletionTime < 1) {
      recommendations.add('Adicionar validações para evitar respostas automáticas');
    }
    
    return recommendations;
  }

  // Métodos auxiliares para cores e ícones (mantidos iguais)
  IconData _getCompletionIcon(double rate) {
    if (rate >= 80) return Icons.check_circle;
    if (rate >= 60) return Icons.trending_up;
    return Icons.warning;
  }

  Color _getCompletionColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getEngagementLabel(EngagementLevel level) {
    switch (level) {
      case EngagementLevel.high:
        return 'Alto';
      case EngagementLevel.medium:
        return 'Médio';
      case EngagementLevel.low:
        return 'Baixo';
    }
  }

  IconData _getEngagementIcon(EngagementLevel level) {
    switch (level) {
      case EngagementLevel.high:
        return Icons.favorite;
      case EngagementLevel.medium:
        return Icons.thumb_up;
      case EngagementLevel.low:
        return Icons.thumb_down;
    }
  }

  Color _getEngagementColor(EngagementLevel level) {
    switch (level) {
      case EngagementLevel.high:
        return Colors.green;
      case EngagementLevel.medium:
        return Colors.orange;
      case EngagementLevel.low:
        return Colors.red;
    }
  }

  IconData _getQualityIcon(double score) {
    if (score >= 70) return Icons.star;
    if (score >= 50) return Icons.star_half;
    return Icons.star_border;
  }

  Color _getQualityColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}

// Modelos auxiliares
class QuestionInsight {
  final String message;
  final InsightType type;

  QuestionInsight(this.message, this.type);
}

enum InsightType {
  positive(Icons.check_circle, Colors.green),
  warning(Icons.warning, Colors.orange),
  info(Icons.info, Colors.blue),
  negative(Icons.error, Colors.red);

  const InsightType(this.icon, this.color);
  
  final IconData icon;
  final Color color;
}

enum EngagementLevel {
  high,
  medium,
  low,
}