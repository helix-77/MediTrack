/**
 * MEDITRACK LANDING PAGE — INTERACTIVE CHOREOGRAPHY
 * IntersectionObserver-driven reveals (no scroll listeners), mobile overlay
 * menu with staggered mask reveal, live phone mockup, generic comparator,
 * AI assistant demo, streak counter, tweened savings calculator, FAQ accordion.
 */

function init() {
  const prefersReducedMotion = window.matchMedia(
    "(prefers-reduced-motion: reduce)",
  ).matches;

  /* 1. Nav state via sentinel IntersectionObserver (never a scroll listener) */
  const navbar = document.getElementById("navbar");
  const sentinel = document.getElementById("navSentinel");
  if (navbar && sentinel) {
    new IntersectionObserver(
      ([entry]) => navbar.classList.toggle("scrolled", !entry.isIntersecting),
      { rootMargin: "-60px 0px 0px 0px", threshold: 0 },
    ).observe(sentinel);
  }

  /* 2. Mobile overlay menu — morph burger to X, staggered mask reveal */
  const burger = document.getElementById("navBurger");
  const overlay = document.getElementById("mobileOverlay");

  function closeOverlay() {
    if (!overlay || !burger) return;
    overlay.classList.remove("open");
    burger.classList.remove("open");
    document.body.classList.remove("no-scroll");
    overlay.setAttribute("aria-hidden", "true");
    burger.setAttribute("aria-expanded", "false");
  }

  burger?.addEventListener("click", () => {
    const willOpen = !overlay?.classList.contains("open");
    overlay?.classList.toggle("open", willOpen);
    burger.classList.toggle("open", willOpen);
    document.body.classList.toggle("no-scroll", willOpen);
    overlay?.setAttribute("aria-hidden", String(!willOpen));
    burger.setAttribute("aria-expanded", String(willOpen));
  });

  overlay
    ?.querySelectorAll("a")
    .forEach((link) => link.addEventListener("click", closeOverlay));
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeOverlay();
  });

  /* 3. Scroll-entry reveals: translateY + blur + opacity, staggered per group */
  const revealEls = document.querySelectorAll("[data-reveal]");
  document.querySelectorAll("[data-reveal-group]").forEach((group) => {
    Array.from(group.querySelectorAll(":scope > [data-reveal]")).forEach(
      (el, i) => {
        el.style.setProperty("--rd", `${Math.min(i * 90, 450)}ms`);
      },
    );
  });

  if (prefersReducedMotion || !("IntersectionObserver" in window)) {
    revealEls.forEach((el) => el.classList.add("is-visible"));
  } else {
    const revealObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            revealObserver.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.05, rootMargin: "0px 0px -20px 0px" },
    );
    revealEls.forEach((el) => revealObserver.observe(el));
  }

  /* 4. Interactive phone mockup — tab switcher */
  const phoneTabBtns = document.querySelectorAll(".phone-tab-btn");
  const appPanels = document.querySelectorAll(".app-panel");
  phoneTabBtns.forEach((btn) => {
    btn.addEventListener("click", () => {
      const target = btn.getAttribute("data-tab");
      phoneTabBtns.forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      appPanels.forEach((panel) => {
        panel.classList.toggle("active", panel.id === `view-${target}`);
      });
    });
  });

  /* 5. Tappable dose card */
  const dose1 = document.getElementById("demoDose1");
  const dosePill1 = document.getElementById("dosePill1");
  let dose1Taken = false;
  dose1?.addEventListener("click", () => {
    dose1Taken = !dose1Taken;
    dose1.classList.toggle("taken", dose1Taken);
    if (dosePill1) {
      dosePill1.textContent = dose1Taken ? "Taken ✓" : "Take now";
      dosePill1.className = dose1Taken
        ? "med-action-pill med-action-taken"
        : "med-action-pill med-action-pink";
    }
  });

  /* 6. Generic medicine price comparator */
  const genericDatabase = {
    napa: {
      brand: "Napa 500mg Tablet",
      manufacturer: "Beximco Pharmaceuticals Ltd.",
      price: "MRP: ৳1.20 / tab",
      generic: "Paracetamol 500mg",
      alternatives: [
        {
          name: "Ace 500mg",
          mfg: "Square Pharmaceuticals",
          price: "৳0.80",
          saving: "Save 33%",
        },
        {
          name: "Renova 500mg",
          mfg: "Opso Saline Ltd.",
          price: "৳0.80",
          saving: "Save 33%",
        },
        {
          name: "Fast 500mg",
          mfg: "Acme Laboratories Ltd.",
          price: "৳0.80",
          saving: "Save 33%",
        },
        {
          name: "Pyrex 500mg",
          mfg: "Incepta Pharmaceuticals",
          price: "৳0.85",
          saving: "Save 29%",
        },
      ],
    },
    seclo: {
      brand: "Seclo 20mg Capsule",
      manufacturer: "Square Pharmaceuticals PLC",
      price: "MRP: ৳7.00 / cap",
      generic: "Omeprazole 20mg",
      alternatives: [
        {
          name: "Proceptin 20mg",
          mfg: "Beximco Pharmaceuticals",
          price: "৳5.00",
          saving: "Save 28%",
        },
        {
          name: "Omecon 20mg",
          mfg: "Popular Pharmaceuticals",
          price: "৳5.00",
          saving: "Save 28%",
        },
        {
          name: "Esofag 20mg",
          mfg: "Incepta Pharmaceuticals",
          price: "৳5.00",
          saving: "Save 28%",
        },
        {
          name: "Lokit 20mg",
          mfg: "Acme Laboratories Ltd.",
          price: "৳5.50",
          saving: "Save 21%",
        },
      ],
    },
    montene: {
      brand: "Montene 10mg Tablet",
      manufacturer: "Incepta Pharmaceuticals Ltd.",
      price: "MRP: ৳16.00 / tab",
      generic: "Montelukast 10mg",
      alternatives: [
        {
          name: "Romilast 10mg",
          mfg: "Popular Pharmaceuticals",
          price: "৳12.99",
          saving: "Save 25%",
        },
        {
          name: "Monas 10mg",
          mfg: "Acme Laboratories Ltd.",
          price: "৳14.00",
          saving: "Save 12%",
        },
        {
          name: "Odmon 10mg",
          mfg: "Square Pharmaceuticals",
          price: "৳14.00",
          saving: "Save 12%",
        },
        {
          name: "Mona 10mg",
          mfg: "Renata Limited",
          price: "৳14.00",
          saving: "Save 12%",
        },
      ],
    },
    sergel: {
      brand: "Sergel 20mg Capsule",
      manufacturer: "Healthcare Pharmaceuticals Ltd.",
      price: "MRP: ৳10.00 / cap",
      generic: "Esomeprazole 20mg",
      alternatives: [
        {
          name: "Opton 20mg",
          mfg: "Incepta Pharmaceuticals",
          price: "৳7.00",
          saving: "Save 30%",
        },
        {
          name: "Nexum 20mg",
          mfg: "Square Pharmaceuticals",
          price: "৳8.00",
          saving: "Save 20%",
        },
        {
          name: "Maxima 20mg",
          mfg: "Beximco Pharmaceuticals",
          price: "৳8.00",
          saving: "Save 20%",
        },
        {
          name: "Esonix 20mg",
          mfg: "Renata Limited",
          price: "৳8.00",
          saving: "Save 20%",
        },
      ],
    },
  };

  const genericCompareBox = document.getElementById("genericCompareBox");

  function renderGenericComparison(medKey) {
    const data = genericDatabase[medKey];
    if (!data || !genericCompareBox) return;

    genericCompareBox.classList.add("fading");
    setTimeout(
      () => {
        const altHtml = data.alternatives
          .map(
            (alt) => `
        <div class="alt-result-row">
          <div><strong>${alt.name}</strong> • ${alt.mfg}</div>
          <div class="alt-price-tag">${alt.price} <span class="badge-saving">${alt.saving}</span></div>
        </div>`,
          )
          .join("");

        genericCompareBox.innerHTML = `
        <div class="current-brand-row">
          <div>
            <span class="table-brand-name">${data.brand}</span>
            <span class="table-brand-mfg">${data.manufacturer}</span>
          </div>
          <div class="table-brand-price">${data.price}</div>
        </div>
        <div class="alt-list-title">Cheaper brands with the same generic (${data.generic}):</div>
        <div class="alt-items-list">${altHtml}</div>`;
        genericCompareBox.classList.remove("fading");
      },
      prefersReducedMotion ? 0 : 220,
    );
  }

  document.querySelectorAll(".med-search-chip").forEach((chip) => {
    chip.addEventListener("click", () => {
      document
        .querySelectorAll(".med-search-chip")
        .forEach((c) => c.classList.remove("active"));
      chip.classList.add("active");
      const medKey = chip.getAttribute("data-med");
      if (medKey) renderGenericComparison(medKey);
    });
  });

  /* 7. AI assistant query demo */
  const aiKnowledgeBase = {
    timing: `<strong>AI Guidance:</strong> Take <strong>Omeprazole (e.g. Seclo)</strong> 30–60 minutes before breakfast on an empty stomach for optimal gastric acid reduction.<div class="ai-action-demo-pill">⚡ Action: Set dose reminder for 7:30 AM</div>`,
    food: `<strong>AI Guidance:</strong> <strong>Montelukast (Montene)</strong> can be taken with or without meals. It is recommended to take it in the evening before sleep.<div class="ai-action-demo-pill">⚡ Action: Scheduled bedtime reminder at 9:30 PM</div>`,
    action: `<strong>AI Guidance:</strong> Extracted: <strong>Paracetamol 500mg Tablet</strong> (1+0+1, after food for 3 days).<div class="ai-action-demo-pill">✓ Action: Added 2 daily reminders (8:00 AM &amp; 8:00 PM)</div>`,
  };

  const aiResponseBox = document.getElementById("aiDemoResponse");
  document.querySelectorAll(".query-chip").forEach((chip) => {
    chip.addEventListener("click", () => {
      document
        .querySelectorAll(".query-chip")
        .forEach((c) => c.classList.remove("active"));
      chip.classList.add("active");
      const queryKey = chip.getAttribute("data-query");
      if (aiResponseBox && queryKey && aiKnowledgeBase[queryKey]) {
        aiResponseBox.classList.add("fading");
        setTimeout(
          () => {
            aiResponseBox.innerHTML = aiKnowledgeBase[queryKey];
            aiResponseBox.classList.remove("fading");
          },
          prefersReducedMotion ? 0 : 220,
        );
      }
    });
  });

  /* 8. Streak counter */
  const logDoseBtn = document.getElementById("logDoseBtn");
  const streakCountDisplay = document.getElementById("streakCount");
  let currentStreak = 7;
  let loggedToday = false;
  logDoseBtn?.addEventListener("click", () => {
    loggedToday = !loggedToday;
    currentStreak += loggedToday ? 1 : -1;
    if (streakCountDisplay)
      streakCountDisplay.textContent = `${currentStreak} Day Streak 🔥`;
    logDoseBtn.classList.toggle("logged", loggedToday);
    logDoseBtn.querySelector("span").textContent = loggedToday
      ? "✓ Dose Logged for Today"
      : "+ Log Afternoon Dose";
  });

  /* 9. Clinical summary copy */
  const copySummaryBtn = document.getElementById("copySummaryBtn");
  copySummaryBtn?.addEventListener("click", () => {
    const textToCopy = `=== MEDITRACK CLINICAL SUMMARY ===\nPatient: Rahi | Adherence: 94.2% (Last 30 Days)\nActive Meds: Napa Extra (500mg, 1+0+1), Seclo (20mg, 1+0+0)\nRefill Status: All active stocks sufficient for 14+ days\nVerified on: 25 August 2026 via MediTrack`;
    navigator.clipboard?.writeText(textToCopy);
    const label = copySummaryBtn.querySelector("span");
    if (label) {
      label.textContent = "✓ Copied to Clipboard!";
      setTimeout(() => {
        label.textContent = "📋 Copy Summary to Clipboard";
      }, 2500);
    }
  });

  /* 10. Savings calculator with tweened count-up */
  const medsSlider = document.getElementById("medsSlider");
  const spendSlider = document.getElementById("spendSlider");
  const medsValueBadge = document.getElementById("medsValueBadge");
  const spendValueBadge = document.getElementById("spendValueBadge");
  const annualDosesVal = document.getElementById("annualDosesVal");
  const missedPreventedVal = document.getElementById("missedPreventedVal");
  const genericSavingsVal = document.getElementById("genericSavingsVal");
  const adherenceScoreVal = document.getElementById("adherenceScoreVal");

  const activeTweens = new Map();

  function tweenText(el, target, format) {
    if (!el) return;
    const from = parseFloat(el.dataset.v || "0") || 0;
    if (prefersReducedMotion) {
      el.dataset.v = String(target);
      el.textContent = format(target);
      return;
    }
    if (activeTweens.has(el)) cancelAnimationFrame(activeTweens.get(el));
    const t0 = performance.now();
    const duration = 550;
    function step(t) {
      const p = Math.min(1, (t - t0) / duration);
      const eased = 1 - Math.pow(1 - p, 3);
      const value = from + (target - from) * eased;
      el.textContent = format(value);
      if (p < 1) {
        activeTweens.set(el, requestAnimationFrame(step));
      } else {
        el.dataset.v = String(target);
        activeTweens.delete(el);
      }
    }
    activeTweens.set(el, requestAnimationFrame(step));
  }

  function updateCalculator() {
    const dailyMeds = parseInt(medsSlider ? medsSlider.value : "3", 10);
    const monthlySpend = parseInt(spendSlider ? spendSlider.value : "2000", 10);

    if (medsValueBadge)
      medsValueBadge.textContent = `${dailyMeds} ${dailyMeds === 1 ? "medication" : "medications"}`;
    if (spendValueBadge)
      spendValueBadge.textContent = `৳${monthlySpend.toLocaleString("en-IN")} / month`;

    // Fill the slider track up to the thumb position
    [medsSlider, spendSlider].forEach((slider) => {
      if (!slider) return;
      const min = parseFloat(slider.min);
      const max = parseFloat(slider.max);
      const pct = ((parseFloat(slider.value) - min) / (max - min)) * 100;
      slider.style.setProperty("--fill", `${pct}%`);
    });

    const annualDoses = dailyMeds * 365;
    const missedPrevented = Math.round(annualDoses * 0.22);
    const annualSavings = Math.round(monthlySpend * 12 * 0.3);
    const adherenceRate = Math.min(99.2, 94 + dailyMeds * 0.5);

    tweenText(annualDosesVal, annualDoses, (v) =>
      Math.round(v).toLocaleString("en-IN"),
    );
    tweenText(
      missedPreventedVal,
      missedPrevented,
      (v) => `${Math.round(v).toLocaleString("en-IN")} doses`,
    );
    tweenText(
      genericSavingsVal,
      annualSavings,
      (v) => `৳${Math.round(v).toLocaleString("en-IN")} / year`,
    );
    tweenText(adherenceScoreVal, adherenceRate, (v) => `${v.toFixed(1)}%`);
  }

  medsSlider?.addEventListener("input", updateCalculator);
  spendSlider?.addEventListener("input", updateCalculator);
  updateCalculator();

  /* 11. FAQ accordion */
  const faqItems = document.querySelectorAll(".faq-item");
  faqItems.forEach((item) => {
    item.querySelector(".faq-question")?.addEventListener("click", () => {
      const isOpen = item.classList.contains("active");
      faqItems.forEach((other) => other.classList.remove("active"));
      if (!isOpen) item.classList.add("active");
    });
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}

