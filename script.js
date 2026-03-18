document.addEventListener('DOMContentLoaded', () => {
    // --- DOM Elements ---
    const idSection = document.getElementById('identification-section');
    const nifForm = document.getElementById('nif-form');
    const nifInput = document.getElementById('nif');
    const nifSubmitBtn = document.getElementById('nif-submit');
    const registrationForm = document.getElementById('registration-form');
    const nomeInput = document.getElementById('nome');
    const idadeInput = document.getElementById('idade');
    const registerSubmitBtn = document.getElementById('register-submit');
    const userWelcome = document.getElementById('user-welcome');
    const idError = document.getElementById('id-error');
    const welcomeContainer = document.getElementById('welcome-container');
    const proceedTriageBtn = document.getElementById('proceed-triage-btn');
    const themeToggleBtn = document.getElementById('theme-toggle-btn');
    const bodyEl = document.body;

    const triageSection = document.getElementById('triage-section');
    const questionContainer = document.getElementById('question-container');
    const loader = document.getElementById('loader');
    const triageError = document.getElementById('triage-error');

    const resultSection = document.getElementById('result-section');
    const resultContent = document.getElementById('result-content');
    const restartButton = document.getElementById('restart-button');

    const historySection = document.getElementById('history-section');
    const historyContent = document.getElementById('history-content');
    const historyBtn = document.getElementById('history-btn');
    const closeHistoryBtn = document.getElementById('close-history-btn');

    // --- State ---
    let triageState = {
        nif: null,
        answers: {} // { question_code: answer, ... }
    };

    // --- API Communication ---
    async function apiCall(endpoint, body) {
        try {
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            });
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return await response.json();
        } catch (error) {
            console.error(`Error calling ${endpoint}:`, error);
            return { error: `Não foi possível comunicar com o servidor. Verifique a sua conexão e tente novamente.` };
        }
    }

    // --- Identification Logic ---
    nifSubmitBtn.addEventListener('click', async () => {
        const nif = nifInput.value.trim();
        if (!/^\d{9}$/.test(nif)) {
            idError.textContent = 'NIF inválido. Por favor, introduza 9 dígitos numéricos.';
            return;
        }
        idError.textContent = '';
        triageState.nif = nif;

        const response = await apiCall('/api/user', { action: 'check', nif: triageState.nif });

        if (response.error) {
            idError.textContent = response.error;
        } else if (response.found) {
            showWelcome(response.user.nome, response.user.idade);
        } else {
            nifForm.classList.add('hidden');
            registrationForm.classList.remove('hidden');
        }
    });

    registerSubmitBtn.addEventListener('click', async () => {
        const nome = nomeInput.value.trim();
        const idade = idadeInput.value.trim();

        if (!nome || !idade || idade < 0) {
            idError.textContent = 'Por favor, preencha todos os campos corretamente.';
            return;
        }
        idError.textContent = '';

        const body = { action: 'register', nif: triageState.nif, nome, idade: parseInt(idade) };
        const response = await apiCall('/api/user', body);

        if (response.error) {
            idError.textContent = response.error;
        } else if (response.success) {
            showWelcome(nome, idade);
        }
    });
    
    function showWelcome(nome, idade) {
        nifForm.classList.add('hidden');
        registrationForm.classList.add('hidden');
        userWelcome.innerHTML = `Bem-vindo(a), <strong>${nome}</strong> (${idade} anos). Selecione uma opção para continuar.`;
        welcomeContainer.classList.remove('hidden');
    }

    // --- Triage Logic ---
    proceedTriageBtn.addEventListener('click', () => {
        startTriage();
    });

    async function startTriage() {
        idSection.classList.add('hidden');
        triageSection.classList.remove('hidden');
        getTriageStep();
    }

    async function getTriageStep() {
        const response = await apiCall('/api/triage', triageState);
        
        // Hide loader before showing content
        loader.classList.add('hidden');

        if (response.error) {
            triageError.textContent = response.error;
            questionContainer.classList.remove('hidden');
        } else if (response.type === 'question') {
            questionContainer.classList.remove('hidden');
            renderQuestion(response.question);
        } else if (response.type === 'result') {
            renderResult(response.result);
        }
    }

    function renderQuestion(question) {
        questionContainer.innerHTML = ''; // Clear previous question
        const questionBlock = document.createElement('div');
        questionBlock.className = 'question-block';

        let questionHTML = `<p>${question.text}</p><div class="question-buttons">`;

        if (question.q_type === 'sn') {
            questionHTML += `
                <button class="btn-yes" data-answer="s">Sim</button>
                <button class="btn-no" data-answer="n">Não</button>
            `;
        } else if (question.q_type === 'scale') {
            // For 0-10 scale, we can use a range slider or simple buttons
            questionHTML = `<p>${question.text}</p>
            <input type="range" id="scale-input" min="0" max="10" value="5" step="1" oninput="this.nextElementSibling.value = this.value">
            <output>5</output>
            <button id="scale-submit">Confirmar</button>
            `;
        }
        questionHTML += '</div>';
        questionBlock.innerHTML = questionHTML;
        questionContainer.appendChild(questionBlock);

        // Add event listeners
        if (question.q_type === 'sn') {
            questionBlock.querySelectorAll('button').forEach(button => {
                button.addEventListener('click', () => {
                    handleAnswer(question.code, button.dataset.answer);
                });
            });
        } else if (question.q_type === 'scale') {
            document.getElementById('scale-submit').addEventListener('click', () => {
                const value = document.getElementById('scale-input').value;
                handleAnswer(question.code, value);
            });
        }
    }

    function handleAnswer(code, answer) {
        triageState.answers[code] = answer;
        questionContainer.classList.add('hidden');
        questionContainer.innerHTML = ''; // Clear old question to prevent flash of old content
        loader.classList.remove('hidden');
        getTriageStep();
    }

    // --- Result Logic ---
    function renderResult(result) {
        triageSection.classList.add('hidden');
        resultSection.classList.remove('hidden');

        if (result.destination === 'error') {
            resultContent.innerHTML = `
                <h3>Não foi possível determinar o encaminhamento</h3>
                <p>${result.justification}</p>
                <p>Por favor, contacte o SNS24 (808 24 24 24) ou, em caso de emergência, o 112.</p>
            `;
        } else {
            resultContent.innerHTML = `
                <h3>Encaminhamento: <span style="color: #003f8a;">${result.destination.replace(/_/g, ' ')}</span></h3>
                <p><strong>Utente:</strong> ${result.user.nome} (NIF: ${result.user.nif})</p>
                <p><strong>Certeza do Diagnóstico:</strong> ${result.certainty.toFixed(2)}%</p>
                <hr>
                <p><strong>Justificação:</strong> ${result.justification}</p>
            `;
        }
    }

    // --- History Logic ---
    historyBtn.addEventListener('click', async () => {
        const response = await apiCall('/api/history', { nif: triageState.nif });
        if (response.error) {
            idError.textContent = response.error;
            return;
        }

        renderHistory(response.history);
        idSection.classList.add('hidden');
        historySection.classList.remove('hidden');
    });

    closeHistoryBtn.addEventListener('click', () => {
        historySection.classList.add('hidden');
        idSection.classList.remove('hidden');
    });

    function renderHistory(history) {
        if (!history || history.length === 0) {
            historyContent.innerHTML = '<p>Não existem registos de triagens anteriores para este utente.</p>';
            return;
        }

        let tableHTML = `
            <table class="history-table">
                <thead>
                    <tr>
                        <th>Data</th>
                        <th>Encaminhamento</th>
                        <th>Certeza</th>
                    </tr>
                </thead>
                <tbody>
        `;
        history.forEach(entry => {
            tableHTML += `
                <tr>
                    <td>${entry.data}</td>
                    <td>${entry.destino.replace(/_/g, ' ')}</td>
                    <td>${entry.certeza.toFixed(0)}%</td>
                </tr>
            `;
        });
        tableHTML += '</tbody></table>';
        historyContent.innerHTML = tableHTML;
    }

    // --- Restart Logic ---
    restartButton.addEventListener('click', () => {
        // Reset state
        triageState = { nif: null, answers: {} };

        // Reset UI
        resultSection.classList.add('hidden');
        triageSection.classList.add('hidden');
        historySection.classList.add('hidden');
        welcomeContainer.classList.add('hidden');
        loader.classList.add('hidden');
        questionContainer.classList.remove('hidden');
        questionContainer.innerHTML = '';
        idSection.classList.remove('hidden');
        
        nifForm.classList.remove('hidden');
        nifInput.value = '';
        
        registrationForm.classList.add('hidden');
        nomeInput.value = '';
        idadeInput.value = '';

        userWelcome.innerHTML = '';
        
        idError.textContent = '';
        triageError.textContent = '';
    });

    // --- Theme Switcher Logic ---
    function applyTheme(theme) {
        if (theme === 'dark') {
            bodyEl.classList.add('dark-mode');
            themeToggleBtn.textContent = '☀️';
        } else {
            bodyEl.classList.remove('dark-mode');
            themeToggleBtn.textContent = '🌙';
        }
    }

    themeToggleBtn.addEventListener('click', () => {
        const isDarkMode = bodyEl.classList.contains('dark-mode');
        const newTheme = isDarkMode ? 'light' : 'dark';
        localStorage.setItem('theme', newTheme);
        applyTheme(newTheme);
    });

    // Load saved theme on startup
    const savedTheme = localStorage.getItem('theme') || 'light';
    applyTheme(savedTheme);

});
