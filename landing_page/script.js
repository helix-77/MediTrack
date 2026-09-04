/**
 * MediTrack landing page interactions.
 * - Floating pill nav
 * - Theme switcher (Light mode default, persistent in localStorage)
 * - Interactive phone demo (dose logging, progress animation, tab switcher)
 * - FAQ accordion
 * - Scroll reveals via IntersectionObserver
 */

function init() {
  /* 1. Theme Switcher (Light mode is default) */
  const savedTheme = localStorage.getItem("meditrack_theme");
  // If savedTheme is valid ("dark" or "light"), use it; otherwise default to "light"
  const initialTheme = savedTheme === "dark" ? "dark" : "light";
  document.documentElement.setAttribute("data-theme", initialTheme);

  const updateThemeAria = (theme) => {
    const isDark = theme === "dark";
    const label = isDark ? "Switch to light mode" : "Switch to dark mode";
    const toggleBtns = [
      document.getElementById("themeToggle"),
      document.getElementById("mobileThemeToggle"),
    ];
    toggleBtns.forEach((btn) => {
      if (btn) btn.setAttribute("aria-label", label);
    });
  };

  updateThemeAria(initialTheme);

  const handleThemeToggle = () => {
    const current =
      document.documentElement.getAttribute("data-theme") || "light";
    const next = current === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    localStorage.setItem("meditrack_theme", next);
    updateThemeAria(next);
  };

  const themeBtn = document.getElementById("themeToggle");
  if (themeBtn) {
    themeBtn.addEventListener("click", handleThemeToggle);
  }

  const mobileThemeBtn = document.getElementById("mobileThemeToggle");
  if (mobileThemeBtn) {
    mobileThemeBtn.addEventListener("click", handleThemeToggle);
  }

  /* 2. Nav scroll sentinel */
  const navbar = document.getElementById("navbar");
  const sentinel = document.getElementById("navSentinel");
  if (navbar && sentinel) {
    new IntersectionObserver(
      ([entry]) => {
        navbar.classList.toggle("is-scrolled", !entry.isIntersecting);
      },
      { rootMargin: "-40px 0px 0px 0px", threshold: 0 },
    ).observe(sentinel);
  }

  /* 3. Mobile menu */
  const burger = document.getElementById("navBurger");
  const menu = document.getElementById("mobileMenu");
  if (burger && menu) {
    const setOpen = (open) => {
      burger.setAttribute("aria-expanded", String(open));
      burger.setAttribute("aria-label", open ? "Close menu" : "Open menu");
      menu.hidden = !open;
      document.body.style.overflow = open ? "hidden" : "";
    };
    burger.addEventListener("click", () => {
      setOpen(burger.getAttribute("aria-expanded") !== "true");
    });
    menu.addEventListener("click", (event) => {
      if (event.target.closest("a")) setOpen(false);
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") setOpen(false);
    });
  }

  /* 4. Scroll reveals */
  const revealables = document.querySelectorAll("[data-reveal]");
  if (revealables.length > 0) {
    const revealObserver = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-revealed");
            revealObserver.unobserve(entry.target);
          }
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" },
    );
    revealables.forEach((el) => revealObserver.observe(el));
  }

  /* 5. Phone demo: Tab switching (Routine, Rx Scan, Generics, AI Chat) */
  const tabBtns = document.querySelectorAll(".phone-tab-btn");
  const panels = {
    routine: document.getElementById("view-routine"),
    scanner: document.getElementById("view-scanner"),
    generics: document.getElementById("view-generics"),
    ai: document.getElementById("view-ai"),
  };

  tabBtns.forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const targetTab = btn.getAttribute("data-tab");
      tabBtns.forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");

      Object.values(panels).forEach((panel) => {
        if (panel) panel.classList.remove("active");
      });

      if (panels[targetTab]) {
        panels[targetTab].classList.add("active");
      }
    });
  });

  /* 6. Phone demo: Interactive dose logging animation */
  const doseItem = document.getElementById("demoDose1");
  const dosePill = document.getElementById("dosePill1");
  const progressBar = document.getElementById("progressBarFill");
  const progressBadge = document.getElementById("progressBadge");
  const progressSub = document.getElementById("progressSub");

  if (doseItem && dosePill) {
    doseItem.addEventListener("click", () => {
      const isTaken = doseItem.classList.toggle("is-taken");
      dosePill.classList.toggle("taken", isTaken);
      dosePill.textContent = isTaken ? "Taken ✓" : "Take now";

      if (progressBar) {
        progressBar.style.width = isTaken ? "80%" : "60%";
      }
      if (progressBadge) {
        progressBadge.textContent = isTaken ? "80%" : "60%";
      }
      if (progressSub) {
        progressSub.textContent = isTaken
          ? "4 of 5 doses completed"
          : "3 of 5 doses completed";
      }
    });
  }

  /* 7. FAQ accordion (one open at a time) */
  const faqItems = document.querySelectorAll(".faq-item");
  faqItems.forEach((item) => {
    const question = item.querySelector(".faq-q");
    if (!question) return;
    question.addEventListener("click", () => {
      const isOpen = item.classList.contains("is-open");
      faqItems.forEach((other) => {
        other.classList.remove("is-open");
        const q = other.querySelector(".faq-q");
        if (q) q.setAttribute("aria-expanded", "false");
      });
      if (!isOpen) {
        item.classList.add("is-open");
        question.setAttribute("aria-expanded", "true");
      }
    });
  });

  /* 8. Clinical AI Showcase: Interactive Prompt Chips */
  const promptData = {
    seclo: {
      text: "<strong>AI Guidance:</strong> Take Omeprazole (e.g. Seclo) 30–60 minutes before breakfast on an empty stomach for optimal gastric acid reduction.",
      action: '<i class="ph ph-lightning-fill" aria-hidden="true"></i><span>Action: Set dose reminder for 7:30 AM</span>',
    },
    montene: {
      text: "<strong>AI Guidance:</strong> Take Montelukast (e.g. Montene) once daily in the evening with or without food for consistent airway management.",
      action: '<i class="ph ph-lightning-fill" aria-hidden="true"></i><span>Action: Set dose reminder for 9:30 PM</span>',
    },
    rx: {
      text: "<strong>AI Guidance:</strong> Verified 2 active medicines from Rx image: Napa Extra 500mg (1+0+1, 7 days) and Seclo 20mg (1+0+0, 14 days).",
      action: '<i class="ph ph-lightning-fill" aria-hidden="true"></i><span>Action: Add both courses to Daily Routine</span>',
    },
  };

  const scChips = document.querySelectorAll(".sc-chip");
  const guidanceText = document.getElementById("guidanceText");
  const guidanceAction = document.getElementById("guidanceAction");

  scChips.forEach((chip) => {
    chip.addEventListener("click", () => {
      scChips.forEach((c) => c.classList.remove("active"));
      chip.classList.add("active");

      const promptKey = chip.getAttribute("data-prompt");
      if (promptData[promptKey] && guidanceText && guidanceAction) {
        guidanceText.style.opacity = "0";
        guidanceAction.style.opacity = "0";
        setTimeout(() => {
          guidanceText.innerHTML = promptData[promptKey].text;
          guidanceAction.innerHTML = promptData[promptKey].action;
          guidanceText.style.opacity = "1";
          guidanceAction.style.opacity = "1";
        }, 120);
      }
    });
  });

  /* 9. Clinical Export: Copy Summary to Clipboard */
  const copyBtn = document.getElementById("copySummaryBtn");
  const copyIcon = document.getElementById("copySummaryIcon");
  const copyLabel = document.getElementById("copySummaryLabel");
  const summaryPre = document.getElementById("clinicalSummaryText");

  if (copyBtn && summaryPre && copyLabel) {
    copyBtn.addEventListener("click", async () => {
      try {
        const textToCopy = summaryPre.innerText || summaryPre.textContent;
        await navigator.clipboard.writeText(textToCopy);
        copyBtn.classList.add("is-copied");
        copyLabel.textContent = "✓ Copied to Clipboard!";
        if (copyIcon) {
          copyIcon.className = "ph ph-check-bold";
        }
        setTimeout(() => {
          copyBtn.classList.remove("is-copied");
          copyLabel.textContent = "Copy Summary to Clipboard";
          if (copyIcon) {
            copyIcon.className = "ph ph-clipboard-text";
          }
        }, 2200);
      } catch {
        copyLabel.textContent = "Copied!";
        setTimeout(() => {
          copyLabel.textContent = "Copy Summary to Clipboard";
        }, 1500);
      }
    });
  }

  /* 10. Nearby Pharmacy Finder: City Quick Filter & Deep Links */
  const cityChips = document.querySelectorAll(".city-chip");
  const catEmergency = document.getElementById("catEmergency");
  const catModel = document.getElementById("catModel");
  const catChemist = document.getElementById("catChemist");
  const mainMapsCta = document.getElementById("mainMapsCta");
  const mapsStatusLabel = document.getElementById("mapsStatusLabel");

  cityChips.forEach((chip) => {
    chip.addEventListener("click", () => {
      cityChips.forEach((c) => c.classList.remove("active"));
      chip.classList.add("active");

      const city = chip.getAttribute("data-city");
      const isGPS = city === "near me";
      const querySuffix = isGPS ? "near me" : city;

      if (catEmergency) {
        catEmergency.href = `https://www.google.com/maps/search/?api=1&query=24+hours+pharmacy+emergency+medicine+${encodeURIComponent(querySuffix)}`;
      }
      if (catModel) {
        catModel.href = `https://www.google.com/maps/search/?api=1&query=model+pharmacy+hospital+${encodeURIComponent(querySuffix)}`;
      }
      if (catChemist) {
        catChemist.href = `https://www.google.com/maps/search/?api=1&query=medicine+store+chemist+${encodeURIComponent(querySuffix)}`;
      }
      if (mainMapsCta) {
        mainMapsCta.href = `https://www.google.com/maps/search/?api=1&query=pharmacy+${encodeURIComponent(querySuffix)}`;
      }
      if (mapsStatusLabel) {
        mapsStatusLabel.textContent = isGPS
          ? "Google Maps Deep Link Active (GPS)"
          : `Google Maps Deep Link Active (${city})`;
      }
    });
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
