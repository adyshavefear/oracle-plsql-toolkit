--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 01_schema_ddl/02_create_indexes.sql
-- DESCRICAO : Criacao de indices B-Tree e baseados em funcao para otimizacao
--------------------------------------------------------------------------------

-- Indices B-Tree para Foreign Keys (Evita table lock e acelera JOINs)
CREATE INDEX idx_prot_cidadao ON tb_protocolo_atendimento (id_cidadao);
CREATE INDEX idx_prot_categoria ON tb_protocolo_atendimento (id_categoria);
CREATE INDEX idx_andam_protocolo ON tb_andamento_processual (id_protocolo);

-- Indice Composto para consultas de relatorios e filtros comuns no Oracle APEX
CREATE INDEX idx_prot_status_data ON tb_protocolo_atendimento (status, data_abertura);

-- Indice para ordenacao e monitoramento de SLA vencido
CREATE INDEX idx_prot_sla_limite ON tb_protocolo_atendimento (data_limite_sla, status);

-- Indice baseado em funcao (Function-Based Index) para buscas case-insensitive
CREATE INDEX idx_cidadao_email_upper ON tb_cidadao (UPPER(email));
CREATE INDEX idx_cidadao_nome_upper ON tb_cidadao (UPPER(nome_completo));

-- Indice de auditoria para analise cronologica
CREATE INDEX idx_audit_tabela_data ON tb_log_auditoria (nome_tabela, data_evento);
