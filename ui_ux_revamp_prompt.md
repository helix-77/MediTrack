# MediTrack UI/UX Revamp — Implementation Prompt

## Objective

You are the lead Flutter UI/UX engineer responsible for revamping the existing MediTrack application.

**Do not redesign the product from scratch. Do not remove features. Do not simplify the application by deleting screens or functionality.**

Use:

- **Existing Flutter repository = source of truth for functionality**
- **Updated Figma file = source of truth for visual language**
- **Your own engineering/UX reasoning = bridge between them**

Updated Figma:
https://www.figma.com/design/GGiUNzAPNMOSsYw5OmpiNq

The Figma contains reference screens, but the existing Flutter app contains more screens. Every existing screen must be brought into the same design system, even when there is no direct Figma counterpart.

---

# 1. First: Audit the Existing App

Before making broad UI changes, inspect the whole Flutter project.

Inventory:

- every route and screen;
- navigation flows;
- reusable widgets/components;
- theme files;
- colors and typography;
- state management;
- providers/controllers;
- services;
- API/database integrations;
- authentication;
- forms and validation;
- OCR/image processing;
- medicine management;
- schedules/reminders;
- adherence/dose tracking;
- prescription scanning/review;
- price/reference-price lookup;
- generic alternatives;
- pharmacy/location flows;
- Google Maps handoff;
- records/history;
- profile/settings;
- AI-related features;
- dialogs, bottom sheets, loading states, empty states, errors;
- any other feature already present.

**Do not assume this list is exhaustive. The repository is authoritative.**

Create a mental feature/screen map before refactoring.

---

# 2. Non-Negotiable: Preserve Functionality

The redesign must preserve **100% of the existing functionality**.

Do not:

- remove routes;
- delete screens;
- disable existing actions;
- hide features because they are absent from Figma;
- replace real functionality with mockups;
- remove API/database behavior;
- remove OCR;
- remove validation;
- remove loading/error/success handling;
- break navigation;
- rewrite business logic unnecessarily.

Preserve the **behavior**, not necessarily the existing presentation code.

If an existing widget is badly structured, refactor or replace it while preserving its behavior.

---

# 3. Study the Updated Figma Properly

Open the Figma file and inspect the actual screens/components.

Study:

- background tone;
- surface colors;
- shadow direction and softness;
- elevation;
- amount of neumorphism;
- amount of flat design;
- restrained use of glass/transparency;
- borders;
- corner radii;
- typography;
- icon sizes;
- icon containers;
- card padding;
- screen padding;
- section spacing;
- CTA placement;
- navigation;
- selected states;
- status pills;
- categorical colors;
- information density;
- alignment.

Do not merely copy coordinates from the reference frames.

Extract the **design principles** and reproduce those principles throughout the application.

---

# 4. Core Design Language

The target aesthetic is:

> **Soft-neumorphic healthcare UI + cool blue-gray canvas + white raised surfaces + pastel categorical accents + dark navy typography + generous whitespace.**

The app should feel:

- calm;
- premium;
- friendly;
- clinical without feeling institutional;
- spacious;
- coherent.

It should NOT feel like:

- a generic Material UI app;
- an enterprise dashboard;
- heavy 2020-era neumorphism;
- glassmorphism everywhere;
- a collection of unrelated screens.

---

# 5. Background

Use a cool, very pale blue-gray canvas.

Approximate starting value:

```text
<!-- #E8EFF2 -->
#EFF1F5
```

The exact value may be adjusted after inspecting Figma.

Avoid:

- pure white everywhere;
- warm beige/cream backgrounds;
- excessive gradients;
- dark backgrounds unless required by an existing feature.

The background should create the environment from which light surfaces appear subtly raised.

---

# 6. Surface & Elevation System

Primary surfaces should be very light, approximately:

```text
#F7FAFB
```

Use **soft neumorphism**, not aggressive neumorphism.

The visual relationship is:

```text
cool blue-gray canvas
        ↓
light surface
        ↓
very soft ambient elevation
        ↓
content
```

Use extremely diffuse shadows/highlights.

Conceptually:

```text
soft light highlight
+
soft cool/dark ambient shadow
```

The shadow should communicate depth without becoming an obvious decorative element.

If the shadow itself is visually prominent, it is too strong.

Avoid:

```text
heavy black drop shadows
```

Avoid visible 1px borders as the primary way of separating cards.

Prefer:

- tonal contrast;
- soft elevation;
- shape;
- spacing;
- accent color.

---

# 7. Neumorphism / Flat / Glass Balance

Use a hybrid design system.

### Soft neumorphism

Use for:

- primary cards;
- medicine cards;
- summary/metric cards;
- floating controls;
- bottom navigation containers;
- selected states;
- circular icon containers;
- major interactive surfaces.

### Flat / low elevation

Use for:

- typography;
- metadata;
- section labels;
- simple informational content;
- content that does not need to feel interactive.

### Glassmorphism

Use **very sparingly**.

Do not turn MediTrack into a glassmorphism app.

If translucency is useful for a floating overlay, modal, or navigation surface, keep it subtle.

Primary language:

> **soft neumorphism, not glassmorphism.**

---

# 8. Color System

### Primary Blue

Approximate:

```text
#5B8FF5
```

Use for:

- primary CTAs;
- selected states;
- active navigation;
- progress;
- important actions;
- primary interactive controls.

### Pink

Approximate:

```text
#F45BA5
```

Use as a meaningful categorical accent.

Good for:

- secondary healthcare categories;
- reminders/secondary events;
- contextual states.

### Orange

Approximate:

```text
#FFB45F
```

Use for:

- tertiary categories;
- contextual medication information;
- non-critical attention states.

Do not use orange as a generic warning color everywhere.

### Typography

Primary:

```text
#18233D
```

Use deep navy instead of pure black.

Secondary text should be muted slate/blue-gray.

Do not make every element colorful.

The application should remain predominantly:

```text
cool canvas
+
light surfaces
+
navy text
```

with blue/pink/orange used selectively.

---

# 9. Typography

Use a modern geometric sans-serif consistent with the Figma design.

Preferred direction:

```text
Plus Jakarta Sans
```

Use a clear hierarchy:

```text
Major heading
Section heading
Card title
Body
Metadata
Caption
```

Typography should carry most of the visual hierarchy.

Do not compensate for weak hierarchy by adding borders, dividers, or excessive icons.

---

# 10. Shape Language

Use generous but controlled rounding.

Starting guidance:

```text
Small controls:      12–14px
Standard controls:   14–16px
Cards:               20–24px
Large surfaces:      24–28px
Circular controls:   50%
```

Do not make every element pill-shaped.

Use pills primarily for:

- status;
- category;
- compact state;
- small actions.

---

# 11. Spacing & Padding — High Priority

Fix the padding inconsistencies in the existing application.

Start with this spacing scale:

```text
4
8
12
16
20
24
32
40
```

Typical guidance:

```text
Screen horizontal padding: 20–24px
Card internal padding:     16–20px
Small control padding:     12–16px
Section gap:               16–24px
Major section gap:         24–32px
```

Do not apply one padding value blindly everywhere.

Fix:

- inconsistent EdgeInsets;
- cramped cards;
- excessive nested padding;
- text touching card edges;
- icons with insufficient breathing room;
- inconsistent button heights;
- misaligned section headings;
- list items with inconsistent vertical rhythm;
- hardcoded offsets;
- rigid widths causing text overflow;
- unnecessary SizedBox chains;
- content colliding with safe areas.

Use a consistent layout grid.

---

# 12. Responsive Flutter Layout

Do not hardcode the Figma coordinates into Flutter.

Translate the design into responsive relationships.

Prefer:

- `Padding`;
- `SafeArea`;
- `Expanded`;
- `Flexible`;
- `LayoutBuilder`;
- `ConstrainedBox`;
- `Wrap`;
- `ListView`;
- `CustomScrollView`;
- slivers where appropriate.

Avoid fragile layouts based on excessive:

```dart
Positioned(...)
```

or fixed pixel offsets.

The result must handle:

- different phone widths;
- long medicine names;
- dynamic content;
- accessibility font scaling;
- localization;
- scrolling.

---

# 13. Component Architecture

Inspect the existing widget architecture before creating new components.

Refactor shared components rather than redesigning every screen independently.

Potential reusable components include:

```text
SoftSurface
SoftCard
PrimaryButton
SecondaryButton
SoftIconButton
StatusPill
CategoryPill
MedicineCard
ScheduleCard
MetricCard
SectionHeader
SearchField
SoftBottomNavigation
DateSelector
InfoBanner
EmptyState
LoadingState
```

These are examples, not mandatory names.

Use existing project naming conventions when they are sensible.

Avoid creating many near-duplicate widgets.

If multiple screens use the same visual pattern, make it reusable.

---

# 14. Screens Missing From Figma

The Figma reference is **not a complete screen inventory**.

For every screen that exists in Flutter but is not shown in Figma:

1. understand its actual purpose;
2. preserve its existing functionality;
3. find the closest visual pattern in the Figma design;
4. apply the same surface, typography, spacing, color, elevation and interaction principles;
5. use your own UX judgment to create the missing layout.

Do NOT ask for a Figma screen for every missing page.

The intended result is:

> **one complete MediTrack product redesigned around one coherent visual and interaction system.**

Not:

> six redesigned screens surrounded by legacy screens.

---

# 15. UX Principles

For every screen, determine:

- the user's primary goal;
- the most important information;
- the primary action;
- secondary actions;
- related information groups;
- what should be visually emphasized;
- what can be visually quiet.

Ask:

> “If I were a real MediTrack user, is the next action obvious?”

Prefer:

```text
clear hierarchy
+
whitespace
+
grouping
+
obvious CTA
```

over:

```text
dense cards
+
many borders
+
many icons
+
many colors
```

Preserve access to detailed information while reducing visual noise.

---

# 16. Interaction States

Every interactive component should account for its actual states:

```text
default
pressed
selected
active
disabled
loading
success
warning
error
empty
```

Use combinations of:

```text
color
+
shape
+
elevation
+
typography
+
iconography
```

Do not depend solely on color to communicate state.

---

# 17. Navigation

Preserve the current navigation architecture unless there is a clear UX improvement.

The Figma reference suggests a clean navigation language:

- soft bottom navigation surface;
- small icons;
- concise labels;
- clear active state;
- blue emphasis for the active/primary destination.

If the existing app has more destinations, integrate them intelligently.

Do not delete routes just to match the Figma reference.

---

# 18. Preserve Product Areas

Make sure the redesign preserves every feature discovered in the repository.

Known MediTrack areas include concepts such as:

- authentication/onboarding;
- dashboard;
- medicines;
- medicine details;
- manual medicine entry;
- medicine-box scanning/OCR;
- prescription scanning/review;
- schedules;
- reminders;
- dose tracking/adherence;
- history/records;
- price/reference-price lookup;
- generic alternatives;
- nearby pharmacy discovery;
- Google Maps handoff;
- profile/settings;
- health summaries;
- existing AI-assisted functionality.

**Again: this is not an exhaustive feature list. Inspect the repository.**

---

# 19. Flutter Engineering Rules

This is primarily a presentation/UX refactor.

Do not rewrite working business logic simply because the UI is changing.

Prefer:

```text
existing business logic
+
refactored presentation layer
```

rather than unnecessarily replacing:

```text
business logic
+
data layer
+
services
+
state management
```

Keep existing API/database integrations intact.

Keep real data.

Keep real loading/error/success behavior.

Do not turn functional screens into static mockups.

---

# 20. Centralized Theme

Create or refactor the project's centralized theme/design tokens where appropriate.

Centralize:

- colors;
- typography;
- spacing;
- radii;
- shadows;
- component heights;
- icon sizes;
- animation durations.

Use existing project abstractions if they already serve this purpose.

Do not create duplicate theme systems.

Conceptually, the design system may include:

```text
AppColors
AppSpacing
AppRadii
AppShadows
AppTypography
AppTheme
```

---

# 21. Implementation Order

### Phase 1 — Audit

Inventory the complete application.

Create a checklist of:

- screens;
- routes;
- features;
- widgets;
- reusable components;
- stateful flows.

### Phase 2 — Figma Analysis

Study the updated Figma deeply.

Extract:

- colors;
- surfaces;
- shadows;
- elevation;
- radii;
- typography;
- spacing;
- icon treatment;
- navigation;
- interaction states.

### Phase 3 — Foundation

Build/refactor:

- theme;
- colors;
- typography;
- spacing;
- radii;
- shadows;
- surfaces;
- buttons;
- inputs;
- status pills;
- icon containers;
- navigation.

### Phase 4 — Shared Components

Update the highest-leverage widgets first.

### Phase 5 — Screen Refactor

Redesign all screens, including those not represented in Figma.

Prioritize the main flows:

1. Home
2. Medicines
3. Add Medicine
4. Medicine Details
5. Prescription/OCR
6. Schedule/Reminders
7. Price & Generic
8. Pharmacy Search
9. Records/History
10. Profile/Settings
11. Every additional screen discovered in the repository

### Phase 6 — UX Review

Check:

- hierarchy;
- CTA placement;
- discoverability;
- navigation;
- empty states;
- loading states;
- error states;
- confirmation;
- back navigation.

### Phase 7 — Visual QA

Compare implementation against Figma.

Check:

- background tone;
- surface tone;
- shadow softness;
- padding;
- alignment;
- typography;
- icon scale;
- radii;
- button dimensions;
- navigation;
- safe areas;
- scrolling;
- overflow.

---

# 22. Accessibility

Do not sacrifice usability for aesthetics.

Ensure:

- adequate contrast;
- readable font sizes;
- adequate touch targets;
- semantic labels;
- accessible controls;
- meaningful errors;
- focus/keyboard behavior where applicable;
- screen-reader semantics where applicable.

Neumorphic depth must never be the only indication that something is interactive.

---

# 23. Quality Bar

Do not stop when the project compiles.

The final product should feel intentionally designed.

A reviewer should not be able to identify obvious “old UI” and “new UI” boundaries.

All screens should feel like they belong to the same healthcare product team.

The desired result:

> **calm + premium + modern + clinical + friendly**

not:

> **generic Material UI + random pastel colors + excessive shadows**

---

# 24. Final Acceptance Checklist

## Functionality

- [ ] Every existing feature still works.
- [ ] Every existing route remains reachable.
- [ ] Business logic remains intact.
- [ ] API/database behavior remains intact.
- [ ] OCR/scanning remains functional.
- [ ] Forms and validation remain functional.
- [ ] Navigation remains functional.
- [ ] Loading/error/success states remain functional.

## Visual

- [ ] Cool blue-gray background is consistent.
- [ ] Light surfaces are consistent.
- [ ] Shadows are soft and restrained.
- [ ] Hard borders are minimized.
- [ ] Navy typography is consistent.
- [ ] Blue is the primary interaction color.
- [ ] Pink/orange are meaningful categorical accents.
- [ ] Radii are consistent.
- [ ] Typography hierarchy is clear.
- [ ] Neumorphism is subtle.
- [ ] Glassmorphism is not overused.
- [ ] The UI is not visually noisy.

## Layout

- [ ] Screen padding is consistent.
- [ ] Card padding is consistent.
- [ ] Section spacing is consistent.
- [ ] Text never touches card edges.
- [ ] Touch targets are adequate.
- [ ] Bottom navigation respects safe areas.
- [ ] Long content scrolls correctly.
- [ ] Text does not overflow.
- [ ] Layouts work on realistic device sizes.

## UX

- [ ] Primary actions are obvious.
- [ ] Secondary actions remain discoverable.
- [ ] States are visually understandable.
- [ ] Empty/loading/error states are intentional.
- [ ] Navigation is coherent.
- [ ] Screens absent from Figma still follow the same design language.

---

# Final Instruction

**Use the Figma design as the visual north star. Use the existing Flutter repository as the functional source of truth. Use your own reasoning to bridge the two.**

Do not ask for individual Figma designs for screens that are not represented.

Do not remove features because they are not represented in Figma.

If a widget does not fit the new visual language, refactor or replace its presentation while preserving behavior.

If several widgets duplicate the same pattern, consolidate them when appropriate.

If the current layout is technically functional but visually poor, improve it.

If the Figma design suggests a better UX principle, apply that principle across the rest of the application where appropriate.

The final result must be:

> **The complete existing MediTrack application, with every feature preserved, but redesigned as one coherent soft-neumorphic healthcare product based on the updated Figma design.**
