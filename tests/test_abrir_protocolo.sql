-- Run after installing the schema, packages and triggers in a test database.
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

DECLARE
    v_cpf       VARCHAR2(14) := 'TEST_' || SUBSTR(RAWTOHEX(SYS_GUID()), 1, 9);
    v_categoria VARCHAR2(30) := 'TEST_' || SUBSTR(RAWTOHEX(SYS_GUID()), 1, 20);
    v_id        NUMBER;
    v_numero    VARCHAR2(25);
    v_salvo     VARCHAR2(25);
    v_historico NUMBER;
BEGIN
    SAVEPOINT teste_abertura;
    INSERT INTO tb_cidadao (nome_completo, cpf) VALUES ('Test fixture', v_cpf);
    INSERT INTO tb_categoria_demanda (codigo, descricao, prazo_dias_sla)
    VALUES (v_categoria, 'Test fixture', 5);

    pkg_atendimento.abrir_protocolo(
        p_cpf_cidadao => v_cpf,
        p_cod_categoria => v_categoria,
        p_assunto => 'Regression test',
        p_descricao => 'Synthetic test data',
        p_num_protocolo_out => v_numero,
        p_id_protocolo_out => v_id
    );

    SELECT numero_protocolo INTO v_salvo FROM tb_protocolo_atendimento WHERE id_protocolo = v_id;
    SELECT COUNT(*) INTO v_historico FROM tb_andamento_processual WHERE id_protocolo = v_id;
    IF v_numero IS NULL OR v_salvo <> v_numero OR v_salvo LIKE 'PROV_%' OR v_historico <> 1 THEN
        RAISE_APPLICATION_ERROR(-20999, 'Protocol opening regression failed.');
    END IF;
    ROLLBACK TO teste_abertura;
    DBMS_OUTPUT.PUT_LINE('PASS: protocol and initial history created.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO teste_abertura;
        RAISE;
END;
/
