-- Active: 1774975794986@@127.0.0.1@5432@restaurante_da_helo
-- EXERCICIOOOOOS
/*-- 1.1 Adicione uma tabela de log ao sistema do restaurante. Ajuste cada procedimento para
         que ele registre:      
            - a data em que a operação aconteceu
            - o nome do procedimento executado */

-- 1° Criação da tabela log
CREATE TABLE tb_log(
	id_log SERIAL PRIMARY KEY,
	data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	procedimento VARCHAR(200)
);

SELECT * FROM tb_log;

-- 2° Criação do procedure
CREATE OR REPLACE PROCEDURE sp_registra_log(
	IN val_procedimento VARCHAR(200)
) LANGUAGE plpgsql
AS $$
BEGIN
	INSERT INTO tb_log(data_hora, procedimento) VALUES (CURRENT_TIMESTAMP, val_procedimento);
END;
$$;

-- 3° REFORMULANDO PROCEDURESSSSSS para registrar no log

-- 3.1. Cadastro de cliente
CREATE OR REPLACE PROCEDURE sp_cadastrar_cliente(
	IN nome VARCHAR(50),
	IN codigo INT DEFAULT NULL-- SE eu não passar nenhum valor, peço para gerar o código do cliente de maneira interna)
) LANGUAGE plpgsql
AS $$
BEGIN
	--se o c´digo for null, cadastrar apenas o nome, gerando automático
	IF codigo IS NULL THEN
		INSERT INTO tb_cliente(nome) VALUES(nome);
	--caso contrario, cadastrar com o codigo recebido
	ELSE
		INSERT INTO tb_cliente(cod_cliente, nome) VALUES(codigo, nome);
	END IF;
	CALL sp_registra_log('Cadastrar Cliente');
END;
$$;

-- 3.2. Criação do pedido
CREATE OR REPLACE PROCEDURE sp_criar_pedido(
	OUT cod_pedido INT,
	IN cod_cliente INT) LANGUAGE plpgsql
AS $$
	BEGIN
	INSERT INTO tb_pedido(cod_cliente) VALUES (cod_cliente);
	--pegar o código d pedido gerado e guardar na variável cod_pedido
	SELECT LASTVAL() INTO cod_pedido;
	CALL sp_registra_log('Criar pedido');
	END;
$$;


-- 3.3. Adicionando itens
CREATE OR REPLACE PROCEDURE sp_add_itens(
	IN cod_pedido INT, 
	IN cod_item INT
) LANGUAGE plpgsql
AS $$
	BEGIN
	--add item
	INSERT INTO tb_item_pedido(cod_pedido, cod_item) VALUES ($1, $2);
	
	--update
	UPDATE tb_pedido p SET data_modificacao = CURRENT_TIMESTAMP 
	WHERE p.cod_pedido = $1; 
	CALL sp_registra_log('Adicionando itens ao pedido');
	END;
$$;

-- 3.4. Calculo do valor do pedido
CREATE OR REPLACE PROCEDURE sp_calcula_valor_pedido(
	IN p_cod_pedido INT,
	OUT valor_total INT
	) LANGUAGE plpgsql
	AS $$
		BEGIN 
			SELECT SUM(i.valor)
			FROM tb_pedido p JOIN tb_item_pedido ip
				ON (p.cod_pedido = ip.cod_pedido)
			JOIN tb_item i
				ON (ip.cod_item = i.cod_item)
			WHERE p.cod_pedido = $1 -- > Variável 1 (p_cod_pedido)
			INTO $2;
			CALL sp_registra_log('Calculo do valor total do pedido');
		END;
	$$;

-- 3.5. Fechamento do pedido
CREATE OR REPLACE PROCEDURE sp_fecha_pedido(
	IN val_cod_pedido INT,
	IN val_pagamento INT
	) LANGUAGE plpgsql
	AS $$
	DECLARE
		val_tot_pedido INT;
	BEGIN
		CALL sp_calcula_valor_pedido(val_cod_pedido, val_tot_pedido);
		IF val_pagamento < val_tot_pedido THEN
			RAISE NOTICE 'Ei!!! Valor insuficiente para pagar a conta! R$%', val_tot_pedido;
		ELSE 
			UPDATE tb_pedido p SET
			data_modificacao = CURRENT_TIMESTAMP,
			status = 'fechado'
			WHERE p.cod_pedido = $1;
		END IF;
		CALL sp_registra_log('Fechamento de pedido');
	END;
	$$;

-- 3.6. Calculo do troco (CÓDIGO DA AULA ALTERADO)
CREATE OR REPLACE PROCEDURE sp_calcular_troco(
	OUT troco INT,
	IN valor_a_pagar INT,
	IN valor_total INT
) LANGUAGE plpgsql
AS $$
BEGIN
    IF valor_a_pagar > valor_total THEN
	    $1 := $2 - $3;
        RAISE NOTICE 'O troco do pedido 2 é: R$%', troco;
    ELSE 
        RAISE NOTICE 'Não há troco';
    END IF;
	CALL sp_registra_log('Calculo do troco');
END;
$$;

-- 4° Procedimentos testes
-- 4.1. Chamando a função: Adicionar cliente
CALL sp_cadastrar_cliente('Heloisa Prestes');

-- 4.2. Chamando a função: Criar pedido
DO $$
DECLARE
	cod_pedido INT;
	cod_cliente INT;
BEGIN	
	SELECT c.cod_cliente FROM tb_cliente c
	WHERE nome LIKE 'Heloisa Prestes' INTO cod_cliente;
	CALL sp_criar_pedido(cod_pedido, cod_cliente);
	RAISE NOTICE 'Código do Pedido gerado: %', cod_pedido;
END;
$$

-- 4.3. Chamando a função: Adicionar item ao pedido
-- Verificar quais itens existem: SELECT * FROM tb_item;
DO $$
BEGIN
	CALL sp_add_itens(2, 5);
	RAISE NOTICE 'Item adicionado com sucesso';
END;
$$

-- 4.4. Chamando a função: Calcular o valor do pedido
DO $$
DECLARE
    valor_TOT INT;
    num_pedido INT := 2;
BEGIN
    CALL sp_calcula_valor_pedido(num_pedido, valor_TOT);
    RAISE NOTICE 'O valor do pedido % é: R$%,00', num_pedido ,valor_TOT;
END
$$

-- 4.5. Chamando a função: Fechar o pedido
DO $$
BEGIN
	CALL sp_fecha_pedido(2, 200);
END;
$$

-- 4.6. Chamando a função: Calcular o troco
DO $$
DECLARE
    valor_total INT;
    troco INT;
	pagamento INT := 200;
BEGIN
	CALL sp_calcula_valor_pedido(2, valor_total);
	CALL sp_calcular_troco(troco, pagamento, valor_total);
END;
$$;

-- 5° Verificação se o sp log funcionou e está registrando na tb_log
SELECT * FROM tb_log;

/*-- 1.2 Adicione um procedimento ao sistema do restaurante. Ele deve
    - receber um parâmetro de entrada (IN) que representa o código de um cliente
    - exibir, com RAISE NOTICE, o total de pedidos que o cliente tem */

-- 1° Criar a procedure
CREATE OR REPLACE PROCEDURE sp_cliente_pedidos(
    IN val_cod_cliente INT
) LANGUAGE plpgsql
AS $$
DECLARE
    nome_cliente VARCHAR (200);
    total_pedidos INT;
BEGIN
    SELECT COUNT(p.cod_pedido) FROM tb_pedido p 
    JOIN tb_cliente c ON (c.cod_cliente = p.cod_cliente)
    WHERE c.cod_cliente = $1
    INTO total_pedidos;

    SELECT c.nome FROM tb_cliente c 
    WHERE c.cod_cliente = $1
    INTO nome_cliente;

    IF total_pedidos > 1 THEN
        RAISE NOTICE '%, cliente %, fez % pedidos', nome_cliente, $1, total_pedidos;
    ELSEIF total_pedidos = 1 THEN
        RAISE NOTICE '%, cliente %, fez 1 pedido', nome_cliente, $1;
    ELSE
        RAISE NOTICE '%, cliente %, não fez nenhum pedido ainda', nome_cliente, $1;
    END IF;
END;
$$;

/*1.3. Reescreva o exercício 1.2 de modo que o total de pedidos seja armazenado em uma
variável de saída (OUT).*/

-- 1° Criar a procedure
CREATE OR REPLACE PROCEDURE sp_pedidos_cliente(
    IN val_cod_cliente INT,
    OUT total_pedidos INT
) LANGUAGE plpgsql
AS $$
DECLARE
    nome_cliente VARCHAR (200);
BEGIN
    SELECT COUNT(p.cod_pedido) FROM tb_pedido p 
    JOIN tb_cliente c ON (c.cod_cliente = p.cod_cliente)
    WHERE c.cod_cliente = $1
    INTO $2;
END;
$$;


/*1.6 Para cada procedimento criado, escreva um bloco anônimo que o coloca em execução*/
-- Exercício 1
SELECT * FROM tb_log;

-- Exercício 2
DO $$
DECLARE 
    num_cliente INT := 2; -- Colocar o número do cliente
    total INT;
BEGIN   
    CALL sp_cliente_pedidos(num_cliente);    
END;
$$;

-- exercício 3
DO $$
DECLARE 
    num_cliente INT := 3; -- Colocar o número do cliente
    total INT;
    nome_cliente VARCHAR (200);
BEGIN   
    CALL sp_pedidos_cliente(num_cliente, total);

    SELECT c.nome FROM tb_cliente c WHERE c.cod_cliente = num_cliente
    INTO nome_cliente;

    IF total > 1 THEN
        RAISE NOTICE '%, cliente %, fez % pedidos', nome_cliente, num_cliente, total;
    ELSEIF total = 1 THEN
        RAISE NOTICE '%, cliente %, fez 1 pedido', nome_cliente, num_cliente;
    ELSE
        RAISE NOTICE '%, cliente %, não fez nenhum pedido ainda', nome_cliente, num_cliente;
    END IF;    
END;
$$;

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--DAQUI PRA BAIXO (EXERCICOS NA AULA)


--  -- 6) CRIANDO PROCEDURE: CALCULAR O TROCO
CREATE OR REPLACE PROCEDURE sp_calcular_troco(
	OUT troco INT,
	IN valor_a_pagar INT,
	IN valor_total INT
) LANGUAGE plpgsql
AS $$
BEGIN
	$1 := $2 - $3;
END;
$$

-- -- CHAMANDO PROCEDURE: FECHAMENTO DE UM PEDIDO
-- testando o fechamento do pedido 1
DO $$
DECLARE
	valor1 INT := 60;
	valor2 INT := 100;
BEGIN
	CALL sp_fecha_pedido(1, valor2);
END;
$$

-- SELECT * FROM tb_pedido;

--  -- 5) CRIANDO PROCEDURE: FECHAMENTO DE UM PEDIDO
CREATE OR REPLACE PROCEDURE sp_fecha_pedido(
	IN val_cod_pedido INT,
	IN val_pagamento INT
	) LANGUAGE plpgsql
	AS $$
	DECLARE
		val_tot_pedido INT;
	BEGIN
		CALL sp_calcula_valor_pedido(1, val_tot_pedido);
		IF val_pagamento < val_tot_pedido THEN
			RAISE NOTICE 'Ei!!! Valor insuficiente para pagar a conta! R$%', val_tot_pedido;
		ELSE 
			UPDATE tb_pedido p SET
			data_modificacao = CURRENT_TIMESTAMP,
			status = 'fechado'
			WHERE p.cod_pedido = $1;
		END IF;
	END;
	$$

-- -- CHAMANDO PROCEDURE: CALCULAR O VALOR DO PEDIDO
DO $$
DECLARE
	valor_tot INT;
BEGIN
	CALL sp_calcula_valor_pedido(2, valor_tot);
	RAISE NOTICE 'Total do pedido %: R$%', 2, valor_tot;
END;$$

--  -- 4) CRIANDO PROCEDURE: CALCULAR O VALOR DO PEDIDO
CREATE OR REPLACE PROCEDURE sp_calcula_valor_pedido(
	IN p_cod_pedido INT,
	OUT valor_total INT
	) LANGUAGE plpgsql
	AS $$
		BEGIN 
			SELECT SUM(i.valor)
			FROM tb_pedido p JOIN tb_item_pedido ip
				ON (p.cod_pedido = ip.cod_pedido)
			JOIN tb_item i
				ON (ip.cod_item = i.cod_item)
			WHERE p.cod_pedido = $1 -- > Variável 1 (p_cod_pedido)
			INTO $2;
		END;
	$$

-- -- CHAMANDO PROCEDURE: ADICIONAR ITENS AO PEDIDO
DO $$
BEGIN
	CALL sp_add_itens(1, 3);
	RAISE NOTICE 'Item adicionado com sucesso';
END;
$$

-- SELECT * FROM tb_item_pedido;
-- SELECT * FROM tb_pedido;


--  -- 3) CRIANDO PROCEDURE: ADICIONAR ITENS AO PEDIDO
-- escrever um proc que adiciona um item a um pedido ele deve associar
-- o item a um pedido e atualizar a data de modificação do pedido
CREATE OR REPLACE PROCEDURE sp_add_itens(
	IN cod_pedido INT, 
	IN cod_item INT
) LANGUAGE plpgsql
AS $$
	BEGIN
	--add item
	INSERT INTO tb_item_pedido(cod_pedido, cod_item) VALUES ($1, $2);
	
	--update
	UPDATE tb_pedido p SET data_modificacao = CURRENT_TIMESTAMP 
	WHERE p.cod_pedido = $1; 
	END;
$$

--FAÇO UM BLOCO PORQUE VOU USAR VARIÁVEIS PARA ADD PEDIDO
-- -- CHAMANDO PROCEDURE: CRIAR PEDIDO
DO $$
DECLARE
	cod_pedido INT;
	cod_cliente INT;
BEGIN	
	SELECT c.cod_cliente FROM tb_cliente c
	WHERE nome LIKE 'João da Silva' INTO cod_cliente;
	CALL sp_criar_pedido(cod_pedido, cod_cliente);
	RAISE NOTICE 'Código do Pedido gerado: %', cod_pedido;
END;
$$
--SELECT * FROM tb_pedido;

--  -- 2) CRIANDO PROCEDURE: CRIAR PEDIDO

CREATE OR REPLACE PROCEDURE sp_criar_pedido(
	OUT cod_pedido INT,
	IN cod_cliente INT) LANGUAGE plpgsql
AS $$
	BEGIN
	INSERT INTO tb_pedido(cod_cliente) VALUES (cod_cliente);
	--pegar o código d pedido gerado e guardar na variável cod_pedido
	SELECT LASTVAL() INTO cod_pedido;
	END;
$$

-- -- CHAMANDO PROCEDURE: CADASTRAR CLIENTES

CALL sp_cadastrar_cliente('João da Silva');
CALL sp_cadastrar_cliente('Maria Clara');

--  -- 1) CRIANDO PROCEDURE: CADASTRAR CLIENTES

CREATE OR REPLACE PROCEDURE sp_cadastrar_cliente(
	IN nome VARCHAR(50),
	IN codigo INT DEFAULT NULL-- SE eu não passar nenhum valor, peço para gerar o código do cliente de maneira interna)
) LANGUAGE plpgsql
AS $$
BEGIN
	--se o c´digo for null, cadastrar apenas o nome, gerando automático
	IF codigo IS NULL THEN
		INSERT INTO tb_cliente(nome) VALUES(nome);
	--caso contrario, cadastrar com o codigo recebido
	ELSE
		INSERT INTO tb_cliente(cod_cliente, nome) VALUES(codigo, nome);
	END IF;
END;
$$

-- -- -- -- CONSULTA DAS TABELAS -- -- -- --

-- SELECT * FROM tb_cliente;
-- SELECT * FROM tb_pedido;
-- SELECT * FROM tb_item_pedido;
-- SELECT * FROM tb_item;
-- SELECT * FROM tb_tipo;
-- SELECT * FROM tb_log;

-- -- -- -- CRIAÇÃO DE TABELAS -- -- -- --

-- CRIACÃO DA TABELA: ITENS DO PEDIDO
CREATE TABLE tb_item_pedido(
	--surrogate key = uma PK não normal da tabela, criado pelo sistema
	-- o natural seria: o cod item +  cod pedido
	cod_item_pedido SERIAL PRIMARY KEY,
	cod_item INT,
	cod_pedido INT,
	CONSTRAINT fk_item FOREIGN KEY (cod_item) REFERENCES tb_item(cod_item),
	CONSTRAINT fk_pedido FOREIGN KEY (cod_pedido) REFERENCES tb_pedido(cod_pedido));


--INSERNDO: ITENS NA TABELA TB_ITEM
INSERT INTO tb_item(descricao, valor, cod_tipo)
VALUES ('Refrigerante', 10, 1),
	   ('Suco', 8, 1),
	   ('Hambúrguer', 55, 2),
	   ('Batata Frita', 15, 2),
	   ('Nuggets', 5, 2);


-- CRIACÃO DA TABELA: ITEM
CREATE TABLE tb_item(
	cod_item SERIAL PRIMARY KEY,
	descricao VARCHAR (200) NOT NULL,
	valor NUMERIC(10,2) NOT NULL,
	cod_tipo INT NOT NULL,
	CONSTRAINT fk_tipo_item FOREIGN KEY(cod_tipo) REFERENCES tb_tipo(cod_tipo));


-- CRIACÃO DA TABELA: TIPO (DO PRODUTO)
CREATE TABLE tb_tipo(
	cod_tipo SERIAL PRIMARY KEY,
	descricao VARCHAR(200) NOT NULL);
INSERT INTO tb_tipo (descricao)
VALUES ('Bebida'),('Comida');


-- CRIACÃO DA TABELA: PEDIDO
CREATE TABLE tb_pedido(
	cod_pedido SERIAL PRIMARY KEY,
	data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	data_modificacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	status VARCHAR DEFAULT 'aberto',
	cod_cliente INT NOT NULL,
	CONSTRAINT fk_cliente FOREIGN KEY (cod_cliente) REFERENCES
	tb_cliente(cod_cliente));


-- CRIACÃO DA TABELA: CLIENTES
CREATE TABLE tb_cliente(
	cod_cliente SERIAL PRIMARY KEY,
	nome VARCHAR(50) NOT NULL);
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --