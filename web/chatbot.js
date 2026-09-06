(function() {
  'use strict';

  // ── Ticketto Assistant — AI Chat Widget ──
  const CONFIG = {
    project: 'ticketto',
    accent: '#0E6B52',
    position: 'right',
    apiUrl: 'https://api-ivufbp6etq-uc.a.run.app/api/v1/chatbot',
    icon: '🎫',
  };

  const STRINGS = {
    it: {
      welcome: 'Ciao! 🎫 Come posso aiutarti?',
      title: 'Ticketto Assistant',
      subtitle: 'Risposte in tempo reale con AI',
      placeholder: 'Scrivi un messaggio...',
      send: 'Invia',
      open: 'Apri assistente',
      error: 'Si è verificato un errore. Riprova.',
      connectionError: 'Connessione non riuscita. Verifica la tua connessione e riprova.',
      powered: 'Powered by Ticketto'
    },
    en: {
      welcome: 'Hello! 🎫 How can I help you?',
      title: 'Ticketto Assistant',
      subtitle: 'Real-time AI answers',
      placeholder: 'Type a message...',
      send: 'Send',
      open: 'Open assistant',
      error: 'An error occurred. Please try again.',
      connectionError: 'Connection failed. Please check your connection and try again.',
      powered: 'Powered by Ticketto'
    }
  };

  function getLang() {
    // 1. Check URL query parameter (lang=en or lang=it)
    const urlParams = new URLSearchParams(window.location.search);
    const langParam = urlParams.get('lang');
    if (langParam === 'en' || langParam === 'it') return langParam;

    // 2. Check localStorage
    try {
      const localLang = localStorage.getItem('ui_language');
      if (localLang === 'en' || localLang === 'it') return localLang;
    } catch (_) {}

    // 3. Check document element lang attribute
    const docLang = document.documentElement.lang;
    if (docLang === 'en' || docLang === 'it') return docLang;

    // 4. Check browser language
    const browserLang = (navigator.language || navigator.userLanguage || '').substring(0, 2);
    if (browserLang === 'en' || browserLang === 'it') return browserLang;

    return 'en'; // default fallback
  }

  function t(key) {
    const lang = getLang();
    return STRINGS[lang]?.[key] || STRINGS['en']?.[key] || '';
  }

  // ── State ──
  let isOpen = false;
  let isLoading = false;
  let messages = [];
  let sessionId = sessionStorage.getItem('_cb_sid') || crypto.randomUUID();
  sessionStorage.setItem('_cb_sid', sessionId);

  // ── Inject CSS ──
  const style = document.createElement('style');
  style.textContent = `
    #cb-widget * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }

    #cb-fab {
      position: fixed;
      bottom: 24px;
      right: 24px;
      width: 60px;
      height: 60px;
      border-radius: 50%;
      background: ${CONFIG.accent};
      color: white;
      border: none;
      cursor: pointer;
      box-shadow: 0 4px 16px rgba(0,0,0,0.2);
      z-index: 99999;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.2s, box-shadow 0.2s;
      animation: cb-pulse 2s infinite;
    }
    #cb-fab:hover { transform: scale(1.08); box-shadow: 0 6px 24px rgba(0,0,0,0.3); }
    #cb-fab.cb-open { animation: none; }
    #cb-fab svg { width: 28px; height: 28px; transition: transform 0.3s; }
    #cb-fab.cb-open svg { transform: rotate(90deg); }
    @keyframes cb-pulse {
      0%, 100% { box-shadow: 0 4px 16px rgba(0,0,0,0.2); }
      50% { box-shadow: 0 4px 16px ${CONFIG.accent}66; }
    }

    #cb-window {
      position: fixed;
      bottom: 100px;
      right: 24px;
      width: 380px;
      max-width: calc(100vw - 32px);
      height: 520px;
      max-height: calc(100vh - 140px);
      background: #ffffff;
      border-radius: 20px;
      box-shadow: 0 12px 48px rgba(0,0,0,0.15);
      z-index: 99998;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      opacity: 0;
      transform: translateY(20px) scale(0.95);
      pointer-events: none;
      transition: opacity 0.3s, transform 0.3s;
    }
    #cb-window.cb-visible {
      opacity: 1;
      transform: translateY(0) scale(1);
      pointer-events: all;
    }

    #cb-header {
      background: ${CONFIG.accent};
      color: white;
      padding: 16px 20px;
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
    }
    #cb-header-icon {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: rgba(255,255,255,0.2);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
    }
    #cb-header-text h3 { font-size: 15px; font-weight: 600; }
    #cb-header-text p { font-size: 11px; opacity: 0.85; margin-top: 2px; }

    #cb-messages {
      flex: 1;
      overflow-y: auto;
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
      scroll-behavior: smooth;
    }
    #cb-messages::-webkit-scrollbar { width: 4px; }
    #cb-messages::-webkit-scrollbar-thumb { background: #ddd; border-radius: 2px; }

    .cb-msg {
      max-width: 85%;
      padding: 10px 14px;
      border-radius: 16px;
      font-size: 14px;
      line-height: 1.5;
      word-break: break-word;
      animation: cb-fadein 0.3s;
    }
    .cb-msg a { color: ${CONFIG.accent}; text-decoration: underline; }
    .cb-msg ul, .cb-msg ol { padding-left: 18px; margin: 4px 0; }
    .cb-msg-user {
      align-self: flex-end;
      background: ${CONFIG.accent};
      color: white;
      border-bottom-right-radius: 4px;
    }
    .cb-msg-bot {
      align-self: flex-start;
      background: #f0f2f5;
      color: #1a1a2e;
      border-bottom-left-radius: 4px;
    }
    @keyframes cb-fadein {
      from { opacity: 0; transform: translateY(8px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .cb-typing {
      align-self: flex-start;
      padding: 12px 18px;
      background: #f0f2f5;
      border-radius: 16px;
      display: flex;
      gap: 4px;
      align-items: center;
    }
    .cb-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: #999;
      animation: cb-bounce 1.4s infinite;
    }
    .cb-dot:nth-child(2) { animation-delay: 0.2s; }
    .cb-dot:nth-child(3) { animation-delay: 0.4s; }
    @keyframes cb-bounce {
      0%, 60%, 100% { transform: translateY(0); }
      30% { transform: translateY(-6px); }
    }

    #cb-input-area {
      padding: 12px 16px;
      border-top: 1px solid #eee;
      display: flex;
      gap: 8px;
      align-items: center;
      flex-shrink: 0;
      background: #fafafa;
    }
    #cb-input {
      flex: 1;
      border: 1px solid #e0e0e0;
      border-radius: 24px;
      padding: 10px 16px;
      font-size: 14px;
      outline: none;
      background: white;
      transition: border-color 0.2s;
    }
    #cb-input:focus { border-color: ${CONFIG.accent}; }
    #cb-input::placeholder { color: #aaa; }
    #cb-send {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      border: none;
      background: ${CONFIG.accent};
      color: white;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: opacity 0.2s, transform 0.1s;
      flex-shrink: 0;
    }
    #cb-send:hover { opacity: 0.9; }
    #cb-send:active { transform: scale(0.92); }
    #cb-send:disabled { opacity: 0.5; cursor: not-allowed; }
    #cb-send svg { width: 18px; height: 18px; }

    #cb-powered {
      text-align: center;
      padding: 6px;
      font-size: 10px;
      color: #bbb;
      background: #fafafa;
    }

    @media (max-width: 480px) {
      #cb-window {
        width: calc(100vw - 16px);
        height: calc(100vh - 100px);
        bottom: 88px;
        right: 8px;
        border-radius: 16px;
      }
      #cb-fab { bottom: 16px; right: 16px; width: 54px; height: 54px; }
    }
  `;
  document.head.appendChild(style);

  // ── Build DOM ──
  const widget = document.createElement('div');
  widget.id = 'cb-widget';

  // Initial visibility check
  const isHidden = localStorage.getItem('show_chatbot') === 'false';
  if (isHidden) {
    widget.style.display = 'none';
  }
  widget.innerHTML = `
    <button id="cb-fab" aria-label="${t('open')}">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      </svg>
    </button>
    <div id="cb-window">
      <div id="cb-header">
        <div id="cb-header-icon">${CONFIG.icon}</div>
        <div id="cb-header-text">
          <h3>${t('title')}</h3>
          <p>${t('subtitle')}</p>
        </div>
      </div>
      <div id="cb-messages"></div>
      <div id="cb-input-area">
        <input id="cb-input" type="text" placeholder="${t('placeholder')}" maxlength="500" autocomplete="off" />
        <button id="cb-send" aria-label="${t('send')}">
          <svg viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
        </button>
      </div>
      <div id="cb-powered">${t('powered')}</div>
    </div>
  `;
  document.body.appendChild(widget);

  const fab = document.getElementById('cb-fab');
  const win = document.getElementById('cb-window');
  const msgContainer = document.getElementById('cb-messages');
  const input = document.getElementById('cb-input');
  const sendBtn = document.getElementById('cb-send');

  function renderMarkdown(text) {
    return text
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/\*(.+?)\*/g, '<em>$1</em>')
      .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
      .replace(/^- (.+)$/gm, '<li>$1</li>')
      .replace(/(<li>.*<\/li>)/gs, '<ul>$1</ul>')
      .replace(/\n/g, '<br>');
  }

  function addMessage(text, isUser) {
    const div = document.createElement('div');
    div.className = `cb-msg ${isUser ? 'cb-msg-user' : 'cb-msg-bot'}`;
    div.innerHTML = isUser ? text.replace(/</g, '&lt;') : renderMarkdown(text);
    msgContainer.appendChild(div);
    msgContainer.scrollTop = msgContainer.scrollHeight;
    messages.push({ role: isUser ? 'user' : 'assistant', text });
  }

  function showTyping() {
    const div = document.createElement('div');
    div.className = 'cb-typing';
    div.id = 'cb-typing';
    div.innerHTML = '<div class="cb-dot"></div><div class="cb-dot"></div><div class="cb-dot"></div>';
    msgContainer.appendChild(div);
    msgContainer.scrollTop = msgContainer.scrollHeight;
  }

  function hideTyping() {
    document.getElementById('cb-typing')?.remove();
  }

  // ── Vertical Dragging Logic ──
  let isDragging = false;
  let hasDragged = false;
  let startY, startOffsetTop;

  // Initialize saved position
  const savedTop = localStorage.getItem('cb_fab_top');
  if (savedTop) {
    fab.style.bottom = 'auto';
    fab.style.top = savedTop + 'px';
  }

  fab.addEventListener('mousedown', startDrag);
  fab.addEventListener('touchstart', startDrag, { passive: true });

  function startDrag(e) {
    if (e.type === 'mousedown' && e.button !== 0) return;
    isDragging = true;
    hasDragged = false;
    const clientY = e.type.startsWith('touch') ? e.touches[0].clientY : e.clientY;
    startY = clientY;
    startOffsetTop = fab.offsetTop;

    document.addEventListener('mousemove', drag);
    document.addEventListener('touchmove', drag, { passive: false });
    document.addEventListener('mouseup', stopDrag);
    document.addEventListener('touchend', stopDrag);
  }

  function drag(e) {
    if (!isDragging) return;
    const clientY = e.type.startsWith('touch') ? e.touches[0].clientY : e.clientY;
    const deltaY = clientY - startY;

    if (Math.abs(deltaY) > 5) {
      hasDragged = true;
      if (e.cancelable) e.preventDefault();
    }

    if (hasDragged) {
      let newTop = startOffsetTop + deltaY;
      const maxTop = window.innerHeight - fab.offsetHeight - 16;
      const minTop = 16;
      if (newTop < minTop) newTop = minTop;
      if (newTop > maxTop) newTop = maxTop;

      fab.style.bottom = 'auto';
      fab.style.top = newTop + 'px';
      localStorage.setItem('cb_fab_top', newTop);
    }
  }

  function stopDrag() {
    isDragging = false;
    document.removeEventListener('mousemove', drag);
    document.removeEventListener('touchmove', drag);
    document.removeEventListener('mouseup', stopDrag);
    document.removeEventListener('touchend', stopDrag);
    // Clear hasDragged after a tiny delay so click doesn't trigger
    setTimeout(() => {
      hasDragged = false;
    }, 50);
  }

  fab.addEventListener('click', () => {
    if (hasDragged) return;
    isOpen = !isOpen;
    fab.classList.toggle('cb-open', isOpen);
    win.classList.toggle('cb-visible', isOpen);
    
    // Update texts dynamically in case language changed
    document.getElementById('cb-header-text').innerHTML = `
      <h3>${t('title')}</h3>
      <p>${t('subtitle')}</p>
    `;
    input.placeholder = t('placeholder');
    sendBtn.setAttribute('aria-label', t('send'));
    fab.setAttribute('aria-label', t('open'));
    document.getElementById('cb-powered').textContent = t('powered');

    if (isOpen && messages.length === 0) addMessage(t('welcome'), false);
    if (isOpen) setTimeout(() => input.focus(), 300);
  });

  async function sendMessage() {
    const text = input.value.trim();
    if (!text || isLoading) return;
    input.value = '';
    addMessage(text, true);
    isLoading = true;
    sendBtn.disabled = true;
    showTyping();
    try {
      const res = await fetch(CONFIG.apiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ project: CONFIG.project, message: text, sessionId, history: messages.slice(-10), lang: getLang() }),
      });
      const data = await res.json();
      hideTyping();
      if (data.status === 'ok') addMessage(data.response, false);
      else addMessage(data.message || t('error'), false);
    } catch (err) {
      hideTyping();
      addMessage(t('connectionError'), false);
    }
    isLoading = false;
    sendBtn.disabled = false;
    input.focus();
  }

  sendBtn.addEventListener('click', sendMessage);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  });

  window.addEventListener('toggle_chatbot', (e) => {
    const show = e.detail !== false;
    widget.style.display = show ? 'block' : 'none';
  });
})();
