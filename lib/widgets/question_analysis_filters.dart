import 'package:flutter/material.dart';
import '../providers/question_analysis_provider.dart';

class QuestionAnalysisFilters extends StatefulWidget {
  final AnalysisFilters currentFilters;
  final Function(AnalysisFilters) onFiltersChanged;
  final List<QuestionnaireAnalysis> questionnaires;
  final List<User> applicators;

  const QuestionAnalysisFilters({
    super.key,
    required this.currentFilters,
    required this.onFiltersChanged,
    required this.questionnaires,
    required this.applicators,
  });

  @override
  State<QuestionAnalysisFilters> createState() => _QuestionAnalysisFiltersState();
}

class _QuestionAnalysisFiltersState extends State<QuestionAnalysisFilters> {
  late AnalysisFilters _filters;
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters.copy();
    _updateDateControllers();
  }

  void _updateDateControllers() {
    if (_filters.dateFrom != null) {
      _dateFromController.text = _formatDate(_filters.dateFrom!);
    }
    if (_filters.dateTo != null) {
      _dateToController.text = _formatDate(_filters.dateTo!);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF0F0F0)),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtros de Análise',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF23345F),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Conteúdo dos filtros
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Período
                  _buildFilterSection(
                    'Período de Análise',
                    Icons.date_range,
                    [
                      _buildPeriodSelector(),
                      const SizedBox(height: 16),
                      _buildDateRangeSelector(),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Questionário específico
                  _buildFilterSection(
                    'Questionário',
                    Icons.quiz,
                    [
                      _buildQuestionnaireSelector(),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Aplicador
                  _buildFilterSection(
                    'Aplicador',
                    Icons.person,
                    [
                      _buildApplicatorSelector(),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Tipo de questão
                  _buildFilterSection(
                    'Tipo de Questão',
                    Icons.category,
                    [
                      _buildQuestionTypeSelector(),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Estatísticas mínimas
                  _buildFilterSection(
                    'Critérios de Resposta',
                    Icons.analytics,
                    [
                      _buildMinResponsesSelector(),
                      const SizedBox(height: 16),
                      _buildMinResponseRateSelector(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Botões de ação
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF0F0F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text(
                      'Limpar Filtros',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8fae5d),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Aplicar Filtros',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF8fae5d),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF23345F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPeriodChip('Última semana', PeriodType.lastWeek),
        _buildPeriodChip('Último mês', PeriodType.lastMonth),
        _buildPeriodChip('Últimos 3 meses', PeriodType.last3Months),
        _buildPeriodChip('Último ano', PeriodType.lastYear),
        _buildPeriodChip('Personalizado', PeriodType.custom),
      ],
    );
  }

  Widget _buildPeriodChip(String label, PeriodType period) {
    final isSelected = _filters.periodType == period;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filters.periodType = period;
          _updateDatesByPeriod(period);
        });
      },
      selectedColor: const Color(0xFF8fae5d).withOpacity(0.2),
      checkmarkColor: const Color(0xFF8fae5d),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF8fae5d) : Colors.grey[700],
        fontSize: 12,
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _dateFromController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Data Inicial',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onTap: () => _selectDate(context, true),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _dateToController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Data Final',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onTap: () => _selectDate(context, false),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionnaireSelector() {
    return DropdownButtonFormField<int?>(
      value: _filters.questionnaireId,
      decoration: const InputDecoration(
        labelText: 'Selecionar Questionário',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos os Questionários'),
        ),
        ...widget.questionnaires.map((q) => DropdownMenuItem<int?>(
          value: q.id,
          child: Text(
            q.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _filters.questionnaireId = value;
        });
      },
    );
  }

  Widget _buildApplicatorSelector() {
    return DropdownButtonFormField<int?>(
      value: _filters.appliedBy,
      decoration: const InputDecoration(
        labelText: 'Selecionar Aplicador',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos os Aplicadores'),
        ),
        ...widget.applicators.map((a) => DropdownMenuItem<int?>(
          value: a.id,
          child: Text(
            a.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _filters.appliedBy = value;
        });
      },
    );
  }

  Widget _buildQuestionTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTypeChip('Escolha Única', 'radio'),
        _buildTypeChip('Múltipla Escolha', 'checkbox'),
        _buildTypeChip('Texto', 'text'),
        _buildTypeChip('Número', 'number'),
        _buildTypeChip('Data', 'date'),
      ],
    );
  }

  Widget _buildTypeChip(String label, String type) {
    final isSelected = _filters.questionTypes.contains(type);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _filters.questionTypes.add(type);
          } else {
            _filters.questionTypes.remove(type);
          }
        });
      },
      selectedColor: const Color(0xFF8fae5d).withOpacity(0.2),
      checkmarkColor: const Color(0xFF8fae5d),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF8fae5d) : Colors.grey[700],
        fontSize: 12,
      ),
    );
  }

  Widget _buildMinResponsesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mínimo de Respostas',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF23345F),
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _filters.minResponses.toDouble(),
          min: 0,
          max: 1000,
          divisions: 20,
          activeColor: const Color(0xFF8fae5d),
          label: _filters.minResponses.toString(),
          onChanged: (value) {
            setState(() {
              _filters.minResponses = value.round();
            });
          },
        ),
        Text(
          'Valor: ${_filters.minResponses}',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildMinResponseRateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Taxa Mínima de Resposta (%)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF23345F),
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _filters.minResponseRate,
          min: 0,
          max: 100,
          divisions: 20,
          activeColor: const Color(0xFF8fae5d),
          label: '${_filters.minResponseRate.toStringAsFixed(1)}%',
          onChanged: (value) {
            setState(() {
              _filters.minResponseRate = value;
            });
          },
        ),
        Text(
          'Valor: ${_filters.minResponseRate.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _updateDatesByPeriod(PeriodType period) {
    final now = DateTime.now();
    switch (period) {
      case PeriodType.lastWeek:
        _filters.dateFrom = now.subtract(const Duration(days: 7));
        _filters.dateTo = now;
        break;
      case PeriodType.lastMonth:
        _filters.dateFrom = DateTime(now.year, now.month - 1, now.day);
        _filters.dateTo = now;
        break;
      case PeriodType.last3Months:
        _filters.dateFrom = DateTime(now.year, now.month - 3, now.day);
        _filters.dateTo = now;
        break;
      case PeriodType.lastYear:
        _filters.dateFrom = DateTime(now.year - 1, now.month, now.day);
        _filters.dateTo = now;
        break;
      case PeriodType.custom:
        // Não altera as datas, permite seleção manual
        break;
    }
    _updateDateControllers();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate 
          ? (_filters.dateFrom ?? DateTime.now())
          : (_filters.dateTo ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8fae5d),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _filters.dateFrom = picked;
          _filters.periodType = PeriodType.custom;
        } else {
          _filters.dateTo = picked;
          _filters.periodType = PeriodType.custom;
        }
        _updateDateControllers();
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _filters = AnalysisFilters();
      _dateFromController.clear();
      _dateToController.clear();
    });
  }

  void _applyFilters() {
    widget.onFiltersChanged(_filters);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }
}