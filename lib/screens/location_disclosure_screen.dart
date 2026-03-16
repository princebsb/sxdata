import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tela de Divulgacao em Destaque para Localizacao
/// Conforme exigido pela politica de Dados de Usuario do Google Play
/// https://support.google.com/googleplay/android-developer/answer/9799150
class LocationDisclosureScreen extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const LocationDisclosureScreen({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Icone principal
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976d2).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 56,
                    color: Color(0xFF1976d2),
                  ),
                ),

                const SizedBox(height: 24),

                // Titulo - EXPLICITO sobre coleta de dados
                const Text(
                  'Coleta de Dados de Localizacao',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF23345F),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // TEXTO PRINCIPAL - Menciona explicitamente a coleta de dados de localizacao
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1976d2).withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Este aplicativo coleta dados de localizacao (coordenadas GPS) do seu dispositivo para registrar onde as coletas de dados foram realizadas.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Card com detalhes do uso
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Como usamos seus dados de localizacao:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF23345F),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildReasonItem(
                        Icons.pin_drop,
                        'Registro de coordenadas GPS',
                        'Coletamos sua localizacao para registrar as coordenadas geograficas de cada formulario preenchido.',
                      ),

                      const SizedBox(height: 14),

                      _buildReasonItem(
                        Icons.verified,
                        'Validacao geografica',
                        'Os dados de localizacao sao usados para validar onde a coleta foi realizada.',
                      ),

                      const SizedBox(height: 14),

                      _buildReasonItem(
                        Icons.map,
                        'Exibicao no mapa',
                        'As coordenadas coletadas sao exibidas no mapa de aplicadores.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Informacao sobre quando a coleta ocorre
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'A coleta de localizacao ocorre apenas quando voce esta preenchendo formularios, com o app aberto e a tela ativa.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Garantia de privacidade
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2e7d32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2e7d32).withOpacity(0.3)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.security,
                        color: Color(0xFF2e7d32),
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Seus dados de localizacao nao sao vendidos ou compartilhados com terceiros para fins publicitarios.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2e7d32),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Botoes de acao
                Column(
                  children: [
                    // Botao Aceitar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8fae5d),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Concordo e Permitir',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botao Recusar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Nao Permitir',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Nota de rodape
                Text(
                  'Voce pode alterar essa permissao a qualquer momento nas configuracoes do seu dispositivo.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReasonItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF8fae5d).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF8fae5d),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF23345F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Helper class para gerenciar o disclosure de localizacao
class LocationDisclosureHelper {
  static const String _disclosureAcceptedKey = 'location_disclosure_accepted_v2';
  static const String _disclosureShownKey = 'location_disclosure_shown_v2';

  /// Verifica se o disclosure ja foi aceito
  static Future<bool> isDisclosureAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_disclosureAcceptedKey) ?? false;
  }

  /// Marca o disclosure como aceito
  static Future<void> setDisclosureAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disclosureAcceptedKey, accepted);
    await prefs.setBool(_disclosureShownKey, true);
  }

  /// Verifica se precisamos mostrar o disclosure antes de pedir permissao
  /// SEMPRE mostra a tela de disclosure (exigido pelo Google Play)
  static Future<bool> shouldShowDisclosure() async {
    // SEMPRE mostrar o disclosure para atender a politica do Google Play
    return true;
  }

  /// Mostra o disclosure e solicita permissao
  static Future<bool> showDisclosureAndRequestPermission(BuildContext context) async {
    // SEMPRE mostrar o disclosure (exigido pelo Google Play)

    // Mostrar tela de disclosure
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => LocationDisclosureScreen(
          onAccept: () async {
            await setDisclosureAccepted(true);
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          onDecline: () {
            Navigator.of(context).pop(false);
          },
        ),
      ),
    );

    if (accepted == true) {
      // Usuario aceitou, solicitar permissao do sistema
      final status = await Permission.location.request();
      return status.isGranted;
    }

    return false;
  }

  /// Reseta o estado do disclosure (para testes)
  static Future<void> resetDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_disclosureAcceptedKey);
    await prefs.remove(_disclosureShownKey);
  }
}
