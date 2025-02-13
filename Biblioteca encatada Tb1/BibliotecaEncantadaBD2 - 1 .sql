-- Reiniciar tabelas
TRUNCATE emprestimos, livros, autores, usuarios RESTART IDENTITY;

-- Tabela de Autores
CREATE TABLE IF NOT EXISTS autores (
    autor_id SERIAL PRIMARY KEY,
    nome_autor VARCHAR(100) NOT NULL
);

-- Tabela de Livros
CREATE TABLE IF NOT EXISTS livros (
    livro_id SERIAL PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    autor_id INT REFERENCES autores(autor_id)
);

-- Tabela de Usuários (Alunos)
CREATE TABLE IF NOT EXISTS usuarios (
    usuario_id SERIAL PRIMARY KEY,
    nome_usuario VARCHAR(100) NOT NULL
);

-- Tabela de Empréstimos
CREATE TABLE IF NOT EXISTS emprestimos (
    emprestimo_id SERIAL PRIMARY KEY,
    usuario_id INT REFERENCES usuarios(usuario_id),
    livro_id INT REFERENCES livros(livro_id),
    data_emprestimo DATE NOT NULL,
    data_devolucao DATE
);

-- Inserir autores (obrigatório inserir antes dos livros)
INSERT INTO autores (nome_autor) VALUES ('Sophia'), ('Marcos'), ('Luis');

-- Inserir livros com IDs de autores válidos
INSERT INTO livros (titulo, autor_id) VALUES 
('Pequeno Príncipe', 1),
('Diário de um Banana', 2),
('Maus', 3);

-- Inserir alunos (usuários)
INSERT INTO usuarios (nome_usuario) VALUES 
('Caio'), 
('Arthur'), 
('Luiz'), 
('Gabriel');

-- Inserir empréstimos com IDs válidos
INSERT INTO emprestimos (usuario_id, livro_id, data_emprestimo, data_devolucao) VALUES
(1, 1, '2024-05-01', '2024-05-10'),  -- Caio emprestou Pequeno Príncipe
(2, 2, '2024-06-15', '2024-06-25'),  -- Arthur emprestou Diário de um Banana
(3, 3, '2024-07-01', NULL),          -- Luiz emprestou Maus (em andamento)
(4, 1, '2024-10-10', '2024-10-20');  -- Gabriel emprestou Pequeno Príncipe

-- Consulta final para exibir nomes no lugar dos IDs
SELECT 
    e.emprestimo_id,
    u.nome_usuario AS nome_aluno,
    l.titulo AS nome_livro,
    a.nome_autor AS nome_autor,
    e.data_emprestimo,
    e.data_devolucao
FROM emprestimos e
JOIN livros l ON e.livro_id = l.livro_id
JOIN autores a ON l.autor_id = a.autor_id
JOIN usuarios u ON e.usuario_id = u.usuario_id;


-----------------------------------------------------------------------
-- Função para calcular a multa de empréstimos atrasados
CREATE OR REPLACE FUNCTION calcular_multa(data_devolucao DATE, data_prevista DATE, taxa_diaria NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    dias_atraso INT;
BEGIN
    -- Calcula o número de dias de atraso
    dias_atraso := GREATEST(0, data_devolucao - data_prevista);
    -- Calcula o valor total da multa
    RETURN dias_atraso * taxa_diaria;
END;
$$ LANGUAGE plpgsql;

-- Exemplo de uso:
SELECT calcular_multa('2024-11-10', '2024-11-05', 2.50);

----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS relatorio_leitura(integer);

-- Função para gerar um relatório dos livros lidos por um usuário nos últimos 6 meses
CREATE OR REPLACE FUNCTION relatorio_leitura_dias(usuario_id_input INT)
RETURNS TABLE(
    livro_id INT, 
    titulo VARCHAR, 
    tempo_medio_em_dias NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.livro_id,
        l.titulo,
        ROUND(AVG(e.data_devolucao - e.data_emprestimo), 2) AS tempo_medio_em_dias -- Média em dias com 2 casas decimais
    FROM emprestimos e
    JOIN livros l ON e.livro_id = l.livro_id
    WHERE e.usuario_id = usuario_id_input
      AND e.data_emprestimo >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY l.livro_id, l.titulo;
END;
$$ LANGUAGE plpgsql;




-- Exemplo de uso:
SELECT * FROM relatorio_leitura_dias(2);

----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS popularidade_autores;

-- Função para gerar um relatório dos livros lidos por um usuário nos últimos 6 meses
CREATE OR REPLACE FUNCTION popularidade_autores()
RETURNS TABLE(nome_autor VARCHAR, total_emprestimos INT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.nome_autor, 
        CAST(COUNT(e.emprestimo_id) AS INT) AS total_emprestimos -- Conversão de bigint para int
    FROM autores a
    JOIN livros l ON a.autor_id = l.autor_id
    JOIN emprestimos e ON l.livro_id = e.livro_id
    GROUP BY a.nome_autor
    ORDER BY total_emprestimos DESC;
END;
$$ LANGUAGE plpgsql;


-- Exemplo de uso:
SELECT * FROM popularidade_autores();

----------------------------------------------------------------------------
-- Consulta de Empréstimos Detalhados
SELECT 
    e.emprestimo_id,
    u.nome_usuario AS nome_aluno,
    l.titulo AS nome_livro,
    a.nome_autor AS nome_autor,
    e.data_emprestimo,
    e.data_devolucao
FROM emprestimos e
JOIN usuarios u ON e.usuario_id = u.usuario_id
JOIN livros l ON e.livro_id = l.livro_id
JOIN autores a ON l.autor_id = a.autor_id;


--Consulta de Todos os Livros
SELECT 
    l.livro_id,
    l.titulo AS nome_livro,
    a.nome_autor AS nome_autor
FROM livros l
JOIN autores a ON l.autor_id = a.autor_id;

--Consulta de Todos os Alunos (Usuários)
SELECT 
    u.usuario_id AS id_aluno,
    u.nome_usuario AS nome_aluno
FROM usuarios u;

--Consulta Geral de Empréstimos com Tempo de Atraso
SELECT 
    e.emprestimo_id,
    u.nome_usuario AS nome_aluno,
    l.titulo AS nome_livro,
    e.data_emprestimo,
    e.data_devolucao,
    GREATEST(0, e.data_devolucao - (e.data_emprestimo + INTERVAL '14 days')) AS dias_atraso,
    GREATEST(0, e.data_devolucao - (e.data_emprestimo + INTERVAL '14 days')) * 2.50 AS multa -- Supondo taxa diária de R$ 2,50
FROM emprestimos e
JOIN usuarios u ON e.usuario_id = u.usuario_id
JOIN livros l ON e.livro_id = l.livro_id;

--Consulta de Popularidade de Autores
SELECT 
    a.nome_autor AS nome_autor,
    COUNT(e.emprestimo_id) AS total_emprestimos
FROM autores a
JOIN livros l ON a.autor_id = l.autor_id
JOIN emprestimos e ON l.livro_id = e.livro_id
GROUP BY a.nome_autor
ORDER BY total_emprestimos DESC;

--Consulta de Livros Lidos por Cada Aluno
SELECT 
    u.nome_usuario AS nome_aluno,
    l.titulo AS nome_livro,
    a.nome_autor AS nome_autor,
    e.data_emprestimo,
    e.data_devolucao
FROM emprestimos e
JOIN usuarios u ON e.usuario_id = u.usuario_id
JOIN livros l ON e.livro_id = l.livro_id
JOIN autores a ON l.autor_id = a.autor_id
ORDER BY u.nome_usuario, e.data_emprestimo;

--Visualização Geral
CREATE OR REPLACE VIEW emprestimos_detalhados AS
SELECT 
    e.emprestimo_id,
    u.nome_usuario AS nome_aluno,
    l.titulo AS nome_livro,
    a.nome_autor AS nome_autor,
    e.data_emprestimo,
    e.data_devolucao
FROM emprestimos e
JOIN usuarios u ON e.usuario_id = u.usuario_id
JOIN livros l ON e.livro_id = l.livro_id
JOIN autores a ON l.autor_id = a.autor_id;

-- comando vizul total
SELECT * FROM emprestimos_detalhados;

