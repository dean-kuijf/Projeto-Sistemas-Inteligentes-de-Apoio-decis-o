:- encoding(utf8).
% ======================================================================
% SISTEMA DE TRIAGEM SNS24 - SERVIDOR WEB
% ======================================================================

% Carregar os módulos necessários
:- consult('conhecimento.pl').
:- consult('motor.pl').
:- consult('identificacao.pl').

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json_convert)).

% Carrega a base de dados de utentes do ficheiro CSV ao iniciar.
% Esta diretiva e executada assim que o ficheiro main.pl e carregado.
:- carregar_utentes.

% --- Ponto de Entrada do Servidor ---

% Inicia o servidor na porta 8000. Para usar, execute: ?- iniciar.
iniciar :-
    Port = 8000,
    http_server(http_dispatch, [port(Port)]),
    format('~n*** Servidor de Triagem SNS24 a correr em http://localhost:~w ***~n', [Port]).

% --- Definição de Rotas ---

% Handlers para servir os ficheiros estáticos (HTML, CSS, JS).
% A configuração anterior estava incorreta, impedindo o carregamento dos ficheiros.
:- http_handler(root(.), http_reply_file('index.html', []), []).      % Envia 'index.html' quando se acede a /
:- http_handler('/style.css', http_reply_file('style.css', []), []).  % Envia 'style.css' quando se acede a /style.css
:- http_handler('/script.js', http_reply_file('script.js', []), []).  % Envia 'script.js' quando se acede a /script.js
:- http_handler('/logo-SNS.png', http_reply_file('logo-SNS.png', []), []). % Envia o ficheiro do logótipo

:- http_handler('/api/user', handle_user_api, [method(post)]).
:- http_handler('/api/triage', handle_triage_api, [method(post)]).
:- http_handler('/api/history', handle_history_api, [method(post)]).

% --- Limpeza de Memória ---

% Limpa os factos dinâmicos da triagem atual.
limpa_memoria_triagem :-
    retractall(sintoma(_, _)),
    retractall(risco(_, _)),
    retractall(nao_tem(_)).

% --- API Handlers ---

% Handler para a API de utilizadores (/api/user)
handle_user_api(Request) :-
    http_read_json_dict(Request, JSON_In),
    (   JSON_In.action == "check" ->
        (   number_string(NIF_Num, JSON_In.nif), % Convert string NIF from JSON to number
            doente_registo(NIF_Num, Nome, Idade) ->
            reply_json_dict(_{found: true, user: _{nome: Nome, idade: Idade}})
        ;   reply_json_dict(_{found: false})
        )
    ;   JSON_In.action == "register" ->
        (   number_string(NIF_Num, JSON_In.nif), % Convert string NIF from JSON to number
            guardar_utente_csv(NIF_Num, JSON_In.nome, JSON_In.idade),
            assertz(doente_registo(NIF_Num, JSON_In.nome, JSON_In.idade)),
            reply_json_dict(_{success: true})
        )
    ).

% Handler para a API de triagem (/api/triage)
handle_triage_api(Request) :-
    http_read_json_dict(Request, JSON_In),
    number_string(NIF_Num, JSON_In.nif), % Convert NIF to number
    nb_delete(already_replied), % Limpa a flag de resposta para esta nova requisição
    limpa_memoria_triagem,
    processa_respostas(JSON_In.answers),
    
    % Tenta encontrar uma solução. Se uma pergunta for necessária, ela é "atirada" (thrown).
    catch(
        (   % Se o encaminhamento for encontrado
            encaminhamento(Destino, Justificacao, CF_Final), !,
            build_result_json(NIF_Num, Destino, Justificacao, CF_Final, JSON_Out),
            reply_json_dict(JSON_Out)
        ),
        question(Code, Text, Type),
        (   % Se uma pergunta for "atirada"
            build_question_json(Code, Text, Type, JSON_Out),
            reply_json_dict(JSON_Out),
            nb_setval(already_replied, true) % Flag para evitar resposta de erro
        )
    ),
    % Se o catch falhar (nenhuma regra correspondeu e nenhuma pergunta foi feita), envia erro.
    (   \+ nb_current(already_replied, true) ->
        build_error_json(NIF_Num, JSON_Out),
        reply_json_dict(JSON_Out)
    ;   true
    ).

% Constrói o JSON para uma pergunta
build_question_json(Code, Text, Type, _{type: "question", question: _{code: Code, text: Text, q_type: Type}}).

% Constrói o JSON para um resultado final bem-sucedido
build_result_json(NIF, Destino, Justificacao, CF_Final, JSON_Out) :-
    doente_registo(NIF, Nome, Idade),
    CF_Percentagem is CF_Final * 100,
    guardar_triagem_csv(NIF, 'triagem_geral', Destino, CF_Percentagem),
    JSON_Out = _{
        type: "result",
        result: _{
            destination: Destino,
            justification: Justificacao,
            certainty: CF_Percentagem,
            user: _{nif: NIF, nome: Nome, idade: Idade}
        }
    },
    nb_setval(already_replied, true). % Flag para evitar resposta de erro

% Constrói o JSON para um resultado de erro (nenhuma regra aplicável)
build_error_json(NIF, JSON_Out) :-
    doente_registo(NIF, Nome, Idade),
    JSON_Out = _{
        type: "result",
        result: _{
            destination: "error",
            justification: "Não foi possível determinar um encaminhamento com base nos sintomas fornecidos. Recomenda-se contactar a linha SNS24.",
            user: _{nif: NIF, nome: Nome, idade: Idade}
        }
    }.

% Processa as respostas do cliente e assevera-as na base de conhecimento
processa_respostas(Answers) :-
    dict_pairs(Answers, _, Pairs),
    forall(member(Code-Answer, Pairs), assert_resposta(Code, Answer)).

assert_resposta(Code, "s") :- assertz(sintoma(Code, 1.0)).
assert_resposta(Code, "n") :- assertz(nao_tem(Code)).
assert_resposta(Code, Answer) :- 
    number_string(Num, Answer),
    CF is Num / 10,
    ( atom_string(Code, S), sub_string(S, _, _, _, "risco_") ->
        assertz(risco(Code, CF))
    ;
        assertz(sintoma(Code, CF))
    ).

% Handler para a API de histórico (/api/history)
handle_history_api(Request) :-
    http_read_json_dict(Request, JSON_In),
    number_string(NIF_Num, JSON_In.nif),
    ler_historico_utente(NIF_Num, History),
    reply_json_dict(_{history: History}).