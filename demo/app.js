/**
 * Schedule Q&A & Entity Extraction Workbench
 * Built following Vercel Geist Light Aesthetics
 */

const SCHEDULE_REGISTRY = {
  summit: {
    id: 'summit',
    name: 'Global AI & Systems Summit 2026',
    questions: [
      {
        id: 'location',
        label: 'Event Location',
        tag: 'Facility',
        desc: 'What is the primary venue and exact address for the summit?',
        placeholder: 'e.g., Shanghai International Convention Center, 3F Grand Ballroom...',
        answer: 'Shanghai International Convention Center (No. 2727 Riverside Ave, Pudong), 3F Grand Ballroom',
        keywords: ['Shanghai International Convention Center', 'Riverside', '2727', 'Grand Ballroom'],
        evidenceId: 'ev-location'
      },
      {
        id: 'date',
        label: 'Conference Dates',
        tag: 'Schedule',
        desc: 'What are the official dates for the 3-day conference?',
        placeholder: 'e.g., October 15 – October 17, 2026...',
        answer: 'October 15 – October 17, 2026',
        keywords: ['October 15', 'October 17', '2026'],
        evidenceId: 'ev-date'
      },
      {
        id: 'keynote',
        label: 'Keynote Speaker & Topic',
        tag: 'Program',
        desc: 'Who is delivering the opening keynote and what is the topic?',
        placeholder: 'e.g., Dr. William Zhang / Next-Gen Embodied Intelligence...',
        answer: 'Dr. William Zhang (Director of National AI Labs), on "Next-Gen Embodied Intelligence"',
        keywords: ['William Zhang', 'Embodied Intelligence'],
        evidenceId: 'ev-keynote'
      },
      {
        id: 'deadline',
        label: 'Registration Deadline',
        tag: 'Cutoff',
        desc: 'What is the final cutoff deadline for badge confirmation?',
        placeholder: 'e.g., September 30, 2026 at 23:59...',
        answer: 'September 30, 2026 at 23:59',
        keywords: ['September 30', '23:59'],
        evidenceId: 'ev-deadline'
      }
    ],
    htmlContent: `
      <span class="doc-tag">Program Brief · Document #GIS-2026</span>
      <h1 class="doc-headline">Global AI & Systems Summit 2026</h1>
      <div class="doc-metadata-bar">
        <span>🗓️ October 15 – 17, 2026</span>
        <span>📍 Shanghai, China</span>
        <span>👥 3,500 Attendees</span>
      </div>

      <div class="doc-section-block">
        <div class="section-label">Overview</div>
        <p class="doc-paragraph">
          The Global AI & Systems Summit officially takes place from
          <span class="evidence-mark" id="ev-date" data-qid="date">October 15 – October 17, 2026</span>
          in Shanghai. Keynotes and partner sessions are hosted at the
          <span class="evidence-mark" id="ev-location" data-qid="location">Shanghai International Convention Center (No. 2727 Riverside Ave, Pudong), 3F Grand Ballroom</span>.
          All participants must verify credentials before
          <span class="evidence-mark" id="ev-deadline" data-qid="deadline">September 30, 2026 at 23:59</span>.
        </p>
      </div>

      <div class="doc-section-block">
        <div class="section-label">Selected Agenda</div>
        <div class="timeline-list">
          <div class="timeline-row">
            <div class="timeline-timestamp">Oct 15 · 10:00</div>
            <div class="timeline-detail">
              <div class="timeline-title">Opening Keynote</div>
              <div class="timeline-desc">
                Delivered by <span class="evidence-mark" id="ev-keynote" data-qid="keynote">Dr. William Zhang (Director of National AI Labs), on "Next-Gen Embodied Intelligence"</span>.
              </div>
            </div>
          </div>
          <div class="timeline-row">
            <div class="timeline-timestamp">Oct 16 · 14:00</div>
            <div class="timeline-detail">
              <div class="timeline-title">Compiler & System Architecture Track</div>
              <div class="timeline-desc">High-throughput inference engines and distributed scheduling.</div>
            </div>
          </div>
          <div class="timeline-row">
            <div class="timeline-timestamp">Oct 17 · 15:30</div>
            <div class="timeline-detail">
              <div class="timeline-title">Closing & Awards</div>
              <div class="timeline-desc">Presentation of distinguished open-source contributions.</div>
            </div>
          </div>
        </div>
      </div>
    `
  },

  delegation: {
    id: 'delegation',
    name: 'Silicon Valley Executive Tech Delegation 2026',
    questions: [
      {
        id: 'location',
        label: 'Base Hotel & Venue',
        tag: 'Accommodation',
        desc: 'Where is the delegation staying and hosting the initial briefing?',
        placeholder: 'e.g., Four Seasons Hotel Silicon Valley at East Palo Alto...',
        answer: 'Four Seasons Hotel Silicon Valley at East Palo Alto (2050 University Ave)',
        keywords: ['Four Seasons', 'East Palo Alto', 'University Ave'],
        evidenceId: 'ev-location-del'
      },
      {
        id: 'date',
        label: 'Tour Dates',
        tag: 'Duration',
        desc: 'What are the formal starting and ending dates of the tour?',
        placeholder: 'e.g., November 2 – November 8, 2026...',
        answer: 'November 2 – November 8, 2026',
        keywords: ['November 2', 'November 8', '2026'],
        evidenceId: 'ev-date-del'
      },
      {
        id: 'keynote',
        label: 'Symposium Speaker & Topic',
        tag: 'Academic',
        desc: 'Who is leading the Stanford AI Lab closed-door session and on what topic?',
        placeholder: 'e.g., Prof. David Miller on Heterogeneous Compute Clusters...',
        answer: 'Prof. David Miller on "Heterogeneous Compute Clusters"',
        keywords: ['David Miller', 'Heterogeneous Compute Clusters'],
        evidenceId: 'ev-keynote-del'
      },
      {
        id: 'deadline',
        label: 'Compliance Deadline',
        tag: 'Compliance',
        desc: 'When must delegates submit their travel compliance disclosures?',
        placeholder: 'e.g., October 10, 2026 at 17:00 (PST)...',
        answer: 'October 10, 2026 at 17:00 (PST)',
        keywords: ['October 10', '17:00'],
        evidenceId: 'ev-deadline-del'
      }
    ],
    htmlContent: `
      <span class="doc-tag">Tour Itinerary · Document #SV-EXEC-2026</span>
      <h1 class="doc-headline">Silicon Valley Frontier AI Tour Itinerary</h1>
      <div class="doc-metadata-bar">
        <span>🗓️ November 02 – 08, 2026</span>
        <span>📍 San Francisco Bay Area, CA</span>
        <span>👥 24 Enterprise Executives</span>
      </div>

      <div class="doc-section-block">
        <div class="section-label">Overview</div>
        <p class="doc-paragraph">
          The executive delegation tour runs from
          <span class="evidence-mark" id="ev-date-del" data-qid="date">November 2 – November 8, 2026</span>
          across Northern California. Accommodations and base briefings are held at
          <span class="evidence-mark" id="ev-location-del" data-qid="location">Four Seasons Hotel Silicon Valley at East Palo Alto (2050 University Ave)</span>.
          Delegates must submit compliance disclosures by
          <span class="evidence-mark" id="ev-deadline-del" data-qid="deadline">October 10, 2026 at 17:00 (PST)</span>.
        </p>
      </div>

      <div class="doc-section-block">
        <div class="section-label">Key Stops</div>
        <div class="timeline-list">
          <div class="timeline-row">
            <div class="timeline-timestamp">Nov 03 · 10:00</div>
            <div class="timeline-detail">
              <div class="timeline-title">Stanford AI Lab Symposium</div>
              <div class="timeline-desc">
                Closed-door exchange with <span class="evidence-mark" id="ev-keynote-del" data-qid="keynote">Prof. David Miller on "Heterogeneous Compute Clusters"</span>.
              </div>
            </div>
          </div>
          <div class="timeline-row">
            <div class="timeline-timestamp">Nov 04 · 14:00</div>
            <div class="timeline-detail">
              <div class="timeline-title">Frontier AI Labs Visit</div>
              <div class="timeline-desc">Private discussion on reasoning models and hardware scaling in San Francisco.</div>
            </div>
          </div>
          <div class="timeline-row">
            <div class="timeline-timestamp">Nov 06 · 15:00</div>
            <div class="timeline-detail">
              <div class="timeline-title">Sand Hill Road Venture Roundtables</div>
              <div class="timeline-desc">Direct investor exchanges with Silicon Valley venture partners.</div>
            </div>
          </div>
        </div>
      </div>
    `
  }
};

let currentKey = 'summit';
let userAnswers = {};

// DOM elements
const scheduleViewer = document.getElementById('scheduleViewer');
const questionsContainer = document.getElementById('questionsContainer');
const toastContainer = document.getElementById('toastContainer');

function init() {
  loadSchedule(currentKey);
}

function loadSchedule(key) {
  currentKey = key;
  const data = SCHEDULE_REGISTRY[key];
  userAnswers = {};

  scheduleViewer.innerHTML = data.htmlContent;
  renderQuestions(data.questions);
}

function renderQuestions(questions) {
  questionsContainer.innerHTML = '';

  questions.forEach((q, index) => {
    const card = document.createElement('div');
    card.className = 'qa-card';
    card.id = `card-${q.id}`;
    card.setAttribute('data-qid', q.id);

    card.innerHTML = `
      <div class="qa-card-header">
        <div class="qa-card-title">
          <span class="qa-field-num">0${index + 1}</span>
          <span class="qa-field-label">${q.label}</span>
        </div>
        <div class="qa-header-meta">
          <div class="status-container" id="status-${q.id}">
            <span class="status-badge correct">● MATCHED</span>
          </div>
          <span class="qa-field-tag">${q.tag}</span>
        </div>
      </div>
      <div class="qa-field-desc">${q.desc}</div>
      <div class="geist-input-wrapper">
        <input 
          type="text" 
          class="geist-input" 
          id="input-${q.id}" 
          data-qid="${q.id}"
          placeholder="${q.placeholder}"
          autocomplete="off"
          spellcheck="false"
        />
      </div>
      <div class="qa-card-actions">
        <button class="qa-action-link locate-action" data-qid="${q.id}">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"></circle>
            <polyline points="12 8 8 12 12 16"></polyline>
            <line x1="16" y1="12" x2="8" y2="12"></line>
          </svg>
          Locate Source
        </button>
        <button class="qa-action-link fill-action" data-qid="${q.id}">Fill Sample</button>
      </div>
    `;

    questionsContainer.appendChild(card);
  });

  bindCardEvents();
}

function bindCardEvents() {
  const inputs = questionsContainer.querySelectorAll('.geist-input');
  inputs.forEach(input => {
    const qid = input.getAttribute('data-qid');

    input.addEventListener('focus', () => {
      focusCard(qid);
    });

    input.addEventListener('blur', () => {
      unfocusCards();
    });

    // When user types: update highlight in source text
    input.addEventListener('input', (e) => {
      handleInput(qid, e.target.value);
    });
  });

  questionsContainer.querySelectorAll('.locate-action').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const qid = btn.getAttribute('data-qid');
      locateSourceInText(qid);
    });
  });

  questionsContainer.querySelectorAll('.fill-action').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const qid = btn.getAttribute('data-qid');
      fillSampleAnswer(qid);
    });
  });
}

function focusCard(qid) {
  unfocusCards();
  const card = document.getElementById(`card-${qid}`);
  if (card) card.classList.add('active-card');
}

function unfocusCards() {
  questionsContainer.querySelectorAll('.qa-card').forEach(c => c.classList.remove('active-card'));
}

/**
 * Text appears ordinary by default.
 * Only AFTER typing something into the input does the source text gain blue highlight.
 */
function handleInput(qid, rawValue) {
  const value = rawValue.trim();
  userAnswers[qid] = value;

  const marks = scheduleViewer.querySelectorAll(`.evidence-mark[data-qid="${qid}"]`);

  if (value.length > 0) {
    // Activate blue highlight
    marks.forEach(m => m.classList.add('highlight-matched'));
  } else {
    // Remove blue highlight if empty
    marks.forEach(m => m.classList.remove('highlight-matched'));
  }

  // Update status badge placed outside input in card header
  const currentQuestions = SCHEDULE_REGISTRY[currentKey].questions;
  const qObj = currentQuestions.find(q => q.id === qid);
  const statusWrap = document.getElementById(`status-${qid}`);
  if (statusWrap) {
    const matchEl = statusWrap.querySelector('.status-badge.correct');
    if (matchEl) {
      if (value.length > 0 && qObj) {
        const matches = qObj.keywords.filter(kw => value.toLowerCase().includes(kw.toLowerCase())).length;
        if (matches >= 2 || (qObj.keywords.length === 1 && matches === 1)) {
          matchEl.style.display = 'inline-flex';
        } else {
          matchEl.style.display = 'none';
        }
      } else {
        matchEl.style.display = 'none';
      }
    }
  }
}

/**
 * Locate source in text:
 * Smooth scroll into view, NO YELLOW.
 * Subtle clean neutral fade pulse.
 */
function locateSourceInText(qid) {
  focusCard(qid);

  const marks = scheduleViewer.querySelectorAll(`.evidence-mark[data-qid="${qid}"]`);
  if (marks.length > 0) {
    const target = marks[0];
    target.scrollIntoView({ behavior: 'smooth', block: 'center' });

    // Clean neutral pulse with zero yellow
    target.classList.remove('locate-pulse');
    void target.offsetWidth; // trigger reflow
    target.classList.add('locate-pulse');
  }
}

function fillSampleAnswer(qid) {
  const questions = SCHEDULE_REGISTRY[currentKey].questions;
  const qObj = questions.find(q => q.id === qid);
  if (!qObj) return;

  const input = document.getElementById(`input-${qid}`);
  if (!input) return;

  typeText(input, qObj.answer, () => {
    handleInput(qid, qObj.answer);
    locateSourceInText(qid);
    showToast(`Filled answer for ${qObj.label}`);
  });
}

function typeText(targetInput, text, onComplete) {
  targetInput.value = '';
  let i = 0;
  const speed = 18;

  const timer = setInterval(() => {
    if (i < text.length) {
      targetInput.value += text.charAt(i);
      handleInput(targetInput.getAttribute('data-qid'), targetInput.value);
      i++;
    } else {
      clearInterval(timer);
      if (onComplete) onComplete();
    }
  }, speed);
}

function showToast(message, duration = 2200) {
  const toast = document.createElement('div');
  toast.className = 'geist-toast';
  toast.innerHTML = `
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <polyline points="20 6 9 17 4 12"></polyline>
    </svg>
    <span>${message}</span>
  `;
  toastContainer.appendChild(toast);

  requestAnimationFrame(() => {
    toast.classList.add('visible');
  });

  setTimeout(() => {
    toast.classList.remove('visible');
    setTimeout(() => toast.remove(), 250);
  }, duration);
}

document.addEventListener('DOMContentLoaded', init);
