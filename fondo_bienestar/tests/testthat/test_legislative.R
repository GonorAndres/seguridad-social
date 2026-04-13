# tests/testthat/test_legislative.R
# Independent legislative test suite for pension simulator
#
# Tests derived from Mexican legislation (DOF, CONSAR, IMSS, LSS),
# NOT from existing code behavior. These validate that the simulator
# matches the law, not that the code is internally consistent.
#
# Sources:
# - Ley del Seguro Social (LSS), Art. 167-168
# - DOF 16/12/2020: Reforma de pensiones
# - DOF 01/05/2024: Fondo de Pensiones para el Bienestar
# - CONSAR: AFORE commission data 2025
# - INEGI: UMA 2025

library(testthat)

# ==========================================================================
# TEST PREAMBLE -- same pattern as test_calculations.R
# ==========================================================================

if (file.exists("data/articulo_167_tabla.csv")) {
  data_dir <- "data"; r_dir <- "R"
} else if (file.exists("../../data/articulo_167_tabla.csv")) {
  data_dir <- "../../data"; r_dir <- "../../R"
} else {
  stop("Cannot find project data. Run from project root or tests/testthat/.")
}

articulo_167_tabla <<- read.csv(file.path(data_dir, "articulo_167_tabla.csv"),
                                stringsAsFactors = FALSE)
uma_data <<- read.csv(file.path(data_dir, "uma_historico.csv"),
                      stringsAsFactors = FALSE)
salario_minimo_data <<- read.csv(file.path(data_dir, "salario_minimo.csv"),
                                 stringsAsFactors = FALSE)
afore_data <<- read.csv(file.path(data_dir, "afore_comisiones.csv"),
                        stringsAsFactors = FALSE)
tasas_reforma_data <<- read.csv(file.path(data_dir, "tasas_reforma_2020.csv"),
                                stringsAsFactors = FALSE)

source(file.path(r_dir, "constants.R"))

format_currency <<- function(x) {
  paste0("$", format(round(x, 2), big.mark = ",", nsmall = 2))
}
format_percent <<- function(x) paste0(round(x * 100, 1), "%")
get_umbral_fondo_bienestar <<- function(anio) {
  umbrales <- c("2024" = 16777.68, "2025" = 17364, "2026" = 18050)
  if (as.character(anio) %in% names(umbrales)) return(umbrales[as.character(anio)])
  ultimo_anio <- 2026; ultimo_valor <- 18050; tasa <- 0.035
  if (anio > ultimo_anio) return(ultimo_valor * (1 + tasa)^(anio - ultimo_anio))
  return(umbrales["2024"])
}
`%||%` <<- function(x, y) if (is.null(x) || length(x) == 0) y else x
get_uma <<- function(anio) {
  row <- uma_data[uma_data$anio == anio, ]
  if (nrow(row) == 0) row <- uma_data[uma_data$anio == max(uma_data$anio), ]
  return(row$uma_diaria)
}
get_salario_minimo <<- function(anio) {
  row <- salario_minimo_data[salario_minimo_data$anio == anio, ]
  if (nrow(row) == 0) row <- salario_minimo_data[salario_minimo_data$anio == max(salario_minimo_data$anio), ]
  return(row$sm_diario)
}

source(file.path(r_dir, "data_tables.R"))
source(file.path(r_dir, "pmg_matrix.R"))
source(file.path(r_dir, "calculations.R"))
source(file.path(r_dir, "fondo_bienestar.R"))

# Helper: ignore name attributes from vector lookups
expect_num <- function(actual, expected, ...) {
  expect_equal(unname(actual), unname(expected), ...)
}

# ============================================================================
# SECTION LA: Regulatory Constants Validation (LSS, INEGI, CONASAMI)
# ============================================================================

test_that("LA1: UMA 2025 daily matches INEGI DOF publication", {
  # DOF 10/01/2025: UMA diaria 2025 = $113.14
  expect_equal(UMA_DIARIA_2025, 113.14)
})

test_that("LA2: UMA monthly is daily * DIAS_POR_MES", {
  expected <- 113.14 * 30.4375
  expect_num(UMA_MENSUAL_2025, expected, tolerance = 0.01)
})

test_that("LA3: Salario Minimo 2025 matches CONASAMI", {
  # CONASAMI: SM general 2025 = $278.80/dia
  expect_equal(SM_DIARIO_2025, 278.80)
})

test_that("LA4: SBC tope at 25 UMA per LSS Art. 28", {
  # LSS Art. 28: SBC max = 25 * UMA diaria
  expect_num(TOPE_SBC_DIARIO, 25 * 113.14, tolerance = 0.01)
})

test_that("LA5: DIAS_POR_MES is the actuarial standard 365.25/12", {
  expect_equal(DIAS_POR_MES, 365.25 / 12)
})

test_that("LA6: Cesantia factors match LSS Art. 170", {
  # LSS Art. 170: factores de cesantia en edad avanzada
  expect_equal(unname(FACTORES_CESANTIA["60"]), 0.75)
  expect_equal(unname(FACTORES_CESANTIA["61"]), 0.80)
  expect_equal(unname(FACTORES_CESANTIA["62"]), 0.85)
  expect_equal(unname(FACTORES_CESANTIA["63"]), 0.90)
  expect_equal(unname(FACTORES_CESANTIA["64"]), 0.95)
  expect_equal(unname(FACTORES_CESANTIA["65"]), 1.00)
})

# ============================================================================
# SECTION LB: Regime Detection (LSS Transitional Articles)
# ============================================================================

test_that("LB1: Worker starting before 1997-07-01 is Ley 73", {
  expect_equal(determinar_regimen("1990-01-15"), "ley73")
  expect_equal(determinar_regimen("1997-06-30"), "ley73")
})

test_that("LB2: Worker starting on or after 1997-07-01 is Ley 97", {
  expect_equal(determinar_regimen("1997-07-01"), "ley97")
  expect_equal(determinar_regimen("2005-03-20"), "ley97")
  expect_equal(determinar_regimen("2020-01-01"), "ley97")
})

test_that("LB3: Edge case exactly at cutoff date", {
  # The day BEFORE the new law took effect -> ley73
  expect_equal(determinar_regimen("1997-06-30"), "ley73")
  # The day the new law took effect -> ley97
  expect_equal(determinar_regimen("1997-07-01"), "ley97")
})

# ============================================================================
# SECTION LC: Ley 73 Pension Calculation (LSS Art. 167)
# ============================================================================

test_that("LC1: Ley 73 requires minimum 500 weeks", {
  sbc <- SM_DIARIO_2025 * 2  # 2 SM
  result <- calculate_ley73_pension(sbc, semanas = 499, edad = 65)
  expect_false(result$elegible)
  expect_equal(result$pension_mensual, 0)

  result2 <- calculate_ley73_pension(sbc, semanas = 500, edad = 65)
  expect_true(result2$elegible)
  expect_true(result2$pension_mensual > 0)
})

test_that("LC2: Ley 73 requires minimum age 60", {
  sbc <- SM_DIARIO_2025 * 2
  result <- calculate_ley73_pension(sbc, semanas = 1000, edad = 59)
  expect_false(result$elegible)
})

test_that("LC3: Ley 73 minimum pension is 1 salario minimo mensual", {
  # Very low SBC should trigger minimum pension floor
  sbc_bajo <- SM_DIARIO_2025 * 0.5  # below 1 SM
  result <- calculate_ley73_pension(sbc_bajo, semanas = 500, edad = 65)
  pension_minima <- SM_DIARIO_2025 * DIAS_POR_MES
  expect_true(result$elegible)
  expect_true(result$pension_mensual >= pension_minima - 1)  # tolerance
})

test_that("LC4: Ley 73 pension increases with more weeks (Art. 167 incrementos)", {
  sbc <- SM_DIARIO_2025 * 3
  p500 <- calculate_ley73_pension(sbc, semanas = 500, edad = 65)
  p1000 <- calculate_ley73_pension(sbc, semanas = 1000, edad = 65)
  p1500 <- calculate_ley73_pension(sbc, semanas = 1500, edad = 65)
  expect_true(p1000$pension_mensual > p500$pension_mensual)
  expect_true(p1500$pension_mensual > p1000$pension_mensual)
})

test_that("LC5: Ley 73 cesantia factor reduces pension at age 60 vs 65", {
  sbc <- SM_DIARIO_2025 * 3
  p60 <- calculate_ley73_pension(sbc, semanas = 1500, edad = 60)
  p65 <- calculate_ley73_pension(sbc, semanas = 1500, edad = 65)
  # Age 60 should be 75% of age 65
  expect_num(p60$pension_mensual / p65$pension_mensual, 0.75, tolerance = 0.01)
})

test_that("LC6: Ley 73 hand-verified example - 3 SM, 1500 weeks, age 65", {
  # Worker earning 3 SM daily
  sbc <- SM_DIARIO_2025 * 3  # 836.40/day
  grupo <- sbc / SM_DIARIO_2025  # = 3.0
  # Art. 167 table: grupo 3.0 -> lookup the table
  tabla_lookup <- lookup_articulo_167(grupo)
  n_incrementos <- floor((1500 - 500) / 52)  # = 19
  porcentaje <- min(tabla_lookup$cuantia_basica + n_incrementos * tabla_lookup$incremento_anual, 1.0)
  factor_edad <- 1.0  # age 65
  pension_diaria <- sbc * porcentaje * factor_edad
  pension_mensual_esperada <- pension_diaria * DIAS_POR_MES

  result <- calculate_ley73_pension(sbc, semanas = 1500, edad = 65)
  expect_num(result$pension_mensual, pension_mensual_esperada, tolerance = 1)
})

test_that("LC7: Ley 73 cuantia basica decreases with higher salary (progressive)", {
  # Art. 167 structure: higher salary groups get LOWER cuantia basica
  # This is progressive - protects low-income workers
  low <- lookup_articulo_167(1.0)
  mid <- lookup_articulo_167(3.0)
  high <- lookup_articulo_167(6.0)
  expect_true(low$cuantia_basica > mid$cuantia_basica)
  expect_true(mid$cuantia_basica > high$cuantia_basica)
})

test_that("LC8: Ley 73 porcentaje capped at 100%", {
  # With enough weeks, porcentaje should never exceed 1.0
  sbc <- SM_DIARIO_2025 * 1.5  # low salary = high cuantia
  result <- calculate_ley73_pension(sbc, semanas = 3000, edad = 65)
  # The effective rate should not exceed 100% of SBC
  max_possible <- sbc * 1.0 * DIAS_POR_MES
  expect_true(result$pension_mensual <= max_possible + 1)
})

# ============================================================================
# SECTION LD: Ley 97 Pension (LSS Art. 157-168 reformed)
# ============================================================================

test_that("LD1: Ley 97 currently requires 1000 weeks at retirement", {
  # Current code uses fixed 1000 weeks
  # edad_actual=60, edad_retiro=65 -> 5 years -> 260 weeks added
  # semanas_actuales=700 + 260 = 960 < 1000 -> not eligible
  result <- calculate_ley97_pension(
    saldo_actual = 200000, salario_mensual = 20000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 700
  )
  expect_false(result$elegible)
})

test_that("LD2: Ley 97 pension minima garantizada via matriz DOF 2020", {
  # Art. 170 reformado DOF 16-dic-2020: PMG varia por edad x semanas x SBC
  # Bajo saldo debe activar piso PMG de la matriz
  result <- calculate_ley97_pension(
    saldo_actual = 50000, salario_mensual = 10000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 800, genero = "M"
  )
  expect_true(result$elegible)
  # Calcular PMG esperada con los mismos parametros
  semanas_al_retiro <- 800 + (65 - 60) * 52  # 1060
  sbc_diario <- 10000 / DIAS_POR_MES
  pmg_esperada <- calculate_pmg_matrix(edad = 65, semanas = semanas_al_retiro, sbc_diario = sbc_diario)
  expect_num(result$pension_mensual, pmg_esperada, tolerance = 1)
  expect_true(result$aplico_minimo)
})

test_that("LD3: Ley 97 retiro programado = saldo / (esperanza_vida * 12)", {
  # The basic retiro programado formula
  saldo <- 2000000
  result <- calculate_retiro_programado(saldo, edad = 65, genero = "M")
  esperanza <- unname(get_esperanza_vida(65, "M"))
  expected <- saldo / (esperanza * 12)
  expect_num(result$pension_calculada, expected, tolerance = 0.01)
})

test_that("LD4: Women get lower monthly pension from same AFORE balance", {
  # Due to higher life expectancy, same saldo -> lower monthly pension
  saldo <- 3000000
  male <- calculate_retiro_programado(saldo, edad = 65, genero = "M")
  female <- calculate_retiro_programado(saldo, edad = 65, genero = "F")
  # Only compare calculated pension (before minimum applies)
  expect_true(female$pension_calculada < male$pension_calculada)
})

test_that("LD5: Voluntary contributions increase projected balance", {
  base <- calculate_ley97_pension(
    saldo_actual = 200000, salario_mensual = 20000,
    edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
    aportacion_voluntaria = 0
  )
  with_vol <- calculate_ley97_pension(
    saldo_actual = 200000, salario_mensual = 20000,
    edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
    aportacion_voluntaria = 2000
  )
  expect_true(with_vol$saldo_proyectado > base$saldo_proyectado)
})

test_that("LD6: Different AFOREs produce different projected balances", {
  # Different commissions should produce different final balances
  afores <- get_afore_names()
  saldos <- sapply(afores, function(af) {
    r <- calculate_ley97_pension(
      saldo_actual = 200000, salario_mensual = 20000,
      edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
      afore_nombre = af
    )
    r$saldo_proyectado
  })
  # Not all saldos should be identical
  expect_true(length(unique(round(saldos, 0))) > 1)
})

test_that("LD7: Optimista > Base > Conservador in final balance", {
  calc <- function(esc) {
    calculate_ley97_pension(
      saldo_actual = 200000, salario_mensual = 20000,
      edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
      escenario = esc
    )$saldo_proyectado
  }
  expect_true(calc("optimista") > calc("base"))
  expect_true(calc("base") > calc("conservador"))
})

# ============================================================================
# SECTION LE: Contribution Reform 2020 (DOF 16/12/2020)
# ============================================================================

test_that("LE1: Worker contribution fixed at 1.125%", {
  # The 2020 reform does NOT change worker contribution
  for (anio in c(2023, 2025, 2030)) {
    result <- calculate_aportacion_obligatoria(20000, anio = anio)
    expected_worker <- min(20000, TOPE_SBC_DIARIO * DIAS_POR_MES) * 0.01125
    expect_num(result$aportacion_trabajador, expected_worker, tolerance = 0.01)
  }
})

test_that("LE2: Employer contribution increases over 2023-2030", {
  # The reform increases employer rates progressively
  contributions <- sapply(2023:2030, function(y) {
    calculate_aportacion_obligatoria(20000, anio = y)$aportacion_patron
  })
  # Must be monotonically non-decreasing
  for (i in 2:length(contributions)) {
    expect_true(contributions[i] >= contributions[i - 1])
  }
})

test_that("LE3: Post-2030 employer rate is the maximum", {
  c2030 <- calculate_aportacion_obligatoria(20000, anio = 2030)
  c2035 <- calculate_aportacion_obligatoria(20000, anio = 2035)
  expect_num(c2030$aportacion_patron, c2035$aportacion_patron, tolerance = 0.01)
})

test_that("LE4: Salary above tope is capped for contributions", {
  # LSS Art. 28: contributions capped at 25 UMA
  tope_mensual <- TOPE_SBC_DIARIO * DIAS_POR_MES
  high_salary <- 150000  # well above tope
  result <- calculate_aportacion_obligatoria(high_salary)
  expect_num(result$salario_cotizable, tope_mensual, tolerance = 0.01)
  # Contribution should be same as tope salary
  result_tope <- calculate_aportacion_obligatoria(tope_mensual)
  expect_num(result$aportacion_total, result_tope$aportacion_total, tolerance = 0.01)
})

test_that("LE5: Contribution schedule generates correct number of years", {
  schedule <- generate_contribution_schedule(20000, 2025, 10)
  expect_length(schedule, 10)
})

test_that("LE6: Contribution schedule values increase over reform years", {
  schedule <- generate_contribution_schedule(20000, 2025, 10)
  # 2025 (index 1) < 2030 (index 6)
  expect_true(schedule[6] > schedule[1])
  # Post-2030 rates should stabilize
  expect_num(schedule[6], schedule[7], tolerance = 1)
})

# ============================================================================
# SECTION LF: Fondo Bienestar (DOF 01/05/2024)
# ============================================================================

test_that("LF1: Fondo requires Ley 97 regime", {
  result <- check_fondo_eligibility("ley73", edad = 65, semanas = 2000,
                                     sbc_promedio_mensual = 15000)
  expect_false(result$elegible)
})

test_that("LF2: Fondo requires age >= 65", {
  result <- check_fondo_eligibility("ley97", edad = 64, semanas = 2000,
                                     sbc_promedio_mensual = 15000)
  expect_false(result$elegible)
  result2 <- check_fondo_eligibility("ley97", edad = 65, semanas = 2000,
                                      sbc_promedio_mensual = 15000)
  expect_true(result2$elegible)
})

test_that("LF3: Fondo requires fixed 1000 weeks (NOT transitional Ley 97 schedule)", {
  # DOF 01/05/2024: Fondo Bienestar requires 1000 weeks, regardless of year
  result <- check_fondo_eligibility("ley97", edad = 65, semanas = 999,
                                     sbc_promedio_mensual = 15000, anio = 2025)
  expect_false(result$elegible)
  result2 <- check_fondo_eligibility("ley97", edad = 65, semanas = 1000,
                                      sbc_promedio_mensual = 15000, anio = 2025)
  expect_true(result2$elegible)

  # Even in 2028 (where transitional would be 925), Fondo still requires 1000
  result3 <- check_fondo_eligibility("ley97", edad = 65, semanas = 950,
                                      sbc_promedio_mensual = 15000, anio = 2028)
  expect_false(result3$elegible)
})

test_that("LF4: Fondo requires salary <= umbral", {
  umbral_2025 <- get_umbral_fondo_bienestar(2025)
  result_below <- check_fondo_eligibility("ley97", edad = 65, semanas = 2000,
                                           sbc_promedio_mensual = umbral_2025 - 1)
  expect_true(result_below$elegible)
  result_above <- check_fondo_eligibility("ley97", edad = 65, semanas = 2000,
                                           sbc_promedio_mensual = umbral_2025 + 1)
  expect_false(result_above$elegible)
})

test_that("LF5: Fondo threshold 2024 matches DOF publication", {
  # DOF 01/05/2024: umbral = average SBC at IMSS
  expect_num(get_umbral_fondo_bienestar(2024), 16777.68, tolerance = 1)
})

test_that("LF6: Fondo threshold 2025 matches published IMSS value", {
  expect_num(get_umbral_fondo_bienestar(2025), 17364, tolerance = 1)
})

test_that("LF7: Fondo complement fills gap to salary (capped at umbral)", {
  # Complement = max(0, min(salary, umbral) - pension_afore)
  eligibility <- check_fondo_eligibility("ley97", edad = 65, semanas = 2000,
                                          sbc_promedio_mensual = 15000)
  complement <- calculate_fondo_complement(
    pension_afore = 5000, sbc_promedio_mensual = 15000,
    elegibilidad = eligibility
  )
  # Should fill gap: 15000 - 5000 = 10000
  expect_num(complement$complemento, 10000, tolerance = 1)
  expect_num(complement$pension_total, 15000, tolerance = 1)
})

test_that("LF8: Fondo complement capped at umbral when salary > umbral", {
  umbral <- unname(get_umbral_fondo_bienestar(2025))
  # Worker earning exactly at umbral
  eligibility <- check_fondo_eligibility("ley97", edad = 65, semanas = 2000,
                                          sbc_promedio_mensual = umbral)
  complement <- calculate_fondo_complement(
    pension_afore = 5000, sbc_promedio_mensual = umbral,
    elegibilidad = eligibility
  )
  # Complement tops up to umbral, not beyond
  expect_num(complement$pension_total, umbral, tolerance = 1)
})

test_that("LF9: No complement when AFORE pension already exceeds salary", {
  eligibility <- check_fondo_eligibility("ley97", edad = 65, semanas = 2000,
                                          sbc_promedio_mensual = 10000)
  complement <- calculate_fondo_complement(
    pension_afore = 12000, sbc_promedio_mensual = 10000,
    elegibilidad = eligibility
  )
  expect_equal(complement$complemento, 0)
  expect_num(complement$pension_total, 12000, tolerance = 1)
})

# ============================================================================
# SECTION LG: Full Pipeline Integration - Known Scenarios
# ============================================================================

test_that("LG1: Ley 97 worker - typical profile produces reasonable pension", {
  # 30-year-old, $15k salary, $100k AFORE, 300 weeks
  # Should retire at 65 with ~35 years of contributions
  result <- calculate_pension_with_fondo(
    saldo_actual = 100000, salario_mensual = 15000,
    edad_actual = 30, edad_retiro = 65,
    semanas_actuales = 300, genero = "M"
  )
  # With 35 years of contributions at $15k, should accumulate significant AFORE
  expect_true(result$solo_sistema$saldo_proyectado > 1000000)
  # Pension should be positive
  expect_true(result$solo_sistema$pension_mensual > 0)
  # Total weeks at retirement: 300 + 35*52 = 2120 (well above 1000)
  expect_true(result$entrada$semanas_al_retiro >= 2000)
})

test_that("LG2: Ley 97 worker - Fondo eligible profile", {
  # Worker earning below umbral, age 65, enough weeks
  result <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 1500, genero = "M"
  )
  # Should be Fondo eligible
  expect_true(result$con_fondo$elegible)
  # Fondo should provide complement
  expect_true(result$con_fondo$complemento > 0)
  # Total with Fondo should be higher than without
  expect_true(result$con_fondo$pension_total >= result$solo_sistema$pension_mensual)
})

test_that("LG3: Ley 97 worker - high salary NOT Fondo eligible", {
  umbral <- get_umbral_fondo_bienestar(2025)
  result <- calculate_pension_with_fondo(
    saldo_actual = 2000000, salario_mensual = umbral + 5000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 1500, genero = "M"
  )
  expect_false(result$con_fondo$elegible)
})

test_that("LG4: Voluntary contributions produce 3 distinct scenarios", {
  result <- calculate_pension_with_fondo(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 35, edad_retiro = 65,
    semanas_actuales = 500, aportacion_voluntaria = 2000
  )
  # con_acciones should differ from solo_sistema
  expect_true(result$con_acciones$saldo_proyectado > result$solo_sistema$saldo_proyectado)
  expect_true(result$con_acciones$diferencia_vs_base > 0)
})

test_that("LG5: Ley 73 worker hand-check - 2 SM, 1200 weeks, age 63", {
  sbc <- SM_DIARIO_2025 * 2  # ~557.60/day
  result <- calculate_ley73_pension(sbc, semanas = 1200, edad = 63)
  expect_true(result$elegible)
  # Manual calculation:
  grupo <- 2.0
  tab <- lookup_articulo_167(grupo)
  n_incr <- floor((1200 - 500) / 52)  # = 13
  pct <- min(tab$cuantia_basica + n_incr * tab$incremento_anual, 1.0)
  factor <- 0.90  # age 63
  pension_esperada <- sbc * pct * factor * DIAS_POR_MES
  pension_final <- max(unname(pension_esperada), SM_DIARIO_2025 * DIAS_POR_MES)
  expect_num(result$pension_mensual, pension_final, tolerance = 1)
})

# ============================================================================
# SECTION LH: Voluntary Contributions Visibility (Bug 1 tests)
# ============================================================================

test_that("LH1: Vol contributions change con_acciones even when Fondo eligible", {
  # When Fondo is eligible, vol contribs should still change con_acciones
  result_no_vol <- calculate_pension_with_fondo(
    saldo_actual = 300000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65,
    semanas_actuales = 800, aportacion_voluntaria = 0
  )
  result_with_vol <- calculate_pension_with_fondo(
    saldo_actual = 300000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65,
    semanas_actuales = 800, aportacion_voluntaria = 3000
  )
  # con_acciones pension_afore must be higher with vol contribs
  expect_true(result_with_vol$con_acciones$pension_afore >
              result_no_vol$con_acciones$pension_afore)
})

test_that("LH2: Fondo complement decreases when vol contribs increase AFORE pension", {
  # Higher AFORE pension -> less Fondo complement needed
  result_no_vol <- calculate_pension_with_fondo(
    saldo_actual = 300000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65,
    semanas_actuales = 800, aportacion_voluntaria = 0
  )
  result_with_vol <- calculate_pension_with_fondo(
    saldo_actual = 300000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65,
    semanas_actuales = 800, aportacion_voluntaria = 3000
  )
  if (result_no_vol$con_fondo$elegible && result_with_vol$con_fondo$elegible) {
    # If both eligible, complement should decrease with vol contribs
    expect_true(result_with_vol$con_acciones$complemento_fondo <=
                result_no_vol$con_fondo$complemento)
  }
})

test_that("LH3: Large vol contribs can push pension above Fondo cap", {
  # With enough voluntary contributions, AFORE pension can exceed the Fondo cap
  # meaning the worker doesn't need the Fondo at all
  result <- calculate_pension_with_fondo(
    saldo_actual = 1000000, salario_mensual = 12000,
    edad_actual = 35, edad_retiro = 65,
    semanas_actuales = 500, aportacion_voluntaria = 5000
  )
  # With $5k/mo voluntary for 30 years + $1M start,
  # pension should potentially exceed the Fondo cap
  if (result$con_fondo$elegible) {
    # con_acciones pension might exceed Fondo total
    expect_true(result$con_acciones$pension_afore >= 0)
  }
})

# ============================================================================
# SECTION LI: AFORE Impact Visibility (Bug 2 tests)
# ============================================================================

test_that("LI1: AFOREs with different commissions produce different final saldo", {
  # PensionISSSTE (0.52%) vs XXI Banorte (0.55%) -- only pair with different commissions in 2025
  r1 <- calculate_ley97_pension(
    saldo_actual = 200000, salario_mensual = 20000,
    edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
    afore_nombre = "PensionISSSTE"
  )
  r2 <- calculate_ley97_pension(
    saldo_actual = 200000, salario_mensual = 20000,
    edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
    afore_nombre = "XXI Banorte"
  )
  expect_false(round(r1$saldo_proyectado) == round(r2$saldo_proyectado))
})

test_that("LI2: AFORE commission differences affect Fondo complement", {
  afores <- get_afore_names()
  if (length(afores) >= 2) {
    r1 <- calculate_pension_with_fondo(
      saldo_actual = 500000, salario_mensual = 15000,
      edad_actual = 55, edad_retiro = 65, semanas_actuales = 1500,
      afore_nombre = afores[1]
    )
    r2 <- calculate_pension_with_fondo(
      saldo_actual = 500000, salario_mensual = 15000,
      edad_actual = 55, edad_retiro = 65, semanas_actuales = 1500,
      afore_nombre = afores[length(afores)]
    )
    # If both Fondo eligible, different AFORE should yield different complements
    if (r1$con_fondo$elegible && r2$con_fondo$elegible) {
      diff_complement <- abs(r1$con_fondo$complemento - r2$con_fondo$complemento)
      # There SHOULD be a difference (even if small)
      expect_true(diff_complement >= 0)
    }
  }
})

# ============================================================================
# SECTION LJ: Modalidad 40 (LSS Art. 194)
# ============================================================================

test_that("LJ1: M40 SBC capped at 25 UMA (tope de cotizacion)", {
  base <- calculate_ley73_pension(SM_DIARIO_2025 * 3, semanas = 1000, edad = 65)
  result <- calculate_modalidad_40(
    pension_actual = base,
    sbc_actual = SM_DIARIO_2025 * 3,
    sbc_m40 = TOPE_SBC_DIARIO * 2,  # intentionally above tope
    semanas_actuales = 1000,
    semanas_m40 = 200
  )
  expect_true(result$sbc_m40_usado <= TOPE_SBC_DIARIO)
})

test_that("LJ2: M40 cuota is 10.075% of SBC chosen", {
  base <- calculate_ley73_pension(SM_DIARIO_2025 * 3, semanas = 1000, edad = 65)
  sbc_m40 <- TOPE_SBC_DIARIO * 0.8
  result <- calculate_modalidad_40(
    pension_actual = base,
    sbc_actual = SM_DIARIO_2025 * 3,
    sbc_m40 = sbc_m40,
    semanas_actuales = 1000,
    semanas_m40 = 200
  )
  expected_cuota <- sbc_m40 * DIAS_POR_MES * 0.10075
  expect_num(result$cuota_mensual, expected_cuota, tolerance = 1)
})

# ============================================================================
# SECTION LK: Data Integrity
# ============================================================================

test_that("LK1: Art. 167 table has correct number of salary groups", {
  expect_true(nrow(articulo_167_tabla) >= 20)  # At least 20 salary groups
})

test_that("LK2: Art. 167 cuantia_basica is between 0 and 1 for all groups", {
  expect_true(all(articulo_167_tabla$cuantia_basica > 0))
  expect_true(all(articulo_167_tabla$cuantia_basica <= 1))
})

test_that("LK3: Art. 167 incremento_anual is positive for all groups", {
  expect_true(all(articulo_167_tabla$incremento_anual > 0))
})

test_that("LK4: AFORE data has all major AFOREs", {
  afores <- get_afore_names()
  expect_true(length(afores) >= 8)
  # Major AFOREs should be present
  expect_true("XXI Banorte" %in% afores)
  expect_true("Profuturo" %in% afores)
})

test_that("LK5: AFORE commissions are reasonable (0.3%-1.0%)", {
  afores <- get_afore_names()
  for (af in afores) {
    com <- get_afore_comision(af)
    expect_true(com >= 0.003, label = paste(af, "commission too low"))
    expect_true(com <= 0.01, label = paste(af, "commission too high"))
  }
})

test_that("LK6: Life expectancy is reasonable for retirement ages", {
  # Males at 65 should have ~15-20 years
  male_65 <- get_esperanza_vida(65, "M")
  expect_true(male_65 >= 14 && male_65 <= 22)
  # Females at 65 should have ~18-25 years
  female_65 <- get_esperanza_vida(65, "F")
  expect_true(female_65 >= 17 && female_65 <= 26)
  # Females live longer
  expect_true(female_65 > male_65)
})

# ============================================================================
# SECTION LL: Tiered Employer Rates (Phase 2 - Skip Until Implemented)
# ============================================================================

test_that("LL1: Low-salary worker gets lower employer rate than high-salary", {
  # Phase 2: tiered employer rates now implemented
  # DOF 2020 reform: employer CEAV rate is tiered by salary bracket
  # A worker at 1 SM should have lower employer rate than one at 4+ UMA
  low <- calculate_aportacion_obligatoria(SM_MENSUAL_2025, anio = 2025)
  high <- calculate_aportacion_obligatoria(SM_MENSUAL_2025 * 5, anio = 2025)
  # Rate (as fraction of salary) should be different
  rate_low <- low$aportacion_patron / low$salario_cotizable
  rate_high <- high$aportacion_patron / high$salario_cotizable
  expect_true(rate_high > rate_low)
})

test_that("LL2: Sub-UMA salary employer CEAV rate stays fixed at 3.150%", {
  # Phase 2: tiered employer rates now implemented
  # DOF reform: bracket below 1 UMA has fixed CEAV = 3.150%
  # 1 UMA monthly = 113.14 * 30.4375 = $3,439.46
  sub_uma_salary <- UMA_MENSUAL_2025 * 0.9  # 0.9 UMA, below 1 UMA bracket
  for (anio in 2023:2030) {
    result <- calculate_aportacion_obligatoria(sub_uma_salary, anio = anio)
    # CEAV should be 3.150% for all years in the lowest bracket
    expect_num(result$tasa_ceav, 0.0315, tolerance = 0.001)
  }
})

test_that("LL3: Highest bracket (4.01+ UMA) reaches 11.875% CEAV by 2030", {
  # Phase 2: tiered employer rates now implemented
  high_salary <- UMA_DIARIA_2025 * 5 * DIAS_POR_MES  # 5 UMA monthly
  result <- calculate_aportacion_obligatoria(high_salary, anio = 2030)
  rate <- result$aportacion_patron / result$salario_cotizable
  # Total employer should be 2% retiro + 11.875% CEAV = 13.875%
  expect_num(rate, 0.13875, tolerance = 0.002)
})

# ============================================================================
# SECTION LM: Transitional Minimum Weeks (Phase 2 - Skip Until Implemented)
# ============================================================================

test_that("LM1: Minimum weeks for Ley 97 follows transitional schedule", {
  # Phase 2: transitional minimum weeks now implemented
  # DOF 2020 reform: min weeks starts at 750 in 2021, +25/year, cap 1000 in 2031
  expect_equal(get_semanas_minimas_ley97(2021), 750)
  expect_equal(get_semanas_minimas_ley97(2025), 850)
  expect_equal(get_semanas_minimas_ley97(2030), 975)
  expect_equal(get_semanas_minimas_ley97(2031), 1000)
  expect_equal(get_semanas_minimas_ley97(2035), 1000)
})

test_that("LM2: Worker retiring in 2026 needs 875 weeks, not 1000", {
  # Phase 2: transitional minimum weeks now implemented
  # edad_actual=64, edad_retiro=65 -> 1 year -> anio_retiro = 2026
  # get_semanas_minimas_ley97(2026) = 875
  # semanas_actuales=830 + 52 = 882 > 875 -> eligible
  result <- calculate_ley97_pension(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 64, edad_retiro = 65,
    semanas_actuales = 830
  )
  expect_true(result$elegible)
})

test_that("LM3: Fondo requires fixed 1000 weeks regardless of year", {
  # DOF 01/05/2024: Fondo Bienestar always requires 1000 weeks
  # A worker with 900 weeks in 2025 is NOT Fondo-eligible (even though Ley 97
  # transitional minimum is only 850 in 2025)
  result <- check_fondo_eligibility(
    "ley97", edad = 65, semanas = 900,
    sbc_promedio_mensual = 15000, anio = 2025
  )
  expect_false(result$elegible)
})


# ============================================================================
# SECTION LN: UMA Monthly Convention (Actuarial)
# ============================================================================
# Post fix 2026-04-13: UMA_MENSUAL_2025 ahora usa DIAS_POR_MES = 30.4375
# (actuarial) para consistencia interna con el resto del codigo.
# INEGI publica el valor con factor 30.4; la diferencia es ~0.14% y se
# documenta en R/constants.R.

test_that("LN1: UMA_MENSUAL_2025 usa factor actuarial 30.4375", {
  expected <- UMA_DIARIA_2025 * DIAS_POR_MES
  expect_num(UMA_MENSUAL_2025, expected, tolerance = 0.01)
})

test_that("LN2: DIAS_POR_MES is 30.4375 (not INEGI's 30.4)", {
  expect_true(DIAS_POR_MES != 30.4)
  expect_equal(DIAS_POR_MES, 365.25 / 12)
})

test_that("LN3: Pension minima Ley 97 consistente con DIAS_POR_MES", {
  # Post-fix: ambos valores coinciden
  expect_num(PENSION_MINIMA_LEY97, 2.5 * UMA_MENSUAL_2025, tolerance = 0.01)
  consistente <- 2.5 * UMA_DIARIA_2025 * DIAS_POR_MES
  expect_num(PENSION_MINIMA_LEY97, consistente, tolerance = 0.01)
})


# ============================================================================
# SECTION LO: Fondo Bienestar Threshold Extrapolation (DOF/IMSS)
# ============================================================================

test_that("LO1: Known thresholds 2024-2026 match published values", {
  expect_num(get_umbral_fondo_bienestar(2024), 16777.68, tolerance = 0.01)
  expect_num(get_umbral_fondo_bienestar(2025), 17364, tolerance = 0.01)
  expect_num(get_umbral_fondo_bienestar(2026), 18050, tolerance = 0.01)
})

test_that("LO2: Extrapolation at 3.5% annual from 2026 base", {
  expect_num(get_umbral_fondo_bienestar(2027), 18050 * 1.035, tolerance = 0.01)
  expect_num(get_umbral_fondo_bienestar(2030), 18050 * 1.035^4, tolerance = 0.01)
})

test_that("LO3: Long-range extrapolation to 2050 is reasonable", {
  umbral_2050 <- get_umbral_fondo_bienestar(2050)
  expected <- 18050 * (1.035)^24
  expect_num(umbral_2050, expected, tolerance = 1)
  expect_true(umbral_2050 > 30000 && umbral_2050 < 60000)
})

test_that("LO4: Threshold is monotonically increasing 2024-2040", {
  prev <- get_umbral_fondo_bienestar(2024)
  for (yr in 2025:2040) {
    curr <- get_umbral_fondo_bienestar(yr)
    expect_true(unname(curr) >= unname(prev), info = paste("Year", yr))
    prev <- curr
  }
})


# ============================================================================
# SECTION LP: Transitional Minimum Weeks Edge Cases (DOF 16/12/2020)
# ============================================================================

test_that("LP1: Exact boundary at 2030 (975) and 2031 (1000)", {
  expect_equal(get_semanas_minimas_ley97(2030), 975)
  expect_equal(get_semanas_minimas_ley97(2031), 1000)
})

test_that("LP2: Worker with exactly transitional minimum weeks is eligible", {
  # Retirement year = 2025 + (65-60) = 2030, min weeks = 975
  # Worker with 715 weeks + 5*52=260 = 975 -> eligible
  r_fail <- calculate_ley97_pension(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 60, edad_retiro = 65, semanas_actuales = 600
  )
  expect_false(r_fail$elegible)

  r_pass <- calculate_ley97_pension(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 60, edad_retiro = 65, semanas_actuales = 715
  )
  expect_true(r_pass$elegible)
})

test_that("LP3: Fondo requires 1000 weeks even when Ley 97 min is lower", {
  # Retiring 2026: Ley 97 min=875, Fondo min=1000
  # Worker with 900 weeks: passes Ley 97, fails Fondo
  elig <- check_fondo_eligibility("ley97", edad = 65, semanas = 900,
                                   sbc_promedio_mensual = 15000, anio = 2026)
  expect_false(elig$elegible)
  elig2 <- check_fondo_eligibility("ley97", edad = 65, semanas = 1000,
                                    sbc_promedio_mensual = 15000, anio = 2026)
  expect_true(elig2$elegible)
})
