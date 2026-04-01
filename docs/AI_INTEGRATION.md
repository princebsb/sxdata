# SXDATA - Documentação de Integração de IA no App Móvel

## Visão Geral

Esta documentação descreve a evolução do app móvel SXDATA com recursos de Inteligência Artificial. Toda lógica de IA (prompts, processamento OpenAI, custos, auditoria avançada) é executada no **backend**. O app apenas envia contexto e recebe resultados processados.

---

## A. DIAGNÓSTICO INICIAL

### Stack Identificada
| Componente | Tecnologia |
|---|---|
| Framework | Flutter (Dart) SDK ^3.8.0 |
| Estado | Provider (ChangeNotifier) |
| Navegação | Navigator push/pop (imperativa) |
| API | HTTP package + classe ApiService estática |
| Storage local | SharedPreferences + path_provider |
| Backend | https://painel.sxdata.com.br/api |
| Autenticação | Token Bearer (SharedPreferences) |
| Offline | Formulários salvos localmente, sync status tracking |

### Arquitetura Atual
```
lib/
├── main.dart                  # Entry point + MultiProvider
├── models/                    # Modelos de dados
│   ├── questionnaire.dart     # Questionário com perguntas
│   ├── question.dart          # Pergunta com opções e lógica
│   ├── form_response.dart     # Resposta do formulário
│   ├── conditional_logic.dart # Regras condicionais
│   └── ai_models.dart         # [NOVO] Modelos de IA
├── providers/                 # Gerenciamento de estado
│   ├── auth_provider.dart     # Autenticação
│   ├── form_provider.dart     # Formulário ativo
│   ├── ai_provider.dart       # [NOVO] Estado de IA
│   └── ...
├── services/                  # Serviços
│   ├── api_service.dart       # API principal
│   ├── ai_api_service.dart    # [NOVO] API de IA
│   ├── ai_audit_service.dart  # [NOVO] Auditoria de IA
│   ├── ai_offline_queue.dart  # [NOVO] Fila offline de IA
│   └── ...
├── screens/                   # Telas
│   ├── question_screen.dart   # [MODIFICADO] Tela de perguntas com IA
│   └── ...
└── widgets/                   # Componentes visuais
    ├── voice_transcription_widget.dart      # [NOVO]
    ├── inconsistency_alert_widget.dart      # [NOVO]
    ├── standardization_suggestion_widget.dart # [NOVO]
    ├── smart_suggestion_widget.dart          # [NOVO]
    ├── follow_up_suggestion_widget.dart      # [NOVO]
    ├── ai_status_indicator.dart              # [NOVO]
    └── ...
```

### Riscos Identificados e Mitigações
| Risco | Mitigação |
|---|---|
| API key no app | Nenhuma chave no app. Toda IA via backend |
| Offline sem IA | Fallback para digitação manual. IA é "nice-to-have" |
| Timeout de transcrição | Timeout configurável, mensagem clara ao usuário |
| Sobrecarga de chamadas | Debounce de 2s para inconsistências |
| Credenciais em texto plano | flutter_secure_storage já está no projeto |

---

## B. IMPLEMENTAÇÃO

### Arquivos Criados

| Arquivo | Descrição |
|---|---|
| `lib/models/ai_models.dart` | Modelos: TranscriptionResult, InconsistencyAlert, DataStandardization, SmartFieldSuggestion, ReformulatedQuestion, AdaptiveNextQuestion, FollowUpSuggestion, AiAuditEvent, AiReportResult |
| `lib/services/ai_api_service.dart` | Client HTTP para endpoints de IA do backend. Tratamento de erros, timeout, retry |
| `lib/services/ai_audit_service.dart` | Auditoria local de eventos de IA com sync ao backend |
| `lib/services/ai_offline_queue.dart` | Fila offline para requisições de IA que falharam |
| `lib/providers/ai_provider.dart` | Provider central com estado de todos os recursos de IA |
| `lib/widgets/voice_transcription_widget.dart` | Widget de gravação + transcrição + edição |
| `lib/widgets/inconsistency_alert_widget.dart` | Widget de alertas de inconsistência |
| `lib/widgets/standardization_suggestion_widget.dart` | Widget de sugestão de padronização |
| `lib/widgets/smart_suggestion_widget.dart` | Widget de preenchimento inteligente |
| `lib/widgets/follow_up_suggestion_widget.dart` | Widget de follow-up sugerido |
| `lib/widgets/ai_status_indicator.dart` | Indicador de disponibilidade da IA |
| `test/ai_models_test.dart` | Testes unitários dos modelos de IA |
| `test/ai_provider_test.dart` | Testes unitários do AiProvider |

### Arquivos Modificados

| Arquivo | Alteração |
|---|---|
| `lib/main.dart` | Adicionado AiProvider no MultiProvider |
| `lib/screens/question_screen.dart` | Integrados widgets de IA, inicialização do AiProvider, verificações finais de IA antes da submissão, indicador de IA no header |

---

## C. TELAS E FLUXOS

### Tela de Perguntas (question_screen.dart)
**Alterações:**
- Header agora exibe indicador de disponibilidade da IA (estrela dourada = ativa, cinza = offline)
- Campos de texto exibem botão de microfone para transcrição de voz
- Após responder, podem aparecer:
  - Alertas de inconsistência (amarelo/vermelho)
  - Sugestões de padronização (azul)
  - Sugestões inteligentes de preenchimento (verde-azulado)
  - Perguntas complementares sugeridas (roxo)
- Ao finalizar, diálogo de padronização antes da submissão

### Fluxo de Transcrição de Voz
```
Toque no microfone → Gravação → Parar → Upload → Processamento → Texto transcrito
                                                                     ↓
                                                           Editar / Aceitar / Regravar
```

### Fluxo de Inconsistência
```
Resposta alterada → Debounce 2s → API verifica → Alerta exibido
                                                     ↓
                                           Corrigir / Manter / Revisar depois
```

---

## D. INTEGRAÇÕES

### Endpoints de IA (Backend)

| Endpoint | Método | Descrição |
|---|---|---|
| `/ai/health` | GET | Health check dos serviços de IA |
| `/ai/transcribe` | POST (multipart) | Transcrição de áudio |
| `/ai/check-inconsistencies` | POST | Verificação de inconsistências |
| `/ai/standardize` | POST | Padronização de dados |
| `/ai/smart-suggestions` | POST | Sugestões inteligentes |
| `/ai/reformulate-questions` | POST | Reformulação de perguntas |
| `/ai/adaptive-next` | POST | Próxima pergunta adaptativa |
| `/ai/follow-up` | POST | Sugestões de follow-up |
| `/ai/generate-report` | POST | Geração de relatório |
| `/ai/audit-log` | POST | Log de evento de auditoria |
| `/ai/audit-log/batch` | POST | Batch de eventos de auditoria |

### Contrato de API - Exemplos

**POST /ai/transcribe**
```
Request: multipart/form-data com campo "audio" (arquivo)
Response: {
  "success": true,
  "data": {
    "text": "texto transcrito",
    "confidence": 0.95,
    "language": "pt-BR",
    "duration_ms": 3500
  }
}
```

**POST /ai/check-inconsistencies**
```
Request: {
  "questionnaire_id": 1,
  "responses": {"1": "valor1", "2": "valor2"},
  "questions": [...]
}
Response: {
  "success": true,
  "data": {
    "alerts": [{
      "question_id": 2,
      "field_name": "idade",
      "message": "Idade inconsistente",
      "severity": "warning",
      "suggestion": "Verifique o campo"
    }]
  }
}
```

**POST /ai/standardize**
```
Request: {
  "questionnaire_id": 1,
  "responses": {"1": "são paulo", "2": "11999998888"}
}
Response: {
  "success": true,
  "data": {
    "suggestions": [{
      "question_id": 1,
      "original_value": "são paulo",
      "suggested_value": "São Paulo",
      "type": "capitalization",
      "confidence": 0.99
    }]
  }
}
```

### Tratamento de Erros
- **401**: Sessão expirada → mensagem ao usuário
- **429**: Rate limit → "Aguarde um momento"
- **Timeout**: Mensagem específica por tipo de operação
- **SocketException**: "Sem conexão. Recurso de IA indisponível offline."
- Todos os erros de IA são **não-bloqueantes**: o app continua funcionando sem IA

---

## E. COMO TESTAR

### Testes Automatizados
```bash
flutter test test/ai_models_test.dart
flutter test test/ai_provider_test.dart
```

### Cenários de Teste Manual

**1. Transcrição de Voz**
- Abrir questionário com campo de texto
- Verificar se ícone de microfone aparece
- Tocar no microfone → deve iniciar gravação com timer
- Parar gravação → deve mostrar "Enviando/Transcrevendo..."
- Se backend responder → campo de edição com texto transcrito
- Editar texto → confirmar → texto deve ir para o campo
- Testar com internet desligada → mensagem de erro + fallback digitação

**2. Inconsistências**
- Preencher campo de idade com "200"
- Preencher data de nascimento incompatível com idade
- Verificar se alerta amarelo aparece abaixo do campo
- Testar botões: Corrigir / Manter / Revisar depois

**3. Padronização**
- Digitar nome em minúsculas: "joão da silva"
- Ao finalizar formulário, verificar se diálogo sugere "João da Silva"
- Aceitar → campo deve ser atualizado
- Rejeitar → valor original mantido

**4. Preenchimento Inteligente**
- Preencher alguns campos
- Verificar se campo seguinte recebe sugestão (card verde-azulado)
- Aplicar sugestão → campo preenchido
- Ignorar → sugestão desaparece

**5. Questionário Adaptativo (requer ativação no backend)**
- Responder pergunta que dispara roteamento adaptativo
- Verificar se próxima pergunta mudou conforme IA
- Se IA falhar → fluxo padrão deve continuar

**6. Offline**
- Desligar internet
- Indicador de IA deve mudar para cinza
- Widgets de IA devem sumir ou mostrar fallback
- Preencher e submeter formulário normalmente
- Religar internet → sincronização deve funcionar

---

## F. DOCUMENTAÇÃO FINAL

### Variáveis de Ambiente do App
Nenhuma variável de ambiente de IA no app. Toda configuração é no backend.

O app usa:
- `ApiService.baseUrl` para o endereço do backend (`https://painel.sxdata.com.br/api`)
- Token de autenticação via `SharedPreferences('auth_token')`

### Permissões Necessárias
| Permissão | Uso | Plataforma |
|---|---|---|
| `RECORD_AUDIO` | Transcrição de voz | Android |
| `INTERNET` | Comunicação com backend | Android/iOS |
| Microphone | Transcrição de voz | iOS (Info.plist) |

**NOTA**: A permissão de microfone deve ser adicionada ao `AndroidManifest.xml` e `Info.plist`:

Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

iOS (`ios/Runner/Info.plist`):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>O SXDATA precisa acessar o microfone para transcrição de voz nas respostas</string>
```

### Dependência de Gravação de Áudio
Para gravação real de áudio, adicionar ao `pubspec.yaml`:
```yaml
record: ^5.0.0  # ou flutter_sound ou similar
```
O widget `VoiceTranscriptionWidget` está preparado para integração com qualquer pacote de gravação.

### Limitações Atuais
1. **Gravação de áudio**: Widget preparado mas requer pacote de gravação (record/flutter_sound)
2. **Offline IA**: Recursos de IA não funcionam offline. Fallback para modo manual.
3. **Reformulação de perguntas**: Funcionalidade completa no backend; app exibe versão ativa
4. **Questionário adaptativo**: Requer ativação por questionário no painel admin
5. **Follow-up**: Perguntas sugeridas são opcionais; não são salvas no formulário padrão (requer adaptação do backend)

### Próximos Passos
1. **Integrar pacote de gravação de áudio** (`record` ou `flutter_sound`) no `VoiceTranscriptionWidget`
2. **Adicionar permissões de microfone** ao AndroidManifest e Info.plist
3. **Implementar endpoints no backend** conforme contratos descritos nesta documentação
4. **Cache inteligente** de reformulações de perguntas (evitar re-chamada por sessão)
5. **Widget de relatório IA** na tela de estatísticas
6. **Notificação push** quando sincronização offline de IA completar
7. **Métricas de uso** de IA no painel admin (baseado nos eventos de auditoria)
8. **Testes de integração** com backend real
9. **Configuração por questionário** no painel: quais recursos de IA ativar

### Arquitetura de Segurança
```
┌──────────────┐     contexto      ┌──────────────┐     prompts     ┌──────────┐
│   App Móvel  │ ──────────────→   │   Backend    │ ──────────────→ │  OpenAI  │
│              │ ←──────────────   │   (PHP/API)  │ ←────────────── │   API    │
│  - Exibe     │     resultado     │  - Prompts   │    respostas    │          │
│  - Edita     │                   │  - Auditoria │                 │          │
│  - Aprova    │                   │  - Custos    │                 │          │
│  - Rejeita   │                   │  - Logs      │                 │          │
└──────────────┘                   └──────────────┘                 └──────────┘
```

- Nenhuma API key no app
- Toda lógica de prompt no backend
- App apenas envia contexto e recebe resultado
- Custos e auditoria controlados no backend
- Eventos de uso registrados para rastreabilidade
