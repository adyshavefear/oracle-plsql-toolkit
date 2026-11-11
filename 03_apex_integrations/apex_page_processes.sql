--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 03_apex_integrations/apex_page_processes.sql
-- DESCRICAO : Exemplos de processos PL/SQL de pagina e AJAX Callbacks no Oracle APEX
--------------------------------------------------------------------------------

-- =============================================================================
-- 1. PROCESSO DE SUBMISSAO DE FORMULARIO (Page Processing -> Execute Code)
-- =============================================================================
DECLARE
    v_id_protocolo   NUMBER;
    v_num_protocolo  VARCHAR2(25);
BEGIN
    pkg_atendimento.abrir_protocolo(
        p_cpf_cidadao       => :P10_CPF_CIDADAO,
        p_cod_categoria     => :P10_COD_CATEGORIA,
        p_assunto           => :P10_ASSUNTO,
        p_descricao         => :P10_DESCRICAO,
        p_prioridade        => :P10_PRIORIDADE,
        p_num_protocolo_out => v_num_protocolo,
        p_id_protocolo_out  => v_id_protocolo
    );

    -- Seta o ID gerado de volta na sessao do Oracle APEX para redirecionamento
    :P10_ID_PROTOCOLO  := v_id_protocolo;
    :P10_NUM_PROTOCOLO := v_num_protocolo;

    -- Mensagem de sucesso visivel na interface APEX
    apex_application.g_print_success_message := 
        'Protocolo ' || v_num_protocolo || ' registrado com sucesso!';
EXCEPTION
    WHEN OTHERS THEN
        apex_error.add_error(
            p_message          => 'Falha ao registrar protocolo: ' || SQLERRM,
            p_display_location => apex_error.c_inline_in_notification
        );
END;
/

-- =============================================================================
-- 2. AJAX CALLBACK PROCESS (Ex: Chamada via JavaScript apex.server.process)
-- =============================================================================
DECLARE
    v_id_protocolo NUMBER := apex_application.g_x01; -- Parametro enviado pelo JS
    v_situacao_sla VARCHAR2(30);
BEGIN
    v_situacao_sla := pkg_atendimento.avaliar_situacao_sla(v_id_protocolo);

    -- Resposta JSON para a requisicao AJAX do frontend
    apex_json.open_object;
    apex_json.write('success', TRUE);
    apex_json.write('idProtocolo', v_id_protocolo);
    apex_json.write('situacaoSla', v_situacao_sla);
    apex_json.close_object;
EXCEPTION
    WHEN OTHERS THEN
        apex_json.open_object;
        apex_json.write('success', FALSE);
        apex_json.write('error', SQLERRM);
        apex_json.close_object;
END;
/
