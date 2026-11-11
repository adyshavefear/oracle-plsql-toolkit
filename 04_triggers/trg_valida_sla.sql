--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 04_triggers/trg_valida_sla.sql
-- DESCRICAO : Trigger BEFORE para consistencia e regras de integridade de datas
--------------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_valida_sla
BEFORE INSERT OR UPDATE ON tb_protocolo_atendimento
FOR EACH ROW
BEGIN
    -- 1. Garante que data_limite_sla seja sempre posterior a data de abertura
    IF :NEW.data_limite_sla < :NEW.data_abertura THEN
        RAISE_APPLICATION_ERROR(
            -20005, 
            'Regra violada: A data limite de SLA nao pode ser anterior a data de abertura.'
        );
    END IF;

    -- 2. Se status for CONCLUIDO, preenche automaticamente data_conclusao se estiver nula
    IF :NEW.status = 'CONCLUIDO' AND :NEW.data_conclusao IS NULL THEN
        :NEW.data_conclusao := SYSDATE;
    END IF;

    -- 3. Impede alteracao de numero de protocolo apos a geracao
    IF UPDATING AND :OLD.numero_protocolo NOT LIKE 'PROV_%' AND :NEW.numero_protocolo <> :OLD.numero_protocolo THEN
        RAISE_APPLICATION_ERROR(
            -20006, 
            'Regra violada: O numero do protocolo e imutavel apos sua confirmacao.'
        );
    END IF;
END trg_valida_sla;
/
