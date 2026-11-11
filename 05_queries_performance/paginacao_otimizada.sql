--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 05_queries_performance/paginacao_otimizada.sql
-- DESCRICAO : Padroes de paginacao de alta performance para Oracle APEX Interactive Grids
--------------------------------------------------------------------------------

-- =============================================================================
-- PADRAO 1: ORACLE 12c+ OFFSET / FETCH NEXT (Padrao ANSI & Performatico)
-- =============================================================================
-- Variaveis de bind :p_pagina_num (ex: 1) e :p_itens_por_pagina (ex: 25)
SELECT p.id_protocolo,
       p.numero_protocolo,
       c.nome_completo AS cidadao,
       cat.descricao   AS categoria,
       p.status,
       p.prioridade,
       p.data_abertura,
       p.data_limite_sla
  FROM tb_protocolo_atendimento p
  JOIN tb_cidadao c ON c.id_cidadao = p.id_cidadao
  JOIN tb_categoria_demanda cat ON cat.id_categoria = p.id_categoria
 WHERE (:p_status IS NULL OR p.status = :p_status)
 ORDER BY p.data_abertura DESC, p.id_protocolo DESC
OFFSET NVL(:p_offset, 0) ROWS 
 FETCH NEXT NVL(:p_limit, 20) ROWS ONLY;

-- =============================================================================
-- PADRAO 2: ROWNUM ANINHADO (Compatibilidade Legada Oracle 11g)
-- =============================================================================
SELECT *
  FROM (
      SELECT a.*, ROWNUM rnum
        FROM (
            SELECT p.id_protocolo,
                   p.numero_protocolo,
                   p.status,
                   p.data_abertura
              FROM tb_protocolo_atendimento p
             ORDER BY p.data_abertura DESC
        ) a
       WHERE ROWNUM <= 50 -- Limite superior (:p_fim)
  )
 WHERE rnum > 25;        -- Limite inferior (:p_inicio)
