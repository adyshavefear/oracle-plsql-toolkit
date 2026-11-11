--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 04_triggers/trg_auditoria_protocolo.sql
-- DESCRICAO : Trigger de auditoria que grava o historico em formato JSON
--------------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER trg_audit_protocolo
AFTER INSERT OR UPDATE OR DELETE ON tb_protocolo_atendimento
FOR EACH ROW
DECLARE
    v_operacao       VARCHAR2(10);
    v_id_reg         NUMBER;
    v_payload_antigo CLOB;
    v_payload_novo   CLOB;
BEGIN
    IF INSERTING THEN
        v_operacao := 'INSERT';
        v_id_reg   := :NEW.id_protocolo;
        v_payload_novo := '{"status":"' || :NEW.status || 
                          '","prioridade":"' || :NEW.prioridade || 
                          '","numero":"' || :NEW.numero_protocolo || '"}';

    ELSIF UPDATING THEN
        v_operacao := 'UPDATE';
        v_id_reg   := :NEW.id_protocolo;
        v_payload_antigo := '{"status":"' || :OLD.status || 
                            '","prioridade":"' || :OLD.prioridade || '"}';
        v_payload_novo   := '{"status":"' || :NEW.status || 
                            '","prioridade":"' || :NEW.prioridade || '"}';

    ELSIF DELETING THEN
        v_operacao := 'DELETE';
        v_id_reg   := :OLD.id_protocolo;
        v_payload_antigo := '{"status":"' || :OLD.status || 
                            '","numero":"' || :OLD.numero_protocolo || '"}';
    END IF;

    -- Chama a package autonoma para persistir na tabela de auditoria
    pkg_auditoria.registrar_evento(
        p_nome_tabela    => 'tb_protocolo_atendimento',
        p_operacao       => v_operacao,
        p_id_registro    => v_id_reg,
        p_payload_antigo => v_payload_antigo,
        p_payload_novo   => v_payload_novo
    );

EXCEPTION
    WHEN OTHERS THEN
        -- Registra o erro no log e nao trava a operacao
        pkg_auditoria.registrar_erro(
            p_rotina_origem => 'trg_audit_protocolo',
            p_codigo_erro   => SQLCODE,
            p_mensagem_erro => SQLERRM,
            p_backtrace     => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
END trg_audit_protocolo;
/
