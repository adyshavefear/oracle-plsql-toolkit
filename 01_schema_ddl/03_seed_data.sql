--------------------------------------------------------------------------------
-- PROJETO   : Oracle PL/SQL & APEX Enterprise Toolkit
-- AUTOR     : Adones Neto (github.com/adyshavefear)
-- ARQUIVO   : 01_schema_ddl/03_seed_data.sql
-- DESCRICAO : Carga de dados iniciais para testes de desenvolvimento e homologacao
--------------------------------------------------------------------------------

-- Categorias de Demanda
INSERT INTO tb_categoria_demanda (codigo, descricao, prazo_dias_sla, ativo) 
VALUES ('ILUM_PUB', 'Reparo de Iluminacao Publica', 3, 'S');

INSERT INTO tb_categoria_demanda (codigo, descricao, prazo_dias_sla, ativo) 
VALUES ('PAVIM_ASF', 'Operacao Tapa-Buraco e Pavimentacao', 7, 'S');

INSERT INTO tb_categoria_demanda (codigo, descricao, prazo_dias_sla, ativo) 
VALUES ('FISCAL_PROCON', 'Reclamacao de Consumidor / Fiscalizacao PROCON', 10, 'S');

INSERT INTO tb_categoria_demanda (codigo, descricao, prazo_dias_sla, ativo) 
VALUES ('CERT_IMOB', 'Emissao de Certidao Cadastral Imobiliaria', 5, 'S');

-- Cidadaos Teste
INSERT INTO tb_cidadao (nome_completo, cpf, email, telefone, status)
VALUES ('Carlos Eduardo Silva', '123.456.789-00', 'carlos.silva@email.com', '(83) 98888-1111', 'A');

INSERT INTO tb_cidadao (nome_completo, cpf, email, telefone, status)
VALUES ('Mariana Albuquerque Costa', '987.654.321-11', 'mariana.costa@email.com', '(83) 99999-2222', 'A');

INSERT INTO tb_cidadao (nome_completo, cpf, email, telefone, status)
VALUES ('Roberto Ferreira Gomes', '456.789.012-22', 'roberto.gomes@email.com', '(83) 98765-3333', 'A');

COMMIT;
