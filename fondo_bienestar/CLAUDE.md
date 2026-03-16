# Simulador de Pension IMSS + Fondo Bienestar

## Project Overview
- R Shiny pension simulator for Mexican workers (IMSS Ley 73, Ley 97, Fondo Bienestar)
- Educational tool, NOT financial advice
- GCP VM: claude-dev-20260207-022749, IP 35.225.171.223
- Run: `R -e "shiny::runApp('.', host='0.0.0.0', port=3838, launch.browser=FALSE)"`

## Architecture

### File Structure & Responsibilities
```
app.R          (~1960 lines) -- Main Shiny app: UI definition + server logic
global.R       (~120 lines)  -- Package loading, CSV data, source()
R/constants.R  (~80 lines)   -- Constants + get_semanas_minimas_ley97() (no Shiny dep)
R/calculations.R    (~770)   -- Core formulas + tiered rate lookups (Ley 73, Ley 97, M40)
R/fondo_bienestar.R (~500)   -- Fondo Bienestar eligibility & complement
R/data_tables.R     (~244)   -- Art. 167 lookup, AFORE data, mortality tables, validation
R/ui_helpers.R      (1330)   -- UI component builders (hero, wizard, timeline, results)
R/document_generators.R (1667) -- HTML/PDF report generation
www/styles.css      (~2170)  -- Full design system CSS
data/*.csv (5 files)         -- Regulatory data tables (incl. DOF 2020 reform rates)
docs/ (3 files)              -- methodology.md, narrative_content.md, portfolio_defense.md
tests/ (6 files)             -- Unit tests, integration tests, QA profiles
```

### Dependency Hierarchy
```
app.R -> source("global.R") -> source("R/constants.R") + loads CSVs + source("R/*.R")
tests -> source("R/constants.R") + loads CSVs + source("R/*.R")
```
Libraries must be in BOTH app.R and global.R (plotlyOutput etc. needed during UI eval).
Global `<<-` assignment required for Shiny scoping rules.

### Data Files
- `articulo_167_tabla.csv`: Art. 167 pension table (22 salary groups, cuantia + incremento)
- `afore_comisiones.csv`: 11 AFOREs with commissions and IRN
- `uma_historico.csv`: UMA values 2016-2025
- `salario_minimo.csv`: Minimum wage 2016-2025

## Coding Conventions

### R Code
- Functions: snake_case, Spanish names (`calculate_ley73_pension`, `validar_entrada`)
- Documentation: Roxygen2 `#'` with `@param`, `@return`
- Section dividers: `# ============...`
- Return values: comprehensive lists (primary result + eligibility flags + metadata)
- Null handling: `%||%` operator for NULL Shiny inputs during initialization
- Namespace plotly: always `plotly::plotlyOutput`, `plotly::renderPlotly`

### CSS
- Custom properties for colors, transitions, shadows
- `.bg-surface` (not `.bg-white`) for card backgrounds
- BEM-ish class naming (`.hero-section`, `.wizard-step`, `.control-zone`)
- `.dimmed-fields` for disabled AFORE fields in Ley 73

### Git
- Imperative mood, feature-specific commit messages
- Example: "Polish Step 4 sliders UX, add salary slider, improve Fondo messages"

## Design System (Tropical Vibrant Palette)

### Colors
- Primary: teal `#0f766e` (headings, values, labels) / dark teal `#115e59`
- Secondary: magenta `#db2777` / pink `#ec4899` (accents, gradients)
- Body background: `#fef7ed` (golden-peach)
- Surface/cards: `#fffbf0`
- Muted text: `#c4a67a` (golden)
- Hero gradient: teal -> coral sweep
- Old navy (`#1a365d`) fully removed from entire codebase

### Key Components
- Hero + Breakdown results pattern (replaced old 3-card layout)
- 4-step wizard (personal data, labor data, AFORE, results)
- Sensitivity sliders with impact labels in 2x2 grid
- Control framework zones: green (you control), yellow (partial), red (no control)
- Chart: 3 traces (dotted golden baseline, dashed teal with-changes, solid teal +aportaciones)

### Document Generators
- Same Tropical Vibrant palette (no navy colors)
- LaTeX PDF headers updated: `\definecolor{primary}` (teal) and `\definecolor{accent}` (magenta)

## Actuarial Methodology

### Ley 73 (Defined Benefit) -- R/calculations.R
```
1. grupo_salarial = SBC_daily / SM_daily
2. {cuantia_basica, incremento} = lookup_articulo_167(grupo_salarial)
3. n_incrementos = floor((weeks - 500) / 52)
4. porcentaje = min(cuantia + n_incr * incremento, 1.0)
5. factor_edad = FACTORES_CESANTIA[age] (60->0.75 ... 65->1.0)
6. pension_diaria = SBC_daily * porcentaje * factor_edad
7. pension_mensual = pension_diaria * 30.4375 (=365.25/12, actuarial standard)
8. pension_final = max(pension_mensual, SM_daily * 30.4375)
```

### Ley 97 (Individual Account / AFORE) -- R/calculations.R
```
1. r_neto = rendimiento - comision_afore
2. r_mensual = (1 + r_neto)^(1/12) - 1
3. contrib_schedule = generate_contribution_schedule(salario, ANIO_ACTUAL, n)
   -> calls calculate_aportacion_obligatoria(salario, anio=year) per year
   -> applies DOF 2020 reform tiered rates by salary bracket (8 brackets, UMA-based)
   -> employer CEAV: 3.150% (1 SM) to 6.422% (4.01+ UMA) in 2025, up to 11.875% by 2030
   -> cuota social: fixed daily amount per bracket, phases out at 4.01+ UMA
4. project_afore_balance(saldo, contrib_schedule, n):
   - Scalar mode: closed-form FV formula (backward compat)
   - Vector mode: iterative year-by-year compounding
5. pension = saldo_final / (esperanza_vida * 12)
6. pension_final = max(pension, 2.5 * UMA_mensual)
```

### Fondo Bienestar -- R/fondo_bienestar.R
```
Eligibility: Ley97 AND age>=65 AND weeks>=1000 AND salary<=umbral(retirement_year)
Complement: max(0, min(salary, umbral) - pension_afore)
Decree: DOF 01/05/2024, effective 01/07/2024
Threshold extrapolation: 3.5% annual growth from last known value (2026=$18,050)
```

### Key Simplifications (documented, intentional)
- 100% density of contribution (real avg ~50-65%)
- Constant real salary (no wage growth modeled)
- Simplified mortality tables (CONAPO-based, linear interpolation)
- Commission subtracted from return (not charged on balance)
- Only retiro programado modeled (no renta vitalicia)
- No inflation modeling (all values real)
- Fondo threshold extrapolated at 3.5% annual beyond 2026 (actual IMSS adjusts by SBC avg)

## Regulatory Constants (2025)

| Parameter | Value | Source |
|-----------|-------|--------|
| UMA Daily | $113.14 | INEGI/DOF |
| UMA Monthly | $3,439.46 | Calculated |
| Salario Minimo | $278.80/day | CONASAMI |
| SM Monthly | $8,474.52 | Calculated |
| Fondo Bienestar Threshold | $17,364/month | DOF/IMSS |
| SBC Cap (Tope) | 25 UMA daily | LSS |
| Rendimiento Conservador | 3% real | |
| Rendimiento Base | 4% real | |
| Rendimiento Optimista | 5% real | |

Contribution reform: tiered by salary bracket (DOF 2020). See `data/tasas_reforma_2020.csv`.
Minimum weeks Ley 97: transitional 750 (2021) +25/yr -> 1000 (2031). See `get_semanas_minimas_ley97()`.
Fondo threshold progression: $16,778 (2024), $17,364 (2025), ~$18,050 (2026).

## UX & Data Flow

### Wizard Flow
- Step 1: Birth date, gender, retirement age
- Step 2: Start-of-work date (auto-detects regime), salary, semanas
- Step 3: AFORE selection, balance, voluntary contributions (dimmed for Ley 73)
- Step 4: Results with sensitivity sliders (vol/AFORE hidden for Ley 73)

### Regime Detection
- `dateInput("fecha_inicio_cotizacion")` + `determinar_regimen()` (cutoff: 1997-07-01)
- Badge shows auto-detected regime with override toggle
- Birth date auto-fills start date (birth+18y); `fecha_cotizacion_user_edited` flag prevents overwrite
- Semanas estimation: `years_working * 52 * 0.60`

### Results Architecture
- `calculate_pension_with_fondo()` returns 3 scenarios: solo_sistema, con_fondo, con_acciones
- `render_results_hero()` / `render_results_hero_ley73()` for display
- `resultados_originales` reactiveVal stores baseline for chart comparison
- Sensitivity sliders debounced at 300ms (`semanas_debounced`)

### Reports
- Temp files written to `www/` directory
- Open in new browser tab via `window.open` (not modal/iframe)
- Session cleanup via `session$onSessionEnded`

## Testing

- `tests/testthat/test_calculations.R`: 380 passing tests across 28 sections (A-BB)
- `tests/testthat/test_legislative.R`: 137 passing tests across 13 sections (LA-LM)
  - Independent legislative tests based on DOF/CONSAR/IMSS, NOT derived from code
  - A-N: Core formulas, Ley 73/97, M40, Fondo eligibility, date validation
  - O: `generate_contribution_schedule()` (6 tests)
  - P: `project_afore_balance()` vector mode (8 tests)
  - Q: Reform impact validation (7 tests)
  - R: Fondo threshold extrapolation + retirement year (5 tests)
  - S: Full-pipeline hand-verified profiles (4 tests)
  - T: `calculate_all_scenarios()` integration (6 tests)
  - U: `compare_afores()` (4 tests)
  - V: `analyze_voluntary_contributions()` (4 tests)
  - W: `analyze_retirement_age()` (4 tests)
  - X: `generate_personalized_message()` (5 tests)
  - Y: Format helpers (4 tests)
  - Z: Data retrieval functions (5 tests)
  - AA: Edge cases (8 tests)
  - BB: /30 regression (DIAS_POR_MES consistency, 3 tests)
  - Uses `expect_num()` helper to ignore name attributes from vector lookups
- `tests/integration_test.R`: Frontend-backend sensitivity pipeline
- `tests/qa_test_profiles.R`: 22+ simulated user profiles
- `tests/edge_case_tests.R`: Stress testing boundary conditions
- `tests/validate_results_responsiveness.R`: UI responsiveness checks
- Run tests: `Rscript tests/testthat.R`

## Narrative & Content
- See `docs/narrative_content.md` for full reference
- Tone: empowering, honest, accessible, practical
- Key message: voluntary contributions are the SAFEST part of your pension
- Control framework: green (you control), yellow (partial), red (no control)
- Glossary of 14 terms in `docs/narrative_content.md`
- External links: IMSS Digital, e-SAR, CONSAR, CONASAMI

## Technical Gotchas
- Libraries must be in BOTH `app.R` and `global.R` (UI evaluation needs plotly etc.)
- `DIAS_POR_MES = 30.4375` (365.25/12) -- all daily-to-monthly conversions use this constant from `R/constants.R`. No more `/ 30` or `* 30` anywhere.
- plotly must be namespaced (`plotly::plotlyOutput`, `plotly::renderPlotly`)
- Global `<<-` assignment is intentional, not a code smell (Shiny scoping)
- `%||%` handles NULL inputs during Shiny initialization
- `.bg-surface` class, never `.bg-white`
- All `tryCatch` blocks log errors via `message()` and show user notification -- no silent `error = function(e) NULL`
- Report handlers wrapped in tryCatch for graceful error display
- `R/constants.R` is the single source of truth for all magic numbers -- sourced by both global.R and tests
- Navy color `#1a365d` fully removed from all R, CSS, SVG, and LaTeX
- CSS `prefers-reduced-motion` media query disables animations for accessibility
- LaTeX PDF headers use `\definecolor{primary}` (teal) and `\definecolor{accent}` (magenta)
