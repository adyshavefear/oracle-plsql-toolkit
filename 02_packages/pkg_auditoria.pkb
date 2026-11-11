--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 02_packages/pkg_auditoria.pkb
-- DESCRICAO : Corpo da Package de Auditoria Transacional Autonoma
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE BODY pkg_auditoria AS

    ----------------------------------------------------------------------------
    -- Funcao auxiliar privada para identificar o usuario ativo (APEX ou BD)
    ----------------------------------------------------------------------------
    FUNCTION obter_usuario_ativo (p_usuario_informado IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF p_usuario_informado IS NOT NULL THEN
            RETURN p_usuario_informado;
        END IF;

        -- Identifica se esta rodando dentro do contexto de sessao do Oracle APEX
        IF SYS_CONTEXT('APEX$SESSION', 'APP_USER') IS NOT NULL THEN
            RETURN SYS_CONTEXT('APEX$SESSION', 'APP_USER');
        END IF;

        -- Fallback para usuario nativo do Oracle
        RETURN COALESCE(SYS_CONTEXT('USERENV', 'SESSION_USER'), USER);
    END obter_usuario_ativo;

    ----------------------------------------------------------------------------
    -- Procedimento publico para gravar auditoria com transacao autonoma
    ----------------------------------------------------------------------------
    PROCEDURE registrar_evento (
        p_nome_tabela     IN tb_log_auditoria.nome_tabela%TYPE,
        p_operacao        IN tb_log_auditoria.operacao%TYPE,
        p_id_registro     IN tb_log_auditoria.id_registro%TYPE,
        p_usuario         IN tb_log_auditoria.usuario_sessao%TYPE DEFAULT NULL,
        p_payload_antigo  IN CLOB DEFAULT NULL,
        p_payload_novo    IN CLOB DEFAULT NULL,
        p_ip_origem       IN VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_usuario_final tb_log_auditoria.usuario_sessao%TYPE;
        v_ip_final      VARCHAR2(45);
    BEGIN
        v_usuario_final := obter_usuario_ativo(p_usuario);
        v_ip_final      := COALESCE(p_ip_origem, SYS_CONTEXT('USERENV', 'IP_ADDRESS'));

        INSERT INTO tb_log_auditoria (
            nome_tabela,
            operacao,
            id_registro,
            usuario_sessao,
            data_evento,
            payload_antigo,
            payload_novo,
            ip_origem
        ) VALUES (
            UPPER(p_nome_tabela),
            UPPER(p_operacao),
            p_id_registro,
            v_usuario_final,
            SYSTIMESTAMP,
            p_payload_antigo,
            p_payload_novo,
            v_ip_final
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            -- Em rotina autonoma de auditoria, evita derrubar a transacao principal
            DBMS_OUTPUT.PUT_LINE('Falha ao gravar auditoria: ' || SQLERRM);
    END registrar_evento;

    ----------------------------------------------------------------------------
    -- Procedimento para registrar excecoes de banco com stack trace
    ----------------------------------------------------------------------------
    PROCEDURE registrar_erro (
        p_rotina_origem   IN VARCHAR2,
        p_codigo_erro     IN NUMBER,
        p_mensagem_erro   IN VARCHAR2,
        p_backtrace       IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_detalhe_erro CLOB;
    BEGIN
        v_detalhe_erro := 'ROTINA: ' || p_rotina_origem || CHR(10) ||
                          'ERRO: ORA-' || TO_CHAR(ABS(p_codigo_erro), 'FM00000') || ': ' || p_mensagem_erro || CHR(10) ||
                          'BACKTRACE: ' || CHR(10) || p_backtrace;

        INSERT INTO tb_log_auditoria (
            nome_tabela,
            operacao,
            id_registro,
            usuario_sessao,
            data_evento,
            payload_novo
        ) VALUES (
            'SYS_EXCEPTION_LOG',
            'ERROR',
            NVL(ABS(p_codigo_erro), 99999),
            obter_usuario_ativo(NULL),
            SYSTIMESTAMP,
            v_detalhe_erro
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END registrar_erro;

END pkg_auditoria;
/
