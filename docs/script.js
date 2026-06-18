// Echo Web App - Main JavaScript
// Transcription, recording, file upload, and history management

// Initialize Web Speech API
const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
let recognition = null;

// State management
const state = {
    isRecording: false,
    recordingStartTime: null,
    recordingDuration: 0,
    currentTranscription: '',
    history: [],
    selectedLanguage: 'auto',
    uploadLanguage: 'auto',
    timerInterval: null,
};

// DOM elements
const recordBtn = document.getElementById('recordBtn');
const recordStatus = document.getElementById('recordStatus');
const recordTime = document.getElementById('recordTime');
const languageSelect = document.getElementById('languageSelect');
const uploadLanguageSelect = document.getElementById('uploadLanguageSelect');
const uploadArea = document.getElementById('uploadArea');
const fileInput = document.getElementById('fileInput');
const transcriptionArea = document.getElementById('transcriptionArea');
const transcriptionText = document.getElementById('transcriptionText');
const transcriptionMeta = document.getElementById('transcriptionMeta');
const copyBtn = document.getElementById('copyBtn');
const downloadBtn = document.getElementById('downloadBtn');
const closeTranscriptionBtn = document.getElementById('closeTranscriptionBtn');
const historyList = document.getElementById('historyList');
const clearHistoryBtn = document.getElementById('clearHistoryBtn');
const settingsBtn = document.getElementById('settingsBtn');
const settingsModal = document.getElementById('settingsModal');
const closeSettingsBtn = document.getElementById('closeSettingsBtn');
const modalOverlay = document.getElementById('modalOverlay');
const themeBtn = document.getElementById('themeBtn');
const tabs = document.querySelectorAll('.tab-btn');
const tabContents = document.querySelectorAll('.tab-content');
const exportHistoryBtn = document.getElementById('exportHistoryBtn');
const importHistoryBtn = document.getElementById('importHistoryBtn');
const historyFileInput = document.getElementById('historyFileInput');
const waveformBars = document.getElementById('waveformBars');
const waveformCanvas = document.getElementById('waveformCanvas');

// Initialize app
function init() {
    setupSpeechRecognition();
    loadHistory();
    setupEventListeners();
    applyThemePreference();
    renderHistory();
}

// Setup Web Speech API
function setupSpeechRecognition() {
    if (!SpeechRecognition) {
        recordBtn.disabled = true;
        recordStatus.textContent = 'Speech recognition not supported in your browser';
        return;
    }

    recognition = new SpeechRecognition();
    recognition.continuous = true;
    recognition.interimResults = true;

    recognition.onstart = () => {
        state.isRecording = true;
        state.recordingStartTime = Date.now();
        recordBtn.classList.add('recording');
        recordStatus.textContent = 'Listening...';
        startTimer();
    };

    recognition.onresult = (event) => {
        let interimTranscript = '';
        let finalTranscript = '';

        for (let i = event.resultIndex; i < event.results.length; i++) {
            const transcript = event.results[i][0].transcript;
            if (event.results[i].isFinal) {
                finalTranscript += transcript + ' ';
            } else {
                interimTranscript += transcript;
            }
        }

        if (finalTranscript) {
            state.currentTranscription += finalTranscript;
        }

        const displayText = state.currentTranscription + interimTranscript;
        recordStatus.textContent = displayText || 'Listening...';
    };

    recognition.onerror = (event) => {
        console.error('Speech recognition error:', event.error);
        recordStatus.textContent = `Error: ${event.error}`;
    };

    recognition.onend = () => {
        state.isRecording = false;
        recordBtn.classList.remove('recording');
        stopTimer();
        if (state.currentTranscription.trim()) {
            displayTranscription(state.currentTranscription.trim(), state.recordingDuration);
            addToHistory(state.currentTranscription.trim(), state.recordingDuration);
        }
        state.currentTranscription = '';
        updateWaveform(0);
    };
}

// Recording controls
recordBtn.addEventListener('click', () => {
    if (!state.isRecording) {
        state.currentTranscription = '';
        state.selectedLanguage = languageSelect.value;

        // Set language for Web Speech API
        const languageCode = state.selectedLanguage === 'auto' ? 'en-US' : mapLanguageToCode(state.selectedLanguage);
        recognition.language = languageCode;

        recognition.start();
    } else {
        recognition.stop();
    }
});

// File upload handling
uploadArea.addEventListener('click', () => fileInput.click());

uploadArea.addEventListener('dragover', (e) => {
    e.preventDefault();
    uploadArea.style.borderColor = 'var(--primary)';
    uploadArea.style.background = 'rgba(124, 58, 237, 0.05)';
});

uploadArea.addEventListener('dragleave', () => {
    uploadArea.style.borderColor = 'var(--border)';
    uploadArea.style.background = 'var(--bg-secondary)';
});

uploadArea.addEventListener('drop', (e) => {
    e.preventDefault();
    uploadArea.style.borderColor = 'var(--border)';
    uploadArea.style.background = 'var(--bg-secondary)';

    const files = e.dataTransfer.files;
    if (files.length > 0) {
        processFile(files[0]);
    }
});

fileInput.addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
        processFile(e.target.files[0]);
    }
});

function processFile(file) {
    const reader = new FileReader();
    reader.onload = (e) => {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();

        audioContext.decodeAudioData(e.target.result, (audioBuffer) => {
            const duration = Math.round(audioBuffer.duration);

            // Transcribe audio file using Web Speech API via blob
            const offlineContext = new OfflineAudioContext(
                audioBuffer.numberOfChannels,
                audioBuffer.length,
                audioBuffer.sampleRate
            );

            const source = offlineContext.createBufferSource();
            source.buffer = audioBuffer;
            source.connect(offlineContext.destination);
            source.start();

            // Use Web Audio API to get audio data and transcribe
            transcribeAudioBuffer(audioBuffer, duration);
        });
    };
    reader.readAsArrayBuffer(file);
}

function transcribeAudioBuffer(audioBuffer, duration) {
    // Create a simple Web Speech API transcription for file upload
    // In production, this would use a proper audio transcription service
    recordStatus.textContent = 'Transcribing audio file...';
    state.selectedLanguage = uploadLanguageSelect.value;

    // Simulate transcription (in real app, would use actual audio data)
    setTimeout(() => {
        const transcription = 'Audio transcription would appear here with a real service integration.';
        displayTranscription(transcription, duration);
        addToHistory(transcription, duration);
        recordStatus.textContent = 'Press record to start';
    }, 2000);
}

// Transcription display
function displayTranscription(text, duration) {
    transcriptionText.textContent = text;
    const durationText = formatDuration(duration);
    transcriptionMeta.textContent = `Duration: ${durationText}`;
    transcriptionArea.style.display = 'block';

    // Scroll to transcription
    transcriptionArea.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// History management
function addToHistory(text, duration) {
    const entry = {
        id: Date.now(),
        text: text,
        date: new Date().toISOString(),
        duration: duration,
        language: state.selectedLanguage,
    };

    state.history.unshift(entry);

    // Cap at 50 entries
    if (state.history.length > 50) {
        state.history.pop();
    }

    saveHistory();
    renderHistory();
}

function loadHistory() {
    const saved = localStorage.getItem('echo-history');
    if (saved) {
        try {
            state.history = JSON.parse(saved);
        } catch (e) {
            console.error('Failed to load history:', e);
            state.history = [];
        }
    }
}

function saveHistory() {
    localStorage.setItem('echo-history', JSON.stringify(state.history));
}

function renderHistory() {
    if (state.history.length === 0) {
        historyList.innerHTML = '<p class="history-empty">No transcriptions yet</p>';
        return;
    }

    historyList.innerHTML = state.history.map(entry => {
        const date = new Date(entry.date);
        const dateStr = formatDate(date);
        const preview = entry.text.substring(0, 100) + (entry.text.length > 100 ? '...' : '');

        return `
            <div class="history-item" data-id="${entry.id}">
                <div class="history-item-text">${escapeHtml(preview)}</div>
                <div class="history-item-date">${dateStr}</div>
                <div class="history-item-actions">
                    <button class="btn-icon-small copy-history" data-id="${entry.id}">Copy</button>
                    <button class="btn-icon-small view-history" data-id="${entry.id}">View</button>
                    <button class="btn-icon-small delete-history" data-id="${entry.id}">Delete</button>
                </div>
            </div>
        `;
    }).join('');

    // Add event listeners to history buttons
    document.querySelectorAll('.copy-history').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const id = parseInt(btn.dataset.id);
            const entry = state.history.find(h => h.id === id);
            if (entry) {
                navigator.clipboard.writeText(entry.text);
                btn.textContent = 'Copied!';
                setTimeout(() => btn.textContent = 'Copy', 2000);
            }
        });
    });

    document.querySelectorAll('.view-history').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const id = parseInt(btn.dataset.id);
            const entry = state.history.find(h => h.id === id);
            if (entry) {
                displayTranscription(entry.text, entry.duration);
            }
        });
    });

    document.querySelectorAll('.delete-history').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const id = parseInt(btn.dataset.id);
            state.history = state.history.filter(h => h.id !== id);
            saveHistory();
            renderHistory();
        });
    });
}

// Transcription controls
copyBtn.addEventListener('click', () => {
    navigator.clipboard.writeText(state.currentTranscription || transcriptionText.textContent);
    copyBtn.textContent = 'Copied!';
    setTimeout(() => copyBtn.textContent = 'Copy', 2000);
});

downloadBtn.addEventListener('click', () => {
    const text = transcriptionText.textContent;
    const element = document.createElement('a');
    element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
    element.setAttribute('download', `transcription-${Date.now()}.txt`);
    element.style.display = 'none';
    document.body.appendChild(element);
    element.click();
    document.body.removeChild(element);
});

closeTranscriptionBtn.addEventListener('click', () => {
    transcriptionArea.style.display = 'none';
});

// History controls
clearHistoryBtn.addEventListener('click', () => {
    if (confirm('Are you sure you want to clear all history?')) {
        state.history = [];
        saveHistory();
        renderHistory();
    }
});

// Tab switching
tabs.forEach(tab => {
    tab.addEventListener('click', () => {
        const tabName = tab.dataset.tab;

        // Update active tab
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');

        // Update active content
        tabContents.forEach(content => content.classList.remove('active'));
        document.getElementById(`${tabName}-tab`).classList.add('active');
    });
});

// Settings modal
settingsBtn.addEventListener('click', () => {
    settingsModal.style.display = 'block';
    modalOverlay.style.display = 'block';
});

closeSettingsBtn.addEventListener('click', closeModal);
modalOverlay.addEventListener('click', closeModal);

function closeModal() {
    settingsModal.style.display = 'none';
    modalOverlay.style.display = 'none';
}

// Export/Import history
exportHistoryBtn.addEventListener('click', () => {
    const dataStr = JSON.stringify(state.history, null, 2);
    const element = document.createElement('a');
    element.setAttribute('href', 'data:application/json;charset=utf-8,' + encodeURIComponent(dataStr));
    element.setAttribute('download', `echo-history-${Date.now()}.json`);
    element.style.display = 'none';
    document.body.appendChild(element);
    element.click();
    document.body.removeChild(element);
});

importHistoryBtn.addEventListener('click', () => {
    historyFileInput.click();
});

historyFileInput.addEventListener('change', (e) => {
    if (e.target.files.length === 0) return;

    const reader = new FileReader();
    reader.onload = (event) => {
        try {
            const imported = JSON.parse(event.target.result);
            if (Array.isArray(imported)) {
                state.history = imported.slice(0, 50); // Cap at 50
                saveHistory();
                renderHistory();
                alert('History imported successfully!');
            }
        } catch (error) {
            alert('Failed to import history: ' + error.message);
        }
    };
    reader.readAsText(e.target.files[0]);
});

// Theme management
function applyThemePreference() {
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const saved = localStorage.getItem('echo-theme');
    const isDark = saved ? saved === 'dark' : prefersDark;

    if (isDark) {
        document.documentElement.classList.add('dark-mode');
    }
}

themeBtn.addEventListener('click', () => {
    const isDark = document.documentElement.classList.toggle('dark-mode');
    localStorage.setItem('echo-theme', isDark ? 'dark' : 'light');
});

// Timer
function startTimer() {
    state.recordingDuration = 0;
    state.timerInterval = setInterval(() => {
        state.recordingDuration++;
        recordTime.textContent = formatDuration(state.recordingDuration);
    }, 1000);
}

function stopTimer() {
    clearInterval(state.timerInterval);
}

// Waveform visualization
function updateWaveform(level) {
    const bars = document.querySelectorAll('.bar');
    bars.forEach((bar, index) => {
        const randomVariation = (Math.random() - 0.5) * 0.5;
        const height = Math.max(20, level * 80 + randomVariation * 80);
        bar.style.height = Math.min(100, height) + 'px';
    });
}

// Utility functions
function formatDuration(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${String(secs).padStart(2, '0')}`;
}

function formatDate(date) {
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;

    return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

function mapLanguageToCode(lang) {
    const codes = {
        'en': 'en-US',
        'es': 'es-ES',
        'fr': 'fr-FR',
        'de': 'de-DE',
        'it': 'it-IT',
        'pt': 'pt-BR',
        'ru': 'ru-RU',
        'ja': 'ja-JP',
        'ko': 'ko-KR',
        'zh': 'zh-CN',
        'ar': 'ar-SA',
    };
    return codes[lang] || 'en-US';
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Initialize on load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
