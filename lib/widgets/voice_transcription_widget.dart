import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../models/ai_models.dart';
import '../providers/ai_provider.dart';
import '../services/transcription_storage_service.dart';

/// Widget de transcrição de voz para campos de texto.
/// Grava áudio real usando o pacote `record`, solicita permissão de microfone
/// automaticamente e envia para transcrição no backend.
/// Salva cada transcrição aceita localmente para posterior sincronização.
class VoiceTranscriptionWidget extends StatefulWidget {
  final String? currentValue;
  final ValueChanged<String> onTranscriptionAccepted;
  final int? questionId;
  final int? questionnaireId;
  final String? questionText;
  final String? applicatorName;
  final int? applicatorId;
  final bool enabled;

  const VoiceTranscriptionWidget({
    super.key,
    this.currentValue,
    required this.onTranscriptionAccepted,
    this.questionId,
    this.questionnaireId,
    this.questionText,
    this.applicatorName,
    this.applicatorId,
    this.enabled = true,
  });

  @override
  State<VoiceTranscriptionWidget> createState() =>
      _VoiceTranscriptionWidgetState();
}

class _VoiceTranscriptionWidgetState extends State<VoiceTranscriptionWidget>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _showEditField = false;
  final TextEditingController _editController = TextEditingController();
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  static const int _maxRecordingSeconds = 120;

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;
  TranscriptionResult? _lastTranscriptionResult;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _editController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  /// Solicita permissão de microfone e retorna se foi concedida.
  Future<bool> _requestMicPermission() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return true;

    // Solicita a permissão (exibe o diálogo do sistema)
    status = await Permission.microphone.request();

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      // Usuário marcou "não perguntar novamente"
      if (!mounted) return false;
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permissão de microfone'),
          content: const Text(
            'A permissão do microfone foi negada permanentemente. '
            'Para usar a gravação de voz, abra as configurações do app e permita o acesso ao microfone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Abrir configurações'),
            ),
          ],
        ),
      );
      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
      return false;
    }

    // Negado (mas pode pedir de novo)
    _showMessage('Permissão do microfone necessária para gravar áudio.');
    return false;
  }

  Future<void> _startRecording() async {
    if (kIsWeb) {
      _showMessage('Gravação de voz não disponível na versão web.');
      return;
    }

    final aiProvider = context.read<AiProvider>();
    if (!aiProvider.isAiAvailable) {
      _showMessage(
          'Serviço de transcrição indisponível. Use a digitação manual.');
      return;
    }

    // Solicita permissão antes de gravar
    final hasPermission = await _requestMicPermission();
    if (!hasPermission) return;

    // Verifica se o recorder pode gravar
    final canRecord = await _audioRecorder.hasPermission();
    if (!canRecord) {
      _showMessage('Não foi possível acessar o microfone.');
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      _recordingPath =
          '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      aiProvider.setRecordingState();

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingSeconds++;
        });

        if (_recordingSeconds >= _maxRecordingSeconds) {
          _stopRecording();
          _showMessage(
              'Gravação limitada a ${_maxRecordingSeconds ~/ 60} minutos.');
        }
      });
    } catch (e) {
      _showMessage('Erro ao iniciar gravação: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
    });

    if (_recordingSeconds < 1) {
      _showMessage('Gravação muito curta. Mantenha pressionado para gravar.');
      context.read<AiProvider>().resetTranscription();
      return;
    }

    try {
      // Para a gravação e obtém o path do arquivo
      final path = await _audioRecorder.stop();
      final filePath = path ?? _recordingPath;

      if (!mounted) return;

      if (filePath == null) {
        _showMessage('Gravação não capturada. Tente novamente.');
        context.read<AiProvider>().resetTranscription();
        return;
      }

      final audioFile = File(filePath);
      if (!audioFile.existsSync()) {
        _showMessage('Arquivo de áudio não encontrado. Tente novamente.');
        context.read<AiProvider>().resetTranscription();
        return;
      }

      if (!mounted) return;
      final result = await context.read<AiProvider>().transcribeAudio(
            audioFile,
            questionId: widget.questionId,
            questionText: widget.questionText,
            applicatorId: widget.applicatorId,
            applicatorName: widget.applicatorName,
            recordingDurationSecs: _recordingSeconds,
          );

      _lastTranscriptionResult = result;

      if (result.hasText) {
        _editController.text = result.text!;
        if (mounted) {
          setState(() {
            _showEditField = true;
          });
        }
      }

      // Limpar arquivo temporário
      try {
        await audioFile.delete();
      } catch (_) {}
    } catch (e) {
      _showMessage('Erro ao processar gravação: $e');
      if (mounted) {
        context.read<AiProvider>().resetTranscription();
      }
    }
  }

  void _acceptTranscription() {
    final text = _editController.text.trim();
    if (text.isNotEmpty) {
      if (widget.currentValue != null &&
          widget.currentValue!.isNotEmpty &&
          widget.currentValue != text) {
        _showOverwriteConfirmation(text);
      } else {
        _saveAndAccept(text);
      }
    }
  }

  void _saveAndAccept(String finalText) {
    // Salvar transcrição localmente para sincronização posterior
    _saveTranscriptionRecord(finalText);
    widget.onTranscriptionAccepted(finalText);
    _resetState();
  }

  void _saveTranscriptionRecord(String finalText) {
    final result = _lastTranscriptionResult;
    if (result == null) return;

    final record = TranscriptionRecord(
      id: const Uuid().v4(),
      questionnaireId: widget.questionnaireId ?? 0,
      questionId: widget.questionId ?? 0,
      questionText: widget.questionText ?? '',
      transcribedText: result.text ?? finalText,
      editedText: finalText != result.text ? finalText : null,
      confidence: result.confidence,
      language: result.language,
      durationMs: result.durationMs,
      recordingDurationSecs: _recordingSeconds,
      applicatorName: widget.applicatorName,
      applicatorId: widget.applicatorId,
    );

    // Fire-and-forget — não bloqueia o fluxo do usuário
    TranscriptionStorageService.save(record);
  }

  void _showOverwriteConfirmation(String newText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Substituir resposta?'),
        content: const Text(
          'Já existe uma resposta digitada. Deseja substituir pela transcrição?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _saveAndAccept(newText);
            },
            child: const Text('Substituir'),
          ),
        ],
      ),
    );
  }

  void _resetState() {
    setState(() {
      _showEditField = false;
      _recordingSeconds = 0;
    });
    _editController.clear();
    _lastTranscriptionResult = null;
    context.read<AiProvider>().resetTranscription();
  }

  void _retryTranscription() {
    _resetState();
    _startRecording();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || kIsWeb) {
      return const SizedBox.shrink();
    }

    return Consumer<AiProvider>(
      builder: (context, aiProvider, _) {
        final status = aiProvider.transcriptionStatus;

        // Campo de edição da transcrição
        if (_showEditField) {
          return _buildEditField(aiProvider);
        }

        // Estados de processamento
        if (status == TranscriptionStatus.uploading ||
            status == TranscriptionStatus.processing) {
          return _buildProcessingState(status);
        }

        // Estado de erro
        if (status == TranscriptionStatus.error) {
          return _buildErrorState(aiProvider);
        }

        // Botão de gravação padrão
        return _buildRecordButton();
      },
    );
  }

  Widget _buildRecordButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isRecording) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_recordingSeconds),
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop_circle, color: Colors.red),
            iconSize: 32,
            tooltip: 'Parar gravação',
          ),
        ] else
          Tooltip(
            message: 'Gravar resposta por voz',
            child: InkWell(
              onTap: _startRecording,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  color: Theme.of(context).primaryColor,
                  size: 22,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProcessingState(TranscriptionStatus status) {
    final message = status == TranscriptionStatus.uploading
        ? 'Enviando áudio...'
        : 'Transcrevendo...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AiProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  aiProvider.transcriptionResult.errorMessage ??
                      'Erro na transcrição',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: _retryTranscription,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tentar novamente',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetState,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child:
                    const Text('Cancelar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(AiProvider aiProvider) {
    final confidence = aiProvider.transcriptionResult.confidence;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over,
                  color: Colors.green.shade700, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Texto transcrito',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (confidence != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: confidence >= 0.85
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(confidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: confidence >= 0.85
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _editController,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Edite o texto antes de confirmar...',
              isDense: true,
              contentPadding: EdgeInsets.all(10),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retryTranscription,
                  icon: const Icon(Icons.refresh, size: 16),
                  label:
                      const Text('Regravar', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetState,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  child:
                      const Text('Cancelar', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _acceptTranscription,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Usar texto',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
