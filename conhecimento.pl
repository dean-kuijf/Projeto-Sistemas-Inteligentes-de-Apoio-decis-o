:- encoding(utf8).
% ======================================================================
% BASE DE CONHECIMENTO - TRIAGEM SNS24 (Adaptado para Incerteza)
% ======================================================================
% Este ficheiro traduz as regras booleanas do sistema 1_dean
% para um modelo com Fatores de Certeza (CF).
% ======================================================================

% --- 1. DICIONÁRIO DE PERGUNTAS ---
% Mantido do ficheiro 1_dean_kb.pl para que o motor de inferência possa obter o texto das perguntas.

texto_pergunta(emergencia, 'Tem alguma das seguintes situacoes: alteracao da consciencia, convulsao, engasgamento, falta de ar grave, dor no peito ou acidente recente?').
texto_pergunta(sintomas_respiratorios, 'Tem algum sintoma respiratorio como falta de ar, tosse ou congestao nasal?').
texto_pergunta(problema_garganta, 'Tem algum problema na garganta?').
texto_pergunta(dormir_sentado, 'Tem de dormir sentado ou tem cansaco grave em atividades do dia-a-dia?').
texto_pergunta(tosse_sangue, 'Tem tosse com saida de sangue vivo?').
texto_pergunta(febre, 'Tem temperatura igual ou superior a 37,8 graus?').
texto_pergunta(pieira, 'Tem pieira (som tipo apito) ao respirar?').
texto_pergunta(inalador_sem_melhoria, 'Fez tratamento com inalador e nao melhorou?').
texto_pergunta(pieira_intensa, 'A pieira impede-o de fazer a sua vida normal?').
texto_pergunta(febre_nao_cede, 'Tomou medicamento para a febre ha mais de 2h e a febre continua?').
texto_pergunta(imunossuprimido, 'E doente imunossuprimido (ex: quimioterapia)?').
texto_pergunta(gastricos_prolongados, 'Tem vomitos ou diarreia ha mais de 12 horas?').
texto_pergunta(sinais_desidratacao, 'Tem urina reduzida, lingua seca ou tonturas?').
texto_pergunta(febre_3_dias, 'Tem febre ha mais de 3 dias completos?').
texto_pergunta(doencas_cronicas, 'Tem mais de 60 anos ou doencas cronicas (Diabetes, Asma, etc.)?').
texto_pergunta(tosse_ou_pieira, 'Tem tosse ou pieira?').
texto_pergunta(sintomas_gripais, 'Tem corrimento nasal ou dores nos musculos?').
texto_pergunta(olfato_paladar, 'Apresenta alteracao do olfato ou do paladar?').


% --- 2. REGRAS DE PRODUÇÃO COM FATORES DE CERTEZA (CF) ---
% NOTA: As regras assumem predicados como `verifica_exato/3`, `verifica_negativo/3` e `minimo/3` definidos no motor de inferência.

% --- REGRAS DE PRIORIDADE ALTA (EMERGÊNCIA) ---

% Regra 1: Emergência
encaminhamento(emergencia_112, 'Presença de sinais de emergência vital (alteração da consciência, convulsão, engasgamento, etc.).', CF_Final) :-
    verifica_exato(sintoma, emergencia, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 1.0,
    CF_Final is CF_Premissa * CF_Regra.

% Regra 2: Dificuldade Respiratória Grave
encaminhamento(urgencia_hospitalar, 'Dificuldade respiratória grave, indicada pela necessidade de dormir sentado ou cansaço extremo.', CF_Final) :-
    verifica_negativo(sintoma, emergencia, CF_Nao_Emergencia),
    verifica_exato(sintoma, sintomas_respiratorios, CF_Resp),
    verifica_exato(sintoma, dormir_sentado, CF_Dormir),
    minimo(CF_Nao_Emergencia, CF_Resp, CF_Temp),
    minimo(CF_Temp, CF_Dormir, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.95,
    CF_Final is CF_Premissa * CF_Regra.

% Regra 3: Hemoptise (Sangue na Tosse)
encaminhamento(urgencia_hospitalar, 'Tosse com sangue (hemoptise), um sinal de alarme que requer avaliação hospitalar.', CF_Final) :-
    verifica_negativo(sintoma, emergencia, CF_Nao_Emergencia),
    verifica_exato(sintoma, sintomas_respiratorios, CF_Resp),
    verifica_negativo(sintoma, dormir_sentado, CF_Nao_Dormir),
    verifica_exato(sintoma, tosse_sangue, CF_Sangue),
    minimo(CF_Nao_Emergencia, CF_Resp, T1),
    minimo(T1, CF_Nao_Dormir, T2),
    minimo(T2, CF_Sangue, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.95,
    CF_Final is CF_Premissa * CF_Regra.

% --- REGRAS DE URGÊNCIA HOSPITALAR ---

% Regra 4: Crise Respiratória sem Melhoria
encaminhamento(urgencia_hospitalar, 'Crise respiratória com febre e pieira que não melhora com inalador.', CF_Final) :-
    verifica_exato(sintoma, sintomas_respiratorios, CF_Resp),
    verifica_exato(sintoma, febre, CF_Febre),
    verifica_exato(sintoma, pieira, CF_Pieira),
    verifica_exato(sintoma, inalador_sem_melhoria, CF_Inalador),
    minimo(CF_Resp, CF_Febre, T1),
    minimo(T1, CF_Pieira, T2),
    minimo(T2, CF_Inalador, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.90,
    CF_Final is CF_Premissa * CF_Regra.

% Regra 5: Pieira Incapacitante
encaminhamento(urgencia_hospitalar, 'Pieira intensa que impede as atividades normais, mesmo sem falha do inalador.', CF_Final) :-
    verifica_exato(sintoma, pieira, CF_Pieira),
    verifica_negativo(sintoma, inalador_sem_melhoria, CF_Nao_Inalador),
    verifica_exato(sintoma, pieira_intensa, CF_Intensa),
    minimo(CF_Pieira, CF_Nao_Inalador, T1),
    minimo(T1, CF_Intensa, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.90,
    CF_Final is CF_Premissa * CF_Regra.

% Regra 7: Doente Imunossuprimido com Febre
encaminhamento(urgencia_hospitalar, 'Doente imunossuprimido (ex: quimioterapia) com febre é uma situação de risco elevado.', CF_Final) :-
    verifica_exato(sintoma, febre, CF_Febre),
    verifica_exato(risco, imunossuprimido, CF_Imuno),
    minimo(CF_Febre, CF_Imuno, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.90,
    CF_Final is CF_Premissa * CF_Regra.

% Regra 8: Desidratação Grave
encaminhamento(urgencia_hospitalar, 'Sinais de desidratação grave (urina reduzida, boca seca) com vómitos/diarreia prolongados.', CF_Final) :-
    verifica_exato(sintoma, gastricos_prolongados, CF_Gastricos),
    verifica_exato(sintoma, sinais_desidratacao, CF_Desidratacao),
    minimo(CF_Gastricos, CF_Desidratacao, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.90,
    CF_Final is CF_Premissa * CF_Regra.

% --- REGRAS DE CONTACTO COM PROFISSIONAL DE SAÚDE ---

% Regra 6: Febre que não cede
encaminhamento(consulta_medica, 'Febre que não baixa com medicação, requerendo avaliação médica.', CF_Final) :-
    verifica_exato(sintoma, febre, CF_Febre),
    verifica_exato(sintoma, febre_nao_cede, CF_NaoCede),
    minimo(CF_Febre, CF_NaoCede, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.80,
    CF_Final is CF_Premissa * CF_Regra.

% Regra 9: Febre e Sintomas Gástricos Prolongados
encaminhamento(contacto_sns24, 'Febre há mais de 3 dias com sintomas gástricos, mas sem sinais de desidratação grave.', CF_Final) :-
    verifica_exato(sintoma, gastricos_prolongados, CF_Gastricos),
    verifica_negativo(sintoma, sinais_desidratacao, CF_Nao_Desidratacao),
    verifica_exato(sintoma, febre_3_dias, CF_Febre3d),
    minimo(CF_Gastricos, CF_Nao_Desidratacao, T1),
    minimo(T1, CF_Febre3d, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.75,
    CF_Final is CF_Premissa * CF_Regra.

% Regra 10: Grupo de Risco com Febre
encaminhamento(contacto_sns24, 'Paciente com mais de 60 anos ou doenças crónicas que apresenta febre.', CF_Final) :-
    verifica_exato(sintoma, febre, CF_Febre),
    verifica_exato(risco, doencas_cronicas, CF_Risco),
    minimo(CF_Febre, CF_Risco, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.75,
    CF_Final is CF_Premissa * CF_Regra.

% --- REGRAS DE AUTO-CUIDADOS E VIGILÂNCIA ---

% Regra 11: Alteração do Olfato/Paladar
encaminhamento(autocuidados_vigilancia, 'Alteração do olfato ou paladar como sintoma isolado ou principal.', CF_Final) :-
    verifica_exato(sintoma, olfato_paladar, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.70,
    CF_Final is CF_Premissa * CF_Regra.

% Regra 12: Vigilância Domiciliária
encaminhamento(autocuidados_vigilancia, 'Sintomas respiratórios com febre, mas sem sinais de alarme ou alteração do olfato/paladar.', CF_Final) :-
    verifica_negativo(sintoma, emergencia, CF_Nao_Emergencia),
    verifica_exato(sintoma, sintomas_respiratorios, CF_Resp),
    verifica_exato(sintoma, febre, CF_Febre),
    verifica_negativo(sintoma, olfato_paladar, CF_Nao_Olfato),
    minimo(CF_Nao_Emergencia, CF_Resp, T1),
    minimo(T1, CF_Febre, T2),
    minimo(T2, CF_Nao_Olfato, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.60,
    CF_Final is CF_Premissa * CF_Regra.

% Regra 13: Sem Sintomas Relevantes
encaminhamento(autocuidados, 'Ausência de sintomas de emergência, respiratórios ou de garganta.', CF_Final) :-
    verifica_negativo(sintoma, emergencia, CF_Nao_Emergencia),
    verifica_negativo(sintoma, sintomas_respiratorios, CF_Nao_Resp),
    verifica_negativo(sintoma, problema_garganta, CF_Nao_Garganta),
    minimo(CF_Nao_Emergencia, CF_Nao_Resp, T1),
    minimo(T1, CF_Nao_Garganta, CF_Premissa),
    CF_Premissa >= 0.5,
    CF_Regra = 0.50,
    CF_Final is CF_Premissa * CF_Regra.