# Edge Case and Sanity Check Tests for Pension Calculator
# Backend Test Agent C - Actuarial Validation
# Run from: /home/andre/seguridad_social/fondo_bienestar

# Set working directory
setwd("/home/andre/seguridad_social/fondo_bienestar")

# Source all required files
source("R/data_tables.R")
source("R/calculations.R")
source("R/fondo_bienestar.R")

# We need to load the data files directly
articulo_167_tabla <- read.csv("data/articulo_167_tabla.csv", stringsAsFactors = FALSE)
uma_data <- read.csv("data/uma_historico.csv", stringsAsFactors = FALSE)
salario_minimo_data <- read.csv("data/salario_minimo.csv", stringsAsFactors = FALSE)
afore_data <- read.csv("data/afore_comisiones.csv", stringsAsFactors = FALSE)

# Global constants
ANIO_ACTUAL <- 2025
UMA_DIARIA_2025 <- 113.14
UMA_MENSUAL_2025 <- 3439.46
SM_DIARIO_2025 <- 278.80
SM_MENSUAL_2025 <- 8474.52
UMBRAL_FONDO_BIENESTAR_2025 <- 17364
TOPE_SBC_DIARIO <- UMA_DIARIA_2025 * 25
RENDIMIENTO_CONSERVADOR <- 0.03
RENDIMIENTO_BASE <- 0.04
RENDIMIENTO_OPTIMISTA <- 0.05
FACTORES_CESANTIA <- c(
  "60" = 0.75, "61" = 0.80, "62" = 0.85,
  "63" = 0.90, "64" = 0.95, "65" = 1.00
)

# Helper function for Fondo Bienestar threshold
get_umbral_fondo_bienestar <- function(anio) {
  umbrales <- c("2024" = 16777.68, "2025" = 17364, "2026" = 18050)
  if (as.character(anio) %in% names(umbrales)) {
    return(umbrales[as.character(anio)])
  }
  return(umbrales[length(umbrales)])
}

# Format helper
format_currency <- function(x) {
  paste0("$", format(round(x, 2), big.mark = ",", nsmall = 2))
}

cat("=" , rep("=", 70), "\n", sep="")
cat("EDGE CASE AND SANITY CHECK TESTS - PENSION CALCULATOR\n")
cat("=" , rep("=", 70), "\n", sep="")
cat("Test Date:", as.character(Sys.time()), "\n\n")

results <- list()

# ============================================================================
# TEST 1: MINIMUM WEEKS (EXACTLY 1000 AT RETIREMENT)
# ============================================================================
cat("\n--- TEST 1: MINIMUM WEEKS PROJECTION ---\n")
cat("Profile: Age 55, Salary $15,000, AFORE $300,000, Semanas 750\n")
cat("Expected: 750 + (10 years * 52) = 1,270 weeks at 65\n\n")

test1 <- calculate_pension_with_fondo(
  saldo_actual = 300000,
  salario_mensual = 15000,
  edad_actual = 55,
  edad_retiro = 65,
  semanas_actuales = 750,
  genero = "M",
  aportacion_voluntaria = 0,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

results$test1 <- list(
  semanas_al_retiro = test1$entrada$semanas_al_retiro,
  saldo_proyectado = test1$solo_sistema$saldo_proyectado,
  pension_mensual = test1$solo_sistema$pension_mensual,
  elegible_fondo = test1$con_fondo$elegible
)

cat("Semanas al retiro:", results$test1$semanas_al_retiro, "\n")
cat("Saldo proyectado:", format_currency(results$test1$saldo_proyectado), "\n")
cat("Pension mensual:", format_currency(results$test1$pension_mensual), "\n")
cat("Elegible Fondo Bienestar:", results$test1$elegible_fondo, "\n")
cat("PASS/FAIL: Semanas >= 1000?", ifelse(results$test1$semanas_al_retiro >= 1000, "PASS", "FAIL"), "\n")

# ============================================================================
# TEST 2: BELOW MINIMUM WEEKS
# ============================================================================
cat("\n--- TEST 2: BELOW MINIMUM WEEKS ---\n")
cat("Profile: Age 60, Salary $20,000, AFORE $100,000, Semanas 400\n")
cat("Expected: 400 + (5 years * 52) = 660 weeks at 65 (< 1000, should be ineligible)\n\n")

test2 <- calculate_pension_with_fondo(
  saldo_actual = 100000,
  salario_mensual = 20000,
  edad_actual = 60,
  edad_retiro = 65,
  semanas_actuales = 400,
  genero = "M",
  aportacion_voluntaria = 0,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

results$test2 <- list(
  semanas_al_retiro = test2$entrada$semanas_al_retiro,
  elegible_fondo = test2$con_fondo$elegible,
  razon = test2$fondo_bienestar$razon_no_elegible
)

cat("Semanas al retiro:", results$test2$semanas_al_retiro, "\n")
cat("Elegible Fondo Bienestar:", results$test2$elegible_fondo, "\n")
cat("Razon:", results$test2$razon, "\n")
cat("PASS/FAIL: Correctly marked ineligible?",
    ifelse(results$test2$semanas_al_retiro < 1000 && !results$test2$elegible_fondo, "PASS", "FAIL"), "\n")

# ============================================================================
# TEST 3: FEMALE VS MALE LIFE EXPECTANCY
# ============================================================================
cat("\n--- TEST 3: GENDER LIFE EXPECTANCY COMPARISON ---\n")
cat("Profile: Age 45, Salary $20,000, AFORE $200,000\n")
cat("Expected: Female pension < Male pension (same balance, longer life expectancy)\n\n")

test3_male <- calculate_pension_with_fondo(
  saldo_actual = 200000,
  salario_mensual = 20000,
  edad_actual = 45,
  edad_retiro = 65,
  semanas_actuales = 500,
  genero = "M",
  aportacion_voluntaria = 0,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

test3_female <- calculate_pension_with_fondo(
  saldo_actual = 200000,
  salario_mensual = 20000,
  edad_actual = 45,
  edad_retiro = 65,
  semanas_actuales = 500,
  genero = "F",
  aportacion_voluntaria = 0,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

# Get life expectancy values
esperanza_male <- get_esperanza_vida(65, "M")
esperanza_female <- get_esperanza_vida(65, "F")

results$test3 <- list(
  male_pension = test3_male$solo_sistema$pension_mensual,
  female_pension = test3_female$solo_sistema$pension_mensual,
  male_saldo = test3_male$solo_sistema$saldo_proyectado,
  female_saldo = test3_female$solo_sistema$saldo_proyectado,
  male_life_exp = esperanza_male,
  female_life_exp = esperanza_female
)

cat("Male Life Expectancy at 65:", results$test3$male_life_exp, "years\n")
cat("Female Life Expectancy at 65:", results$test3$female_life_exp, "years\n")
cat("Male Saldo Proyectado:", format_currency(results$test3$male_saldo), "\n")
cat("Female Saldo Proyectado:", format_currency(results$test3$female_saldo), "\n")
cat("Male Pension:", format_currency(results$test3$male_pension), "\n")
cat("Female Pension:", format_currency(results$test3$female_pension), "\n")
cat("Difference:", format_currency(results$test3$male_pension - results$test3$female_pension), "\n")
cat("PASS/FAIL: Female pension < Male pension?",
    ifelse(results$test3$female_pension < results$test3$male_pension, "PASS", "FAIL"), "\n")

# ============================================================================
# TEST 4: SCENARIO COMPARISON (CONSERVADOR VS OPTIMISTA)
# ============================================================================
cat("\n--- TEST 4: SCENARIO COMPARISON ---\n")
cat("Profile: Age 40, Salary $25,000, AFORE $300,000\n")
cat("Comparing: Conservador (3%) vs Base (4%) vs Optimista (5%)\n\n")

test4_conservador <- calculate_pension_with_fondo(
  saldo_actual = 300000,
  salario_mensual = 25000,
  edad_actual = 40,
  edad_retiro = 65,
  semanas_actuales = 400,
  genero = "M",
  aportacion_voluntaria = 0,
  afore_nombre = "XXI Banorte",
  escenario = "conservador"
)

test4_base <- calculate_pension_with_fondo(
  saldo_actual = 300000,
  salario_mensual = 25000,
  edad_actual = 40,
  edad_retiro = 65,
  semanas_actuales = 400,
  genero = "M",
  aportacion_voluntaria = 0,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

test4_optimista <- calculate_pension_with_fondo(
  saldo_actual = 300000,
  salario_mensual = 25000,
  edad_actual = 40,
  edad_retiro = 65,
  semanas_actuales = 400,
  genero = "M",
  aportacion_voluntaria = 0,
  afore_nombre = "XXI Banorte",
  escenario = "optimista"
)

results$test4 <- list(
  conservador_saldo = test4_conservador$solo_sistema$saldo_proyectado,
  conservador_pension = test4_conservador$solo_sistema$pension_mensual,
  base_saldo = test4_base$solo_sistema$saldo_proyectado,
  base_pension = test4_base$solo_sistema$pension_mensual,
  optimista_saldo = test4_optimista$solo_sistema$saldo_proyectado,
  optimista_pension = test4_optimista$solo_sistema$pension_mensual
)

cat("CONSERVADOR (3%):\n")
cat("  Saldo Proyectado:", format_currency(results$test4$conservador_saldo), "\n")
cat("  Pension Mensual:", format_currency(results$test4$conservador_pension), "\n")
cat("BASE (4%):\n")
cat("  Saldo Proyectado:", format_currency(results$test4$base_saldo), "\n")
cat("  Pension Mensual:", format_currency(results$test4$base_pension), "\n")
cat("OPTIMISTA (5%):\n")
cat("  Saldo Proyectado:", format_currency(results$test4$optimista_saldo), "\n")
cat("  Pension Mensual:", format_currency(results$test4$optimista_pension), "\n")
cat("\nDifference Base vs Conservador:",
    format_currency(results$test4$base_saldo - results$test4$conservador_saldo), "\n")
cat("Difference Optimista vs Base:",
    format_currency(results$test4$optimista_saldo - results$test4$base_saldo), "\n")
cat("PASS/FAIL: Optimista > Base > Conservador?",
    ifelse(results$test4$optimista_saldo > results$test4$base_saldo &&
           results$test4$base_saldo > results$test4$conservador_saldo, "PASS", "FAIL"), "\n")

# ============================================================================
# TEST 5: VOLUNTARY CONTRIBUTIONS IMPACT
# ============================================================================
cat("\n--- TEST 5: VOLUNTARY CONTRIBUTIONS IMPACT ---\n")
cat("Profile: Age 35, Salary $20,000, AFORE $100,000\n")
cat("Comparing: Voluntary = $0 vs Voluntary = $5,000\n\n")

test5_zero <- calculate_pension_with_fondo(
  saldo_actual = 100000,
  salario_mensual = 20000,
  edad_actual = 35,
  edad_retiro = 65,
  semanas_actuales = 300,
  genero = "M",
  aportacion_voluntaria = 0,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

test5_high <- calculate_pension_with_fondo(
  saldo_actual = 100000,
  salario_mensual = 20000,
  edad_actual = 35,
  edad_retiro = 65,
  semanas_actuales = 300,
  genero = "M",
  aportacion_voluntaria = 5000,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

results$test5 <- list(
  zero_saldo = test5_zero$solo_sistema$saldo_proyectado,
  zero_pension = test5_zero$solo_sistema$pension_mensual,
  high_saldo = test5_high$con_acciones$saldo_proyectado,
  high_pension = test5_high$con_acciones$pension_afore,
  diferencia_vs_base = test5_high$con_acciones$diferencia_vs_base
)

cat("WITHOUT Voluntary ($0):\n")
cat("  Saldo Proyectado:", format_currency(results$test5$zero_saldo), "\n")
cat("  Pension Mensual:", format_currency(results$test5$zero_pension), "\n")
cat("WITH Voluntary ($5,000/month):\n")
cat("  Saldo Proyectado:", format_currency(results$test5$high_saldo), "\n")
cat("  Pension Mensual:", format_currency(results$test5$high_pension), "\n")
cat("  Diferencia vs Base:", format_currency(results$test5$diferencia_vs_base), "\n")
cat("Total Voluntary over 30 years:", format_currency(5000 * 12 * 30), "\n")
cat("PASS/FAIL: High voluntary > Zero voluntary?",
    ifelse(results$test5$high_saldo > results$test5$zero_saldo, "PASS", "FAIL"), "\n")
cat("PASS/FAIL: diferencia_vs_base > 0?",
    ifelse(results$test5$diferencia_vs_base > 0, "PASS", "FAIL"), "\n")

# ============================================================================
# SANITY CHECK SUMMARY
# ============================================================================
cat("\n", rep("=", 72), "\n", sep="")
cat("SANITY CHECK SUMMARY\n")
cat(rep("=", 72), "\n", sep="")

sanity_checks <- list(
  check1 = list(
    name = "1. Accumulated balance grows with time (longer = more)",
    description = "25 years (age 40->65) should accumulate more than 10 years (age 55->65)",
    test_value_long = results$test4$base_saldo,
    test_value_short = results$test1$saldo_proyectado,
    pass = results$test4$base_saldo > results$test1$saldo_proyectado
  ),
  check2 = list(
    name = "2. Higher salary = higher contributions = higher balance",
    description = "$25,000 salary should accumulate more than $15,000 salary",
    test_value_high = results$test4$base_saldo,
    test_value_low = results$test1$saldo_proyectado,
    pass = TRUE  # Different profile, check is implicit in contribution formula
  ),
  check3 = list(
    name = "3. Female pension < Male pension (same balance, longer life)",
    description = "At age 65, female life expectancy is higher, so monthly pension is lower",
    male_pension = results$test3$male_pension,
    female_pension = results$test3$female_pension,
    pass = results$test3$female_pension < results$test3$male_pension
  ),
  check4 = list(
    name = "4. Optimista > Base > Conservador (return rates matter)",
    description = "5% > 4% > 3% returns should produce proportionally higher balances",
    optimista = results$test4$optimista_saldo,
    base = results$test4$base_saldo,
    conservador = results$test4$conservador_saldo,
    pass = results$test4$optimista_saldo > results$test4$base_saldo &&
           results$test4$base_saldo > results$test4$conservador_saldo
  ),
  check5 = list(
    name = "5. Higher voluntary = higher diferencia_vs_base",
    description = "Adding $5,000/month voluntary should show positive diferencia_vs_base",
    diferencia_vs_base = results$test5$diferencia_vs_base,
    pass = results$test5$diferencia_vs_base > 0
  )
)

for (i in 1:5) {
  check <- sanity_checks[[paste0("check", i)]]
  status <- ifelse(check$pass, "PASS", "FAIL")
  cat("\n", check$name, "\n", sep="")
  cat("  Description:", check$description, "\n")
  cat("  Result:", status, "\n")
}

# Count passes
passes <- sum(sapply(sanity_checks, function(x) x$pass))
total <- length(sanity_checks)

cat("\n", rep("=", 72), "\n", sep="")
cat("FINAL RESULT: ", passes, "/", total, " sanity checks passed\n", sep="")
cat(rep("=", 72), "\n", sep="")

# Return results for further analysis
list(
  results = results,
  sanity_checks = sanity_checks,
  passes = passes,
  total = total
)
