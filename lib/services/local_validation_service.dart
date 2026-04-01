/// Serviço de validação inteligente LOCAL para respostas de questionários.
/// Funciona 100% offline, sem depender do backend.
/// Analisa o texto da pergunta para inferir o tipo de dado esperado
/// e critica respostas improváveis em tempo real.
class LocalValidationService {
  /// Analisa uma resposta e retorna alertas de possíveis inconsistências.
  /// Retorna lista vazia se tudo estiver ok.
  static List<ValidationAlert> validate({
    required String questionText,
    required String questionType,
    required dynamic value,
    Map<int, dynamic>? allResponses,
    Map<int, String>? allQuestionTexts,
  }) {
    if (value == null) return [];
    final strValue = value.toString().trim();
    if (strValue.isEmpty) return [];

    final alerts = <ValidationAlert>[];
    final lowerQuestion = questionText.toLowerCase();
    final type = questionType.toLowerCase().trim();

    // Tipos de campo com seleção fixa — não validar conteúdo
    final isSelectionType = type == 'radio' || type == 'checkbox' ||
        type == 'select' || type == 'dropdown';

    // ============================================================
    // 1. VALIDAÇÕES NUMÉRICAS (campos number ou texto com contexto numérico)
    // ============================================================
    if (!isSelectionType && (type == 'number' || _isNumericContext(lowerQuestion))) {
      final cleanValue = strValue.replaceAll(',', '.');
      final numValue = double.tryParse(cleanValue);

      // --- CAMPO NUMÉRICO COM CARACTERES INVÁLIDOS ---
      if (numValue == null && strValue.isNotEmpty) {
        final hasLetters = RegExp(r'[a-zA-ZáàâãéèêíïóôõúüçÁÀÂÃÉÈÊÍÏÓÔÕÚÜÇ]').hasMatch(strValue);
        final hasSymbols = RegExp(r'[^0-9.,\-\s]').hasMatch(strValue);

        if (hasLetters && type == 'number') {
          alerts.add(ValidationAlert(
            message: 'Este campo aceita apenas números. Remova as letras.',
            severity: AlertSeverity.error,
          ));
        } else if (hasLetters) {
          alerts.add(ValidationAlert(
            message: 'Esperado um valor numérico, mas há letras na resposta.',
            severity: AlertSeverity.warning,
            suggestion: 'Informe apenas números.',
          ));
        } else if (hasSymbols) {
          // Extrair os símbolos encontrados para mostrar ao usuário
          final symbols = strValue.replaceAll(RegExp(r'[0-9.,\-\s]'), '');
          alerts.add(ValidationAlert(
            message: 'Caracteres inválidos encontrados: "$symbols". Use apenas números.',
            severity: AlertSeverity.warning,
          ));
        } else {
          alerts.add(ValidationAlert(
            message: 'Valor "$strValue" não é um número válido.',
            severity: AlertSeverity.warning,
            suggestion: 'Informe apenas dígitos (ex: 25).',
          ));
        }
      }

      if (numValue != null) {
        // --- IDADE ---
        if (_matchesAny(lowerQuestion, _ageKeywords)) {
          if (numValue < 0) {
            alerts.add(ValidationAlert(
              message: 'Idade não pode ser negativa.',
              severity: AlertSeverity.error,
              suggestion: 'Verifique o valor informado.',
            ));
          } else if (numValue > 130) {
            alerts.add(ValidationAlert(
              message: 'Idade $strValue parece incorreta. A idade máxima conhecida é ~130 anos.',
              severity: AlertSeverity.warning,
              suggestion: 'Você quis dizer ${strValue.length > 2 ? strValue.substring(0, 2) : strValue}?',
            ));
          } else if (numValue > 110) {
            alerts.add(ValidationAlert(
              message: 'Idade $strValue anos é bastante incomum. Confira se está correto.',
              severity: AlertSeverity.info,
            ));
          } else if (numValue != numValue.roundToDouble()) {
            alerts.add(ValidationAlert(
              message: 'Idade geralmente é um número inteiro.',
              severity: AlertSeverity.info,
              suggestion: 'Você quis dizer ${numValue.round()}?',
            ));
          }
        }

        // --- PESO (kg) ---
        if (_matchesAny(lowerQuestion, _weightKeywords)) {
          if (numValue < 0) {
            alerts.add(ValidationAlert(
              message: 'Peso não pode ser negativo.',
              severity: AlertSeverity.error,
            ));
          } else if (numValue > 0 && numValue < 2) {
            alerts.add(ValidationAlert(
              message: 'Peso de ${numValue}kg parece muito baixo. Confira o valor.',
              severity: AlertSeverity.warning,
            ));
          } else if (numValue > 350) {
            alerts.add(ValidationAlert(
              message: 'Peso de ${numValue}kg parece muito alto. O recorde mundial é ~635kg.',
              severity: AlertSeverity.warning,
              suggestion: 'Verifique se não digitou números a mais.',
            ));
          }
        }

        // --- ALTURA (cm ou m) ---
        if (_matchesAny(lowerQuestion, _heightKeywords)) {
          if (lowerQuestion.contains('cm') || lowerQuestion.contains('centímetro')) {
            if (numValue > 0 && numValue < 30) {
              alerts.add(ValidationAlert(
                message: 'Altura de ${numValue}cm parece muito baixa.',
                severity: AlertSeverity.warning,
              ));
            } else if (numValue > 280) {
              alerts.add(ValidationAlert(
                message: 'Altura de ${numValue}cm parece muito alta. O recorde é ~272cm.',
                severity: AlertSeverity.warning,
              ));
            }
          } else {
            // Assume metros
            if (numValue > 3) {
              alerts.add(ValidationAlert(
                message: 'Altura de ${numValue}m parece incorreta. Talvez esteja em centímetros?',
                severity: AlertSeverity.warning,
                suggestion: numValue > 100 ? 'Você quis dizer ${(numValue / 100).toStringAsFixed(2)}m?' : null,
              ));
            } else if (numValue > 0 && numValue < 0.3) {
              alerts.add(ValidationAlert(
                message: 'Altura de ${numValue}m parece muito baixa.',
                severity: AlertSeverity.warning,
              ));
            }
          }
        }

        // --- SALÁRIO / RENDA ---
        if (_matchesAny(lowerQuestion, _incomeKeywords)) {
          if (numValue < 0) {
            alerts.add(ValidationAlert(
              message: 'Valor de renda não pode ser negativo.',
              severity: AlertSeverity.error,
            ));
          } else if (numValue > 1000000) {
            alerts.add(ValidationAlert(
              message: 'Renda de R\$ ${_formatNumber(numValue)} por mês parece muito alta. Confira o valor.',
              severity: AlertSeverity.warning,
            ));
          }
        }

        // --- FILHOS / QUANTIDADE DE PESSOAS ---
        if (_matchesAny(lowerQuestion, _childrenKeywords)) {
          if (numValue < 0) {
            alerts.add(ValidationAlert(
              message: 'Quantidade não pode ser negativa.',
              severity: AlertSeverity.error,
            ));
          } else if (numValue > 30) {
            alerts.add(ValidationAlert(
              message: 'Quantidade de $strValue parece muito alta. Confira o valor.',
              severity: AlertSeverity.warning,
            ));
          } else if (numValue != numValue.roundToDouble()) {
            alerts.add(ValidationAlert(
              message: 'Quantidade de pessoas geralmente é um número inteiro.',
              severity: AlertSeverity.info,
              suggestion: 'Você quis dizer ${numValue.round()}?',
            ));
          }
        }

        // --- ANO ---
        if (_matchesAny(lowerQuestion, _yearKeywords) && !_matchesAny(lowerQuestion, _ageKeywords)) {
          final currentYear = DateTime.now().year;
          if (numValue > 1000 && numValue < 1900) {
            alerts.add(ValidationAlert(
              message: 'Ano $strValue é muito antigo. Confira se está correto.',
              severity: AlertSeverity.info,
            ));
          } else if (numValue > currentYear + 10) {
            alerts.add(ValidationAlert(
              message: 'Ano $strValue está muito no futuro.',
              severity: AlertSeverity.warning,
            ));
          } else if (numValue > currentYear) {
            alerts.add(ValidationAlert(
              message: 'Ano $strValue é no futuro. Confira se está correto.',
              severity: AlertSeverity.info,
            ));
          }
        }

        // --- CPF (valor numérico) ---
        if (_matchesAny(lowerQuestion, _cpfKeywords)) {
          final digits = strValue.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.length != 11) {
            alerts.add(ValidationAlert(
              message: 'CPF deve ter 11 dígitos. Informado: ${digits.length} dígitos.',
              severity: AlertSeverity.warning,
            ));
          } else if (_isAllSameDigit(digits)) {
            alerts.add(ValidationAlert(
              message: 'CPF com todos os dígitos iguais é inválido.',
              severity: AlertSeverity.error,
            ));
          }
        }

        // --- TELEFONE ---
        if (_matchesAny(lowerQuestion, _phoneKeywords)) {
          final digits = strValue.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty && (digits.length < 10 || digits.length > 11)) {
            alerts.add(ValidationAlert(
              message: 'Telefone brasileiro deve ter 10 ou 11 dígitos (com DDD). Informado: ${digits.length}.',
              severity: AlertSeverity.warning,
            ));
          }
        }

        // --- CEP ---
        if (_matchesAny(lowerQuestion, _cepKeywords)) {
          final digits = strValue.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty && digits.length != 8) {
            alerts.add(ValidationAlert(
              message: 'CEP deve ter 8 dígitos. Informado: ${digits.length}.',
              severity: AlertSeverity.warning,
            ));
          }
        }

        // --- VALOR NUMÉRICO GENÉRICO SUSPEITO ---
        // Se nenhum keyword específico bateu, aplicar heurísticas genéricas
        if (alerts.isEmpty) {
          // Números com 4+ dígitos em campos numéricos simples (sem contexto de renda/valor/ano)
          if (numValue.abs() >= 1000 &&
              !_matchesAny(lowerQuestion, _incomeKeywords) &&
              !_matchesAny(lowerQuestion, _yearKeywords) &&
              !_matchesAny(lowerQuestion, _cpfKeywords) &&
              !_matchesAny(lowerQuestion, _phoneKeywords) &&
              !_matchesAny(lowerQuestion, _cepKeywords) &&
              !_matchesAny(lowerQuestion, ['valor', 'preço', 'preco', 'custo', 'total'])) {
            alerts.add(ValidationAlert(
              message: 'O valor ${numValue.toInt()} parece muito alto para este campo. Confira se digitou corretamente.',
              severity: AlertSeverity.warning,
              suggestion: 'Talvez tenha digitado dígitos a mais?',
            ));
          }
        }

        if (alerts.isEmpty && numValue.abs() > 99999999) {
          alerts.add(ValidationAlert(
            message: 'O valor $strValue parece muito grande. Confira se está correto.',
            severity: AlertSeverity.info,
          ));
        }

        // --- NÚMERO NEGATIVO EM CONTEXTO QUE NÃO FAZ SENTIDO ---
        if (alerts.isEmpty && numValue < 0 && _matchesAny(lowerQuestion, _positiveOnlyKeywords)) {
          alerts.add(ValidationAlert(
            message: 'Este valor não deveria ser negativo.',
            severity: AlertSeverity.warning,
          ));
        }
      }
    }

    // ============================================================
    // 2. VALIDAÇÕES DE TEXTO
    // ============================================================
    if (type == 'text' || type == 'textarea') {
      // --- NOME ---
      if (_matchesAny(lowerQuestion, _nameKeywords)) {
        if (strValue.length < 3) {
          alerts.add(ValidationAlert(
            message: 'Nome parece muito curto. Confira se está completo.',
            severity: AlertSeverity.info,
          ));
        }
        if (RegExp(r'^[0-9\s.,\-]+$').hasMatch(strValue)) {
          alerts.add(ValidationAlert(
            message: 'O campo de nome contém apenas números. Informe um nome.',
            severity: AlertSeverity.error,
          ));
        } else if (RegExp(r'[0-9]').hasMatch(strValue)) {
          alerts.add(ValidationAlert(
            message: 'Nome contém números. Confira se está correto.',
            severity: AlertSeverity.warning,
          ));
        }
        if (RegExp(r'[!@#\$%\^&\*\(\)=\+\[\]\{\};:\"\\|<>/\?]').hasMatch(strValue)) {
          alerts.add(ValidationAlert(
            message: 'Nome contém caracteres especiais. Confira se está correto.',
            severity: AlertSeverity.warning,
          ));
        }
        if (strValue == strValue.toUpperCase() && strValue.length > 3 &&
            RegExp(r'[A-Z]').hasMatch(strValue)) {
          alerts.add(ValidationAlert(
            message: 'Nome está todo em MAIÚSCULAS. Deseja manter assim?',
            severity: AlertSeverity.info,
          ));
        }
        // Nome com uma só palavra (sem sobrenome)
        if (strValue.length >= 3 && !strValue.contains(' ')) {
          alerts.add(ValidationAlert(
            message: 'Informe o nome completo (nome e sobrenome).',
            severity: AlertSeverity.info,
          ));
        }
      }

      // --- EMAIL ---
      if (_matchesAny(lowerQuestion, _emailKeywords)) {
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(strValue)) {
          alerts.add(ValidationAlert(
            message: 'Este email não parece válido. Confira o formato.',
            severity: AlertSeverity.warning,
            suggestion: 'Formato esperado: exemplo@dominio.com',
          ));
        }
      }

      // --- CPF em campo texto ---
      if (_matchesAny(lowerQuestion, _cpfKeywords)) {
        final digits = strValue.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          if (digits.length != 11) {
            alerts.add(ValidationAlert(
              message: 'CPF deve ter 11 dígitos. Informado: ${digits.length}.',
              severity: AlertSeverity.warning,
            ));
          } else if (_isAllSameDigit(digits)) {
            alerts.add(ValidationAlert(
              message: 'CPF com todos os dígitos iguais é inválido.',
              severity: AlertSeverity.error,
            ));
          }
        }
      }

      // --- TELEFONE em campo texto ---
      if (_matchesAny(lowerQuestion, _phoneKeywords)) {
        final digits = strValue.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty && (digits.length < 10 || digits.length > 11)) {
          alerts.add(ValidationAlert(
            message: 'Telefone deve ter 10 ou 11 dígitos (com DDD).',
            severity: AlertSeverity.warning,
          ));
        }
      }

      // --- CEP em campo texto ---
      if (_matchesAny(lowerQuestion, _cepKeywords)) {
        final digits = strValue.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty && digits.length != 8) {
          alerts.add(ValidationAlert(
            message: 'CEP deve ter 8 dígitos.',
            severity: AlertSeverity.warning,
          ));
        }
      }

      // --- NÚMERO DIGITADO EM CAMPO DE TEXTO (possível idade, etc.) ---
      if (_matchesAny(lowerQuestion, _ageKeywords) && type == 'text') {
        final numValue = double.tryParse(strValue.replaceAll(',', '.'));
        if (numValue != null && numValue > 130) {
          alerts.add(ValidationAlert(
            message: 'Idade $strValue parece incorreta.',
            severity: AlertSeverity.warning,
            suggestion: 'Você quis dizer ${strValue.length > 2 ? strValue.substring(0, 2) : strValue}?',
          ));
        }
      }
    }

    // ============================================================
    // 2.5 VALIDAÇÕES DE TEXTO GENÉRICAS (qualquer tipo de campo textual)
    // ============================================================
    if (!isSelectionType && type != 'date' && type != 'datetime') {
      // --- SÓ ESPAÇOS EM BRANCO ---
      if (strValue.isNotEmpty && strValue.trim().isEmpty) {
        alerts.add(ValidationAlert(
          message: 'O campo contém apenas espaços em branco.',
          severity: AlertSeverity.error,
        ));
      }

      // --- SÓ PONTUAÇÃO / SÍMBOLOS ---
      if (strValue.length >= 2 &&
          RegExp(r'^[^a-zA-Z0-9áàâãéèêíïóôõúüçÁÀÂÃÉÈÊÍÏÓÔÕÚÜÇ]+$').hasMatch(strValue)) {
        alerts.add(ValidationAlert(
          message: 'Resposta contém apenas símbolos. Informe um valor válido.',
          severity: AlertSeverity.error,
        ));
      }

      // --- RESPOSTA GENÉRICA / PREGUIÇOSA ---
      final lowerValue = strValue.toLowerCase().trim();
      if (_genericAnswers.contains(lowerValue)) {
        alerts.add(ValidationAlert(
          message: 'Resposta muito genérica. Tente ser mais específico.',
          severity: AlertSeverity.info,
        ));
      }

      // --- RESPOSTA CURTA DEMAIS (1-2 letras) em campos texto/textarea ---
      if ((type == 'text' || type == 'textarea') &&
          strValue.length <= 2 &&
          !_matchesAny(lowerQuestion, _cpfKeywords) &&
          !_matchesAny(lowerQuestion, _cepKeywords) &&
          !_matchesAny(lowerQuestion, ['uf', 'estado', 'sigla'])) {
        alerts.add(ValidationAlert(
          message: 'Resposta muito curta. Tente ser mais detalhado.',
          severity: AlertSeverity.info,
        ));
      }

      // --- CARACTERES REPETIDOS ---
      if (strValue.length >= 5 && _isRepeatingPattern(strValue)) {
        alerts.add(ValidationAlert(
          message: 'Resposta parece conter caracteres repetidos sem sentido.',
          severity: AlertSeverity.warning,
        ));
      }

      // --- EXCESSO DE NÚMEROS EM CAMPO DE TEXTO (possível erro de campo) ---
      if ((type == 'text' || type == 'textarea') &&
          !_matchesAny(lowerQuestion, [..._cpfKeywords, ..._phoneKeywords, ..._cepKeywords,
            'número', 'numero', 'código', 'codigo', 'cns', 'nis', 'pis', 'registro'])) {
        final digitCount = strValue.replaceAll(RegExp(r'[^0-9]'), '').length;
        final totalLength = strValue.length;
        if (totalLength > 3 && digitCount > totalLength * 0.8) {
          alerts.add(ValidationAlert(
            message: 'Este campo parece conter mais números do que texto. Confira se é o campo correto.',
            severity: AlertSeverity.info,
          ));
        }
      }
    }

    // ============================================================
    // 3. VALIDAÇÕES DE DATA
    // ============================================================
    if (type == 'date' || type == 'datetime') {
      DateTime? dateValue;
      if (value is DateTime) {
        dateValue = value;
      } else if (value is String) {
        dateValue = DateTime.tryParse(value);
      }

      if (dateValue != null) {
        final now = DateTime.now();

        // --- DATA DE NASCIMENTO ---
        if (_matchesAny(lowerQuestion, _birthDateKeywords)) {
          final age = now.year - dateValue.year;
          if (dateValue.isAfter(now)) {
            alerts.add(ValidationAlert(
              message: 'Data de nascimento não pode ser no futuro.',
              severity: AlertSeverity.error,
            ));
          } else if (age > 130) {
            alerts.add(ValidationAlert(
              message: 'Esta data indica $age anos de idade. Confira o ano.',
              severity: AlertSeverity.warning,
            ));
          } else if (age < 0) {
            alerts.add(ValidationAlert(
              message: 'Data de nascimento inválida.',
              severity: AlertSeverity.error,
            ));
          }
        }

        // --- DATA FUTURA genérica ---
        if (!_matchesAny(lowerQuestion, _futureDateKeywords)) {
          if (dateValue.isAfter(now.add(const Duration(days: 365)))) {
            alerts.add(ValidationAlert(
              message: 'Esta data é mais de 1 ano no futuro. Confira se está correta.',
              severity: AlertSeverity.warning,
            ));
          }
        }

        // --- DATA MUITO ANTIGA ---
        if (dateValue.year < 1900 && !_matchesAny(lowerQuestion, _historicalKeywords)) {
          alerts.add(ValidationAlert(
            message: 'Data anterior a 1900 é incomum. Confira o ano.',
            severity: AlertSeverity.info,
          ));
        }
      }
    }

    return alerts;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  static bool _isNumericContext(String text) {
    return _matchesAny(text, [
      'quantos', 'quantas', 'quantidade', 'número', 'numero', 'total',
      'idade', 'anos', 'peso', 'altura', 'renda', 'salário', 'salario',
      'valor', 'preço', 'preco', 'cpf', 'telefone', 'celular', 'cep',
    ]);
  }

  static bool _isAllSameDigit(String digits) {
    if (digits.isEmpty) return false;
    return digits.split('').every((d) => d == digits[0]);
  }

  static bool _isRepeatingPattern(String text) {
    if (text.length < 5) return false;
    // Verifica se é só um caractere repetido (ex: "aaaaaaa", "1111111")
    if (text.split('').toSet().length == 1) return true;
    // Verifica padrões como "asdasdasd", "abcabcabc"
    for (int len = 1; len <= 3; len++) {
      if (text.length >= len * 3) {
        final pattern = text.substring(0, len);
        final repeated = pattern * (text.length ~/ len + 1);
        if (repeated.startsWith(text)) return true;
      }
    }
    return false;
  }

  static String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} milhões';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} mil';
    }
    return value.toStringAsFixed(2);
  }

  // ============================================================
  // KEYWORDS
  // ============================================================

  static const _ageKeywords = [
    'idade', 'anos de idade', 'quantos anos', 'qual a idade', 'qual sua idade',
    'faixa etária', 'faixa etaria',
  ];

  static const _weightKeywords = [
    'peso', 'quilos', 'kg', 'quilogramas',
  ];

  static const _heightKeywords = [
    'altura', 'estatura', 'metros', 'centímetros', 'centimetros',
  ];

  static const _incomeKeywords = [
    'renda', 'salário', 'salario', 'ganho', 'remuneração', 'remuneracao',
    'renda mensal', 'renda familiar', 'renda per capita',
  ];

  static const _childrenKeywords = [
    'filhos', 'filhas', 'dependentes', 'moradores', 'pessoas na casa',
    'membros da família', 'membros da familia', 'quantas pessoas',
    'quantos filhos', 'número de filhos', 'numero de filhos',
  ];

  static const _yearKeywords = [
    'ano', 'qual ano', 'em que ano', 'ano de',
  ];

  static const _cpfKeywords = ['cpf'];
  static const _phoneKeywords = ['telefone', 'celular', 'whatsapp', 'fone', 'contato'];
  static const _cepKeywords = ['cep', 'código postal', 'codigo postal'];
  static const _emailKeywords = ['email', 'e-mail', 'correio eletrônico'];

  static const _nameKeywords = [
    'nome', 'nome completo', 'seu nome', 'nome do', 'nome da',
    'responsável', 'responsavel', 'entrevistado',
  ];

  static const _birthDateKeywords = [
    'nascimento', 'data de nascimento', 'quando nasceu', 'nasceu em',
  ];

  static const _futureDateKeywords = [
    'previsão', 'previsao', 'prazo', 'vencimento', 'entrega',
    'agendamento', 'programado', 'próximo', 'proximo',
  ];

  static const _historicalKeywords = [
    'histórico', 'historico', 'fundação', 'fundacao', 'construção', 'construcao',
  ];

  static const _positiveOnlyKeywords = [
    'quantidade', 'quantos', 'quantas', 'número de', 'numero de',
    'total', 'filhos', 'moradores', 'pessoas',
  ];

  static const _genericAnswers = [
    'sim', 'não', 'nao', 'ok', 'talvez', 'nenhum', 'nenhuma',
    'nada', 'nao sei', 'não sei', 'sei lá', 'sei la',
    'tanto faz', 'qualquer', 'qualquer coisa',
    'teste', 'test', 'xxx', 'aaa', 'bbb', 'abc', 'asdf',
  ];
}

// ============================================================
// MODELOS
// ============================================================

enum AlertSeverity {
  info,    // Informativo - azul
  warning, // Alerta - amarelo/laranja
  error,   // Erro provável - vermelho
}

class ValidationAlert {
  final String message;
  final AlertSeverity severity;
  final String? suggestion;

  const ValidationAlert({
    required this.message,
    required this.severity,
    this.suggestion,
  });
}
