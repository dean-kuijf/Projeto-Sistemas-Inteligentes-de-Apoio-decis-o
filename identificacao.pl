% ======================================================================
% MÓDULO DE IDENTIFICAÇÃO E PERSISTÊNCIA (identificacao.pl)
% ======================================================================

:- dynamic doente_registo/3.

% Carrega os utentes existentes do ficheiro CSV para a memoria.
% E executado automaticamente quando o sistema arranca.
carregar_utentes :-
    exists_file('utentes.csv'),
    !,
    setup_call_cleanup(
        open('utentes.csv', read, Stream),
        processar_linhas_csv(Stream),
        close(Stream)
    ).
carregar_utentes :-
    nl, write('AVISO: Ficheiro "utentes.csv" nao encontrado. Nenhum utente foi pre-carregado.'), nl.

processar_linhas_csv(Stream) :-
    read_line_to_string(Stream, Line),
    (   Line == end_of_file -> true
    ;   (   split_string(Line, ",", "\"", [NIF_Str, Nome, Idade_Str]),
            number_string(NIF, NIF_Str),
            number_string(Idade, Idade_Str),
            \+ doente_registo(NIF, _, _), % Evita duplicados se ja estiver em memoria
            assertz(doente_registo(NIF, Nome, Idade))
        ;   true % Ignora linhas mal formatadas ou duplicados
        ),
        processar_linhas_csv(Stream)
    ).

% ======================================================================
% SISTEMA DE GRAVAÇÃO (I/O)
% ======================================================================


guardar_utente_csv(NIF, Nome, Idade) :-
    open('utentes.csv', append, Stream),
    format(Stream, '~w,"~w",~w~n', [NIF, Nome, Idade]), 
    close(Stream).

guardar_triagem_csv(NIF, Sintoma, Destino, Certeza) :-
    get_time(T), stamp_date_time(T, DT, local), format_time(string(DH), '%Y-%m-%d %H:%M', DT),
    % Use setup_call_cleanup for safe file handling
    setup_call_cleanup(
        open('triagens.csv', append, Stream),
        format(Stream, '~w,"~w","~w","~w",~2f~n', [NIF, DH, Sintoma, Destino, Certeza]),
        close(Stream)
    ).

% Lê o ficheiro de triagens e devolve uma lista de entradas para um NIF específico.
ler_historico_utente(NIF_Num, ListaHistorico) :-
    (   exists_file('triagens.csv') ->
        setup_call_cleanup(
            open('triagens.csv', read, Stream),
            ler_linhas_historico(Stream, NIF_Num, ListaHistorico),
            close(Stream)
        )
    ;   ListaHistorico = [] % Se o ficheiro não existir, retorna uma lista vazia.
    ).

ler_linhas_historico(Stream, NIF_Num, Lista) :-
    read_line_to_string(Stream, Line),
    (   Line == end_of_file ->
        Lista = []
    ;   ler_linhas_historico(Stream, NIF_Num, Resto), % Chamada recursiva primeiro
        (   split_string(Line, ",", "\"", [NIF_Str, Data, Sintoma, Destino, CertezaStr]),
            number_string(NIF_Linha, NIF_Str),
            NIF_Linha == NIF_Num
        ->  number_string(CertezaNum, CertezaStr),
            Entrada = _{data:Data, sintoma:Sintoma, destino:Destino, certeza:CertezaNum},
            Lista = [Entrada|Resto] % Adiciona a entrada correspondente à cabeça da lista
        ;   Lista = Resto % Se o NIF não corresponder, ignora a linha
        )
    ).