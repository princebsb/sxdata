# PROMPT PARA O AGENTE DO PAINEL — Tela "Transcrições de Áudio"

Você é o desenvolvedor backend do painel administrativo SXDATA (CodeIgniter 3 + PHP).
Implemente a tela de Transcrições de Áudio no módulo de IA.

## CONTEXTO

O app móvel SXDATA agora grava áudio das respostas dos entrevistadores, transcreve via IA e salva os registros localmente. Na sincronização, o app envia as transcrições para o backend via `POST /api/ai/transcriptions/sync`. O painel precisa receber, armazenar e exibir essas transcrições na tela `ai/transcriptions`.

## 1. ENDPOINT DE RECEBIMENTO

### POST /api/ai/transcriptions/sync
Recebe batch de transcrições do app.

**Request body:**
```json
{
  "transcriptions": [
    {
      "id": "uuid-gerado-no-app",
      "questionnaire_id": 5,
      "question_id": 12,
      "question_text": "Qual a sua ocupação principal?",
      "transcribed_text": "eu trabalho como pedreiro há mais de vinte anos",
      "edited_text": "Eu trabalho como pedreiro há mais de 20 anos",
      "confidence": 0.91,
      "language": "pt-BR",
      "duration_ms": 4200,
      "recording_duration_secs": 5,
      "applicator_name": "João Silva",
      "applicator_id": 3,
      "timestamp": "2026-03-27T14:30:00.000Z",
      "sync_status": "pending"
    }
  ]
}
```

**Campos:**
| Campo | Tipo | Descrição |
|---|---|---|
| id | string (UUID) | ID único gerado no app — usar para deduplicação |
| questionnaire_id | int | ID do questionário |
| question_id | int | ID da pergunta |
| question_text | string | Texto da pergunta (para contexto) |
| transcribed_text | string | Texto original retornado pela IA |
| edited_text | string/null | Texto editado pelo entrevistador antes de confirmar. NULL se não editou |
| confidence | float/null | Confiança da transcrição (0 a 1). NULL se indisponível |
| language | string/null | Idioma detectado (ex: "pt-BR") |
| duration_ms | int/null | Duração do áudio em milissegundos |
| recording_duration_secs | int | Duração da gravação em segundos |
| applicator_name | string/null | Nome do entrevistador |
| applicator_id | int/null | ID do usuário entrevistador |
| timestamp | string (ISO8601) | Momento da transcrição |
| sync_status | string | Sempre "pending" quando chega do app |

**Response (sucesso):**
```json
{
  "success": true,
  "message": "X transcrições recebidas com sucesso",
  "data": {
    "received": 3,
    "duplicates_skipped": 0
  }
}
```

**Lógica:**
- Usar o campo `id` (UUID) como chave única para evitar duplicatas (INSERT IGNORE ou check antes)
- Se o `id` já existir no banco, pular silenciosamente (não é erro)
- Retornar sempre `success: true` com a contagem

## 2. TABELA NO BANCO

```sql
CREATE TABLE ai_transcriptions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    app_id VARCHAR(36) NOT NULL UNIQUE COMMENT 'UUID gerado no app para deduplicação',
    questionnaire_id INT NOT NULL,
    question_id INT NOT NULL,
    question_text TEXT,
    transcribed_text TEXT NOT NULL,
    edited_text TEXT DEFAULT NULL,
    was_edited TINYINT(1) GENERATED ALWAYS AS (edited_text IS NOT NULL) STORED,
    confidence DECIMAL(4,3) DEFAULT NULL,
    language VARCHAR(10) DEFAULT NULL,
    duration_ms INT DEFAULT NULL,
    recording_duration_secs INT DEFAULT 0,
    applicator_name VARCHAR(255) DEFAULT NULL,
    applicator_id INT DEFAULT NULL,
    timestamp_app DATETIME NOT NULL COMMENT 'Momento da transcrição no app',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_questionnaire (questionnaire_id),
    INDEX idx_applicator (applicator_id),
    INDEX idx_timestamp (timestamp_app),
    INDEX idx_confidence (confidence),
    UNIQUE KEY uk_app_id (app_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## 3. CONTROLLER — Ai.php

Adicionar método no controller `Ai.php`:

```php
/**
 * Recebe transcrições sincronizadas do app
 * POST /api/ai/transcriptions/sync
 */
public function transcriptions_sync_post() {
    $data = json_decode(file_get_contents('php://input'), true);

    if (empty($data['transcriptions']) || !is_array($data['transcriptions'])) {
        return $this->response([
            'success' => false,
            'message' => 'Nenhuma transcrição enviada'
        ], 400);
    }

    $received = 0;
    $duplicates = 0;

    foreach ($data['transcriptions'] as $t) {
        // Verificar duplicata pelo app_id (UUID)
        $exists = $this->db->where('app_id', $t['id'])->count_all_results('ai_transcriptions');

        if ($exists > 0) {
            $duplicates++;
            continue;
        }

        $insert = [
            'app_id'                 => $t['id'],
            'questionnaire_id'       => intval($t['questionnaire_id']),
            'question_id'            => intval($t['question_id']),
            'question_text'          => $t['question_text'] ?? '',
            'transcribed_text'       => $t['transcribed_text'] ?? '',
            'edited_text'            => $t['edited_text'] ?? null,
            'confidence'             => isset($t['confidence']) ? floatval($t['confidence']) : null,
            'language'               => $t['language'] ?? null,
            'duration_ms'            => isset($t['duration_ms']) ? intval($t['duration_ms']) : null,
            'recording_duration_secs'=> intval($t['recording_duration_secs'] ?? 0),
            'applicator_name'        => $t['applicator_name'] ?? null,
            'applicator_id'          => isset($t['applicator_id']) ? intval($t['applicator_id']) : null,
            'timestamp_app'          => date('Y-m-d H:i:s', strtotime($t['timestamp'])),
        ];

        $this->db->insert('ai_transcriptions', $insert);
        $received++;
    }

    return $this->response([
        'success' => true,
        'message' => "$received transcrições recebidas com sucesso",
        'data' => [
            'received' => $received,
            'duplicates_skipped' => $duplicates,
        ]
    ], 200);
}

/**
 * Lista transcrições para a tela do painel
 * GET /api/ai/transcriptions
 */
public function transcriptions_get() {
    $questionnaire_id = $this->get('questionnaire_id');
    $applicator_id    = $this->get('applicator_id');
    $date_from        = $this->get('date_from');
    $date_to          = $this->get('date_to');
    $search           = $this->get('search');
    $page             = intval($this->get('page') ?: 1);
    $per_page         = intval($this->get('per_page') ?: 20);
    $offset           = ($page - 1) * $per_page;

    $this->db->select('t.*, q.title as questionnaire_title')
             ->from('ai_transcriptions t')
             ->join('questionnaires q', 'q.id = t.questionnaire_id', 'left');

    if ($questionnaire_id) {
        $this->db->where('t.questionnaire_id', $questionnaire_id);
    }
    if ($applicator_id) {
        $this->db->where('t.applicator_id', $applicator_id);
    }
    if ($date_from) {
        $this->db->where('t.timestamp_app >=', $date_from);
    }
    if ($date_to) {
        $this->db->where('t.timestamp_app <=', $date_to . ' 23:59:59');
    }
    if ($search) {
        $this->db->group_start()
                 ->like('t.transcribed_text', $search)
                 ->or_like('t.edited_text', $search)
                 ->or_like('t.question_text', $search)
                 ->or_like('t.applicator_name', $search)
                 ->group_end();
    }

    // Total para paginação
    $total = $this->db->count_all_results('', false);

    $this->db->order_by('t.timestamp_app', 'DESC')
             ->limit($per_page, $offset);

    $transcriptions = $this->db->get()->result();

    // Estatísticas rápidas
    $stats = $this->db->select('
        COUNT(*) as total,
        AVG(confidence) as avg_confidence,
        SUM(CASE WHEN was_edited = 1 THEN 1 ELSE 0 END) as edited_count,
        SUM(recording_duration_secs) as total_seconds
    ')->from('ai_transcriptions')->get()->row();

    return $this->response([
        'success' => true,
        'data' => [
            'transcriptions' => $transcriptions,
            'pagination' => [
                'page' => $page,
                'per_page' => $per_page,
                'total' => $total,
                'total_pages' => ceil($total / $per_page),
            ],
            'stats' => $stats,
        ]
    ], 200);
}
```

## 4. VIEW — ai/transcriptions.php

Criar a view em `application/views/admin/ai/transcriptions.php`:

### Layout da tela:

```
+------------------------------------------------------------------+
|  Transcrições de Áudio                            [Filtros ▼]     |
+------------------------------------------------------------------+
|  Cards de estatísticas:                                           |
|  [Total: 847] [Confiança Média: 89%] [Editadas: 23%] [12h áudio]|
+------------------------------------------------------------------+
|  Filtros (colapsável):                                           |
|  Questionário: [dropdown]  Aplicador: [dropdown]                  |
|  Período: [data inicio] a [data fim]   Buscar: [___________]     |
+------------------------------------------------------------------+
|  Tabela de transcrições:                                          |
|  +-------+-------------+----------+-----------+-------+--------+ |
|  | Data  | Pergunta    | Original | Editado   | Conf. | Aplic. | |
|  +-------+-------------+----------+-----------+-------+--------+ |
|  | 27/03 | Qual a sua  | eu traba | Eu trabal | 91%   | João   | |
|  |       | ocupação..  | lho como | ho como   | ✅    | Silva  | |
|  |       |             | pedreiro | pedreiro  |       |        | |
|  |       |             | há mais..| há mais.. |       |        | |
|  +-------+-------------+----------+-----------+-------+--------+ |
|  Paginação: [< 1 2 3 ... 42 >]                                  |
+------------------------------------------------------------------+
```

### Detalhes visuais:

1. **Cards de estatísticas no topo:**
   - Total de transcrições
   - Confiança média (com barra de progresso)
   - % de transcrições que foram editadas pelo entrevistador
   - Tempo total de áudio gravado (formatado em horas:minutos)

2. **Tabela com colunas:**
   - Data/hora (formatada dd/mm/yyyy HH:mm)
   - Questionário (título)
   - Pergunta (texto, truncado com tooltip)
   - Texto original (transcrito pela IA)
   - Texto editado (se houver, em cor diferente com ícone de edição; se não, mostrar "-")
   - Confiança (badge colorido: verde >=85%, amarelo >=70%, vermelho <70%)
   - Aplicador (nome)
   - Duração (ex: "5s")

3. **Indicador de edição:**
   - Se `edited_text` é diferente de `transcribed_text`: mostrar badge "Editado" em laranja
   - Se não foi editado: nenhum badge

4. **Filtros:**
   - Dropdown de questionários (populado do banco)
   - Dropdown de aplicadores (populado do banco)
   - Date range picker
   - Campo de busca full-text (busca em transcribed_text, edited_text, question_text, applicator_name)

5. **Modal de detalhes (ao clicar numa linha):**
   - Texto original completo
   - Texto editado completo (se houver)
   - Diff visual entre original e editado (highlight das diferenças)
   - Informações completas: questionário, pergunta, aplicador, confiança, idioma, duração

### Exemplo de código da view (estrutura):

```php
<div class="content-header">
    <h1><i class="fa fa-microphone"></i> Transcrições de Áudio</h1>
</div>

<!-- Stats Cards -->
<div class="row">
    <div class="col-md-3">
        <div class="small-box bg-info">
            <div class="inner">
                <h3><?= $stats->total ?? 0 ?></h3>
                <p>Total de Transcrições</p>
            </div>
            <div class="icon"><i class="fa fa-file-audio-o"></i></div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="small-box bg-success">
            <div class="inner">
                <h3><?= number_format(($stats->avg_confidence ?? 0) * 100, 0) ?>%</h3>
                <p>Confiança Média</p>
            </div>
            <div class="icon"><i class="fa fa-check-circle"></i></div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="small-box bg-warning">
            <div class="inner">
                <?php
                $editedPct = ($stats->total > 0)
                    ? round(($stats->edited_count / $stats->total) * 100)
                    : 0;
                ?>
                <h3><?= $editedPct ?>%</h3>
                <p>Editadas pelo Entrevistador</p>
            </div>
            <div class="icon"><i class="fa fa-pencil"></i></div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="small-box bg-primary">
            <div class="inner">
                <?php
                $totalSecs = $stats->total_seconds ?? 0;
                $hours = floor($totalSecs / 3600);
                $mins = floor(($totalSecs % 3600) / 60);
                ?>
                <h3><?= $hours ?>h <?= $mins ?>m</h3>
                <p>Tempo Total de Áudio</p>
            </div>
            <div class="icon"><i class="fa fa-clock-o"></i></div>
        </div>
    </div>
</div>

<!-- Filters -->
<div class="box box-default collapsed-box">
    <div class="box-header with-border">
        <h3 class="box-title">Filtros</h3>
        <div class="box-tools pull-right">
            <button type="button" class="btn btn-box-tool" data-widget="collapse">
                <i class="fa fa-plus"></i>
            </button>
        </div>
    </div>
    <div class="box-body">
        <form method="get" action="<?= base_url('ai/transcriptions') ?>">
            <div class="row">
                <div class="col-md-3">
                    <select name="questionnaire_id" class="form-control select2">
                        <option value="">Todos os Questionários</option>
                        <?php foreach ($questionnaires as $q): ?>
                        <option value="<?= $q->id ?>" <?= ($q->id == $filter_questionnaire_id) ? 'selected' : '' ?>>
                            <?= htmlspecialchars($q->title) ?>
                        </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-3">
                    <select name="applicator_id" class="form-control select2">
                        <option value="">Todos os Aplicadores</option>
                        <?php foreach ($applicators as $a): ?>
                        <option value="<?= $a->id ?>" <?= ($a->id == $filter_applicator_id) ? 'selected' : '' ?>>
                            <?= htmlspecialchars($a->applicator_name) ?>
                        </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-2">
                    <input type="date" name="date_from" class="form-control"
                           value="<?= $filter_date_from ?>" placeholder="Data início">
                </div>
                <div class="col-md-2">
                    <input type="date" name="date_to" class="form-control"
                           value="<?= $filter_date_to ?>" placeholder="Data fim">
                </div>
                <div class="col-md-2">
                    <button type="submit" class="btn btn-primary btn-block">
                        <i class="fa fa-search"></i> Filtrar
                    </button>
                </div>
            </div>
            <div class="row" style="margin-top: 10px;">
                <div class="col-md-6">
                    <input type="text" name="search" class="form-control"
                           value="<?= htmlspecialchars($filter_search ?? '') ?>"
                           placeholder="Buscar no texto da transcrição...">
                </div>
            </div>
        </form>
    </div>
</div>

<!-- Transcriptions Table -->
<div class="box">
    <div class="box-body table-responsive no-padding">
        <table class="table table-hover table-striped">
            <thead>
                <tr>
                    <th>Data/Hora</th>
                    <th>Questionário</th>
                    <th>Pergunta</th>
                    <th>Texto Transcrito (IA)</th>
                    <th>Texto Editado</th>
                    <th>Confiança</th>
                    <th>Aplicador</th>
                    <th>Duração</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($transcriptions as $t): ?>
                <tr style="cursor:pointer" onclick="showDetail(<?= $t->id ?>)"
                    data-transcription='<?= htmlspecialchars(json_encode($t), ENT_QUOTES) ?>'>
                    <td>
                        <?= date('d/m/Y H:i', strtotime($t->timestamp_app)) ?>
                    </td>
                    <td>
                        <span title="<?= htmlspecialchars($t->questionnaire_title ?? '') ?>">
                            <?= mb_strimwidth($t->questionnaire_title ?? 'N/A', 0, 30, '...') ?>
                        </span>
                    </td>
                    <td>
                        <span title="<?= htmlspecialchars($t->question_text) ?>">
                            <?= mb_strimwidth(htmlspecialchars($t->question_text), 0, 40, '...') ?>
                        </span>
                    </td>
                    <td>
                        <span title="<?= htmlspecialchars($t->transcribed_text) ?>">
                            <?= mb_strimwidth(htmlspecialchars($t->transcribed_text), 0, 50, '...') ?>
                        </span>
                    </td>
                    <td>
                        <?php if ($t->edited_text && $t->edited_text !== $t->transcribed_text): ?>
                            <span class="label label-warning">Editado</span>
                            <span title="<?= htmlspecialchars($t->edited_text) ?>">
                                <?= mb_strimwidth(htmlspecialchars($t->edited_text), 0, 40, '...') ?>
                            </span>
                        <?php else: ?>
                            <span class="text-muted">-</span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <?php if ($t->confidence !== null): ?>
                            <?php
                            $pct = round($t->confidence * 100);
                            $color = $pct >= 85 ? 'success' : ($pct >= 70 ? 'warning' : 'danger');
                            ?>
                            <span class="label label-<?= $color ?>"><?= $pct ?>%</span>
                        <?php else: ?>
                            <span class="text-muted">N/A</span>
                        <?php endif; ?>
                    </td>
                    <td><?= htmlspecialchars($t->applicator_name ?? 'N/A') ?></td>
                    <td><?= $t->recording_duration_secs ?>s</td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <div class="box-footer clearfix">
        <!-- Paginação -->
        <?php if ($pagination['total_pages'] > 1): ?>
        <ul class="pagination pagination-sm no-margin pull-right">
            <?php for ($p = 1; $p <= $pagination['total_pages']; $p++): ?>
            <li class="<?= ($p == $pagination['page']) ? 'active' : '' ?>">
                <a href="?page=<?= $p ?>&<?= http_build_query(array_filter([
                    'questionnaire_id' => $filter_questionnaire_id,
                    'applicator_id' => $filter_applicator_id,
                    'date_from' => $filter_date_from,
                    'date_to' => $filter_date_to,
                    'search' => $filter_search,
                ])) ?>"><?= $p ?></a>
            </li>
            <?php endfor; ?>
        </ul>
        <?php endif; ?>
    </div>
</div>

<!-- Modal de Detalhes -->
<div class="modal fade" id="transcriptionDetailModal" tabindex="-1">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal">&times;</button>
                <h4 class="modal-title">
                    <i class="fa fa-microphone"></i> Detalhe da Transcrição
                </h4>
            </div>
            <div class="modal-body" id="transcriptionDetailBody">
                <!-- Preenchido via JS -->
            </div>
        </div>
    </div>
</div>

<script>
function showDetail(id) {
    var row = event.currentTarget;
    var t = JSON.parse(row.getAttribute('data-transcription'));

    var html = '<div class="row">';
    html += '<div class="col-md-6">';
    html += '<h4>Informações</h4>';
    html += '<table class="table table-condensed">';
    html += '<tr><th>Questionário</th><td>' + (t.questionnaire_title || 'N/A') + '</td></tr>';
    html += '<tr><th>Pergunta</th><td>' + (t.question_text || '') + '</td></tr>';
    html += '<tr><th>Aplicador</th><td>' + (t.applicator_name || 'N/A') + '</td></tr>';
    html += '<tr><th>Data/Hora</th><td>' + t.timestamp_app + '</td></tr>';
    html += '<tr><th>Confiança</th><td>' + (t.confidence ? (t.confidence * 100).toFixed(0) + '%' : 'N/A') + '</td></tr>';
    html += '<tr><th>Idioma</th><td>' + (t.language || 'N/A') + '</td></tr>';
    html += '<tr><th>Duração</th><td>' + t.recording_duration_secs + 's</td></tr>';
    html += '</table>';
    html += '</div>';

    html += '<div class="col-md-6">';
    html += '<h4>Texto Original (IA)</h4>';
    html += '<div class="well well-sm" style="white-space:pre-wrap">' + escapeHtml(t.transcribed_text) + '</div>';

    if (t.edited_text && t.edited_text !== t.transcribed_text) {
        html += '<h4>Texto Editado <span class="label label-warning">Modificado</span></h4>';
        html += '<div class="well well-sm" style="white-space:pre-wrap;border-color:#f0ad4e">' + escapeHtml(t.edited_text) + '</div>';
    }
    html += '</div></div>';

    document.getElementById('transcriptionDetailBody').innerHTML = html;
    $('#transcriptionDetailModal').modal('show');
}

function escapeHtml(text) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(text || ''));
    return div.innerHTML;
}
</script>
```

## 5. ROTA

Adicionar no arquivo de rotas (application/config/routes.php):

```php
// Transcrições de áudio
$route['ai/transcriptions'] = 'ai/transcriptions';
$route['api/ai/transcriptions/sync']['POST'] = 'api/ai/transcriptions_sync';
$route['api/ai/transcriptions']['GET'] = 'api/ai/transcriptions';
```

## 6. MENU LATERAL

Adicionar link no menu lateral do painel (provavelmente em `views/admin/sidebar.php` ou similar):

```html
<li>
    <a href="<?= base_url('ai/transcriptions') ?>">
        <i class="fa fa-microphone"></i>
        <span>Transcrições de Áudio</span>
    </a>
</li>
```

## 7. MÉTODO NO CONTROLLER PARA A VIEW

```php
/**
 * Tela de transcrições de áudio
 * GET /ai/transcriptions
 */
public function transcriptions() {
    // Filtros
    $filter_questionnaire_id = $this->input->get('questionnaire_id');
    $filter_applicator_id    = $this->input->get('applicator_id');
    $filter_date_from        = $this->input->get('date_from');
    $filter_date_to          = $this->input->get('date_to');
    $filter_search           = $this->input->get('search');
    $page                    = intval($this->input->get('page') ?: 1);
    $per_page                = 20;
    $offset                  = ($page - 1) * $per_page;

    // Query base
    $this->db->select('t.*, q.title as questionnaire_title')
             ->from('ai_transcriptions t')
             ->join('questionnaires q', 'q.id = t.questionnaire_id', 'left');

    if ($filter_questionnaire_id) {
        $this->db->where('t.questionnaire_id', $filter_questionnaire_id);
    }
    if ($filter_applicator_id) {
        $this->db->where('t.applicator_id', $filter_applicator_id);
    }
    if ($filter_date_from) {
        $this->db->where('t.timestamp_app >=', $filter_date_from);
    }
    if ($filter_date_to) {
        $this->db->where('t.timestamp_app <=', $filter_date_to . ' 23:59:59');
    }
    if ($filter_search) {
        $this->db->group_start()
                 ->like('t.transcribed_text', $filter_search)
                 ->or_like('t.edited_text', $filter_search)
                 ->or_like('t.question_text', $filter_search)
                 ->or_like('t.applicator_name', $filter_search)
                 ->group_end();
    }

    $total = $this->db->count_all_results('', false);

    $this->db->order_by('t.timestamp_app', 'DESC')
             ->limit($per_page, $offset);

    $transcriptions = $this->db->get()->result();

    // Stats gerais
    $stats = $this->db->select('
        COUNT(*) as total,
        AVG(confidence) as avg_confidence,
        SUM(CASE WHEN edited_text IS NOT NULL AND edited_text != transcribed_text THEN 1 ELSE 0 END) as edited_count,
        SUM(recording_duration_secs) as total_seconds
    ')->from('ai_transcriptions')->get()->row();

    // Dropdowns para filtros
    $questionnaires = $this->db->select('id, title')
                               ->from('questionnaires')
                               ->order_by('title')
                               ->get()->result();

    $applicators = $this->db->select('DISTINCT applicator_id as id, applicator_name')
                            ->from('ai_transcriptions')
                            ->where('applicator_id IS NOT NULL')
                            ->order_by('applicator_name')
                            ->get()->result();

    $data = [
        'transcriptions'           => $transcriptions,
        'stats'                    => $stats,
        'questionnaires'           => $questionnaires,
        'applicators'              => $applicators,
        'pagination'               => [
            'page'        => $page,
            'per_page'    => $per_page,
            'total'       => $total,
            'total_pages' => ceil($total / max($per_page, 1)),
        ],
        'filter_questionnaire_id'  => $filter_questionnaire_id,
        'filter_applicator_id'     => $filter_applicator_id,
        'filter_date_from'         => $filter_date_from,
        'filter_date_to'           => $filter_date_to,
        'filter_search'            => $filter_search,
    ];

    $this->load->view('admin/ai/transcriptions', $data);
}
```

## 8. IMPORTANTE

- **NÃO usar `$resultado['campo']`** para acessar dados do banco — CodeIgniter retorna objetos `stdClass`. Usar `$resultado->campo`.
- A tabela `questionnaires` pode ter nome diferente no seu banco — ajuste conforme necessário.
- O campo `was_edited` é um campo computado (GENERATED COLUMN) que facilita queries. Se o MySQL for antigo, substitua por um campo normal e calcule no INSERT.
- Transcrições são dados sensíveis — garantir que apenas admins autenticados acessem a tela.
