/**
 * MEDITRACK LANDING PAGE - INTERACTIVE SCRIPT
 * Handles live phone mockup tab switching, AI assistant responses,
 * dosage streak counters, adherence ROI slider calculation, and scroll effects.
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Sticky Navbar Scroll Effect
  const navbar = document.querySelector('.navbar');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 40) {
      navbar?.classList.add('scrolled');
    } else {
      navbar?.classList.remove('scrolled');
    }
  });

  // 2. Interactive Phone Mockup Tab Switcher
  const phoneTabBtns = document.querySelectorAll('.phone-tab-btn');
  const appViewPanels = document.querySelectorAll('.app-view-panel');

  phoneTabBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetTab = btn.getAttribute('data-tab');

      // Update Active Tab Button
      phoneTabBtns.forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');

      // Show Matching View Panel
      appViewPanels.forEach((panel) => {
        if (panel.id === `view-${targetTab}`) {
          panel.classList.add('active');
        } else {
          panel.classList.remove('active');
        }
      });
    });
  });

  // 3. Interactive Phone Dose Logger Checkboxes
  const medCards = document.querySelectorAll('.med-card-item');
  medCards.forEach((card) => {
    const checkBtn = card.querySelector('.med-check-btn');
    checkBtn?.addEventListener('click', (e) => {
      e.stopPropagation();
      card.classList.toggle('taken');
      const isTaken = card.classList.contains('taken');

      if (isTaken) {
        checkBtn.innerHTML = `
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>`;
      } else {
        checkBtn.innerHTML = '';
      }
    });
  });

  // 4. Bento Grid: Interactive AI Assistant Query Demo
  const queryChips = document.querySelectorAll('.query-chip');
  const aiResponseBox = document.getElementById('aiDemoResponse');

  const aiKnowledgeBase = {
    interaction: "<strong>AI Insight:</strong> Aspirin and Ibuprofen are both NSAIDs. Taking them simultaneously can increase the risk of stomach irritation. It is recommended to space them by at least 8 hours.",
    food: "<strong>AI Insight:</strong> Atorvastatin can be taken with or without food, but avoid large quantities of grapefruit juice as it interferes with liver breakdown.",
    timing: "<strong>AI Insight:</strong> Taking Blood Pressure medication (like Lisinopril) in the morning helps maintain consistent 24-hour BP control."
  };

  queryChips.forEach((chip) => {
    chip.addEventListener('click', () => {
      queryChips.forEach((c) => c.classList.remove('active'));
      chip.classList.add('active');

      const queryKey = chip.getAttribute('data-query');
      if (aiResponseBox && aiKnowledgeBase[queryKey]) {
        aiResponseBox.style.opacity = '0';
        setTimeout(() => {
          aiResponseBox.innerHTML = aiKnowledgeBase[queryKey];
          aiResponseBox.style.opacity = '1';
        }, 150);
      }
    });
  });

  // 5. Bento Grid: Dose Streak Interactive Counter
  const logDoseBtn = document.getElementById('logDoseBtn');
  const streakCountDisplay = document.getElementById('streakCount');
  let currentStreak = 7;
  let loggedToday = false;

  logDoseBtn?.addEventListener('click', () => {
    if (!loggedToday) {
      currentStreak += 1;
      loggedToday = true;
      if (streakCountDisplay) {
        streakCountDisplay.textContent = `${currentStreak} Days 🔥`;
      }
      logDoseBtn.textContent = '✓ Dose Logged for Today';
      logDoseBtn.style.backgroundColor = '#5B8C5A';
    } else {
      currentStreak -= 1;
      loggedToday = false;
      if (streakCountDisplay) {
        streakCountDisplay.textContent = `${currentStreak} Days 🔥`;
      }
      logDoseBtn.textContent = '+ Log Evening Dose';
      logDoseBtn.style.backgroundColor = '#47594E';
    }
  });

  // 6. Interactive Adherence ROI Calculator
  const medsSlider = document.getElementById('medsSlider');
  const medsValueBadge = document.getElementById('medsValueBadge');
  const annualDosesVal = document.getElementById('annualDosesVal');
  const missedPreventedVal = document.getElementById('missedPreventedVal');
  const adherenceScoreVal = document.getElementById('adherenceScoreVal');

  function updateCalculator() {
    if (!medsSlider) return;
    const dailyMeds = parseInt(medsSlider.value, 10);
    
    if (medsValueBadge) {
      medsValueBadge.textContent = `${dailyMeds} ${dailyMeds === 1 ? 'medication' : 'medications'}`;
    }

    const annualDoses = dailyMeds * 365;
    const missedWithoutApp = Math.round(annualDoses * 0.22); // average 22% missed without tracking
    const adherenceRate = Math.min(99.2, 94 + (dailyMeds * 0.5));

    if (annualDosesVal) annualDosesVal.textContent = annualDoses.toLocaleString();
    if (missedPreventedVal) missedPreventedVal.textContent = `${missedWithoutApp.toLocaleString()} doses`;
    if (adherenceScoreVal) adherenceScoreVal.textContent = `${adherenceRate.toFixed(1)}%`;
  }

  medsSlider?.addEventListener('input', updateCalculator);
  updateCalculator();

  // 7. Scroll Reveal Animation using IntersectionObserver
  const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  };

  const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('revealed');
        revealObserver.unobserve(entry.target);
      }
    });
  }, observerOptions);

  document.querySelectorAll('.bento-card, .review-card, .metric-item, .calc-card').forEach((el) => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(24px)';
    el.style.transition = 'opacity 0.6s cubic-bezier(0.4, 0, 0.2, 1), transform 0.6s cubic-bezier(0.4, 0, 0.2, 1)';
    revealObserver.observe(el);
  });

  // Handle revealed elements transition inline
  const styleTag = document.createElement('style');
  styleTag.textContent = `
    .revealed {
      opacity: 1 !important;
      transform: translateY(0) !important;
    }
  `;
  document.head.appendChild(styleTag);
});
