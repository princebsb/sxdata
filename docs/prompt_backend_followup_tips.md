# PROMPT PARA O AGENTE DO PAINEL — Tips de Follow-up nas Perguntas

Você é o desenvolvedor backend do painel administrativo SXDATA (CodeIgniter 3 + PHP).
Implemente o campo de "tips" (dicas de follow-up) no cadastro/edição de perguntas e a integração com a tela "Sugestões de Follow-up" (ai/followup).

## CONTEXTO

O app móvel SXDATA exibe um botão `?` ao lado de cada pergunta do questionário. Ao tocar, ele abre um modal com dicas de follow-up para o entrevistador (ex: "Se o entrevistado mencionar trabalho informal, aprofunde sobre outras fontes de renda").

Essas dicas vêm de duas fontes:
1. **Cadastradas manualmente** pelo administrador na edição da pergunta
2. **Aprovadas** a partir das sugestões de IA geradas na tela `ai/followup`

O app busca as dicas via `GET /api/ai/followup-tips?questionnaire_id={id}`.

## 1. ALTERAÇÃO NO BANCO DE DADOS

### Opção A — Campo JSON na tabela de perguntas (mais simples)

```sql
ALTER TABLE questions ADD COLUMN followup_tips JSON DEFAULT NULL
    COMMENT 'Dicas de follow-up para o entrevistador. Array JSON de strings.';
```

Exemplo de valor armazenado:
```json
[
    "Pergunte sobre a renda complementar se mencionar trabalho informal",
    "Confirme se a ocupação informada é a principal ou secundária",
    "Se aposentado, pergunte há quanto tempo"
]
```

### Opção B — Tabela separada (se preferir normalizar)

```sql
CREATE TABLE question_followup_tips (
    id INT AUTO_INCREMENT PRIMARY KEY,
    question_id INT NOT NULL,
    tip TEXT NOT NULL,
    source ENUM('manual', 'ai_approved') NOT NULL DEFAULT 'manual'
        COMMENT 'manual = digitado pelo admin, ai_approved = veio da tela ai/followup',
    ai_suggestion_id INT DEFAULT NULL
        COMMENT 'ID da sugestão de IA original (se source=ai_approved)',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by INT DEFAULT NULL COMMENT 'ID do admin que criou/aprovou',

    INDEX idx_question (question_id),
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

**Recomendação:** Use a **Opção B** (tabela separada) pois permite rastrear origem (manual vs IA) e auditar quem aprovou.

## 2. EDIÇÃO DE PERGUNTAS — Formulário de Cadastro/Edição

### Onde adicionar

Na tela de edição de perguntas do questionário (provavelmente em `views/admin/questionnaires/edit_question.php` ou similar), adicionar uma seção **"Dicas de Follow-up"** abaixo dos campos existentes (texto da pergunta, tipo, opções, obrigatório, etc.).

### Layout do campo

```
+------------------------------------------------------------------+
|  Dicas de Follow-up para o Entrevistador                          |
|  (Exibidas no app quando o entrevistador toca no ícone ?)         |
+------------------------------------------------------------------+
|                                                                    |
|  1. [Pergunte sobre renda complementar se mencio...] [🗑️ Excluir] |
|  2. [Confirme se a ocupação informada é a princip...] [🗑️ Excluir] |
|  3. [Se aposentado, pergunte há quanto tempo       ] [🗑️ Excluir] |
|                                                                    |
|  [+ Adicionar dica]                                                |
|                                                                    |
+------------------------------------------------------------------+
```

### Código da view (seção a adicionar)

```php
<!-- Dicas de Follow-up -->
<div class="form-group">
    <label>
        <i class="fa fa-lightbulb-o"></i> Dicas de Follow-up para o Entrevistador
        <small class="text-muted">(exibidas no app ao tocar no ícone ?)</small>
    </label>

    <div id="followup-tips-container">
        <?php if (!empty($followup_tips)): ?>
            <?php foreach ($followup_tips as $i => $tip): ?>
            <div class="input-group" style="margin-bottom: 8px;" data-tip-id="<?= $tip->id ?? '' ?>">
                <span class="input-group-addon">
                    <?= $i + 1 ?>.
                    <?php if (!empty($tip->source) && $tip->source === 'ai_approved'): ?>
                        <i class="fa fa-robot text-info" title="Aprovado da IA"></i>
                    <?php endif; ?>
                </span>
                <input type="text" name="followup_tips[]" class="form-control"
                       value="<?= htmlspecialchars($tip->tip ?? (is_string($tip) ? $tip : '')) ?>"
                       placeholder="Ex: Se o entrevistado mencionar X, pergunte sobre Y...">
                <span class="input-group-btn">
                    <button type="button" class="btn btn-danger btn-remove-tip" title="Excluir">
                        <i class="fa fa-trash"></i>
                    </button>
                </span>
            </div>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>

    <button type="button" class="btn btn-sm btn-default" id="btn-add-tip"
            style="margin-top: 5px;">
        <i class="fa fa-plus"></i> Adicionar dica
    </button>
</div>

<script>
// Adicionar nova dica
document.getElementById('btn-add-tip').addEventListener('click', function() {
    var container = document.getElementById('followup-tips-container');
    var count = container.querySelectorAll('.input-group').length + 1;

    var div = document.createElement('div');
    div.className = 'input-group';
    div.style.marginBottom = '8px';
    div.innerHTML = '<span class="input-group-addon">' + count + '.</span>' +
        '<input type="text" name="followup_tips[]" class="form-control" ' +
        'placeholder="Ex: Se o entrevistado mencionar X, pergunte sobre Y...">' +
        '<span class="input-group-btn">' +
        '<button type="button" class="btn btn-danger btn-remove-tip" title="Excluir">' +
        '<i class="fa fa-trash"></i></button></span>';

    container.appendChild(div);
});

// Remover dica (delegação de eventos)
document.getElementById('followup-tips-container').addEventListener('click', function(e) {
    var btn = e.target.closest('.btn-remove-tip');
    if (btn) {
        btn.closest('.input-group').remove();
        // Renumerar
        var items = document.querySelectorAll('#followup-tips-container .input-group');
        items.forEach(function(item, i) {
            var addon = item.querySelector('.input-group-addon');
            // Preservar ícone de IA se houver
            var icon = addon.querySelector('i');
            addon.innerHTML = (i + 1) + '. ';
            if (icon) addon.appendChild(icon);
        });
    }
});
</script>
```

### Salvar no controller (ao submeter o formulário de edição)

```php
/**
 * Salva as dicas de follow-up de uma pergunta.
 * Chamado após salvar a pergunta principal.
 *
 * @param int $question_id
 * @param array $tips Array de strings vindos do form (followup_tips[])
 */
private function _save_followup_tips($question_id, $tips) {
    // Remover tips manuais existentes (preservar as de IA que foram deletadas explicitamente)
    $this->db->where('question_id', $question_id)
             ->where('source', 'manual')
             ->delete('question_followup_tips');

    if (empty($tips)) return;

    foreach ($tips as $tip_text) {
        $tip_text = trim($tip_text);
        if (empty($tip_text)) continue;

        // Verificar se já existe (pode ser uma tip de IA que não foi removida)
        $exists = $this->db->where('question_id', $question_id)
                           ->where('tip', $tip_text)
                           ->count_all_results('question_followup_tips');

        if ($exists > 0) continue;

        $this->db->insert('question_followup_tips', [
            'question_id' => $question_id,
            'tip'         => $tip_text,
            'source'      => 'manual',
            'created_by'  => $this->session->userdata('user_id'),
        ]);
    }
}

/**
 * Carregar tips ao abrir formulário de edição
 */
private function _get_followup_tips($question_id) {
    return $this->db->where('question_id', $question_id)
                    ->order_by('id', 'ASC')
                    ->get('question_followup_tips')
                    ->result();
}
```

No método de edição da pergunta, adicionar:
```php
// Ao carregar para edição:
$data['followup_tips'] = $this->_get_followup_tips($question_id);

// Ao salvar:
$tips = $this->input->post('followup_tips');
$this->_save_followup_tips($question_id, $tips ?: []);
```

## 3. TELA "SUGESTÕES DE FOLLOW-UP" (ai/followup) — Botão Aprovar

### O que existe hoje

A tela `ai/followup` já exibe sugestões de follow-up geradas pela IA. Cada sugestão tem:
- `question_id` — pergunta alvo
- `suggestion_text` — texto da sugestão
- Status (pendente, aprovado, rejeitado)

### O que precisa mudar

Quando o admin clicar em **"Aprovar"** numa sugestão:

1. Marcar a sugestão como aprovada (já existe)
2. **NOVO:** Inserir automaticamente o texto como tip na tabela `question_followup_tips`

### Código do botão Aprovar (atualizar no controller)

```php
/**
 * Aprova uma sugestão de follow-up da IA.
 * Marca como aprovada E insere como tip na pergunta.
 */
public function approve_followup($suggestion_id) {
    // 1. Buscar a sugestão
    $suggestion = $this->db->where('id', $suggestion_id)
                           ->get('ai_followup_suggestions') // ajustar nome da tabela
                           ->row();

    if (!$suggestion) {
        $this->session->set_flashdata('error', 'Sugestão não encontrada');
        redirect('ai/followup');
        return;
    }

    // 2. Marcar como aprovada
    $this->db->where('id', $suggestion_id)
             ->update('ai_followup_suggestions', [
                 'status'      => 'approved',
                 'approved_by' => $this->session->userdata('user_id'),
                 'approved_at' => date('Y-m-d H:i:s'),
             ]);

    // 3. NOVO: Inserir como tip na pergunta
    // Verificar duplicata
    $exists = $this->db->where('question_id', $suggestion->question_id)
                       ->where('tip', $suggestion->suggestion_text)
                       ->count_all_results('question_followup_tips');

    if ($exists == 0) {
        $this->db->insert('question_followup_tips', [
            'question_id'       => $suggestion->question_id,
            'tip'               => $suggestion->suggestion_text,
            'source'            => 'ai_approved',
            'ai_suggestion_id'  => $suggestion_id,
            'created_by'        => $this->session->userdata('user_id'),
        ]);
    }

    $this->session->set_flashdata('success', 'Sugestão aprovada e adicionada às dicas da pergunta');
    redirect('ai/followup');
}
```

### Na view ai/followup.php — Atualizar o botão de Aprovar

```php
<!-- Botão de Aprovar existente — trocar a URL -->
<a href="<?= base_url('ai/approve_followup/' . $suggestion->id) ?>"
   class="btn btn-sm btn-success"
   onclick="return confirm('Aprovar e adicionar como dica na pergunta?')">
    <i class="fa fa-check"></i> Aprovar
</a>
```

### Feedback visual após aprovação

Na tela `ai/followup`, sugestões já aprovadas devem mostrar um badge:

```php
<?php if ($suggestion->status === 'approved'): ?>
    <span class="label label-success">
        <i class="fa fa-check"></i> Aprovada — adicionada à pergunta
    </span>
<?php endif; ?>
```

## 4. ENDPOINT PARA O APP BUSCAR AS DICAS

### GET /api/ai/followup-tips?questionnaire_id={id}

O app chama este endpoint ao abrir um questionário para buscar todas as dicas.

### Controller (adicionar no Ai.php)

```php
/**
 * Retorna todas as dicas de follow-up para as perguntas de um questionário.
 * GET /api/ai/followup-tips?questionnaire_id={id}
 */
public function followup_tips_get() {
    $questionnaire_id = $this->get('questionnaire_id');

    if (empty($questionnaire_id)) {
        return $this->response([
            'success' => false,
            'message' => 'questionnaire_id é obrigatório'
        ], 400);
    }

    // Buscar question_ids do questionário
    $question_ids = $this->db->select('id')
                             ->where('questionnaire_id', $questionnaire_id)
                             ->get('questions')
                             ->result_array();

    $question_ids = array_column($question_ids, 'id');

    if (empty($question_ids)) {
        return $this->response([
            'success' => true,
            'data' => ['tips' => []]
        ], 200);
    }

    // Buscar todas as tips dessas perguntas
    $tips = $this->db->select('question_id, tip')
                     ->where_in('question_id', $question_ids)
                     ->order_by('question_id, id')
                     ->get('question_followup_tips')
                     ->result();

    return $this->response([
        'success' => true,
        'data' => ['tips' => $tips]
    ], 200);
}
```

### Response esperada

```json
{
    "success": true,
    "data": {
        "tips": [
            {
                "question_id": 5,
                "tip": "Pergunte sobre renda complementar se mencionar trabalho informal"
            },
            {
                "question_id": 5,
                "tip": "Confirme se a ocupação é a principal"
            },
            {
                "question_id": 8,
                "tip": "Se menor de idade, pergunte quem é o responsável"
            }
        ]
    }
}
```

## 5. ROTA

Adicionar no arquivo de rotas (`application/config/routes.php`):

```php
// Dicas de follow-up para o app
$route['api/ai/followup-tips']['GET'] = 'api/ai/followup_tips';

// Aprovação de sugestão de follow-up (painel)
$route['ai/approve_followup/(:num)'] = 'ai/approve_followup/$1';
```

## 6. RESUMO DO FLUXO COMPLETO

```
                        PAINEL ADMIN
                        ============

  [Edição da Pergunta]                [Tela ai/followup]
         |                                    |
         |  Admin digita dicas                |  IA gera sugestões
         |  manualmente                       |
         v                                    v
  +-------------------+              +-------------------+
  | followup_tips[]   |              | Botão "Aprovar"   |
  | source = manual   |              | source = ai_appr. |
  +-------------------+              +-------------------+
         \                                  /
          \                                /
           v                              v
      +------------------------------------+
      |   question_followup_tips           |
      |   (tabela no banco)                |
      +------------------------------------+
                      |
                      | GET /api/ai/followup-tips
                      |   ?questionnaire_id=5
                      v
              +----------------+
              |   APP MÓVEL    |
              |                |
              |  Botão ? abre  |
              |  modal com as  |
              |  dicas         |
              +----------------+
```

## 7. IMPORTANTE

- **Usar `$resultado->campo`** (objeto) e NÃO `$resultado['campo']` (array) — CodeIgniter retorna stdClass.
- A tabela `questions` pode ter nome diferente (ex: `questionnaire_questions`). Ajustar os nomes conforme o banco real.
- A tabela de sugestões de IA (`ai_followup_suggestions`) pode ter nome diferente. Verificar no banco existente.
- O campo `suggestion_text` na tabela de sugestões de IA pode se chamar diferente (ex: `text`, `content`). Ajustar.
- Ao rejeitar uma sugestão na tela ai/followup, NÃO inserir na tabela de tips.
- Ao excluir uma tip que veio de IA aprovada, considerar se deve voltar o status da sugestão original para "pendente" (opcional).
