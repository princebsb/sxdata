# PROMPT PARA O AGENTE DO PAINEL — Corrigir/Criar endpoint POST /api/ai/transcribe

> ## ⚠️ ATUALIZAÇÃO 09/06/2026 — O PROBLEMA MUDOU APÓS A TROCA DE SERVIDOR
>
> O endpoint `transcribe` **já existe e responde** (não é mais o caso de criá-lo).
> Depois que o servidor foi migrado, ele passou a retornar este erro ao app:
>
> ```
> Erro interno: unlink(/home/sxdata/painel.sxdata.com.br/uploads/audio/audio_1781004579_2816.wav): No such file or directory
> ```
>
> ### Diagnóstico confirmado (com evidência de FTP)
>
> 1. O áudio **sai do app e chega ao servidor** por HTTP (`POST /api/ai/transcribe`, campo `audio`, arquivo ~60–100 KB).
> 2. **Nenhum arquivo novo está sendo gravado** na pasta de upload — no FTP, `/uploads/audio/` só tem `.wav` antigos (de 14/05/2026), nenhum da data atual.
> 3. A mensagem aponta o caminho **`/home/sxdata/painel.sxdata.com.br/uploads/audio/`**, que provavelmente **não é mais a pasta física real** depois da migração — ou o usuário do PHP não tem permissão de escrita nela.
> 4. Como o `do_upload()` falha (caminho inexistente / sem permissão), o arquivo nunca é salvo, e em seguida o `unlink()` num nome remontado (`audio_<time>_<rand>.wav`) estoura com *"No such file or directory"*. Esse `unlink` é só o **sintoma final** — a falha real é o upload não gravar.
>
> Observação reforçando o item 4: o nome que o `unlink` tenta apagar (`audio_..._....wav`) é **diferente** do nome com que o app envia o arquivo (`recording_<millis>.wav`). Antes da migração já havia divergência entre o nome gravado e o nome apagado.
>
> ### O que corrigir (em ordem de prioridade)
>
> 1. **Conferir o `upload_path` real no servidor novo.** Descobrir o caminho absoluto correto da pasta `uploads/audio/` (use `FCPATH . 'uploads/audio/'` em vez de hardcode `/home/sxdata/...`) e garantir que o código aponte para ele.
> 2. **Permissão/dono da pasta.** `0775` não basta se o dono/grupo não for o usuário do PHP (`www-data` ou usuário do cPanel). Ajustar `chown` para o usuário que roda o PHP.
> 3. **Checar se o `do_upload()` deu certo ANTES de transcrever** — se `false`, retornar JSON de erro e **não** prosseguir para o `unlink`.
> 4. **Usar o caminho que o upload realmente gravou:** `$path = $this->upload->data('full_path');` — nunca remontar o nome do arquivo manualmente.
> 5. **Limpeza segura:** trocar `unlink($path)` por `if ($path && file_exists($path)) { @unlink($path); }` para a limpeza nunca derrubar a resposta.
>
> ```bash
> # No servidor NOVO, descobrir o caminho real e ajustar dono/permissão:
> ls -la $(php -r "echo getcwd();")/uploads/audio/
> chmod 775 <caminho_real>/uploads/audio/
> chown <usuario_do_php>:<grupo_do_php> <caminho_real>/uploads/audio/
> ```
>
> **Nada precisa mudar no app.** A URL base (`https://painel.sxdata.com.br/api`) já aponta para o servidor novo (login e carregamento de questionário funcionam). O app não conhece caminhos de pasta nem FTP — apenas envia o áudio por HTTP. A correção é inteiramente no painel.
>
> O restante deste documento (abaixo) continua válido como referência da implementação completa do endpoint.
>
> ---

Você é o desenvolvedor backend do painel administrativo SXDATA (CodeIgniter 3 + PHP).
O app móvel está enviando arquivos de áudio `.wav` para transcrição via `POST /api/ai/transcribe`, mas o endpoint está retornando uma página de erro PHP em vez de JSON.

## PROBLEMA

O app envia:
```
POST /api/ai/transcribe
Content-Type: multipart/form-data
Authorization: Bearer <token>
Campo: audio (arquivo .wav)
```

O backend retorna HTML de erro PHP (`<div style="border:1px solid #990000">`) em vez de JSON.
O endpoint GET /api/ai/status funciona e confirma que `transcription` está habilitada com modelo `whisper-1`.

## O QUE PRECISA SER FEITO

### 1. Verificar se o método existe

Abrir `application/controllers/api/Ai.php` (ou `application/controllers/Ai.php`) e procurar pelo método `transcribe_post()` ou `transcribe()`.

**Se NÃO existir**, criar conforme a seção 3 abaixo.
**Se existir**, verificar os problemas comuns na seção 2.

### 2. Problemas comuns a verificar (se o método já existe)

#### a) Upload `allowed_types` não inclui wav
Procurar no método por `$config['allowed_types']` e garantir que inclua `wav`:
```php
$config['allowed_types'] = 'wav|mp3|m4a|ogg|webm|aac|flac';
```

#### b) Nome do campo do upload está errado
O app envia o arquivo com o campo `audio`. Verificar se o `do_upload()` usa esse nome:
```php
// CORRETO:
$this->upload->do_upload('audio');

// ERRADO (campo diferente):
$this->upload->do_upload('file');
$this->upload->do_upload('userfile');
```

#### c) Tamanho máximo muito baixo
```php
$config['max_size'] = 10240; // 10MB — WAV é maior que MP3
```

#### d) Diretório de upload não existe ou sem permissão
```php
$config['upload_path'] = FCPATH . 'uploads/audio/';
// Verificar se a pasta existe e tem permissão 755 ou 775
```

#### e) Erro na chamada à API OpenAI Whisper
Verificar se a chave da API OpenAI está configurada e se o endpoint do Whisper está correto:
```php
// URL correta para Whisper:
$url = 'https://api.openai.com/v1/audio/transcriptions';
```

#### f) cURL não tem suporte a multipart
Verificar se a chamada ao OpenAI usa `CURLFile`:
```php
// CORRETO:
$postFields = [
    'file'  => new CURLFile($filePath, 'audio/wav', basename($filePath)),
    'model' => 'whisper-1',
    'language' => 'pt',
];

// ERRADO (string path sem CURLFile):
$postFields = [
    'file' => '@' . $filePath,  // Depreciado no PHP 5.6+
];
```

### 3. Implementação completa (se o método não existe)

Adicionar no controller `Ai.php`:

```php
/**
 * Recebe áudio do app e transcreve usando OpenAI Whisper.
 * POST /api/ai/transcribe
 * Campo: audio (arquivo .wav, .mp3, .m4a, etc.)
 */
public function transcribe_post() {
    // 1. Verificar se transcription está habilitada
    // (ajustar conforme sua lógica de features/configuração)

    // 2. Configurar upload
    $uploadPath = FCPATH . 'uploads/audio/';
    if (!is_dir($uploadPath)) {
        mkdir($uploadPath, 0755, true);
    }

    $config['upload_path']   = $uploadPath;
    $config['allowed_types'] = 'wav|mp3|m4a|ogg|webm|aac|flac';
    $config['max_size']      = 25600; // 25MB (limite do Whisper)
    $config['file_name']     = 'audio_' . time() . '_' . rand(1000, 9999);

    $this->load->library('upload', $config);

    if (!$this->upload->do_upload('audio')) {
        return $this->response([
            'success' => false,
            'message' => 'Erro no upload: ' . strip_tags($this->upload->display_errors()),
        ], 400);
    }

    $uploadData = $this->upload->data();
    $filePath   = $uploadData['full_path'];

    try {
        // 3. Enviar para OpenAI Whisper
        $result = $this->_call_whisper($filePath);

        // 4. Limpar arquivo temporário
        @unlink($filePath);

        if ($result === false) {
            return $this->response([
                'success' => false,
                'message' => 'Erro na transcrição. Tente novamente.',
            ], 500);
        }

        return $this->response([
            'success' => true,
            'data' => [
                'text'       => $result['text'] ?? '',
                'confidence' => $result['confidence'] ?? null,
                'language'   => $result['language'] ?? 'pt',
                'duration_ms'=> $result['duration_ms'] ?? null,
            ],
        ], 200);

    } catch (Exception $e) {
        // Limpar arquivo em caso de erro
        @unlink($filePath);

        log_message('error', 'Erro na transcrição: ' . $e->getMessage());

        return $this->response([
            'success' => false,
            'message' => 'Erro interno na transcrição: ' . $e->getMessage(),
        ], 500);
    }
}

/**
 * Chama a API OpenAI Whisper para transcrever o áudio.
 *
 * @param string $filePath Caminho completo do arquivo de áudio
 * @return array|false Retorna array com 'text', 'language', etc. ou false em caso de erro
 */
private function _call_whisper($filePath) {
    // Buscar chave da API (ajustar conforme sua configuração)
    // Opções comuns:
    //   $apiKey = $this->config->item('openai_api_key');
    //   $apiKey = getenv('OPENAI_API_KEY');
    //   $apiKey = $this->db->where('key', 'openai_api_key')->get('settings')->row()->value;
    $apiKey = $this->_get_openai_key(); // Ajustar para seu método

    if (empty($apiKey)) {
        log_message('error', 'Chave da API OpenAI não configurada');
        return false;
    }

    $url = 'https://api.openai.com/v1/audio/transcriptions';

    // Detectar mime type
    $mimeType = mime_content_type($filePath) ?: 'audio/wav';

    $postFields = [
        'file'            => new CURLFile($filePath, $mimeType, basename($filePath)),
        'model'           => 'whisper-1',
        'language'        => 'pt',
        'response_format' => 'verbose_json', // Retorna confidence e duração
    ];

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $url,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => $postFields,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 60,
        CURLOPT_HTTPHEADER     => [
            'Authorization: Bearer ' . $apiKey,
            // NÃO definir Content-Type — cURL define automaticamente para multipart
        ],
    ]);

    $response   = curl_exec($ch);
    $httpCode   = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError  = curl_error($ch);
    curl_close($ch);

    if ($curlError) {
        log_message('error', 'cURL error ao chamar Whisper: ' . $curlError);
        return false;
    }

    if ($httpCode !== 200) {
        log_message('error', 'Whisper retornou HTTP ' . $httpCode . ': ' . $response);
        return false;
    }

    $data = json_decode($response, true);

    if (empty($data) || !isset($data['text'])) {
        log_message('error', 'Resposta inválida do Whisper: ' . $response);
        return false;
    }

    // verbose_json retorna: text, task, language, duration, segments[]
    // Calcular confiança média dos segmentos (se disponível)
    $confidence = null;
    if (!empty($data['segments'])) {
        $avgLogProbs = array_map(function($seg) {
            return $seg['avg_logprob'] ?? -1;
        }, $data['segments']);

        // Converter log probability para 0-1 (aproximação)
        $avgLogProb = array_sum($avgLogProbs) / count($avgLogProbs);
        $confidence = max(0, min(1, exp($avgLogProb)));
    }

    $durationMs = isset($data['duration'])
        ? intval($data['duration'] * 1000)
        : null;

    return [
        'text'        => trim($data['text']),
        'language'    => $data['language'] ?? 'pt',
        'confidence'  => $confidence,
        'duration_ms' => $durationMs,
    ];
}

/**
 * Obtém a chave da API OpenAI.
 * AJUSTAR conforme a configuração do seu projeto.
 */
private function _get_openai_key() {
    // Opção 1: Variável de ambiente
    $key = getenv('OPENAI_API_KEY');
    if ($key) return $key;

    // Opção 2: Tabela de configurações
    $row = $this->db->where('key', 'openai_api_key')
                    ->get('ai_settings') // ajustar nome da tabela
                    ->row();
    if ($row) return $row->value;

    // Opção 3: Config file
    return $this->config->item('openai_api_key');
}
```

### 4. Rota

Verificar se a rota já existe em `application/config/routes.php`. Se não:

```php
$route['api/ai/transcribe']['POST'] = 'api/ai/transcribe';
```

Se o controller REST usa sufixo automático (`_post`, `_get`), a rota pode ser:
```php
$route['api/ai/transcribe'] = 'api/ai/transcribe';
```

### 5. Dependências PHP

Verificar se o servidor tem:
- `php-curl` instalado e habilitado
- `upload_max_filesize` >= 25M no `php.ini`
- `post_max_size` >= 30M no `php.ini`
- Pasta `uploads/audio/` com permissão de escrita

```bash
# No servidor, verificar:
php -m | grep curl
php -i | grep upload_max_filesize
php -i | grep post_max_size
ls -la /home/sxdata/painel.sxdata.com.br/uploads/
```

Se a pasta não existir:
```bash
mkdir -p /home/sxdata/painel.sxdata.com.br/uploads/audio/
chmod 755 /home/sxdata/painel.sxdata.com.br/uploads/audio/
chown www-data:www-data /home/sxdata/painel.sxdata.com.br/uploads/audio/
```

### 6. Response esperada pelo app

O app espera EXATAMENTE este formato JSON:

**Sucesso:**
```json
{
    "success": true,
    "data": {
        "text": "eu trabalho como pedreiro há mais de vinte anos",
        "confidence": 0.91,
        "language": "pt",
        "duration_ms": 4200
    }
}
```

**Erro:**
```json
{
    "success": false,
    "message": "Descrição do erro"
}
```

**NUNCA retornar HTML.** Se houver erro PHP, deve ser capturado pelo try/catch e retornado como JSON.

### 7. Checklist de debug

Se ainda não funcionar, verificar nesta ordem:

1. [ ] O método `transcribe_post()` existe no controller?
2. [ ] A rota está configurada?
3. [ ] `var_dump($_FILES)` mostra o arquivo `audio`?
4. [ ] A pasta `uploads/audio/` existe e tem permissão de escrita?
5. [ ] `allowed_types` inclui `wav`?
6. [ ] A chave da API OpenAI está configurada e é válida?
7. [ ] O servidor tem `php-curl`?
8. [ ] `upload_max_filesize` e `post_max_size` são >= 25M?
9. [ ] O Whisper retorna 200? (verificar log de erros)
10. [ ] O JSON de resposta segue o formato esperado pelo app?

### 8. Teste rápido

Após implementar, testar com curl:

```bash
# Gravar um áudio curto de teste (se tiver sox instalado):
# sox -n test.wav synth 3 sine 440

# Enviar para o endpoint:
curl -X POST https://painel.sxdata.com.br/api/ai/transcribe \
  -H "Authorization: Bearer SEU_TOKEN" \
  -F "audio=@test.wav" \
  -v

# Deve retornar JSON com success:true e o texto transcrito
```

### 9. IMPORTANTE

- **NUNCA retornar HTML** — todo erro deve ser capturado e retornado como `{"success": false, "message": "..."}`.
- **Usar `$resultado->campo`** (objeto) e NÃO `$resultado['campo']` (array) para dados do banco.
- **Limpar o arquivo** de áudio após transcrição — não acumular arquivos no servidor.
- O campo do upload se chama `audio` — o app envia com esse nome exato.
- O formato do áudio é `.wav` (16kHz, mono) — o Whisper aceita wav, mp3, m4a, webm, etc.
