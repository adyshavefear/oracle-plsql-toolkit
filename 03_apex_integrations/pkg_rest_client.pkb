--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 03_apex_integrations/pkg_rest_client.pkb
-- DESCRICAO : Corpo da Package de Integracao REST via APEX_WEB_SERVICE e APEX_JSON
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE BODY pkg_rest_client AS

    -- Variaveis globais de estado de sessao da package
    g_base_url          VARCHAR2(255) := 'https://api.exemplo-municipal.gov.br/v1';
    g_api_token         VARCHAR2(255);
    g_ultimo_status_code NUMBER;

    ----------------------------------------------------------------------------
    -- Define URL base e configuracoes padrao de requisicao
    ----------------------------------------------------------------------------
    PROCEDURE configurar_ambiente (
        p_base_url  IN VARCHAR2,
        p_api_token IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        g_base_url  := RTRIM(p_base_url, '/');
        g_api_token := p_api_token;
    END configurar_ambiente;

    ----------------------------------------------------------------------------
    -- Retorna o HTTP status code da ultima chamada executada
    ----------------------------------------------------------------------------
    FUNCTION obter_ultimo_status_code RETURN NUMBER IS
    BEGIN
        RETURN g_ultimo_status_code;
    END obter_ultimo_status_code;

    ----------------------------------------------------------------------------
    -- Funcao auxiliar: Prepara headers da requisicao HTTP
    ----------------------------------------------------------------------------
    PROCEDURE preparar_headers (p_token IN VARCHAR2) IS
        v_token_final VARCHAR2(255);
    BEGIN
        v_token_final := COALESCE(p_token, g_api_token);

        -- Limpa cabecalhos anteriores da sessao do APEX_WEB_SERVICE
        apex_web_service.g_request_headers.DELETE;

        apex_web_service.g_request_headers(1).name  := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';

        apex_web_service.g_request_headers(2).name  := 'Accept';
        apex_web_service.g_request_headers(2).value := 'application/json';

        IF v_token_final IS NOT NULL THEN
            apex_web_service.g_request_headers(3).name  := 'Authorization';
            apex_web_service.g_request_headers(3).value := 'Bearer ' || v_token_final;
        END IF;
    END preparar_headers;

    ----------------------------------------------------------------------------
    -- Executa chamada GET retornando CLOB JSON
    ----------------------------------------------------------------------------
    FUNCTION executar_get (
        p_endpoint  IN VARCHAR2,
        p_api_token IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        v_url      VARCHAR2(500);
        v_resposta CLOB;
    BEGIN
        preparar_headers(p_api_token);
        v_url := g_base_url || '/' || LTRIM(p_endpoint, '/');

        v_resposta := apex_web_service.make_rest_request(
            p_url         => v_url,
            p_http_method => 'GET'
        );

        g_ultimo_status_code := apex_web_service.g_status_code;
        RETURN v_resposta;
    EXCEPTION
        WHEN OTHERS THEN
            pkg_auditoria.registrar_erro(
                p_rotina_origem => 'pkg_rest_client.executar_get',
                p_codigo_erro   => SQLCODE,
                p_mensagem_erro => SQLERRM,
                p_backtrace     => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END executar_get;

    ----------------------------------------------------------------------------
    -- Executa chamada POST enviando payload JSON em CLOB
    ----------------------------------------------------------------------------
    FUNCTION executar_post (
        p_endpoint  IN VARCHAR2,
        p_body_json IN CLOB,
        p_api_token IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        v_url      VARCHAR2(500);
        v_resposta CLOB;
    BEGIN
        preparar_headers(p_api_token);
        v_url := g_base_url || '/' || LTRIM(p_endpoint, '/');

        v_resposta := apex_web_service.make_rest_request(
            p_url         => v_url,
            p_http_method => 'POST',
            p_body        => p_body_json
        );

        g_ultimo_status_code := apex_web_service.g_status_code;
        RETURN v_resposta;
    EXCEPTION
        WHEN OTHERS THEN
            pkg_auditoria.registrar_erro(
                p_rotina_origem => 'pkg_rest_client.executar_post',
                p_codigo_erro   => SQLCODE,
                p_mensagem_erro => SQLERRM,
                p_backtrace     => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END executar_post;

    ----------------------------------------------------------------------------
    -- Notifica webhook externo montando JSON estruturado
    ----------------------------------------------------------------------------
    PROCEDURE disparar_webhook_conclusao (
        p_id_protocolo IN NUMBER,
        p_sucesso_out  OUT BOOLEAN,
        p_resposta_out OUT CLOB
    ) IS
        v_payload    CLOB;
        v_num_prot   tb_protocolo_atendimento.numero_protocolo%TYPE;
        v_status     tb_protocolo_atendimento.status%TYPE;
        v_cidadao    tb_cidadao.nome_completo%TYPE;
    BEGIN
        SELECT p.numero_protocolo, p.status, c.nome_completo
          INTO v_num_prot, v_status, v_cidadao
          FROM tb_protocolo_atendimento p
          JOIN tb_cidadao c ON c.id_cidadao = p.id_cidadao
         WHERE p.id_protocolo = p_id_protocolo;

        -- Montagem do payload JSON usando APEX_JSON
        apex_json.initialize_clob_output;
        apex_json.open_object;
        apex_json.write('evento', 'PROTOCOLO_FINALIZADO');
        apex_json.write('idProtocolo', p_id_protocolo);
        apex_json.write('numeroProtocolo', v_num_prot);
        apex_json.write('status', v_status);
        apex_json.write('cidadao', v_cidadao);
        apex_json.write('timestamp', TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
        apex_json.close_object;

        v_payload := apex_json.get_clob_output;
        apex_json.free_output;

        -- Disparo para webhook
        p_resposta_out := executar_post('/webhooks/notificacoes', v_payload);

        IF g_ultimo_status_code BETWEEN 200 AND 299 THEN
            p_sucesso_out := TRUE;
        ELSE
            p_sucesso_out := FALSE;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            p_sucesso_out := FALSE;
            pkg_auditoria.registrar_erro(
                p_rotina_origem => 'pkg_rest_client.disparar_webhook_conclusao',
                p_codigo_erro   => SQLCODE,
                p_mensagem_erro => SQLERRM,
                p_backtrace     => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END disparar_webhook_conclusao;

END pkg_rest_client;
/
