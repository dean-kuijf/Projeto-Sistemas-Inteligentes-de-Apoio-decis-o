:- encoding(utf8).
% ======================================================================
% MOTOR DE INFERÊNCIA E INCERTEZA
% ======================================================================

minimo(A, B, Min) :- A =< B, Min = A.
minimo(A, B, Min) :- A > B, Min = B.

% --- Predicados de Verificação ---
% Usam o dicionário texto_pergunta/2 (de conhecimento.pl) para obter o texto das perguntas.

% verifica_incerteza(Atributo, Valor, CF)
% Pergunta ao utilizador um valor de 0-10 e converte para um CF de 0.0-1.0.
% Memoriza a resposta para não perguntar novamente.
verifica_incerteza(Atributo, Valor, CF) :- 
    Facto =.. [Atributo, Valor, CF], call(Facto), !. % A resposta já existe na memória
verifica_incerteza(Atributo, Valor, CF) :- 
    % Se a resposta não existe, lança uma exceção para perguntar ao utilizador.
    texto_pergunta(Valor, TextoPergunta),
    throw(question(Valor, TextoPergunta, scale)). % Tipo 'scale' para 0-10

% verifica_exato(Atributo, Valor, CF)
% Pergunta sim/não. Se 'sim', sucede com CF=1.0. Se 'não', falha.
% Memoriza a resposta para não perguntar novamente.
verifica_exato(Atributo, Valor, 1.0) :- 
    Facto =.. [Atributo, Valor, 1.0], call(Facto), !. % Resposta 'sim' (1.0) já existe
verifica_exato(_, Valor, _) :- 
    nao_tem(Valor), !, fail. % Resposta 'não' já existe
verifica_exato(Atributo, Valor, 1.0) :- 
    % Se a resposta não existe, lança uma exceção para perguntar ao utilizador.
    texto_pergunta(Valor, TextoPergunta),
    throw(question(Valor, TextoPergunta, sn)). % Tipo 'sn' para sim/não

% verifica_negativo(Atributo, Valor, CF)
% Pergunta sim/não. Se 'não', sucede com CF=1.0. Se 'sim', falha.
% Memoriza a resposta para não perguntar novamente.
verifica_negativo(Atributo, Valor, 1.0) :-
    nao_tem(Valor), !. % Resposta 'não' já existe
verifica_negativo(Atributo, Valor, _) :-
    Facto =.. [Atributo, Valor, 1.0], call(Facto), !, fail. % Resposta 'sim' já existe
verifica_negativo(Atributo, Valor, 1.0) :-
    % Se a resposta não existe, lança uma exceção para perguntar ao utilizador.
    texto_pergunta(Valor, TextoPergunta),
    throw(question(Valor, TextoPergunta, sn)). % Tipo 'sn' para sim/não