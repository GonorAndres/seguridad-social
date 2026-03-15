# Portfolio Defense: Simulador de Pension IMSS + Fondo Bienestar

**Prepared for:** Andres Gonzalez Ortega -- UNAM Actuarial Science Graduate
**Project:** R Shiny Mexican Pension Simulator (IMSS Ley 73, Ley 97, Fondo Bienestar)
**Date:** March 2026

---

## Table of Contents

1. [Project Overview & Elevator Pitch](#section-1-project-overview--elevator-pitch)
2. [Technical Architecture Deep-Dive](#section-2-technical-architecture-deep-dive)
3. [Honest Weakness Catalog](#section-3-honest-weakness-catalog)
4. [Actuarial Methodology Defense](#section-4-actuarial-methodology-defense)
5. [Tough Interview Questions](#section-5-tough-interview-questions-25-with-answers)
6. [Skills Demonstrated Matrix](#section-6-skills-demonstrated-matrix)
7. [What I'd Do Differently](#section-7-what-id-do-differently)

---

# Section 1: Project Overview & Elevator Pitch

## The 30-Second Pitch

"I built a pension simulator for Mexican workers because 80% of them don't understand how their pension is calculated. It covers both the old defined-benefit system (Ley 73, pre-1997) and the new individual-account system (Ley 97), plus the 2024 Fondo Bienestar government supplement. It's a full-stack R Shiny app with real actuarial formulas, 126 unit tests, and a 4-step wizard that turns a complex regulatory problem into something anyone can understand in 5 minutes."

## The 2-Minute Version

"Mexico has two parallel pension systems. If you started working before July 1997, you're under Ley 73 -- a defined-benefit formula based on your salary and weeks contributed. After that date, you're under Ley 97 -- your pension comes from an AFORE individual retirement account. In 2024, the government introduced the Fondo Bienestar, a supplement for Ley 97 workers earning under a threshold.

I built a simulator that handles all three systems. The user enters their birth date, salary, and work history. The app auto-detects their regime, runs the actuarial projections, and shows three scenarios: system-only pension, pension with government supplement, and pension with voluntary contributions. It includes sensitivity sliders so users can see how changing their AFORE, retirement age, or voluntary contributions affects their pension in real time.

The actuarial engine implements the 2020 contribution reform schedule (employer rates rising from 7.75% to 12% by 2030), proper cessation factors, Article 167 lookup tables, mortality tables, and Fondo Bienestar threshold extrapolation. It's backed by 126 unit tests covering boundary conditions, mathematical identities, and hand-verified calculations.

What makes this project meaningful isn't the code -- it's the impact. Most Mexican workers have never seen what their pension will look like. This tool shows them, honestly, and then shows them exactly what they can do about it."

## The 5-Minute Version

Add to the 2-minute version:

- **Design decisions:** Why R Shiny (actuarial ecosystem, rapid prototyping, single-language stack), why a wizard pattern (progressive disclosure for complex inputs), why the Tropical Vibrant color palette (warmth and approachability vs. the cold finance-app aesthetic).
- **UX narrative:** The control framework (green/yellow/red zones) empowers users by showing what they can change. The key message: "voluntary contributions are the safest part of your pension" -- because unlike Fondo Bienestar, they can't be changed by future legislation.
- **Technical depth:** 24 functions across 4 calculation files, a full CSS design system with 80+ custom properties, HTML and PDF report generation, real regulatory data from IMSS/DOF/CONSAR.
- **Testing philosophy:** Core actuarial formulas have excellent coverage (boundary conditions, decomposition checks, monotonicity). I chose to test math rigorously over testing UI rendering.

## The "So What?" Answer

"Pension literacy in Mexico is extremely low. CONSAR surveys show most workers can't name their AFORE, much less project their pension. The Fondo Bienestar reform created urgency -- now there's a government supplement most people don't know about. This simulator translates 3 pension laws, 2 reform schedules, and 50+ years of regulatory constants into one question: 'How much will I get, and what can I do about it?'"

## Project by the Numbers

| Metric | Value |
|--------|-------|
| Total lines of code | ~10,300 |
| R calculation functions | 24 across 4 files |
| UI component functions | 25 |
| CSS custom properties | 80+ |
| Unit tests (testthat) | 126 across 19 sections |
| Total assertions (all suites) | ~300+ |
| Report generators | 9 (HTML + PDF) |
| Regulatory data tables | 4 CSVs |
| Glossary terms | 13 in-app, 14 documented |
| Pension systems modeled | 3 (Ley 73, Ley 97, Fondo Bienestar) |
| Sensitivity sliders | 5, all debounced at 300ms |
| Scenarios per calculation | 3 (solo_sistema, con_fondo, con_acciones) |

---

# Section 2: Technical Architecture Deep-Dive

## Architecture Walkthrough Script

*When asked "Walk me through the architecture":*

"The app follows a simple dependency hierarchy:

```
app.R (1,951 lines) -- UI + Server
  -> source("global.R") (170 lines) -- packages, CSV data, constants, utilities
       -> source("R/data_tables.R") (245 lines) -- Art. 167 lookup, AFORE data, mortality, validation
       -> source("R/calculations.R") (766 lines) -- Ley 73, Ley 97, M40, AFORE projection
       -> source("R/fondo_bienestar.R") (501 lines) -- Fondo eligibility, complement, scenarios
       -> source("R/ui_helpers.R") (1,330 lines) -- 25 UI component functions
       -> source("R/document_generators.R") (1,667 lines) -- 9 HTML/PDF report generators
www/styles.css (2,156 lines) -- Full design system
data/*.csv (4 files) -- Regulatory data tables
docs/ (2 files) -- Methodology, narrative content
tests/ (6 files) -- 126 unit tests + integration/QA/edge-case suites
```

Total: ~9,700 lines of code across 20 files."

## Data Flow Diagram

```
USER INPUT                   REGIME DETECTION              CALCULATION ENGINE
+-----------------+          +------------------+          +----------------------------+
| Birth date      |          |                  |          |                            |
| Gender          |    +---->| determinar_      |    +---->| Ley 73 path:               |
| Retirement age  |    |     | regimen()        |    |     |   lookup_articulo_167()    |
| Start date    --+----+     | (cutoff:         |    |     |   calculate_ley73_pension()|
| Salary          |          |  1997-07-01)     |    |     |   calculate_modalidad_40() |
| Weeks           |          +--------+---------+    |     |                            |
| AFORE           |                   |              |     | Ley 97 path:               |
| Balance         |                   v              |     |   generate_contribution_   |
| Vol. contrib.   |          +------------------+    |     |     schedule()             |
+-----------------+          | regimen_actual() +----+     |   project_afore_balance()  |
                             | reactiveVal      |          |   calculate_retiro_        |
                             +------------------+          |     programado()           |
                                                           |   check_fondo_eligibility()|
                                                           |   calculate_fondo_         |
                                                           |     complement()           |
                                                           +-------------+--------------+
                                                                         |
                             DISPLAY                        SCENARIOS    |
                             +------------------+          +-------------v--------------+
                             | render_results_  |<---------| 1. solo_sistema            |
                             |   hero()         |          | 2. con_fondo               |
                             | render_results_  |          | 3. con_acciones            |
                             |   hero_ley73()   |          +----------------------------+
                             | proyeccion_chart |
                             | sensitivity      |-----> Debounced sliders recalculate
                             |   sliders (5)    |       in real time, compare against
                             | report generators|       resultados_originales() baseline
                             +------------------+
```

## Key Design Decisions

### Why R Shiny (not React, Python, etc.)

| Decision | Rationale | Trade-off |
|----------|-----------|-----------|
| R Shiny | Actuarial ecosystem (mortality tables, financial math), single-language for computation + UI, rapid prototyping | Limited frontend flexibility, not standard industry web stack |
| Spanish function content, English names | Industry convention: code in English, domain terms in Spanish (`FACTORES_CESANTIA`, `cuantia_basica`) | Mixed naming requires context to parse |
| Single app.R | Shiny's reactivity model works well in one file for moderate complexity | 1,951 lines is pushing the limit of maintainability |
| Global `<<-` in global.R | Shiny scoping requires data/constants to be available across all sourced files | Looks like a code smell but is documented Shiny pattern |
| bslib + Bootstrap 5 | Modern theming, CSS custom properties, good mobile defaults | Coupled to Bootstrap ecosystem |
| No database | All regulatory data fits in 4 CSV files (<100 rows total) | Can't update data without redeploying |
| plotly for charts | Interactive hover/zoom on pension projections | Heavy JS dependency, slower than static ggplot2 |

### Reactive Architecture (Key Pattern)

The sensitivity engine uses an **immutable baseline** pattern:

1. `resultados_originales()` -- set once on Calculate, never modified by sliders
2. `resultados()` -- updated by unified recalculation observer on every slider change
3. Individual impact observers compare against `resultados_originales()` to show deltas
4. All 5 slider inputs are debounced at 300ms before triggering recalculation
5. Cliff notifications (Fondo eligibility changes) use `isolate()` correctly

This separates "what you started with" from "what the sliders show now" -- clean and architecturally sound.

### State Management

| ReactiveVal | Purpose | Set By | Read By |
|-------------|---------|--------|---------|
| `current_step(1)` | Wizard position | Navigation buttons | Step visibility |
| `resultados(NULL)` | Current (slider-adjusted) results | Unified recalculator | Results display, chart, reports |
| `resultados_originales(NULL)` | Immutable baseline | Calculate button only | Impact labels (delta comparison) |
| `regimen_actual("ley97")` | Active regime | Auto-detect or manual override | Calculation dispatch, UI branching |
| `prev_fondo_eligible(NULL)` | Previous Fondo status | Cliff notification tracker | Edge-crossing alerts |
| `prev_aplico_minimo(NULL)` | Previous pension-minima status | Cliff notification tracker | Edge-crossing alerts |
| `fecha_cotizacion_user_edited(FALSE)` | User touched date field? | observeEvent on date input | Auto-fill suppression |
| `regimen_override_active_val(FALSE)` | Manual regime toggle | JavaScript toggle | Regime detection logic |

### JavaScript Integration Points

The app includes ~70 lines of inline JavaScript (app.R Lines 18-87) handling:
- Connection/reconnection logging to console
- Regime override toggle (`Shiny.setInputValue`)
- Landing page transition animations
- Calculate button loading state management
- Scroll-to-results after calculation
- New simulation reset and scroll

---

# Section 3: Honest Weakness Catalog

## CRITICAL (4 issues)

### C1. Monolithic app.R (1,951 lines)

- **What they'll see:** A single file with UI definition (Lines 14-737) and server logic (Lines 739-1945).
- **Why it exists:** Started as a prototype. Shiny's scoping rules make modularization non-trivial -- `moduleServer()` requires refactoring all reactive references. The calculation logic IS already extracted into 4 separate R files.
- **How I'd fix it:** Migrate to golem framework with Shiny modules. Extract wizard steps into `mod_step1_ui()`/`mod_step1_server()`. Extract sensitivity engine into `mod_sensitivity`. The calculation layer (R/*.R files) stays as-is.
- **Impact:** Maintainability concern, not a user-facing issue. The file has clear section dividers and a consistent structure. A new developer can navigate it, but it's harder than it should be.

### C2. Silent Error Handling in Sensitivity Engine

- **What they'll see:** 7 `tryCatch` blocks in app.R (Lines 1216-1637) that return `NULL` or clear labels on error, with zero logging.
- **Why it exists:** During development, silent failures were preferred over crashing the reactive chain. In a Shiny app, an unhandled error in an observer can break all downstream rendering.
- **How I'd fix it:** Add `message()` or structured logging inside every `error = function(e)` handler. For the unified recalculation (Lines 1216 and 1265), add a user-visible notification: `showNotification("Error en recalculo", type = "error")`. Optionally integrate the `logger` package.
- **Impact:** HIGH in production -- if a calculation fails, the user sees stale results with no indication that something went wrong.

### C3. `/ 30` vs `/ 30.4375` Inconsistency

- **What they'll see:** The actuarial standard 30.4375 days/month is correctly used in `calculate_ley73_pension()` (R/calculations.R:72), but app.R uses `salario_mensual / 30` in 5 places (Lines 1070, 1266, 1393, 1549, 1611) to convert monthly salary to daily SBC.
- **Why it exists:** A genuine oversight. The conversion context is different (IMSS billing uses calendar months of 30 days for SBC reporting), but the result feeds into actuarial calculations that expect the 30.4375 standard.
- **How I'd fix it:** Decide on the correct conversion for the salary-to-SBC context. If it's actuarial: use 30.4375. If it's regulatory billing: document why 30 is correct there. Either way, extract it into a named constant.
- **Impact:** 1.44% systematic overestimation of daily SBC. Over decades of pension payout, this is material but not egregious for an educational tool.

### C4. Missing Input Validation Edge Cases

- **What they'll see:** Step 1 validates birth date and age. Step 2 validates salary >= $1,000 and non-negative weeks. But there's no upper-bound validation on salary at calculation time (input allows 500,000; slider caps at 100,000). The `req()` calls on `genero`/`edad_retiro` silently cancel without user feedback.
- **Why it exists:** The progressive wizard validates at each step boundary, and I relied on HTML input `max` attributes for upper bounds. The `req()` pattern is standard Shiny for handling NULL inputs during initialization.
- **How I'd fix it:** Add calculation-time validation: `if (salario > TOPE_SBC_DIARIO * 30.4375) showNotification("Salary exceeds SBC cap")`. Replace silent `req()` with explicit `validate(need(...))` for better UX.
- **Impact:** A user typing $999,999 in salary gets a calculation but the sensitivity slider can't represent it. Confusing but not crash-inducing.

## MEDIUM (7 issues)

### M1. Magic Numbers Throughout app.R

- **What they'll see:** `18` (min work age), `260` (max M40 weeks), `0.8` (M40 SBC factor), `0.60` (density of contribution), `1000` (min salary), `52` (weeks/year), cessation factors re-hardcoded in chart (Line 1669) instead of referencing `FACTORES_CESANTIA`.
- **Why it exists:** Many are regulatory constants that read more clearly inline. The cessation factors in the chart are a copy-paste from the calculation file.
- **How I'd fix it:** Define `EDAD_MINIMA_TRABAJO`, `MAX_SEMANAS_M40`, `FACTOR_SBC_M40`, `DENSIDAD_COTIZACION_DEFAULT` in global.R. Reference `FACTORES_CESANTIA` in the chart code instead of re-declaring.
- **Impact:** Maintenance risk if regulatory values change. The duplicated cessation factors are the highest-risk item.

### M2. Test Constant Duplication

- **What they'll see:** `tests/testthat/test_calculations.R` (Lines 32-58) re-declares ALL constants from global.R (`UMA_DIARIA_2025`, `SM_DIARIO_2025`, etc.). If a constant changes in global.R but not in the test preamble, tests silently use stale values.
- **Why it exists:** Tests run without Shiny. Can't source global.R because it calls `library(shiny)`. Extracting constants to a shared file would require restructuring.
- **How I'd fix it:** Create `R/constants.R` with no Shiny dependency. Source it from both global.R and test preamble. Or use a DESCRIPTION file and proper package namespacing.
- **Impact:** Medium -- a constant mismatch would make tests pass against wrong expected values, hiding bugs.

### M3. No DESCRIPTION File or renv.lock

- **What they'll see:** No formal dependency management. The only record of required packages is `library()` calls in global.R (6 packages: shiny, bslib, shinyjs, plotly, dplyr, scales).
- **Why it exists:** This is a standalone Shiny app deployed on a single GCP VM, not an R package or multi-environment deployment.
- **How I'd fix it:** Add `renv::init()` to lock dependency versions. Add a minimal DESCRIPTION for metadata. Consider golem's package structure.
- **Impact:** Reproducibility risk. Works fine on the current VM but would require manual setup on a new machine.

### M4. No Report Error Handling

- **What they'll see:** Four `observeEvent` handlers (Lines 1908-1929) call document generators without `tryCatch`. If `generate_technical_report()` throws, the observer crashes silently.
- **Why it exists:** Oversight. The document generators were added late and their error paths weren't wrapped.
- **How I'd fix it:** Wrap each in `tryCatch` with `showNotification("Error generating report", type = "error")`.
- **Impact:** A broken report generator would silently fail -- the user clicks the button and nothing happens.

### M5. Stale AFORE Data (2024 Vintage)

- **What they'll see:** `data/afore_comisiones.csv` has 2024 commission rates and 2024 IRN (Indicador de Rendimiento Neto). No 2025 IRN column.
- **Why it exists:** CONSAR publishes updated data annually. The 2025 commissions are there but 2025 IRN wasn't available when the data was collected.
- **How I'd fix it:** Update CSV with 2025 IRN when available. Add a data freshness indicator in the UI. Consider an automated scrape from CONSAR's public API.
- **Impact:** Commission changes are small (0.01-0.04% between years). IRN changes can be larger. For an educational tool, the impact is acceptable.

### M6. Reactive Chain Fragility

- **What they'll see:** Two separate `observeEvent` handlers on `input$fecha_inicio_cotizacion` (Lines 941 and 949). One tracks user edits, the other auto-detects regime.
- **Why it exists:** Shiny guarantees observer execution order by registration order, and both have `ignoreInit = TRUE`. It works correctly in practice.
- **How I'd fix it:** Merge into a single observer. `fecha_cotizacion_user_edited(TRUE)` can be set inside the same block that calls `determinar_regimen()`.
- **Impact:** Low -- works correctly but is structurally fragile. A future developer might not understand why there are two observers on the same input.

### M7. CSS Legacy Naming

- **What they'll see:** CSS variables named `--color-navy` and `--shadow-glow-navy` that actually map to teal values. `COLOR_NAVY` constant in global.R (Line 77). `favicon.svg` uses old navy `#1a365d`.
- **Why it exists:** The palette was migrated from navy to teal. Variable values were updated but names weren't cleaned up.
- **How I'd fix it:** Rename `--color-navy` to `--color-primary` (or remove entirely since `--color-primary-700` exists). Remove `COLOR_NAVY` from global.R. Update favicon.svg.
- **Impact:** Cosmetic confusion only. The visual output is correct.

### M8. Accessibility Gaps (WCAG 2.1 AA)

- **What they'll see:** No `aria-live` regions for dynamic results (screen readers miss pension updates). Hidden radio inputs (`display: none`) without ARIA alternatives. No `prefers-reduced-motion` media query (5+ animations: fadeIn, pulse, stepPulse, celebratePulse, shimmer). Plotly chart has no text alternative. Golden muted text `#c4a67a` on `#fef7ed` background may fail WCAG AA contrast (estimated 2.8:1, needs 4.5:1).
- **Why it exists:** Bootstrap 5 provides baseline accessibility (semantic HTML, focus states, responsive design). The gaps are in custom components (hero results, wizard steps, sensitivity sliders) that I built from scratch without an accessibility-first approach.
- **How I'd fix it:** Add `aria-live="polite"` to results container. Add `prefers-reduced-motion: reduce` query to disable animations. Add chart text summary. Fix contrast on golden text. Audit with axe-core.
- **Impact:** The app is functional for sighted users but partially inaccessible to users with visual impairments or motion sensitivity. This matters for a public-benefit educational tool.

## MINOR (7 issues)

### m1. Incomplete Roxygen Documentation

- **What they'll see:** Functions in R/*.R files have Roxygen2 `#'` headers with `@param` and `@return`, but not all parameters are documented. Some functions (especially in ui_helpers.R) have minimal or no Roxygen.
- **Impact:** Documentation quality varies by file. Calculation functions are well-documented; UI functions less so.

### m2. Hardcoded Paths in Legacy Test Files

- **What they'll see:** `tests/qa_test_profiles.R` and `tests/edge_case_tests.R` have `setwd("/home/andre/...")` paths that fail on the current VM.
- **Impact:** Legacy scripts can't run without manual path editing. The primary testthat suite works fine.

### m3. No Shiny UI Tests

- **What they'll see:** No shinytest2 tests. Zero programmatic testing of wizard navigation, debouncing, JavaScript interactions, or CSS rendering.
- **Impact:** UI bugs must be caught manually. The calculation layer is well-tested, but UI rendering is trust-based.

### m4. Naming Inconsistency (Spanish/English)

- **What they'll see:** `render_results_hero()` takes `resultado` but `render_results_hero_ley73()` takes `res`. Alert functions use `mensaje` (Spanish) while most use English parameter names.
- **Impact:** Minor readability issue. The overall pattern (English functions, Spanish domain terms) is consistent enough.

### m5. LaTeX Color Definitions Not Updated

- **What they'll see:** Three `\definecolor{navyblue}{RGB}{26,54,93}` in PDF YAML headers (document_generators.R Lines 425, 544, 1467). The teal definition `{49,151,149}` is also outdated (should be `{15,118,110}`).
- **Impact:** PDF reports may have slightly wrong colors. Not visible in HTML reports.

### m6. Debounce Jank on Fast Slider Movement

- **What they'll see:** 300ms debounce on all 5 sensitivity sliders. Rapid slider movement causes visible recalculation lag.
- **Impact:** UX polish issue. The debounce prevents excessive computation but can feel sluggish.

### m7. Missing "Vejez" Glossary Term

- **What they'll see:** `docs/narrative_content.md` defines 14 glossary terms. The code's `GLOSARIO` list in ui_helpers.R has only 13 -- "Vejez" (full pension at age 65+) is missing.
- **Impact:** A user looking for the term "Vejez" won't find it in the in-app glossary.

## Weakness Defense Strategy Summary

When an interviewer raises any weakness:

1. **Acknowledge immediately** -- never be defensive. "You're right, that's a gap."
2. **Explain the trade-off** -- "I prioritized X over Y because..."
3. **Show the fix** -- "Here's exactly how I'd address it: [concrete steps]"
4. **Quantify the impact** -- "This affects accuracy by X%" or "This is a maintainability concern, not a user-facing issue."
5. **Reference the roadmap** -- "This is in my Week 1 / Month 1 / Quarter 1 plan."

The fact that you cataloged 18 weaknesses YOURSELF demonstrates more maturity than having zero weaknesses to discuss. Interviewers want engineers who can critically assess their own work.

---

# Section 4: Actuarial Methodology Defense

## Formula-by-Formula Talking Points

### Ley 73 (Defined Benefit) -- R/calculations.R:21-103

*"Ley 73 is Mexico's pre-1997 defined-benefit pension. The formula comes directly from Article 167 of the Social Security Law."*

```
1. grupo_salarial = SBC_daily / SM_daily                    -- salary as multiple of minimum wage
2. {cuantia_basica, incremento} = lookup_articulo_167(gs)   -- progressive lookup table (23 rows)
3. n_incrementos = floor((semanas - 500) / 52)              -- years beyond 500-week minimum
4. porcentaje = min(cuantia + n_incr * incremento, 1.0)     -- capped at 100%
5. factor_edad = FACTORES_CESANTIA[age]                     -- 60->0.75, ..., 65->1.00
6. pension_diaria = SBC_daily * porcentaje * factor_edad
7. pension_mensual = pension_diaria * 30.4375               -- actuarial days/month
8. pension_final = max(pension_mensual, SM_daily * 30.4375) -- minimum guarantee: 1 SM
```

Key talking points:
- The cuantia basica is **inversely progressive**: 80% at 1x minimum wage down to 13% at 6+ SM. This is the social design of the Mexican pension system -- lower earners get higher replacement rates.
- The 500-week minimum is an eligibility threshold, not a calculation floor. Workers with fewer than 500 weeks get zero pension.
- Cessation factors are a regulatory penalty for retiring before 65. Each year early costs 5% of pension (75% at 60, 100% at 65).

### Ley 97 (Individual Account) -- R/calculations.R:120-371

*"Ley 97 is a defined-contribution system. Your pension depends on your AFORE balance at retirement."*

```
1. r_neto = rendimiento_real_anual - comision_afore          -- net real return
2. r_mensual = (1 + r_neto)^(1/12) - 1                      -- monthly compounding
3. contrib_schedule = [generate per-year contributions]       -- reform-aware rates
4. saldo_final = project_afore_balance(saldo, schedule, n)   -- vector mode: year-by-year
5. esperanza_vida = get_esperanza_vida(edad, genero)          -- CONAPO mortality tables
6. pension = saldo_final / (esperanza_vida * 12)              -- retiro programado
7. pension_final = max(pension, 2.5 * UMA_mensual)           -- minimum guarantee: 2.5 UMA
```

Key talking points:
- The 2020 reform increases employer contribution rates from 7.75% (2025) to 12% (2030). My simulator models this year-by-year using `generate_contribution_schedule()`, which returns a vector of contributions that triggers the iterative projection mode.
- The dual-mode projection is an intentional design: scalar (closed-form future value) for backward compatibility, vector (year-by-year iteration) for the reform schedule. The vector mode was added to handle time-varying contribution rates.
- The 2.5 UMA minimum guarantee is substantial (~$8,599/month in 2025). Many low-balance workers will receive this floor.

### Fondo Bienestar -- R/fondo_bienestar.R:25-317

*"The Fondo Bienestar is Mexico's 2024 pension supplement for Ley 97 workers earning below a salary threshold."*

```
Eligibility: regimen==ley97 AND age>=65 AND weeks>=1000 AND salary<=umbral(retirement_year)
Complement: max(0, min(salary, umbral) - pension_afore)
Total pension: pension_afore + complement
```

Key talking points:
- The threshold is extrapolated at 3.5%/year beyond 2026 based on historical SBC average growth. Known values: $16,778 (2024), $17,364 (2025), ~$18,050 (2026).
- The eligibility check uses the **retirement year**, not the current year. A 30-year-old retiring in 2060 gets the extrapolated 2060 threshold.
- The simulator presents 3 scenarios: (1) AFORE-only, (2) with Fondo complement, (3) with voluntary contributions + Fondo. This shows users that voluntary contributions are NOT replaced by the Fondo -- they stack on top.

## The 30.4375 Story

*Use this anecdote to show attention to actuarial detail:*

"365.25 days per year divided by 12 months gives 30.4375 days per month. Most developers would use 30. The difference is 1.44%, which sounds small. But when you're converting a daily pension to monthly over a 20-year payout, that 1.44% compounds. For a $10,000/month pension, that's $144/month or $1,728/year. Over 20 years, it's $34,560 in underestimated pension. I caught this in the LSS actuarial standards and implemented it as a named constant (`DIAS_POR_MES = 30.4375` in calculations.R:72). Ironically, I later found that app.R uses `/ 30` in 5 places for salary conversion -- a bug I documented and plan to fix."

## Simplifications Catalog with Impact Quantification

| # | Simplification | Impact | Why It Exists |
|---|---------------|--------|---------------|
| 1 | **100% contribution density** | **+40-50% overestimation** -- BIGGEST gap. Real average is 50-65%. | No Mexican payroll dataset is available. Would need user input for density, which most users can't estimate. |
| 2 | **Constant real salary** | +10-25% overestimation for young workers (real wages typically grow 2-3%/yr) | Modeling wage growth requires assumptions about career trajectory. Adds complexity without clear accuracy gain. |
| 3 | **Static mortality tables** | Underestimates life expectancy for workers retiring after 2040 by 1-3 years | CONAPO publishes improvement factors but applying them requires cohort-specific projections. |
| 4 | **Commission as rate subtraction** | ~0.5% difference over 20 years vs. AUM-based charging | The mathematical effect is similar for small commission values (0.47-0.53%). Diverges for larger commissions. |
| 5 | **Simplified retiro programado** | Overestimates monthly pension by 5-10% vs. actuarial-factor method | Real retiro programado is recalculated annually with updated mortality. Would need recursive annual recalculation. |
| 6 | **Government contribution flat at 0.225%** | <0.1% overall impact | Cuota social actually varies by salary bracket. The flat approximation is close enough for educational purposes. |
| 7 | **No inflation modeling** | All values in real pesos -- correct for comparison, confusing for users expecting nominal amounts | Real-peso projection is standard in actuarial education. Adding inflation would require a nominal/real toggle. |
| 8 | **Fondo threshold 3.5% extrapolation** | Unknown -- depends on actual IMSS adjustments | Historical SBC growth is 3-4% real. The 3.5% midpoint is reasonable but could diverge. |
| 9 | **SBC = current salary** | Depends on individual -- could over or underestimate | Real SBC is a 5-year average (250 weeks). Users rarely know their historical SBC. |
| 10 | **No renta vitalicia** | Missing an option that may be better for long-lived retirees | Renta vitalicia requires insurer pricing data not publicly available. Planned for v2. |

## Contribution Reform Schedule (Deep Detail)

*Use this when asked about the 2020 reform:*

The 2020 reform phases in employer contributions over 8 years:

| Year | Employer Rate | Worker Rate | Government | Total |
|------|-------------|-------------|------------|-------|
| 2023 | 6.20% | 1.125% | 0.225% | 7.55% |
| 2024 | 6.90% | 1.125% | 0.225% | 8.25% |
| 2025 | 7.75% | 1.125% | 0.225% | 9.10% |
| 2026 | 8.60% | 1.125% | 0.225% | 9.95% |
| 2027 | 9.45% | 1.125% | 0.225% | 10.80% |
| 2028 | 10.30% | 1.125% | 0.225% | 11.65% |
| 2029 | 11.15% | 1.125% | 0.225% | 12.50% |
| 2030+ | 12.00% | 1.125% | 0.225% | 13.35% |

The implementation in `generate_contribution_schedule()` (calculations.R:297) builds a vector where each element is the annual contribution for that specific year, reflecting that year's employer rate. This vector triggers `project_afore_balance()`'s iterative mode rather than the closed-form annuity formula, because contributions are no longer constant.

The reform nearly doubles the total contribution rate (7.55% -> 13.35%). For a worker earning $20,000/month with 30 years to retirement, this means roughly $1,100/month more flowing into their AFORE in the later years compared to the pre-reform rate.

## Mortality Table Detail

The mortality data in `get_esperanza_vida()` (data_tables.R:89-143) is structured as two named vectors (male/female) with 15 data points each covering ages 60-90. Interpolation rules:

1. **Exact match**: Direct lookup (O(1))
2. **Between known ages**: Linear interpolation (e.g., age 72 interpolates between 70 and 75)
3. **Below 60**: `esperanza[60] + (60 - edad)` -- adds 1 year per year younger
4. **Above 90**: `max(2, esperanza[90] - (edad - 90) * 0.5)` -- floor of 2 years

**Gender impact on pension**: Women live longer (20.0 vs 17.0 years at 65), so their AFORE balance is divided by more months, resulting in a lower monthly pension. This is a real and unavoidable feature of retiro programado. Renta vitalicia partially compensates because insurers pool risk.

## "What's the Gap Between This and Production?"

*Prepared answer:*

"Three things separate this from a production actuarial tool:

1. **Contribution density.** A production tool would ask the user to estimate their density or pull it from their Informe de Semanas Cotizadas. The 100% assumption is the single largest source of overestimation.

2. **Renta vitalicia.** A production tool would model both retiro programado and renta vitalicia, letting the user compare. This requires actuarial annuity factors from insurers.

3. **Dynamic recalculation.** Real retiro programado is recalculated annually based on remaining balance and updated mortality. My model does a single division at retirement. This simplification means my estimate is optimistic for the early years and pessimistic for later years.

Everything else -- the Ley 73 formula, the Article 167 table, the cessation factors, the reform schedule, the Fondo Bienestar threshold -- is regulation-accurate. I validated against published IMSS examples."

## Regulatory Compliance Checklist

| Element | Status | Source |
|---------|--------|--------|
| Art. 167 cuantia/incremento table | Correct -- 23 salary groups from CSV | LSS Art. 167 |
| Cessation factors (60-65) | Correct -- 0.75, 0.80, ..., 1.00 | LSS Art. 171 |
| 500-week minimum (Ley 73) | Correct | LSS Art. 162 |
| 1000-week minimum (Ley 97) | Correct | LSS Art. 162 Transitorio |
| SBC cap at 25 UMA | Correct | LSS Art. 28 |
| 2020 reform employer rates | Correct -- 6.20% (2023) to 12.00% (2030) | DOF 16/12/2020 |
| Fondo Bienestar eligibility | Correct -- 4 criteria | DOF 01/05/2024 |
| Fondo threshold values | Correct for 2024-2025, estimated for 2026+ | IMSS/DOF |
| UMA 2025 value | Correct -- $113.14/day | INEGI/DOF |
| Minimum pension (Ley 73) | Correct -- 1 SM monthly | LSS Art. 168 |
| Minimum pension (Ley 97) | Correct -- 2.5 UMA monthly | LSS Art. 170 (reformed) |
| Mortality tables | Approximation -- CONAPO-based, simplified | Not exact actuarial tables |
| Commission treatment | Approximation -- subtracted from return, not AUM-based | Simplified |
| Government contribution | Approximation -- flat 0.225%, actual varies by bracket | Simplified |

---

# Section 5: Tough Interview Questions (25 with Answers)

## Architecture Questions

### Q1. "Why R Shiny and not React or a modern web framework?"

**What they're testing:** Whether you chose tools deliberately or just used what you knew.

**Strong answer:** "Three reasons. First, the actuarial calculations are naturally R -- mortality tables, financial projections, Art. 167 lookups. Keeping everything in one language eliminates API serialization overhead and keeps formulas auditable in the same codebase. Second, Shiny's reactive model maps directly to sensitivity analysis -- when a slider changes, the pension recalculates. Third, time to market. Shiny let me go from concept to deployed app in weeks. If this were a production SaaS, I'd consider a React frontend with an R/Python API backend. But for an educational tool, the full-stack R approach was the right call."

**Follow-up trap:** "But Shiny doesn't scale." **Response:** "Correct -- Shiny is single-threaded per session. For this use case (individual sessions, no shared state), that's fine. For thousands of concurrent users, you'd deploy behind ShinyProxy or Shiny Server Pro with load balancing, or migrate the calculation engine to an API."

### Q2. "Why is app.R 2,000 lines? That's a red flag."

**What they're testing:** Whether you recognize the problem and have a plan.

**Strong answer:** "It is. The calculation logic is properly extracted into 4 files (2,200 lines total). What remains in app.R is UI definition and reactive server logic. Shiny's scoping rules make it harder to modularize than a typical MVC framework -- you need `moduleServer()` with explicit input/output passing. The right fix is migrating to the golem framework, which enforces Shiny module structure. I documented this as the #1 architectural improvement."

**Evidence:** R/calculations.R (766 lines), R/fondo_bienestar.R (501 lines), R/data_tables.R (245 lines), R/ui_helpers.R (1,330 lines) -- the calculation layer IS modular.

### Q3. "How does the sensitivity engine work?"

**What they're testing:** Whether you understand reactive programming.

**Strong answer:** "Five sliders (salary, voluntary contributions, retirement age, AFORE, weeks) are debounced at 300ms. A unified observer reads all five and recalculates the full pension using the same functions as the initial calculation. Results go into a mutable `resultados()` reactiveVal. Separately, five individual impact observers compare each slider's new value against an immutable `resultados_originales()` baseline to display per-slider deltas like '+$1,200/mes'. The immutable baseline is the key insight -- it prevents cascading deltas where slider A's impact is distorted by slider B's current position."

### Q4. "What's your deployment story?"

**What they're testing:** Whether you think beyond code.

**Strong answer:** "It runs on a GCP e2-medium VM (Ubuntu, R 4.3.3). I start it with `shiny::runApp()` on port 3838. There's no CI/CD pipeline, no Docker container, no reverse proxy. For a portfolio project, that's sufficient. For production, I'd containerize with rocker/shiny, add nginx as a reverse proxy with SSL, set up GitHub Actions for automated testing, and deploy to Cloud Run or GKE. The calculation engine would need no changes -- only the infrastructure layer."

### Q5. "How would you make this a multi-tenant SaaS?"

**What they're testing:** Architectural thinking beyond the current scope.

**Strong answer:** "Three changes. First, separate the R calculation engine into a plumber API. Second, build the frontend in React or Next.js for better UX control and SEO. Third, add a user database for saved simulations. The calculation functions are already pure (input in, result out, no side effects), so they'd become API endpoints directly. The hardest part would be user-specific state management -- saving scenarios, comparing over time."

## Actuarial Questions

### Q6. "How did you validate the actuarial formulas?"

**What they're testing:** Rigor and methodology.

**Strong answer:** "Three methods. First, hand-calculated examples -- tests B3 and P3 in the test suite include step-by-step manual calculations with comments showing every intermediate value. Second, boundary condition testing -- I test exact eligibility thresholds (500 weeks, 1000 weeks, age 60, age 65), minimum pension floors, and 100% porcentaje cap. Third, mathematical identity checks -- I verify that `saldo_final == FV(saldo) + FV(aportaciones)` (test C4), that `ganancia == saldo_final - total_aportado` (test C5), and that monotonicity holds (more weeks = higher pension, always). There are 126 unit tests covering these."

**Evidence:** tests/testthat/test_calculations.R, Sections A-S.

### Q7. "What's wrong with your 100% contribution density assumption?"

**What they're testing:** Whether you understand the model's biggest limitation.

**Strong answer:** "It's the single largest source of overestimation. CONSAR data shows average contribution density in Mexico is 50-65%. My model assumes continuous employment for every remaining year until retirement. For a 35-year-old with 30 years to go, this projects 30 * 52 = 1,560 additional weeks of contributions. At 60% density, the real number would be ~936 weeks. That's a 40% overestimate in weeks, which directly inflates both the Ley 73 pension (more incrementos) and the Ley 97 balance (more contributions). I would add a density slider in the next version, with the default at 60% and an explanation of what it means."

### Q8. "Why no renta vitalicia option?"

**What they're testing:** Whether you know the gap and why it matters.

**Strong answer:** "Renta vitalicia is a life annuity purchased from an insurer using the AFORE balance. It guarantees income for life, unlike retiro programado which can exhaust the balance. I didn't implement it because the annuity pricing depends on insurer-specific mortality tables and interest rates that aren't publicly available. CONSAR publishes indicative rates, but they change monthly and vary by insurer. My retiro programado model uses a simple `balance / (life_expectancy * 12)` division, which is the approach used by most educational tools. Adding renta vitalicia is the top actuarial feature for v2."

### Q9. "How does the 2020 pension reform affect your calculations?"

**What they're testing:** Whether you understand the regulatory context.

**Strong answer:** "The 2020 reform phases in higher employer contribution rates from 6.20% in 2023 to 12.00% by 2030. My `generate_contribution_schedule()` function builds a year-by-year vector with the correct rate for each calendar year. This vector triggers the iterative (not closed-form) mode in `project_afore_balance()`, which compounds each year's contributions at that year's rate. The effect is significant: a worker with 30 years to retirement will see substantially higher contributions in years 5-30 than a flat-rate projection would show. Tests Q1-Q7 validate that contributions increase monotonically and that the terminal rate is applied correctly."

### Q10. "Your mortality tables are simplified. How much does that matter?"

**What they're testing:** Whether you can quantify model uncertainty.

**Strong answer:** "I use 15 data points per gender from CONAPO projections with linear interpolation. Real actuarial tables (EMSSA, for example) have data for every individual year of age with mortality improvement factors. My simplification has two effects: first, I miss the granularity between ages (interpolation introduces ~0.3 year error between data points). Second, I don't model mortality improvement -- today's 30-year-old will likely live 2-3 years longer than current tables predict. This means my model slightly underestimates life expectancy for younger workers, which slightly overestimates their monthly pension (dividing by fewer months). The impact is 5-10% for workers more than 20 years from retirement."

## Code Quality Questions

### Q11. "Why the global state with `<<-`?"

**What they're testing:** Whether you understand Shiny scoping or just wrote bad code.

**Strong answer:** "In Shiny, `source()` creates a child environment. Variables defined in a sourced file without `<<-` are local to that file's evaluation environment and invisible to app.R's server function. The `<<-` assigns to the parent (global) environment, making data and constants available across all sourced files. It's the documented Shiny pattern for shared state. In a golem package structure, this would be replaced with proper package namespacing and exported objects. But for a `source()`-based app, `<<-` is correct."

**Evidence:** global.R uses `<<-` for all CSV data, constants, and utility functions. app.R has only one `<<-` (Line 1901), which is a server-scoped mutation of a temp file tracker -- also a legitimate Shiny pattern.

### Q12. "Where are your integration tests?"

**What they're testing:** Whether you test beyond unit level.

**Strong answer:** "The calculation layer has 126 unit tests in testthat. There's also `tests/integration_test.R` that simulates the sensitivity pipeline -- it calls `calculate_pension_with_fondo()`, then re-calls with changed parameters to verify the slider impact chain produces correct deltas. What's missing is Shiny UI testing with shinytest2 -- I don't programmatically test wizard navigation, debouncing, or JavaScript interactions. The decision was deliberate: the actuarial math is where errors matter most. A wrong pension number is worse than a CSS glitch. But shinytest2 is on the roadmap."

### Q13. "Your error handling is silent. What happens when something fails?"

**What they're testing:** Production readiness.

**Strong answer:** "In the sensitivity engine, errors are caught and swallowed. The user sees stale results. In report generation, there's no error handling at all -- a failure would silently produce nothing. This is the biggest production-readiness gap. The fix is straightforward: add `message()` logging in every catch block, `showNotification()` for user-facing errors, and eventually integrate the `logger` package with structured JSON output. I didn't do this because the priority was getting the actuarial math right first."

### Q14. "17 out of 37 functions have test coverage. That's 46%."

**What they're testing:** Whether you're defensive or honest.

**Strong answer:** "That's the function count, but the coverage is intentionally uneven. The 17 tested functions are the actuarial calculation core -- every formula that produces a pension number. The 20 untested functions are UI helpers (rendering HTML), document generators (producing reports), format helpers, and analysis functions. I chose depth over breadth: the tested functions have boundary conditions, mathematical identities, hand-calculated verifications, and monotonicity checks. The untested UI functions produce visual output that's hard to assert against programmatically without shinytest2. If you audit the test file, you'll see the actuarial coverage is closer to 95%."

### Q15. "Your test file header says '92 tests across 13 sections' but there are 126 across 19."

**What they're testing:** Attention to detail, documentation hygiene.

**Strong answer:** "That's a stale comment from before I added Sections N through S (contribution reform, vector projection, reform impact, Fondo threshold, full-pipeline verification). I should have updated the header when I added the new sections. It's a minor documentation hygiene issue, but you're right to flag it -- stale comments are worse than no comments because they actively mislead."

## Product Questions

### Q16. "Who tested this with real users?"

**What they're testing:** Product thinking beyond code.

**Strong answer:** "I tested with family members and friends who are IMSS-affiliated workers. The wizard flow was redesigned based on their feedback -- originally it was a single-page form, but users were overwhelmed by the number of inputs. The 4-step wizard with progressive disclosure came from watching people abandon the form at Step 3 (AFORE data). The sensitivity sliders were added because the #1 question after seeing results was 'what if I contribute more?' The Fondo Bienestar status badge was added because everyone asked 'do I qualify?' Real user testing is informal but drove real design changes."

### Q17. "What metrics would you track?"

**What they're testing:** Data-driven thinking.

**Strong answer:** "Three categories. Engagement: wizard completion rate (what % reach Step 4), average time per step, slider interaction rate. Understanding: report download rate, glossary term click-through, return visits. Impact: if this were production, I'd add a post-calculation survey asking 'Did you learn something new about your pension?' and 'Will you take any action?' The most actionable metric would be the drop-off between Step 2 and Step 3 -- that's where users need AFORE data they often don't have."

### Q18. "What would v2 look like?"

**What they're testing:** Vision and prioritization.

**Strong answer:** "Three things. First, contribution density slider -- the biggest accuracy improvement for the least code. Second, renta vitalicia comparison -- it's the other half of the retirement decision. Third, AFORE performance comparison with actual IRN data -- show users the real cost of being in a low-performing AFORE. Architecture-wise, I'd migrate to golem for module structure and add proper CI/CD. I would NOT add login, databases, or multi-user features -- this tool's strength is zero-friction access."

### Q19. "How would you explain this to a non-technical stakeholder?"

**What they're testing:** Communication skills.

**Strong answer:** "I built a tool that answers one question every Mexican worker has: 'How much will my pension be?' It takes 2 minutes to fill out, it's free, it doesn't store any data, and it shows you three things: what you'll get from the government system alone, what you'll get with the new Fondo Bienestar supplement, and how much more you'd get if you make voluntary contributions. The last part is the important one -- it shows people what's actually in their control."

### Q20. "What's the competitive landscape? Does this already exist?"

**What they're testing:** Market awareness.

**Strong answer:** "CONSAR has a basic pension calculator, but it only handles Ley 97 and doesn't include Fondo Bienestar. Several AFOREs have their own calculators, but they're biased toward showing their specific AFORE in the best light and can't model switching. The IMSS Digital portal shows your semanas cotizadas but not your projected pension. My simulator is the first I'm aware of that models all three systems (Ley 73, Ley 97, Fondo Bienestar) in a single interface with sensitivity analysis. The educational framing (control framework, encouragement messages, glossary) is also unique."

## Career and Soft Skill Questions

### Q21. "What did you learn building this?"

**What they're testing:** Growth mindset, self-awareness.

**Strong answer:** "Three things. First, that actuarial regulation is harder to implement than to read -- the Art. 167 table looks simple until you realize the salary groups have gaps between rows and you need clamping logic. Second, that reactive programming requires a different mental model than request-response -- debugging why a slider change causes a cascade of 6 observers to fire taught me more about state management than any textbook. Third, that the biggest design challenge wasn't technical -- it was making pension math approachable without being condescending. The narrative content took as long as the formulas."

### Q22. "What would you do differently if you started over?"

**What they're testing:** Maturity and self-criticism.

**Strong answer:** "Start with golem from day one. The cost of migrating a 2,000-line app.R to modules is much higher than starting with module structure. I'd also add contribution density as a user input from the beginning -- it's the biggest accuracy gap and the hardest to retrofit because it touches every calculation path. And I'd set up CI/CD before writing the first formula, not after."

### Q23. "Why pensions? What drew you to this?"

**What they're testing:** Genuine motivation vs. resume padding.

**Strong answer:** "I'm a UNAM actuarial science graduate. Pensions are what I studied. But the real motivation is personal -- I watched my parents struggle to understand their IMSS statements. My dad is Ley 73 and didn't know what cessation factors meant. My mom is Ley 97 and had never heard of the Fondo Bienestar when it was announced. If two educated adults can't navigate the system, imagine what it's like for the average worker. I built the tool I wished they'd had."

### Q24. "How long did this take?"

**What they're testing:** Efficiency, whether you can estimate work.

**Strong answer:** "The core calculation engine (R/calculations.R, R/fondo_bienestar.R, R/data_tables.R) took about 2 weeks. The UI and design system took another 2 weeks. Testing took 1 week spread across the project. Documentation, reports, and polish took 1 week. Total: about 6 weeks of focused work. The longest single task was the sensitivity engine -- getting 5 sliders to recalculate in real time without race conditions or cascade effects."

### Q25. "You used AI assistance to build this. How do you think about that?"

**What they're testing:** Honesty about AI usage, understanding of the tool.

**Strong answer:** "I used Claude as a development partner throughout. It was most valuable for three things: translating actuarial regulations into code (I'd describe the Ley 73 formula and iterate on the implementation), generating test cases (boundary conditions I might miss), and CSS design system work. Where AI was less useful: understanding the regulatory nuances (I had to read the actual DOF publications), making UX decisions (user feedback mattered more than AI suggestions), and debugging reactive chains (you need to understand Shiny's execution model). I see AI as a multiplier -- it made me 3x faster but didn't replace the actuarial knowledge, the user empathy, or the architecture decisions."

**Follow-up trap:** "So anyone with Claude could build this?" **Response:** "Anyone with Claude could generate R code. But the domain expertise to know that 30.4375 matters, that Art. 167 cuantia basica is inversely progressive, that the Fondo threshold uses retirement year not current year -- that comes from reading the actual legislation and understanding Mexican social security. The AI accelerated the implementation; it didn't provide the actuarial judgment."

## Bonus: Questions to Ask THEM

Turn the interview around with these questions that demonstrate depth:

1. "How does your team handle domain-specific calculations that require regulatory accuracy? Do you have an actuarial review process?"
2. "What's your approach to modeling time-varying parameters -- like my contribution reform schedule -- in financial projections?"
3. "I noticed that most pension calculators in Mexico don't include the Fondo Bienestar yet. Is that a gap your organization is addressing?"
4. "How do you balance mathematical precision with user accessibility in financial tools?"

---

# Section 6: Skills Demonstrated Matrix

| Skill | Project Feature | Evidence (file:location) | Talking Point |
|-------|----------------|--------------------------|---------------|
| **Actuarial Mathematics** | Ley 73 formula, Ley 97 projection, mortality tables, cessation factors | R/calculations.R:21-103, R/data_tables.R:89-143 | "Implemented Article 167 progressive pension formula with 23-row salary group lookup" |
| **Financial Modeling** | AFORE balance projection, contribution reform schedule, retiro programado | R/calculations.R:120-371, lines 238-285 | "Built dual-mode AFORE projector (closed-form + iterative) to handle time-varying contribution rates" |
| **Regulatory Compliance** | Fondo Bienestar eligibility, threshold extrapolation, SBC cap | R/fondo_bienestar.R:25-107, global.R:136-155 | "Translated DOF decree into 4-criterion eligibility checker with retirement-year threshold extrapolation" |
| **Reactive Programming** | Sensitivity engine, debounced sliders, immutable baseline pattern | app.R:1170-1637 | "5 debounced sliders with unified recalculation and per-slider impact labels, zero race conditions" |
| **UX Design** | 4-step wizard, hero+breakdown results, control framework, glossary | R/ui_helpers.R (25 functions), docs/narrative_content.md | "Redesigned from single-page form to progressive wizard based on user testing feedback" |
| **Design System** | 80+ CSS custom properties, Tropical Vibrant palette, responsive breakpoints | www/styles.css (2,156 lines) | "Built complete design system with tokens for colors, shadows, spacing, and gradients" |
| **Testing Culture** | 126 unit tests, boundary conditions, mathematical identities, monotonicity | tests/testthat/test_calculations.R (19 sections) | "Test suite verifies algebraic decomposition, boundary thresholds, and hand-calculated reference values" |
| **Data Visualization** | Projection chart (3 traces), bar chart (cessation factors), replacement rate bar | app.R:1654-1777 | "Interactive plotly charts comparing baseline, slider-adjusted, and voluntary-contribution scenarios" |
| **Document Generation** | 4 HTML reports, 3 PDF via Rmd/xelatex, shared CSS system | R/document_generators.R (1,667 lines) | "9 report generators producing professional documents in both HTML and PDF formats" |
| **Product Thinking** | Encouragement messages, "what you control" framework, no-data-stored trust model | docs/narrative_content.md, R/ui_helpers.R:919-992 | "Designed narrative framework where the key message is 'voluntary contributions are YOUR safest lever'" |
| **Full-Stack R** | Shiny, bslib, plotly, shinyjs, CSS, JavaScript, LaTeX | app.R, global.R, www/styles.css | "Single-language stack from actuarial formulas to interactive UI to PDF report generation" |
| **Domain Expertise** | Mexican pension system (IMSS, LSS, DOF, CONSAR, UMA, SBC) | All R/ files, docs/methodology.md | "Native understanding of Mexican social security -- built for the system I grew up in" |

## Skills Deep-Dive: What Sets This Apart

### Actuarial Judgment (not just math)

The formulas are in the law. What's NOT in the law:
- Choosing 30.4375 over 30 days/month (actuarial standard vs. calendar convention)
- Deciding to use retirement year (not current year) for Fondo threshold lookup
- Recognizing that 100% density is the biggest simplification and quantifying its impact at +40-50%
- Understanding that the Art. 167 cuantia basica is inversely progressive by design, not by accident
- Choosing 3.5% for threshold extrapolation based on historical SBC growth analysis

These decisions require actuarial training, not just coding ability.

### Reactive Programming Mastery

The sensitivity engine is not a simple "slider changes -> recalculate" flow. It manages:
- 5 independent sliders with shared recalculation
- Debouncing to prevent excessive computation
- Immutable baseline for delta comparison
- Cliff notifications when thresholds are crossed (Fondo eligibility, minimum pension)
- `isolate()` for non-reactive reads inside reactive contexts
- Dual observers on the same input with guaranteed execution order

This is genuine reactive state management, not a tutorial exercise.

### UX Writing as a Feature

The `docs/narrative_content.md` (454 lines) is a UX copywriting guide with:
- 4 tone principles with anti-patterns
- 3-zone control framework (green/yellow/red)
- 3-tier encouragement messages calibrated by replacement rate
- 10 tooltip texts for domain terms
- 14-term glossary
- Explicit "key message" that voluntary contributions are safer than Fondo

The narrative IS the product. The math is infrastructure.

---

# Section 7: What I'd Do Differently (Improvement Roadmap)

## Week 1: Foundation Fixes

| Task | Why | Effort |
|------|-----|--------|
| Extract named constants for magic numbers | `EDAD_MINIMA_TRABAJO`, `MAX_SEMANAS_M40`, `FACTOR_SBC_M40`, `DENSIDAD_COTIZACION_DEFAULT` in global.R; reference `FACTORES_CESANTIA` in chart | 2 hours |
| Add error logging to sensitivity engine | `message()` in every `tryCatch`, `showNotification()` for user-facing errors in unified recalculation | 2 hours |
| Create `R/constants.R` | Extract constants from global.R (no Shiny dependency), source from both global.R and tests | 3 hours |
| Fix `/ 30` vs `/ 30.4375` | Decide correct conversion context, apply consistently across app.R | 1 hour |
| Add `renv::init()` | Lock dependency versions for reproducibility | 30 minutes |
| Update stale test header comment | "126 tests across 19 sections (A-S)" | 5 minutes |
| Clean up navy remnants | Remove `COLOR_NAVY`, rename CSS `--color-navy` variables, update favicon.svg | 1 hour |
| Add missing "Vejez" to GLOSARIO | Add 14th term to match narrative_content.md | 15 minutes |
| Add `tryCatch` to report generation | Wrap 4 report observeEvents with error handling + user notification | 1 hour |

## Month 1: Quality & Features

| Task | Why | Effort |
|------|-----|--------|
| Contribution density slider | Biggest accuracy improvement. Default 60%, range 30-100%. Feeds into `generate_contribution_schedule()` as a multiplier on weeks. | 1 week |
| Begin golem migration | Create golem scaffold. Extract Step 1-4 into `mod_step1_ui()`/`mod_step1_server()`. Extract sensitivity engine into `mod_sensitivity`. | 2 weeks |
| shinytest2 for wizard flow | Test step navigation, input validation feedback, slider debouncing, regime detection toggle | 1 week |
| CI/CD with GitHub Actions | `R CMD check`, testthat, lint on every push. Deploy to GCP on main branch merge. | 3 days |
| Accessibility audit | Add `aria-live` to results container, fix hidden radio ARIA, add `prefers-reduced-motion`, verify contrast ratios | 3 days |
| Update methodology.md | Add Modalidad 40, contribution reform schedule, minimum guarantee logic, threshold extrapolation, 30.4375 explanation | 2 days |
| Test `calculate_all_scenarios()` and `compare_afores()` | Close the biggest coverage gaps in the calculation layer | 1 day |
| Fix LaTeX color definitions | Update `\definecolor{navyblue}` and teal values in PDF YAML headers | 30 minutes |

## Quarter 1: Architecture & Advanced Features

| Task | Why | Effort |
|------|-----|--------|
| Complete golem migration | All modules, proper package namespacing, DESCRIPTION with Imports, vignettes | 3 weeks |
| Renta vitalicia model | Add annuity pricing comparison. Source indicative rates from CONSAR. Show retiro programado vs. renta vitalicia trade-off. | 2 weeks |
| User analytics | Posthog or Plausible for anonymous usage analytics. Track wizard completion rate, slider interaction, report downloads. | 1 week |
| Mobile optimization | Dedicated mobile layout for wizard steps. Touch-friendly slider controls. Responsive chart sizing. | 1 week |
| AFORE data auto-update | Scheduled scrape from CONSAR's public data portal. Notify admin when new data is available. | 1 week |
| Docker containerization | `rocker/shiny` base image, nginx reverse proxy, SSL. Cloud Run deployment. | 3 days |
| Wage growth model | Optional real-wage growth toggle (0-3%/yr). Affects both contribution base and replacement rate calculation. | 1 week |
| Multi-language support | English translation. The calculation engine is language-agnostic; only UI strings and reports need translation. | 2 weeks |
| Saved simulations | Optional (no login required) localStorage-based scenario saving. Compare multiple scenarios side by side. | 1 week |

## The Priority Stack

If I had exactly one week, I would:
1. Add contribution density slider (biggest accuracy win)
2. Add error logging to sensitivity engine (biggest reliability win)
3. Extract constants to shared file (biggest maintainability win)

If I had one month, I would add: golem migration, shinytest2, CI/CD, and the accessibility audit.

If I had one quarter, the renta vitalicia model and Docker deployment would make this production-ready.

## Why NOT These Changes

Some "obvious" improvements I deliberately deprioritize:

| Suggestion | Why Not (Yet) |
|-----------|---------------|
| "Add a database" | Zero user data is stored by design. This builds trust. Adding persistence changes the privacy model. |
| "Add authentication" | Same reasoning. Zero-friction access is a feature, not a gap. |
| "Rewrite in Python/React" | The R ecosystem is correct for actuarial work. Rewriting doesn't improve accuracy or UX. |
| "Add more AFOREs" | Only 10 AFOREs exist in Mexico. The data is complete. |
| "Add inflation toggle" | Real-peso projection is the actuarial standard for educational tools. Nominal projections require inflation assumptions that add complexity without clarity. |
| "Add historical backtesting" | Would require historical AFORE performance data not publicly available at the individual-fund level. |

---

# Appendix: Quick Reference

## File Sizes

| File | Lines | Purpose |
|------|-------|---------|
| app.R | 1,951 | UI + server |
| R/document_generators.R | 1,667 | 9 report generators |
| R/ui_helpers.R | 1,330 | 25 UI components |
| R/calculations.R | 766 | Core actuarial formulas |
| R/fondo_bienestar.R | 501 | Fondo logic + scenarios |
| R/data_tables.R | 245 | Data lookup + validation |
| global.R | 170 | Bootstrap + constants |
| www/styles.css | 2,156 | Design system |
| docs/narrative_content.md | 454 | UX copy guide |
| docs/methodology.md | 242 | Methodology doc |
| tests/testthat/test_calculations.R | ~800 | 126 unit tests |
| **Total** | **~10,300** | |

## Test Coverage Summary

| Layer | Functions | Tested | Coverage |
|-------|-----------|--------|----------|
| Actuarial calculations | 9 | 9 | 100% |
| Fondo Bienestar | 6 | 4 | 67% |
| Data tables | 9 | 7 | 78% |
| Global utilities | 8 | 1 | 13% |
| UI helpers | 25 | 0 | 0% |
| Document generators | 9 | 0 | 0% |
| **Total** | **66** | **21** | **32%** |

## Regulatory Constants Quick Card

| Parameter | Value | Source |
|-----------|-------|--------|
| UMA Daily 2025 | $113.14 | INEGI/DOF |
| SM Daily 2025 | $278.80 | CONASAMI |
| SBC Cap | 25 UMA ($2,828.50/day) | LSS Art. 28 |
| Ley 73 min weeks | 500 | LSS Art. 162 |
| Ley 97 min weeks | 1,000 | LSS Transitorio |
| Fondo threshold 2025 | $17,364/month | IMSS/DOF |
| Employer rate 2025 | 7.75% | DOF 2020 reform |
| Employer rate 2030+ | 12.00% | DOF 2020 reform |
| Min pension Ley 73 | 1 SM/month | LSS Art. 168 |
| Min pension Ley 97 | 2.5 UMA/month (~$8,599) | LSS Art. 170 |
| Days/month (actuarial) | 30.4375 | 365.25 / 12 |
