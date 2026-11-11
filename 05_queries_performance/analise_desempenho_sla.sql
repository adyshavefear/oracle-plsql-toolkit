--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 05_queries_performance/analise_desempenho_sla.sql
-- DESCRICAO : Consultas com Window Functions para analise de SLA e volumetria
--------------------------------------------------------------------------------

-- =============================================================================
-- 1. RANKING E VOLUMETRIA POR CATEGORIA COM PARTITION BY E DENSE_RANK
-- =============================================================================
SELECT cat.codigo,
       cat.descricao AS categoria,
       COUNT(p.id_protocolo) AS total_protocolos,
       ROUND(AVG(p.data_conclusao - p.data_abertura), 1) AS media_dias_resolucao,
       DENSE_RANK() OVER (ORDER BY COUNT(p.id_protocolo) DESC) AS rank_volume_demandas,
       ROUND(
           COUNT(p.id_protocolo) * 100.0 / SUM(COUNT(p.id_protocolo)) OVER (), 
           2
       ) AS percentual_do_total
  FROM tb_categoria_demanda cat
  LEFT JOIN tb_protocolo_atendimento p ON p.id_categoria = cat.id_categoria
 GROUP BY cat.codigo, cat.descricao
 ORDER BY total_protocolos DESC;

-- =============================================================================
-- 2. IDENTIFICACAO DO ULTIMO DESPACHO POR PROTOCOLO USANDO ROW_NUMBER()
-- =============================================================================
WITH ultimos_andamentos AS (
    SELECT a.id_protocolo,
           a.data_registro,
           a.usuario_registro,
           a.status_novo,
           a.despacho_texto,
           ROW_NUMBER() OVER (
               PARTITION BY a.id_protocolo 
               ORDER BY a.data_registro DESC, a.id_andamento DESC
           ) AS rn
      FROM tb_andamento_processual a
)
SELECT p.numero_protocolo,
       p.status AS status_protocolo,
       u.usuario_registro AS ultimo_atendente,
       u.data_registro    AS data_ultimo_despacho,
       u.status_novo      AS status_registrado
  FROM tb_protocolo_atendimento p
  JOIN ultimos_andamentos u ON u.id_protocolo = p.id_protocolo AND u.rn = 1
 WHERE p.status NOT IN ('CONCLUIDO', 'CANCELADO');
