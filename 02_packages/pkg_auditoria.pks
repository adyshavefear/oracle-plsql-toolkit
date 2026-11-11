--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 02_packages/pkg_auditoria.pks
-- DESCRICAO : Especificacao da Package de Auditoria Transacional Autonoma
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE pkg_auditoria AS

    -- Registra evento de auditoria sem interferir no commit/rollback da transacao principal
    PROCEDURE registrar_evento (
        p_nome_tabela     IN tb_log_auditoria.nome_tabela%TYPE,
        p_operacao        IN tb_log_auditoria.operacao%TYPE,
        p_id_registro     IN tb_log_auditoria.id_registro%TYPE,
        p_usuario         IN tb_log_auditoria.usuario_sessao%TYPE DEFAULT NULL,
        p_payload_antigo  IN CLOB DEFAULT NULL,
        p_payload_novo    IN CLOB DEFAULT NULL,
        p_ip_origem       IN VARCHAR2 DEFAULT NULL
    );

    -- Grava log de erro de execucao (excecoes ORA/PLS) com stack trace completo
    PROCEDURE registrar_erro (
        p_rotina_origem   IN VARCHAR2,
        p_codigo_erro     IN NUMBER,
        p_mensagem_erro   IN VARCHAR2,
        p_backtrace       IN VARCHAR2
    );

END pkg_auditoria;
/
