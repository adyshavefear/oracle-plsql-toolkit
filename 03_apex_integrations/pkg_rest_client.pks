--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 03_apex_integrations/pkg_rest_client.pks
-- DESCRICAO : Especificacao da Package para consumo de servicos REST no Oracle APEX
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE pkg_rest_client AS

    -- Define URL base e configuracoes padrao de requisicao
    PROCEDURE configurar_ambiente (
        p_base_url  IN VARCHAR2,
        p_api_token IN VARCHAR2 DEFAULT NULL
    );

    -- Retorna o HTTP status code da ultima chamada executada
    FUNCTION obter_ultimo_status_code RETURN NUMBER;

    -- Executa chamada GET retornando CLOB JSON
    FUNCTION executar_get (
        p_endpoint  IN VARCHAR2,
        p_api_token IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Executa chamada POST enviando payload JSON em CLOB
    FUNCTION executar_post (
        p_endpoint  IN VARCHAR2,
        p_body_json IN CLOB,
        p_api_token IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Notifica webhook externo ao concluir um protocolo
    PROCEDURE disparar_webhook_conclusao (
        p_id_protocolo IN NUMBER,
        p_sucesso_out  OUT BOOLEAN,
        p_resposta_out OUT CLOB
    );

END pkg_rest_client;
/
