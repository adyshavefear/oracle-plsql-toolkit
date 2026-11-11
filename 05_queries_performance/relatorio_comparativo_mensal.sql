--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 05_queries_performance/relatorio_comparativo_mensal.sql
-- DESCRICAO : Consulta comparativa mes a mes com LAG() e calculo de variacao %
--------------------------------------------------------------------------------

WITH metricas_mensais AS (
    SELECT TO_CHAR(data_abertura, 'YYYY-MM') AS ano_mes,
           COUNT(id_protocolo)               AS total_abertos,
           SUM(CASE WHEN status = 'CONCLUIDO' THEN 1 ELSE 0 END) AS total_concluidos
      FROM tb_protocolo_atendimento
     GROUP BY TO_CHAR(data_abertura, 'YYYY-MM')
)
SELECT ano_mes,
       total_abertos,
       LAG(total_abertos, 1, 0) OVER (ORDER BY ano_mes) AS mes_anterior_abertos,
       ROUND(
           CASE 
               WHEN LAG(total_abertos, 1, 0) OVER (ORDER BY ano_mes) = 0 THEN 0
               ELSE (
                   (total_abertos - LAG(total_abertos, 1, 0) OVER (ORDER BY ano_mes)) 
                   * 100.0 / LAG(total_abertos, 1, 0) OVER (ORDER BY ano_mes)
               )
           END, 
           1
       ) AS variacao_percentual,
       total_concluidos
  FROM metricas_mensais
 ORDER BY ano_mes DESC;
