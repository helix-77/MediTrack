/**
 * MEDITRACK LANDING PAGE - INTERACTIVE SCRIPT
 * Handles live phone mockup tab switching, generic medicine search simulator,
 * AI assistant responses, dosage streak counters, adherence & generic savings ROI calculator,
 * FAQ accordion, and scroll reveal effects.
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Sticky Navbar Scroll Effect & Mobile Menu Toggle
  const navbar = document.querySelector('.navbar');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 30) {
      navbar?.classList.add('scrolled');
    } else {
      navbar?.classList.remove('scrolled');
    }
  });

  const mobileToggle = document.querySelector('.mobile-menu-toggle');
  const navMenu = document.querySelector('.nav-menu');
  mobileToggle?.addEventListener('click', () => {
    if (navMenu) {
      const isVisible = navMenu.style.display === 'flex';
      navMenu.style.display = isVisible ? 'none' : 'flex';
      navMenu.style.flexDirection = 'column';
      navMenu.style.position = 'absolute';
      navMenu.style.top = '100%';
      navMenu.style.left = '16px';
      navMenu.style.right = '16px';
      navMenu.style.background = '#FFFFFF';
      navMenu.style.padding = '1.5rem';
      navMenu.style.borderRadius = '20px';
      navMenu.style.border = '1px solid #E2E8F0';
      navMenu.style.boxShadow = '0 15px 35px rgba(24, 35, 61, 0.12)';
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

  // 3. Interactive Phone Dose Items
  const dose1 = document.getElementById('demoDose1');
  const dosePill1 = document.getElementById('dosePill1');
  let dose1Taken = false;

  dose1?.addEventListener('click', () => {
    dose1Taken = !dose1Taken;
    if (dose1Taken) {
      if (dosePill1) {
        dosePill1.textContent = 'Taken ✓';
        dosePill1.className = 'med-action-pill med-action-taken';
      }
      dose1.style.borderColor = '#10B981';
      dose1.style.background = '#F0FDF4';
    } else {
      if (dosePill1) {
        dosePill1.textContent = 'Take now';
        dosePill1.className = 'med-action-pill med-action-pink';
      }
      dose1.style.borderColor = '#E2E8F0';
      dose1.style.background = '#FFFFFF';
    }
  });

  // 4. Bento Grid: Interactive Medicine Price & Generic Alternative Simulator
  const genericDatabase = {
    napa: {
      brand: 'Napa 500mg Tablet',
      manufacturer: 'Beximco Pharmaceuticals Ltd.',
      price: 'MRP: ৳1.20 / tab',
      generic: 'Paracetamol 500mg',
      alternatives: [
        { name: 'Ace 500mg', mfg: 'Square Pharmaceuticals', price: '৳0.80', saving: 'Save 33%' },
        { name: 'Renova 500mg', mfg: 'Opso Saline Ltd.', price: '৳0.80', saving: 'Save 33%' },
        { name: 'Fast 500mg', mfg: 'Acme Laboratories Ltd.', price: '৳0.80', saving: 'Save 33%' },
        { name: 'Pyrex 500mg', mfg: 'Incepta Pharmaceuticals', price: '৳0.85', saving: 'Save 29%' }
      ]
    },
    seclo: {
      brand: 'Seclo 20mg Capsule',
      manufacturer: 'Square Pharmaceuticals PLC',
      price: 'MRP: ৳7.00 / cap',
      generic: 'Omeprazole 20mg',
      alternatives: [
        { name: 'Proceptin 20mg', mfg: 'Beximco Pharmaceuticals', price: '৳5.00', saving: 'Save 28%' },
        { name: 'Omecon 20mg', mfg: 'Popular Pharmaceuticals', price: '৳5.00', saving: 'Save 28%' },
        { name: 'Esofag 20mg', mfg: 'Incepta Pharmaceuticals', price: '৳5.00', saving: 'Save 28%' },
        { name: 'Lokit 20mg', mfg: 'Acme Laboratories Ltd.', price: '৳5.50', saving: 'Save 21%' }
      ]
    },
    montene: {
      brand: 'Montene 10mg Tablet',
      manufacturer: 'Incepta Pharmaceuticals Ltd.',
      price: 'MRP: ৳16.00 / tab',
      generic: 'Montelukast 10mg',
      alternatives: [
        { name: 'Romilast 10mg', mfg: 'Popular Pharmaceuticals', price: '৳12.99', saving: 'Save 25%' },
        { name: 'Monas 10mg', mfg: 'Acme Laboratories Ltd.', price: '৳14.00', saving: 'Save 12%' },
        { name: 'Odmon 10mg', mfg: 'Square Pharmaceuticals', price: '৳14.00', saving: 'Save 12%' },
        { name: 'Mona 10mg', mfg: 'Renata Limited', price: '৳14.00', saving: 'Save 12%' }
      ]
    },
    sergel: {
      brand: 'Sergel 20mg Capsule',
      manufacturer: 'Healthcare Pharmaceuticals Ltd.',
      price: 'MRP: ৳10.00 / cap',
      generic: 'Esomeprazole 20mg',
      alternatives: [
        { name: 'Opton 20mg', mfg: 'Incepta Pharmaceuticals', price: '৳7.00', saving: 'Save 30%' },
        { name: 'Nexum 20mg', mfg: 'Square Pharmaceuticals', price: '৳8.00', saving: 'Save 20%' },
        { name: 'Maxima 20mg', mfg: 'Beximco Pharmaceuticals', price: '৳8.00', saving: 'Save 20%' },
        { name: 'Esonix 20mg', mfg: 'Renata Limited', price: '৳8.00', saving: 'Save 20%' }
      ]
    }
  };

  const medSearchChips = document.querySelectorAll('.med-search-chip');
  const genericCompareBox = document.getElementById('genericCompareBox');

  function renderGenericComparison(medKey) {
    const data = genericDatabase[medKey];
    if (!data || !genericCompareBox) return;

    genericCompareBox.style.opacity = '0';
    setTimeout(() => {
      let altHtml = data.alternatives
        .map(
          (alt) => `
        <div class="alt-result-row">
          <div>
            <strong>${alt.name}</strong> • ${alt.mfg}
          </div>
          <div class="alt-price-tag">${alt.price} <span class="badge-saving">${alt.saving}</span></div>
        </div>
      `
        )
        .join('');

      genericCompareBox.innerHTML = `
        <div class="current-brand-row">
          <div>
            <span class="table-brand-name">${data.brand}</span>
            <span class="table-brand-mfg">${data.manufacturer}</span>
          </div>
          <div class="table-brand-price">${data.price}</div>
        </div>

        <div class="alt-list-title">Cheaper Brands with Same Generic (${data.generic}):</div>
        <div class="alt-items-list">
          ${altHtml}
        </div>
      `;
      genericCompareBox.style.opacity = '1';
    }, 150);
  }

  medSearchChips.forEach((chip) => {
    chip.addEventListener('click', () => {
      medSearchChips.forEach((c) => c.classList.remove('active'));
      chip.classList.add('active');
      const medKey = chip.getAttribute('data-med');
      if (medKey) renderGenericComparison(medKey);
    });
  });

  // 5. Bento Grid: Interactive AI Health Assistant Query Demo
  const queryChips = document.querySelectorAll('.query-chip');
  const aiResponseBox = document.getElementById('aiDemoResponse');

  const aiKnowledgeBase = {
    timing: `<strong>AI Guidance:</strong> Take <strong>Omeprazole (e.g. Seclo)</strong> 30–60 minutes before breakfast on an empty stomach for optimal gastric acid reduction.<div class="ai-action-demo-pill">⚡ Action: Set dose reminder for 7:30 AM</div>`,
    food: `<strong>AI Guidance:</strong> <strong>Montelukast (Montene)</strong> can be taken with or without meals. It is recommended to take it in the evening before sleep.<div class="ai-action-demo-pill">⚡ Action: Scheduled bedtime reminder at 9:30 PM</div>`,
    action: `<strong>AI Guidance:</strong> Extracted: <strong>Paracetamol 500mg Tablet</strong> (1+0+1, after food for 3 days).<div class="ai-action-demo-pill">✓ Action: Added 2 daily reminders (8:00 AM & 8:00 PM)</div>`
  };

  queryChips.forEach((chip) => {
    chip.addEventListener('click', () => {
      queryChips.forEach((c) => c.classList.remove('active'));
      chip.classList.add('active');

      const queryKey = chip.getAttribute('data-query');
      if (aiResponseBox && queryKey && aiKnowledgeBase[queryKey]) {
        aiResponseBox.style.opacity = '0';
        setTimeout(() => {
          aiResponseBox.innerHTML = aiKnowledgeBase[queryKey];
          aiResponseBox.style.opacity = '1';
        }, 150);
      }
    });
  });

  // 6. Bento Grid: Dose Streak Counter
  const logDoseBtn = document.getElementById('logDoseBtn');
  const streakCountDisplay = document.getElementById('streakCount');
  let currentStreak = 7;
  let loggedToday = false;

  logDoseBtn?.addEventListener('click', () => {
    if (!loggedToday) {
      currentStreak += 1;
      loggedToday = true;
      if (streakCountDisplay) {
        streakCountDisplay.textContent = `${currentStreak} Day Streak 🔥`;
      }
      logDoseBtn.textContent = '✓ Dose Logged for Today';
      logDoseBtn.style.backgroundColor = '#10B981';
      logDoseBtn.style.boxShadow = '0 6px 18px rgba(16, 185, 129, 0.35)';
    } else {
      currentStreak -= 1;
      loggedToday = false;
      if (streakCountDisplay) {
        streakCountDisplay.textContent = `${currentStreak} Day Streak 🔥`;
      }
      logDoseBtn.textContent = '+ Log Afternoon Dose';
      logDoseBtn.style.backgroundColor = 'var(--primary-blue)';
      logDoseBtn.style.boxShadow = '0 6px 18px rgba(91, 143, 245, 0.35)';
    }
  });

  // 7. Clinical Summary Copy Button
  const copySummaryBtn = document.getElementById('copySummaryBtn');
  copySummaryBtn?.addEventListener('click', () => {
    const textToCopy = `=== MEDITRACK CLINICAL SUMMARY ===\nPatient: Rahi | Adherence: 94.2% (Last 30 Days)\nActive Meds: Napa Extra (500mg, 1+0+1), Seclo (20mg, 1+0+0)\nRefill Status: All active stocks sufficient for 14+ days\nVerified on: 25 August 2026 via MediTrack`;
    navigator.clipboard?.writeText(textToCopy);
    copySummaryBtn.textContent = '✓ Copied to Clipboard!';
    setTimeout(() => {
      copySummaryBtn.textContent = '📋 Copy Summary to Clipboard';
    }, 2500);
  });

  // 8. Interactive Adherence & Generic Savings Calculator
  const medsSlider = document.getElementById('medsSlider');
  const spendSlider = document.getElementById('spendSlider');
  const medsValueBadge = document.getElementById('medsValueBadge');
  const spendValueBadge = document.getElementById('spendValueBadge');
  const annualDosesVal = document.getElementById('annualDosesVal');
  const missedPreventedVal = document.getElementById('missedPreventedVal');
  const genericSavingsVal = document.getElementById('genericSavingsVal');
  const adherenceScoreVal = document.getElementById('adherenceScoreVal');

  function updateCalculator() {
    const dailyMeds = parseInt(medsSlider ? medsSlider.value : '3', 10);
    const monthlySpend = parseInt(spendSlider ? spendSlider.value : '2000', 10);

    if (medsValueBadge) {
      medsValueBadge.textContent = `${dailyMeds} ${dailyMeds === 1 ? 'medication' : 'medications'}`;
    }

    if (spendValueBadge) {
      spendValueBadge.textContent = `৳${monthlySpend.toLocaleString()} / month`;
    }

    const annualDoses = dailyMeds * 365;
    const missedWithoutApp = Math.round(annualDoses * 0.22); // 22% average unmanaged miss rate
    const annualGenericSavings = Math.round(monthlySpend * 12 * 0.30); // 30% average generic alternative savings
    const adherenceRate = Math.min(99.2, 94 + dailyMeds * 0.5);

    if (annualDosesVal) annualDosesVal.textContent = annualDoses.toLocaleString();
    if (missedPreventedVal) missedPreventedVal.textContent = `${missedWithoutApp.toLocaleString()} doses`;
    if (genericSavingsVal) genericSavingsVal.textContent = `৳${annualGenericSavings.toLocaleString()} / year`;
    if (adherenceScoreVal) adherenceScoreVal.textContent = `${adherenceRate.toFixed(1)}%`;
  }

  medsSlider?.addEventListener('input', updateCalculator);
  spendSlider?.addEventListener('input', updateCalculator);
  updateCalculator();

  // 9. Frequently Asked Questions (FAQ) Accordion
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach((item) => {
    const questionBtn = item.querySelector('.faq-question');
    questionBtn?.addEventListener('click', () => {
      const isOpen = item.classList.contains('active');
      // Close other items
      faqItems.forEach((other) => other.classList.remove('active'));
      if (!isOpen) {
        item.classList.add('active');
      }
    });
  });

  // 10. Scroll Reveal Animation using IntersectionObserver
  const observerOptions = {
    threshold: 0.08,
    rootMargin: '0px 0px -40px 0px'
  };

  const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('revealed');
        revealObserver.unobserve(entry.target);
      }
    });
  }, observerOptions);

  document
    .querySelectorAll('.pillar-card, .bento-card, .review-card, .calc-card, .pricing-card, .faq-item')
    .forEach((el) => {
      el.style.opacity = '0';
      el.style.transform = 'translateY(24px)';
      el.style.transition =
        'opacity 0.6s cubic-bezier(0.4, 0, 0.2, 1), transform 0.6s cubic-bezier(0.4, 0, 0.2, 1)';
      revealObserver.observe(el);
    });

  const styleTag = document.createElement('style');
  styleTag.textContent = `
    .revealed {
      opacity: 1 !important;
      transform: translateY(0) !important;
    }
  `;
  document.head.appendChild(styleTag);
});
