--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 02_packages/pkg_atendimento.pks
-- DESCRICAO : Especificacao da Package de Gestao de Protocolos e Regras de Negocio
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE pkg_atendimento AS

    -- Excecoes publicas de negocio
    e_cidadao_inativo      EXCEPTION;
    e_protocolo_fechado    EXCEPTION;
    e_dados_invalidos      EXCEPTION;

    PRAGMA EXCEPTION_INIT(e_cidadao_inativo,   -20001);
    PRAGMA EXCEPTION_INIT(e_protocolo_fechado, -20002);
    PRAGMA EXCEPTION_INIT(e_dados_invalidos,   -20003);

    -- Record e tipos para retorno de colecoes
    TYPE r_protocolo_resumo IS RECORD (
        id_protocolo     tb_protocolo_atendimento.id_protocolo%TYPE,
        numero_protocolo tb_protocolo_atendimento.numero_protocolo%TYPE,
        nome_cidadao     tb_cidadao.nome_completo%TYPE,
        categoria        tb_categoria_demanda.descricao%TYPE,
        status           tb_protocolo_atendimento.status%TYPE,
        dias_restantes   NUMBER
    );

    TYPE t_cursor_protocolos IS REF CURSOR RETURN r_protocolo_resumo;

    ----------------------------------------------------------------------------
    -- Abre novo protocolo calculando SLA de acordo com a categoria
    ----------------------------------------------------------------------------
    PROCEDURE abrir_protocolo (
        p_cpf_cidadao       IN tb_cidadao.cpf%TYPE,
        p_cod_categoria     IN tb_categoria_demanda.codigo%TYPE,
        p_assunto           IN tb_protocolo_atendimento.assunto%TYPE,
        p_descricao         IN CLOB,
        p_prioridade        IN tb_protocolo_atendimento.prioridade%TYPE DEFAULT 'NORMAL',
        p_num_protocolo_out OUT tb_protocolo_atendimento.numero_protocolo%TYPE,
        p_id_protocolo_out  OUT tb_protocolo_atendimento.id_protocolo%TYPE
    );

    ----------------------------------------------------------------------------
    -- Adiciona despacho/andamento e atualiza o status do processo
    ----------------------------------------------------------------------------
    PROCEDURE despachar_protocolo (
        p_id_protocolo    IN tb_protocolo_atendimento.id_protocolo%TYPE,
        p_novo_status     IN tb_protocolo_atendimento.status%TYPE,
        p_despacho_texto  IN CLOB,
        p_usuario         IN VARCHAR2 DEFAULT NULL
    );

    ----------------------------------------------------------------------------
    -- Finaliza protocolo e valida se pode ser concluido
    ----------------------------------------------------------------------------
    PROCEDURE concluir_protocolo (
        p_id_protocolo    IN tb_protocolo_atendimento.id_protocolo%TYPE,
        p_parecer_final   IN CLOB,
        p_usuario         IN VARCHAR2 DEFAULT NULL
    );

    ----------------------------------------------------------------------------
    -- Funcao que avalia a saude do SLA de um protocolo ('NO_PRAZO', 'CRITICO', 'VENCIDO')
    ----------------------------------------------------------------------------
    FUNCTION avaliar_situacao_sla (
        p_id_protocolo IN tb_protocolo_atendimento.id_protocolo%TYPE
    ) RETURN VARCHAR2;

    ----------------------------------------------------------------------------
    -- Retorna cursor com protocolos pendentes de atendimento
    ----------------------------------------------------------------------------
    FUNCTION listar_protocolos_pendentes (
        p_prioridade IN VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

END pkg_atendimento;
/
