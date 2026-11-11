--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 02_packages/pkg_atendimento.pkb
-- DESCRICAO : Corpo da Package de Gestao de Protocolos com regras e tratamento de erros
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE BODY pkg_atendimento AS

    ----------------------------------------------------------------------------
    -- Funcao privada: Gera mascara de numero de protocolo ANO.MES.SEQUENCIAL
    ----------------------------------------------------------------------------
    FUNCTION gerar_mascara_protocolo (p_id_protocolo IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN TO_CHAR(SYSDATE, 'YYYY') || '.' || 
               TO_CHAR(SYSDATE, 'MM')   || '.' || 
               LPAD(p_id_protocolo, 6, '0');
    END gerar_mascara_protocolo;

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
    ) IS
        v_id_cidadao     tb_cidadao.id_cidadao%TYPE;
        v_status_cidadao tb_cidadao.status%TYPE;
        v_id_categoria   tb_categoria_demanda.id_categoria%TYPE;
        v_prazo_sla      tb_categoria_demanda.prazo_dias_sla%TYPE;
        v_data_limite    DATE;
        v_id_novo_prot   NUMBER;
        v_num_gerado     VARCHAR2(25);
    BEGIN
        -- 1. Validacao de parametros obrigatorios
        IF p_cpf_cidadao IS NULL OR p_cod_categoria IS NULL OR p_assunto IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'Parametros obrigatorios nao informados (CPF, Categoria ou Assunto).');
        END IF;

        -- 2. Busca e validacao do cidadao
        BEGIN
            SELECT id_cidadao, status
              INTO v_id_cidadao, v_status_cidadao
              FROM tb_cidadao
             WHERE cpf = p_cpf_cidadao;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003, 'Cidadao nao localizado para o CPF: ' || p_cpf_cidadao);
        END;

        IF v_status_cidadao <> 'A' THEN
            RAISE_APPLICATION_ERROR(-20001, 'Cidadao com cadastro inativo. Nao e possivel abrir nova solicitacao.');
        END IF;

        -- 3. Busca e validacao da categoria
        BEGIN
            SELECT id_categoria, prazo_dias_sla
              INTO v_id_categoria, v_prazo_sla
              FROM tb_categoria_demanda
             WHERE codigo = p_cod_categoria
               AND ativo = 'S';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003, 'Categoria invalida ou inativa: ' || p_cod_categoria);
        END;

        -- 4. Calculo de data limite considerando prazo SLA
        v_data_limite := SYSDATE + v_prazo_sla;

        -- 5. Insercao do protocolo (gerando ID via identity)
        INSERT INTO tb_protocolo_atendimento (
            numero_protocolo,
            id_cidadao,
            id_categoria,
            assunto,
            descricao,
            status,
            prioridade,
            data_abertura,
            data_limite_sla
        ) VALUES (
            'PROV_' || SUBSTR(RAWTOHEX(SYS_GUID()), 1, 20),
            v_id_cidadao,
            v_id_categoria,
            TRIM(p_assunto),
            p_descricao,
            'ABERTO',
            NVL(p_prioridade, 'NORMAL'),
            SYSDATE,
            v_data_limite
        ) RETURNING id_protocolo INTO v_id_novo_prot;

        -- Atualiza mascara oficial do protocolo
        v_num_gerado := gerar_mascara_protocolo(v_id_novo_prot);

        UPDATE tb_protocolo_atendimento
           SET numero_protocolo = v_num_gerado
         WHERE id_protocolo = v_id_novo_prot;

        -- 6. Grava despacho inicial
        INSERT INTO tb_andamento_processual (
            id_protocolo,
            data_registro,
            usuario_registro,
            status_anterior,
            status_novo,
            despacho_texto
        ) VALUES (
            v_id_novo_prot,
            SYSDATE,
            COALESCE(SYS_CONTEXT('APEX$SESSION', 'APP_USER'), USER),
            NULL,
            'ABERTO',
            'Abertura de protocolo registrada no sistema.'
        );

        p_id_protocolo_out  := v_id_novo_prot;
        p_num_protocolo_out := v_num_gerado;

    EXCEPTION
        WHEN OTHERS THEN
            pkg_auditoria.registrar_erro(
                p_rotina_origem => 'pkg_atendimento.abrir_protocolo',
                p_codigo_erro   => SQLCODE,
                p_mensagem_erro => SQLERRM,
                p_backtrace     => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END abrir_protocolo;

    ----------------------------------------------------------------------------
    -- Adiciona despacho/andamento e atualiza o status do processo
    ----------------------------------------------------------------------------
    PROCEDURE despachar_protocolo (
        p_id_protocolo    IN tb_protocolo_atendimento.id_protocolo%TYPE,
        p_novo_status     IN tb_protocolo_atendimento.status%TYPE,
        p_despacho_texto  IN CLOB,
        p_usuario         IN VARCHAR2 DEFAULT NULL
    ) IS
        v_status_atual tb_protocolo_atendimento.status%TYPE;
        v_usuario_exec VARCHAR2(50);
    BEGIN
        SELECT status
          INTO v_status_atual
          FROM tb_protocolo_atendimento
         WHERE id_protocolo = p_id_protocolo
           FOR UPDATE;

        IF v_status_atual IN ('CONCLUIDO', 'CANCELADO') THEN
            RAISE_APPLICATION_ERROR(-20002, 'Protocolo ja finalizado (' || v_status_atual || '). Nao aceita novos despachos.');
        END IF;

        v_usuario_exec := COALESCE(p_usuario, SYS_CONTEXT('APEX$SESSION', 'APP_USER'), USER);

        -- Atualiza status da solicitacao
        UPDATE tb_protocolo_atendimento
           SET status = NVL(p_novo_status, status)
         WHERE id_protocolo = p_id_protocolo;

        -- Insere no historico
        INSERT INTO tb_andamento_processual (
            id_protocolo,
            data_registro,
            usuario_registro,
            status_anterior,
            status_novo,
            despacho_texto
        ) VALUES (
            p_id_protocolo,
            SYSDATE,
            v_usuario_exec,
            v_status_atual,
            NVL(p_novo_status, v_status_atual),
            p_despacho_texto
        );

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Protocolo ID ' || p_id_protocolo || ' nao encontrado.');
        WHEN OTHERS THEN
            pkg_auditoria.registrar_erro(
                p_rotina_origem => 'pkg_atendimento.despachar_protocolo',
                p_codigo_erro   => SQLCODE,
                p_mensagem_erro => SQLERRM,
                p_backtrace     => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END despachar_protocolo;

    ----------------------------------------------------------------------------
    -- Finaliza protocolo e valida se pode ser concluido
    ----------------------------------------------------------------------------
    PROCEDURE concluir_protocolo (
        p_id_protocolo    IN tb_protocolo_atendimento.id_protocolo%TYPE,
        p_parecer_final   IN CLOB,
        p_usuario         IN VARCHAR2 DEFAULT NULL
    ) IS
        v_status_atual tb_protocolo_atendimento.status%TYPE;
        v_usuario_exec VARCHAR2(50);
    BEGIN
        SELECT status
          INTO v_status_atual
          FROM tb_protocolo_atendimento
         WHERE id_protocolo = p_id_protocolo
           FOR UPDATE;

        IF v_status_atual = 'CONCLUIDO' THEN
            RAISE_APPLICATION_ERROR(-20002, 'Protocolo ja se encontra concluido.');
        END IF;

        v_usuario_exec := COALESCE(p_usuario, SYS_CONTEXT('APEX$SESSION', 'APP_USER'), USER);

        UPDATE tb_protocolo_atendimento
           SET status = 'CONCLUIDO',
               data_conclusao = SYSDATE
         WHERE id_protocolo = p_id_protocolo;

        INSERT INTO tb_andamento_processual (
            id_protocolo,
            data_registro,
            usuario_registro,
            status_anterior,
            status_novo,
            despacho_texto
        ) VALUES (
            p_id_protocolo,
            SYSDATE,
            v_usuario_exec,
            v_status_atual,
            'CONCLUIDO',
            'PARECER DE CONCLUSAO: ' || CHR(10) || p_parecer_final
        );

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Protocolo ID ' || p_id_protocolo || ' nao encontrado.');
        WHEN OTHERS THEN
            pkg_auditoria.registrar_erro(
                p_rotina_origem => 'pkg_atendimento.concluir_protocolo',
                p_codigo_erro   => SQLCODE,
                p_mensagem_erro => SQLERRM,
                p_backtrace     => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END concluir_protocolo;

    ----------------------------------------------------------------------------
    -- Avalia SLA ('NO_PRAZO', 'CRITICO', 'VENCIDO')
    ----------------------------------------------------------------------------
    FUNCTION avaliar_situacao_sla (
        p_id_protocolo IN tb_protocolo_atendimento.id_protocolo%TYPE
    ) RETURN VARCHAR2 IS
        v_status         tb_protocolo_atendimento.status%TYPE;
        v_data_limite    DATE;
        v_data_conclusao DATE;
    BEGIN
        SELECT status, data_limite_sla, data_conclusao
          INTO v_status, v_data_limite, v_data_conclusao
          FROM tb_protocolo_atendimento
         WHERE id_protocolo = p_id_protocolo;

        IF v_status = 'CONCLUIDO' THEN
            IF v_data_conclusao <= v_data_limite THEN
                RETURN 'CONCLUIDO_NO_PRAZO';
            ELSE
                RETURN 'CONCLUIDO_COM_ATRASO';
            END IF;
        END IF;

        IF SYSDATE > v_data_limite THEN
            RETURN 'VENCIDO';
        ELSIF (v_data_limite - SYSDATE) <= 1 THEN
            RETURN 'CRITICO';
        ELSE
            RETURN 'NO_PRAZO';
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'NAO_ENCONTRADO';
    END avaliar_situacao_sla;

    ----------------------------------------------------------------------------
    -- Retorna cursor com protocolos pendentes
    ----------------------------------------------------------------------------
    FUNCTION listar_protocolos_pendentes (
        p_prioridade IN VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        c_resultado SYS_REFCURSOR;
    BEGIN
        OPEN c_resultado FOR
            SELECT p.id_protocolo,
                   p.numero_protocolo,
                   c.nome_completo AS nome_cidadao,
                   cat.descricao   AS categoria,
                   p.status,
                   ROUND(p.data_limite_sla - SYSDATE, 1) AS dias_restantes
              FROM tb_protocolo_atendimento p
              JOIN tb_cidadao c ON c.id_cidadao = p.id_cidadao
              JOIN tb_categoria_demanda cat ON cat.id_categoria = p.id_categoria
             WHERE p.status NOT IN ('CONCLUIDO', 'CANCELADO')
               AND (p_prioridade IS NULL OR p.prioridade = p_prioridade)
             ORDER BY p.data_limite_sla ASC;

        RETURN c_resultado;
    END listar_protocolos_pendentes;

END pkg_atendimento;
/
