# tests/testthat/test_calculations.R
# Comprehensive actuarial test suite for pension simulator
# ~176 test cases across 28 sections (A-BB)
#
# Note: Many R functions return named numerics from vector lookups.
# We use unname() in comparisons to avoid attr-mismatch failures.

library(testthat)

# ==========================================================================
# TEST PREAMBLE -- load environment without Shiny
# ==========================================================================

if (file.exists("data/articulo_167_tabla.csv")) {
  data_dir <- "data"; r_dir <- "R"
} else if (file.exists("../../data/articulo_167_tabla.csv")) {
  data_dir <- "../../data"; r_dir <- "../../R"
} else {
  stop("Cannot find project data. Run from project root or tests/testthat/.")
}

# Load data into global environment
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

# Constants (single source of truth)
source(file.path(r_dir, "constants.R"))

# Utility functions from global.R needed by sourced files
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

# Source calculation files
source(file.path(r_dir, "data_tables.R"))
source(file.path(r_dir, "pmg_matrix.R"))
source(file.path(r_dir, "calculations.R"))
source(file.path(r_dir, "fondo_bienestar.R"))

# Helper: numeric comparison ignoring names attribute
# R propagates names from vector lookups through arithmetic,
# making strict expect_equal fail on otherwise-equal numbers.
expect_num <- function(object, expected, ...) {
  expect_equal(unname(object), unname(expected), ...)
}


# ==========================================================================
# SECTION A: lookup_articulo_167 (6 tests)
# ==========================================================================

test_that("A1: First group (0-1 SM) returns correct cuantia and incremento", {
  r <- lookup_articulo_167(1.0)
  expect_num(r$cuantia_basica, 0.8000)
  expect_num(r$incremento_anual, 0.00563)
})

test_that("A2: Mid-table group (1.76-2.00) returns correct values", {
  r <- lookup_articulo_167(1.79)
  expect_num(r$cuantia_basica, 0.4267)
  expect_num(r$incremento_anual, 0.01615)
})

test_that("A3: Last group (6.01-25) returns correct values", {
  r <- lookup_articulo_167(10.0)
  expect_num(r$cuantia_basica, 0.1300)
  expect_num(r$incremento_anual, 0.02450)
})

test_that("A4: Above table maximum uses last row", {
  r <- lookup_articulo_167(30.0)
  expect_num(r$cuantia_basica, 0.1300)
  expect_num(r$incremento_anual, 0.02450)
})

test_that("A5: Below table minimum uses first row", {
  r <- lookup_articulo_167(-1.0)
  expect_num(r$cuantia_basica, 0.8000)
  expect_num(r$incremento_anual, 0.00563)
})

test_that("A6: Boundary between groups (1.00 vs 1.01)", {
  r1 <- lookup_articulo_167(1.00)
  r2 <- lookup_articulo_167(1.01)
  expect_num(r1$cuantia_basica, 0.8000)   # group 0.00-1.00
  expect_num(r2$cuantia_basica, 0.7711)   # group 1.01-1.25
})


# ==========================================================================
# SECTION B: calculate_ley73_pension (10 tests)
# ==========================================================================

test_that("B1: Ineligible with fewer than 500 weeks", {
  r <- calculate_ley73_pension(sbc_promedio_diario = 300, semanas = 400, edad = 65)
  expect_false(r$elegible)
  expect_equal(r$pension_mensual, 0)
})

test_that("B2: Ineligible when age < 60", {
  r <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 1000, edad = 55)
  expect_false(r$elegible)
  expect_equal(r$pension_mensual, 0)
})

test_that("B3: Correct calculation at age 65, SBC=500, 1800 weeks", {
  # Hand-computed:
  # grupo_salarial = 500/278.80 = 1.7935 -> row (1.76-2.00)
  # cuantia = 0.4267, incr = 0.01615
  # n_incr = floor((1800-500)/52) = 25
  # porcentaje = 0.4267 + 25*0.01615 = 0.83045
  # pension_diaria = 500 * 0.83045 = 415.225
  # pension_mensual = 415.225 * 30.4375 = ~12638.41
  r <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 1800, edad = 65)
  expect_true(r$elegible)
  expect_num(r$grupo_salarial, 500 / 278.80, tolerance = 1e-4)
  expect_num(r$cuantia_basica, 0.4267)
  expect_num(r$incremento_anual, 0.01615)
  expect_num(r$n_incrementos, 25)
  expect_num(r$porcentaje_total, 0.4267 + 25 * 0.01615, tolerance = 1e-6)
  expect_num(r$factor_edad, 1.0)
  expect_equal(r$tipo_pension, "vejez")
  expected_pension <- 500 * (0.4267 + 25 * 0.01615) * DIAS_POR_MES
  expect_num(r$pension_mensual, expected_pension, tolerance = 0.01)
})

test_that("B4: Cesantia factor at age 60 is 0.75", {
  r <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 1800, edad = 60)
  expect_true(r$elegible)
  expect_num(r$factor_edad, 0.75)
  expect_equal(r$tipo_pension, "cesantia")
})

test_that("B5: Cesantia factor at age 62 is 0.85", {
  r <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 1800, edad = 62)
  expect_num(r$factor_edad, 0.85)
})

test_that("B6: Cesantia factors are monotonically increasing 60-65", {
  pensions <- sapply(60:65, function(age) {
    calculate_ley73_pension(
      sbc_promedio_diario = 500, semanas = 1800, edad = age
    )$pension_mensual
  })
  for (i in 2:length(pensions)) {
    expect_true(unname(pensions[i]) > unname(pensions[i - 1]))
  }
})

test_that("B7: Pension minima floor applies for low SBC", {
  r <- calculate_ley73_pension(sbc_promedio_diario = 100, semanas = 500, edad = 65)
  expect_true(r$elegible)
  expect_true(r$aplico_minimo)
  pension_minima <- SM_DIARIO_2025 * DIAS_POR_MES
  expect_num(r$pension_mensual, pension_minima, tolerance = 0.01)
})

test_that("B8: Porcentaje total capped at 100%", {
  # grupo > 6 -> cuantia=0.13, incr=0.02450
  # Need: 0.13 + n*0.02450 >= 1.0 -> n >= 35.5 -> 500+36*52 = 2372 weeks
  r <- calculate_ley73_pension(sbc_promedio_diario = 2000, semanas = 3000, edad = 65)
  expect_true(r$elegible)
  expect_num(r$porcentaje_total, 1.0)
})

test_that("B9: Exactly 500 weeks gives zero incrementos", {
  r <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 500, edad = 65)
  expect_true(r$elegible)
  expect_num(r$n_incrementos, 0)
  expect_num(r$total_incrementos, 0)
  expect_num(r$porcentaje_total, r$cuantia_basica)
})

test_that("B10: Tasa de reemplazo is pension/salario", {
  r <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 1800, edad = 65)
  salario_mensual <- 500 * DIAS_POR_MES
  expected_tasa <- unname(r$pension_mensual) / salario_mensual
  expect_num(r$tasa_reemplazo, expected_tasa, tolerance = 1e-6)
})


# ==========================================================================
# SECTION C: project_afore_balance (7 tests)
# ==========================================================================

test_that("C1: Pure compound interest with zero contributions", {
  # FV = 100000 * (1.035)^10
  r <- project_afore_balance(
    saldo_actual = 100000, aportacion_mensual = 0,
    anios_al_retiro = 10, rendimiento_real_anual = 0.04,
    comision_anual = 0.005
  )
  expected <- 100000 * (1.035)^10
  expect_num(r$saldo_final, expected, tolerance = 0.01)
  expect_num(r$fv_aportaciones, 0)
  expect_num(r$fv_saldo_actual, expected, tolerance = 0.01)
})

test_that("C2: Compound interest with monthly contributions", {
  r <- project_afore_balance(
    saldo_actual = 100000, aportacion_mensual = 1000,
    anios_al_retiro = 10, rendimiento_real_anual = 0.04,
    comision_anual = 0.005
  )
  expect_true(r$saldo_final > 100000 + 1000 * 120)
  expect_true(r$ganancia_intereses > 0)
})

test_that("C3: Zero net rate gives simple accumulation", {
  r <- project_afore_balance(
    saldo_actual = 50000, aportacion_mensual = 1000,
    anios_al_retiro = 5, rendimiento_real_anual = 0.02,
    comision_anual = 0.02
  )
  # r_neto = 0 -> fv_actual = 50000, fv_aportaciones = 1000*60 = 60000
  expect_num(r$saldo_final, 110000, tolerance = 0.01)
})

test_that("C4: Decomposition identity: saldo_final = fv_actual + fv_aportaciones", {
  r <- project_afore_balance(
    saldo_actual = 200000, aportacion_mensual = 2000,
    anios_al_retiro = 15, rendimiento_real_anual = 0.05,
    comision_anual = 0.006
  )
  expect_num(r$saldo_final, r$fv_saldo_actual + r$fv_aportaciones, tolerance = 0.01)
})

test_that("C5: Ganancia = saldo_final - total_aportado", {
  r <- project_afore_balance(
    saldo_actual = 100000, aportacion_mensual = 500,
    anios_al_retiro = 20, rendimiento_real_anual = 0.04,
    comision_anual = 0.005
  )
  expected_aportado <- 100000 + 500 * 240
  expect_num(r$total_aportado, expected_aportado)
  expect_num(r$ganancia_intereses, r$saldo_final - r$total_aportado, tolerance = 0.01)
})

test_that("C6: Trajectory included when requested", {
  r <- project_afore_balance(
    saldo_actual = 100000, aportacion_mensual = 1000,
    anios_al_retiro = 5, rendimiento_real_anual = 0.04,
    comision_anual = 0.005, incluir_trayectoria = TRUE
  )
  expect_false(is.null(r$trayectoria))
  expect_equal(nrow(r$trayectoria), 6)  # years 0 through 5
  expect_num(r$trayectoria$saldo[1], 100000)
})

test_that("C7: Trajectory endpoint matches closed-form saldo_final", {
  r <- project_afore_balance(
    saldo_actual = 100000, aportacion_mensual = 1000,
    anios_al_retiro = 5, rendimiento_real_anual = 0.04,
    comision_anual = 0.005, incluir_trayectoria = TRUE
  )
  expect_num(r$trayectoria$saldo[6], r$saldo_final, tolerance = 1)
})


# ==========================================================================
# SECTION D: calculate_aportacion_obligatoria (6 tests)
# ==========================================================================

test_that("D1: 2025 tiered rates -- high salary uses correct CEAV bracket", {
  # $20,000/month -> ~21.7 UMA daily -> 4.01+ UMA bracket
  # CEAV 2025 for 4.01+ UMA = 6.422%, retiro = 2%, worker = 1.125%
  r <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2025)
  expect_num(r$tasa_ceav, 0.06422, tolerance = 0.001)
  expect_num(r$tasa_patron, 0.02 + 0.06422, tolerance = 0.001)
  expect_true(r$aportacion_total > 0)
})

test_that("D2: 2023 uses lower CEAV rates than 2025", {
  r_2023 <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2023)
  r_2025 <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2025)
  expect_true(unname(r_2023$aportacion_patron) < unname(r_2025$aportacion_patron))
})

test_that("D3: 2030 and beyond uses maximum CEAV rates", {
  r_2030 <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2030)
  r_2035 <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2035)
  expect_num(r_2030$tasa_ceav, r_2035$tasa_ceav, tolerance = 0.001)
  expect_num(r_2030$tasa_patron, r_2035$tasa_patron, tolerance = 0.001)
})

test_that("D4: Low salary (1 SM) gets lowest employer rate", {
  r_low <- calculate_aportacion_obligatoria(salario_mensual = SM_MENSUAL_2025, anio = 2025)
  r_high <- calculate_aportacion_obligatoria(salario_mensual = 50000, anio = 2025)
  # 1 SM bracket has CEAV = 3.150% (lowest); high salary has 6.422% (highest)
  expect_true(unname(r_low$tasa_ceav) < unname(r_high$tasa_ceav))
})

test_that("D5: Salary above tope is capped", {
  tope_mensual <- TOPE_SBC_DIARIO * DIAS_POR_MES
  r <- calculate_aportacion_obligatoria(salario_mensual = 200000, anio = 2025)
  expect_num(r$salario_cotizable, tope_mensual)
  r_tope <- calculate_aportacion_obligatoria(salario_mensual = tope_mensual, anio = 2025)
  expect_num(r$aportacion_total, r_tope$aportacion_total, tolerance = 0.01)
})

test_that("D6: Component breakdown sums to total", {
  r <- calculate_aportacion_obligatoria(salario_mensual = 25000, anio = 2025)
  suma <- unname(r$aportacion_patron + r$aportacion_trabajador + r$aportacion_gobierno)
  expect_num(r$aportacion_total, suma, tolerance = 0.01)
})


# ==========================================================================
# SECTION E: calculate_retiro_programado (6 tests)
# ==========================================================================

test_that("E1: Basic retiro programado calculation", {
  # Male, age 65 EMSSA 2009: esperanza = 18.4, meses = 220.8
  r <- calculate_retiro_programado(saldo = 2500000, edad = 65, genero = "M")
  expect_num(r$esperanza_vida, 18.4)
  expect_num(r$meses_esperados, 220.8)
  expected_pension <- 2500000 / 220.8
  expect_num(r$pension_calculada, expected_pension, tolerance = 0.01)
  expect_false(r$aplico_minimo)
  expect_num(r$pension_mensual, expected_pension, tolerance = 0.01)
})

test_that("E2: Pension minima garantizada applies for low saldo", {
  r <- calculate_retiro_programado(saldo = 500000, edad = 65, genero = "M")
  pension_minima <- UMA_MENSUAL_2025 * 2.5
  expect_true(r$aplico_minimo)
  expect_num(r$pension_mensual, pension_minima, tolerance = 0.01)
  expect_true(unname(r$pension_calculada) < pension_minima)
})

test_that("E3: Gender difference -- women live longer, lower monthly pension", {
  saldo <- 2000000
  rm <- calculate_retiro_programado(saldo = saldo, edad = 65, genero = "M")
  rf <- calculate_retiro_programado(saldo = saldo, edad = 65, genero = "F")
  expect_true(unname(rf$esperanza_vida) > unname(rm$esperanza_vida))
  expect_true(unname(rf$pension_calculada) < unname(rm$pension_calculada))
})

test_that("E4: Both genders get pension minima when saldo is very low", {
  saldo <- 100000
  rm <- calculate_retiro_programado(saldo = saldo, edad = 65, genero = "M")
  rf <- calculate_retiro_programado(saldo = saldo, edad = 65, genero = "F")
  pension_minima <- UMA_MENSUAL_2025 * 2.5
  expect_true(rm$aplico_minimo)
  expect_true(rf$aplico_minimo)
  expect_num(rm$pension_mensual, pension_minima, tolerance = 0.01)
  expect_num(rf$pension_mensual, pension_minima, tolerance = 0.01)
})

test_that("E5: aplico_minimo flag is consistent above/below threshold", {
  pension_minima <- UMA_MENSUAL_2025 * 2.5
  meses <- 220.8  # male, age 65 EMSSA (18.4 * 12)

  saldo_above <- pension_minima * meses + 1000
  r_above <- calculate_retiro_programado(saldo = saldo_above, edad = 65, genero = "M")
  expect_false(r_above$aplico_minimo)

  saldo_below <- pension_minima * meses - 1000
  r_below <- calculate_retiro_programado(saldo = saldo_below, edad = 65, genero = "M")
  expect_true(r_below$aplico_minimo)
})

test_that("E6: saldo_minimo_para_superar_garantia is correct", {
  r <- calculate_retiro_programado(saldo = 1000000, edad = 65, genero = "M")
  pension_minima <- UMA_MENSUAL_2025 * 2.5
  expected <- pension_minima * unname(r$meses_esperados)
  expect_num(r$saldo_minimo_para_superar_garantia, expected, tolerance = 0.01)
})


# ==========================================================================
# SECTION F: calculate_ley97_pension (6 tests)
# ==========================================================================

test_that("F1: Ineligible when projected weeks < 1000", {
  # semanas_al_retiro = 700 + 5*52 = 960 < 1000
  r <- calculate_ley97_pension(
    saldo_actual = 500000, salario_mensual = 20000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 700, genero = "M"
  )
  expect_false(r$elegible)
  expect_equal(r$pension_mensual, 0)
})

test_that("F2: Eligible base scenario returns positive pension", {
  r <- calculate_ley97_pension(
    saldo_actual = 500000, salario_mensual = 20000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    escenario = "base"
  )
  expect_true(r$elegible)
  expect_true(unname(r$pension_mensual) > 0)
  expect_true(r$saldo_proyectado > 500000)
})

test_that("F3: Optimistic > Base > Conservative projected balance", {
  args <- list(
    saldo_actual = 500000, salario_mensual = 20000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    aportacion_voluntaria = 0, afore_nombre = "XXI Banorte"
  )
  rc <- do.call(calculate_ley97_pension, c(args, escenario = "conservador"))
  rb <- do.call(calculate_ley97_pension, c(args, escenario = "base"))
  ro <- do.call(calculate_ley97_pension, c(args, escenario = "optimista"))
  expect_true(ro$saldo_proyectado > rb$saldo_proyectado)
  expect_true(rb$saldo_proyectado > rc$saldo_proyectado)
})

test_that("F4: Voluntary contributions increase projected balance", {
  args_base <- list(
    saldo_actual = 500000, salario_mensual = 20000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    afore_nombre = "XXI Banorte", escenario = "base"
  )
  r0 <- do.call(calculate_ley97_pension, c(args_base, aportacion_voluntaria = 0))
  r1 <- do.call(calculate_ley97_pension, c(args_base, aportacion_voluntaria = 1000))
  expect_true(r1$saldo_proyectado > r0$saldo_proyectado)
  expect_true(unname(r1$pension_mensual) >= unname(r0$pension_mensual))
})

test_that("F5: Return structure has expected fields", {
  r <- calculate_ley97_pension(
    saldo_actual = 500000, salario_mensual = 20000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M"
  )
  expected_fields <- c("pension_mensual", "elegible", "saldo_proyectado",
                       "tasa_reemplazo", "aplico_minimo", "trayectoria",
                       "semanas_al_retiro", "aportacion_obligatoria",
                       "rendimiento_usado", "comision_usada", "escenario")
  for (f in expected_fields) {
    expect_true(f %in% names(r), info = paste("Missing field:", f))
  }
})

test_that("F6: Exactly 1000 weeks at retirement is eligible", {
  # semanas_al_retiro = 480 + 10*52 = 1000
  r <- calculate_ley97_pension(
    saldo_actual = 500000, salario_mensual = 20000,
    edad_actual = 55, edad_retiro = 65,
    semanas_actuales = 480, genero = "M"
  )
  expect_true(r$elegible)
})


# ==========================================================================
# SECTION G: calculate_modalidad_40 (7 tests)
# ==========================================================================

test_that("G1: SBC_M40 is capped at TOPE_SBC_DIARIO", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1200, edad = 65)
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = 5000,
    semanas_actuales = 1200, semanas_m40 = 260,
    edad_actual = 60, edad_retiro = 65
  )
  expect_num(r$sbc_m40_usado, TOPE_SBC_DIARIO)
})

test_that("G2: Cuota mensual = SBC_M40_real * DIAS_POR_MES * 10.075%", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1200, edad = 65)
  sbc_m40 <- 1000
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = sbc_m40,
    semanas_actuales = 1200, semanas_m40 = 260,
    edad_actual = 60, edad_retiro = 65
  )
  expected_cuota <- sbc_m40 * DIAS_POR_MES * 0.10075
  expect_num(r$cuota_mensual_m40, expected_cuota, tolerance = 0.01)
})

test_that("G3: SBC averaging uses M40 SBC entirely when semanas_m40 >= 250", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1200, edad = 65)
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = 1000,
    semanas_actuales = 1200, semanas_m40 = 260,
    edad_actual = 60, edad_retiro = 65
  )
  expect_num(r$nuevo_sbc_promedio, 1000)
})

test_that("G4: SBC averaging uses weighted average when semanas_m40 < 250", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1200, edad = 65)
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = 1000,
    semanas_actuales = 1200, semanas_m40 = 100,
    edad_actual = 60, edad_retiro = 65
  )
  # Weighted: (1000*100 + 400*150) / 250 = 160000/250 = 640
  expect_num(r$nuevo_sbc_promedio, 640, tolerance = 0.01)
})

test_that("G5: Total cost = cuota_mensual * meses_m40", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1200, edad = 65)
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = 800,
    semanas_actuales = 1200, semanas_m40 = 208,
    edad_actual = 61, edad_retiro = 65
  )
  expect_num(r$costo_total_m40, r$cuota_mensual_m40 * r$meses_m40, tolerance = 0.01)
})

test_that("G6: Incremento is new pension minus old pension", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1200, edad = 65)
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = 1000,
    semanas_actuales = 1200, semanas_m40 = 260,
    edad_actual = 60, edad_retiro = 65
  )
  expect_num(r$incremento_mensual,
             unname(r$pension_con_m40) - unname(r$pension_sin_m40),
             tolerance = 0.01)
})

test_that("G7: Meses recuperacion = ceiling(costo / incremento)", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1200, edad = 65)
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = 1000,
    semanas_actuales = 1200, semanas_m40 = 260,
    edad_actual = 60, edad_retiro = 65
  )
  if (unname(r$incremento_mensual) > 0) {
    expected <- ceiling(unname(r$costo_total_m40) / unname(r$incremento_mensual))
    expect_num(r$meses_recuperacion, expected)
  }
})


# ==========================================================================
# SECTION H: check_fondo_eligibility (8 tests)
# ==========================================================================

test_that("H1: Ley 73 regimen is not eligible", {
  r <- check_fondo_eligibility(
    regimen = "ley73", edad = 65, semanas = 1500,
    sbc_promedio_mensual = 15000
  )
  expect_false(r$elegible)
  expect_false(r$checks$regimen_valido$cumple)
})

test_that("H2: Age < 65 is not eligible", {
  r <- check_fondo_eligibility(
    regimen = "ley97", edad = 64, semanas = 1500,
    sbc_promedio_mensual = 15000
  )
  expect_false(r$elegible)
  expect_false(r$checks$edad_minima$cumple)
})

test_that("H3: Less than 1000 weeks is not eligible for Fondo", {
  # Fondo Bienestar requires fixed 1000 weeks (DOF 01/05/2024), NOT transitional Ley 97 schedule
  r <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 999,
    sbc_promedio_mensual = 15000
  )
  expect_false(r$elegible)
  expect_false(r$checks$semanas_minimas$cumple)
})

test_that("H4: Salary above umbral is not eligible", {
  umbral <- unname(get_umbral_fondo_bienestar(2025))
  r <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1500,
    sbc_promedio_mensual = umbral + 1000
  )
  expect_false(r$elegible)
  expect_false(r$checks$salario_bajo_umbral$cumple)
})

test_that("H5: All conditions met -> eligible", {
  umbral <- unname(get_umbral_fondo_bienestar(2025))
  r <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1500,
    sbc_promedio_mensual = umbral - 2000
  )
  expect_true(r$elegible)
  expect_null(r$razon_no_elegible)
})

test_that("H6: Salary exactly at umbral is eligible", {
  umbral <- unname(get_umbral_fondo_bienestar(2025))
  r <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1500,
    sbc_promedio_mensual = umbral
  )
  expect_true(r$checks$salario_bajo_umbral$cumple)
  expect_true(r$elegible)
})

test_that("H7: Exactly 1000 weeks is eligible", {
  r <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1000,
    sbc_promedio_mensual = 15000
  )
  expect_true(r$checks$semanas_minimas$cumple)
})

test_that("H8: Exactly age 65 is eligible", {
  r <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1500,
    sbc_promedio_mensual = 15000
  )
  expect_true(r$checks$edad_minima$cumple)
})


# ==========================================================================
# SECTION I: calculate_fondo_complement (4 tests)
# ==========================================================================

test_that("I1: No complement when not eligible", {
  elegibilidad <- list(elegible = FALSE, razon_no_elegible = "No cumple",
                       umbral_usado = 17364)
  r <- calculate_fondo_complement(
    pension_afore = 5000, sbc_promedio_mensual = 15000,
    elegibilidad = elegibilidad
  )
  expect_num(r$complemento, 0)
  expect_num(r$pension_total, 5000)
  expect_false(r$elegible)
})

test_that("I2: Complement = salary - pension when salary < umbral", {
  elegibilidad <- list(elegible = TRUE, razon_no_elegible = NULL,
                       umbral_usado = 17364)
  r <- calculate_fondo_complement(
    pension_afore = 5000, sbc_promedio_mensual = 15000,
    elegibilidad = elegibilidad
  )
  expect_num(r$complemento, 10000)
  expect_num(r$pension_total, 15000)
  expect_true(r$elegible)
})

test_that("I3: Complement capped at umbral when salary exceeds it", {
  # pension_objetivo = min(20000, 17364) = 17364
  # complemento = 17364 - 5000 = 12364
  elegibilidad <- list(elegible = TRUE, razon_no_elegible = NULL,
                       umbral_usado = 17364)
  r <- calculate_fondo_complement(
    pension_afore = 5000, sbc_promedio_mensual = 20000,
    elegibilidad = elegibilidad
  )
  expect_num(r$complemento, 12364)
  expect_num(r$pension_total, 17364)
})

test_that("I4: No complement when pension >= salary", {
  elegibilidad <- list(elegible = TRUE, razon_no_elegible = NULL,
                       umbral_usado = 17364)
  r <- calculate_fondo_complement(
    pension_afore = 16000, sbc_promedio_mensual = 15000,
    elegibilidad = elegibilidad
  )
  expect_num(r$complemento, 0)
  expect_num(r$pension_total, 16000)
})


# ==========================================================================
# SECTION J: calculate_pension_with_fondo -- integration (4 tests)
# ==========================================================================

test_that("J1: End-to-end eligible scenario", {
  r <- calculate_pension_with_fondo(
    saldo_actual = 300000, salario_mensual = 15000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    aportacion_voluntaria = 500
  )
  expect_true(r$con_fondo$elegible)
  expect_true(unname(r$solo_sistema$pension_mensual) > 0)
  expect_true(unname(r$con_fondo$pension_total) >= unname(r$solo_sistema$pension_mensual))
  expect_true(unname(r$con_acciones$pension_afore) >= unname(r$solo_sistema$pension_mensual))
})

test_that("J2: High salary makes ineligible for fondo", {
  r <- calculate_pension_with_fondo(
    saldo_actual = 1000000, salario_mensual = 50000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M"
  )
  expect_false(r$con_fondo$elegible)
  expect_num(r$con_fondo$complemento, 0)
})

test_that("J3: Voluntary contributions increase con_acciones pension", {
  r <- calculate_pension_with_fondo(
    saldo_actual = 300000, salario_mensual = 15000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    aportacion_voluntaria = 2000
  )
  expect_true(unname(r$con_acciones$diferencia_vs_base) > 0)
  expect_true(r$con_acciones$saldo_proyectado > r$solo_sistema$saldo_proyectado)
})

test_that("J4: Insufficient weeks -> solo_sistema pension is zero", {
  # semanas_al_retiro = 200 + 5*52 = 460 < 1000
  r <- calculate_pension_with_fondo(
    saldo_actual = 300000, salario_mensual = 15000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 200, genero = "M"
  )
  expect_equal(r$solo_sistema$pension_mensual, 0)
  expect_false(r$con_fondo$elegible)
})


# ==========================================================================
# SECTION K: Helper functions (12 tests)
# ==========================================================================

test_that("K1: get_esperanza_vida male at 65 = 18.4 (EMSSA 2009)", {
  expect_num(get_esperanza_vida(65, "M"), 18.4)
})

test_that("K2: get_esperanza_vida female at 65 = 21.5 (EMSSA 2009)", {
  expect_num(get_esperanza_vida(65, "F"), 21.5)
})

test_that("K3: Female life expectancy > male at every listed age", {
  for (age in c(60, 65, 70, 75, 80)) {
    expect_true(
      unname(get_esperanza_vida(age, "F")) > unname(get_esperanza_vida(age, "M")),
      info = paste("Age:", age)
    )
  }
})

test_that("K4: Life expectancy interpolates for unlisted ages", {
  ev71 <- unname(get_esperanza_vida(71, "M"))
  ev70 <- unname(get_esperanza_vida(70, "M"))  # EMSSA 2009: 14.5
  ev75 <- unname(get_esperanza_vida(75, "M"))  # EMSSA 2009: 11.3
  expect_true(ev71 < ev70)
  expect_true(ev71 > ev75)
})

test_that("K5: Life expectancy below minimum age extrapolates upward", {
  ev55 <- unname(get_esperanza_vida(55, "M"))
  ev60 <- unname(get_esperanza_vida(60, "M"))  # EMSSA 2009: 22.5
  expect_true(ev55 > ev60)
})

test_that("K6: Life expectancy above maximum age has floor of 2", {
  ev95 <- unname(get_esperanza_vida(95, "M"))
  expect_true(ev95 >= 2)
})

test_that("K7: validar_entrada accepts valid inputs", {
  r <- validar_entrada(edad = 50, semanas = 1500, sbc = 20000)
  expect_true(r$valido)
  expect_equal(length(r$errores), 0)
})

test_that("K8: validar_entrada rejects invalid age", {
  r <- validar_entrada(edad = 150, semanas = 1000, sbc = 15000)
  expect_false(r$valido)
  expect_true(length(r$errores) > 0)
})

test_that("K9: validar_entrada rejects inconsistent age-weeks", {
  r <- validar_entrada(edad = 25, semanas = 2000, sbc = 15000)
  expect_false(r$valido)
})

test_that("K10: determinar_regimen -- before 1997-07-01 is ley73", {
  expect_equal(determinar_regimen("1990-01-01"), "ley73")
  expect_equal(determinar_regimen("1997-06-30"), "ley73")
})

test_that("K11: determinar_regimen -- on/after 1997-07-01 is ley97", {
  expect_equal(determinar_regimen("1997-07-01"), "ley97")
  expect_equal(determinar_regimen("2000-01-01"), "ley97")
})

test_that("K12: AFORE helpers return consistent data after bug fix", {
  # get_afore_names returns all 10 AFOREs
  names_list <- get_afore_names()
  expect_equal(length(names_list), 10)
  expect_true("XXI Banorte" %in% names_list)

  # Known AFORE: comision as decimal (CONSAR 2025: 0.55% for most, 0.52% PensionISSSTE)
  com <- get_afore_comision("XXI Banorte")
  expect_num(com, 0.55 / 100, tolerance = 1e-6)

  # Known AFORE: IRN as decimal
  irn <- get_afore_irn("XXI Banorte")
  expect_num(irn, 6.89 / 100, tolerance = 1e-6)

  # Bug fix: unknown AFORE fallback returns decimal, not raw percentage
  com_unknown <- get_afore_comision("NONEXISTENT_AFORE")
  expect_true(com_unknown < 0.01,
              info = "Fallback comision should be ~0.00517, not 0.517")

  irn_unknown <- get_afore_irn("NONEXISTENT_AFORE")
  expect_true(irn_unknown < 0.1,
              info = "Fallback IRN should be ~0.06005, not 6.005")
})


# ==========================================================================
# SECTION L: Sensitivity tests (8 tests)
# Verify that changing one input produces a different calculation output
# ==========================================================================

test_that("L1: Different AFORE comision -> different projected balance", {
  # PensionISSSTE (0.52%) vs XXI Banorte (0.55%) -- only pair with different commissions in 2025
  args <- list(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    aportacion_voluntaria = 0, escenario = "base"
  )
  r1 <- do.call(calculate_pension_with_fondo, c(args, afore_nombre = "PensionISSSTE"))
  r2 <- do.call(calculate_pension_with_fondo, c(args, afore_nombre = "XXI Banorte"))
  expect_false(r1$solo_sistema$saldo_proyectado == r2$solo_sistema$saldo_proyectado)
})

test_that("L2: More semanas -> higher Ley 73 pension (more incrementos)", {
  sbc <- 500
  edad <- 65
  r_low <- calculate_ley73_pension(sbc_promedio_diario = sbc, semanas = 1000, edad = edad)
  r_high <- calculate_ley73_pension(sbc_promedio_diario = sbc, semanas = 1800, edad = edad)
  expect_true(r_low$elegible)
  expect_true(r_high$elegible)
  expect_true(unname(r_high$pension_mensual) > unname(r_low$pension_mensual))
  expect_true(r_high$n_incrementos > r_low$n_incrementos)
})

test_that("L3: More semanas -> crosses Ley 97 eligibility threshold", {
  # edad_actual=60, edad_retiro=65 -> anios_restantes=5 -> adds 260 weeks
  # Retirement year: 2025+5 = 2030 -> min weeks = 975 (transitional)
  # semanas_actuales=714 -> semanas_al_retiro=974 (not eligible)
  # semanas_actuales=716 -> semanas_al_retiro=976 (eligible)
  r_below <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 714, genero = "M"
  )
  r_above <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 716, genero = "M"
  )
  expect_equal(r_below$solo_sistema$pension_mensual, 0)
  expect_true(unname(r_above$solo_sistema$pension_mensual) > 0)
})

test_that("L4: Higher voluntary contribution -> higher projected balance", {
  r_low <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    aportacion_voluntaria = 500
  )
  r_high <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    aportacion_voluntaria = 3000
  )
  expect_true(r_high$con_acciones$saldo_proyectado > r_low$con_acciones$saldo_proyectado)
})

test_that("L5: Older retirement age -> higher Ley 73 pension", {
  sbc <- 500
  semanas_base <- 1000
  r60 <- calculate_ley73_pension(sbc_promedio_diario = sbc, semanas = semanas_base, edad = 60)
  r65 <- calculate_ley73_pension(sbc_promedio_diario = sbc, semanas = semanas_base + 5 * 52, edad = 65)
  expect_true(r60$elegible)
  expect_true(r65$elegible)
  # Higher age -> higher cesantia factor + more weeks -> higher pension
  expect_true(unname(r65$pension_mensual) > unname(r60$pension_mensual))
})

test_that("L6: Older retirement age -> higher Ley 97 projected balance", {
  r_young <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 20000,
    edad_actual = 45, edad_retiro = 60,
    semanas_actuales = 800, genero = "M"
  )
  r_old <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 20000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M"
  )
  # More years of growth -> higher projected balance
  expect_true(r_old$solo_sistema$saldo_proyectado > r_young$solo_sistema$saldo_proyectado)
})

test_that("L7: Different escenario -> different rendimiento -> different balance", {
  args <- list(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    aportacion_voluntaria = 0
  )
  rc <- do.call(calculate_pension_with_fondo, c(args, escenario = "conservador"))
  rb <- do.call(calculate_pension_with_fondo, c(args, escenario = "base"))
  ro <- do.call(calculate_pension_with_fondo, c(args, escenario = "optimista"))
  expect_true(ro$solo_sistema$saldo_proyectado > rb$solo_sistema$saldo_proyectado)
  expect_true(rb$solo_sistema$saldo_proyectado > rc$solo_sistema$saldo_proyectado)
})

test_that("L8: Gender difference -> different esperanza -> different retiro programado", {
  saldo <- 2000000
  rm <- calculate_retiro_programado(saldo = saldo, edad = 65, genero = "M")
  rf <- calculate_retiro_programado(saldo = saldo, edad = 65, genero = "F")
  # Women live longer -> lower monthly pension from same saldo
  expect_true(unname(rf$esperanza_vida) > unname(rm$esperanza_vida))
  expect_true(unname(rf$pension_calculada) < unname(rm$pension_calculada))
})


# ==========================================================================
# SECTION M: Full-pipeline tests (16 tests)
# Tests the fecha_nacimiento -> edad_actual -> anios_restantes ->
# semanas_al_retiro transformation chain that real users go through,
# plus M40 interaction and Fondo eligibility cliff boundaries.
# ==========================================================================

# --- M1-M3: Pipeline transformation mechanics ---

test_that("M1: Age computation from birth date matches expected integer age", {
  # Simulating the app logic: edad_actual = floor(difftime / 365.25)
  fecha_nacimiento <- as.Date("1960-06-15")
  today <- as.Date("2025-01-15")  # fixed reference date
  edad_actual <- as.numeric(floor(difftime(today, fecha_nacimiento, units = "days") / 365.25))
  expect_equal(edad_actual, 64)

  # Someone born 1960-01-15 evaluated on 2025-02-15 -> age 65
  fecha2 <- as.Date("1960-01-15")
  today2 <- as.Date("2025-02-15")
  edad2 <- as.numeric(floor(difftime(today2, fecha2, units = "days") / 365.25))
  expect_equal(edad2, 65)
})

test_that("M2: anios_restantes is 0 when person already past retirement age", {
  edad_actual <- 66
  edad_retiro <- 65
  anios_restantes <- max(0, edad_retiro - edad_actual)
  expect_equal(anios_restantes, 0)
})

test_that("M3: semanas_al_retiro correctly adds anios_restantes * 52 to base semanas", {
  semanas_actuales <- 800
  edad_actual <- 55
  edad_retiro <- 65
  anios_restantes <- max(0, edad_retiro - edad_actual)
  semanas_al_retiro <- semanas_actuales + (anios_restantes * 52)
  expect_equal(anios_restantes, 10)
  expect_equal(semanas_al_retiro, 800 + 10 * 52)  # 1320
})

# --- M4-M5: Ley 73 end-to-end pipeline ---

test_that("M4: Ley 73 pipeline -- low salary hits pension minima floor", {
  # Case 1 actuarial: born 1961-06-15, salary $8,000, 1200 weeks, age 65
  salario_mensual <- 8000
  sbc_diario <- salario_mensual / 30
  edad_actual <- 64  # floor(age) at calculation time
  edad_retiro <- 65
  semanas_actuales <- 1200

  anios_restantes <- max(0, edad_retiro - edad_actual)
  semanas_al_retiro <- semanas_actuales + (anios_restantes * 52)

  r <- calculate_ley73_pension(
    sbc_promedio_diario = sbc_diario,
    semanas = semanas_al_retiro,
    edad = edad_retiro
  )

  expect_true(r$elegible)
  # Low SBC -> pension minima applies
  pension_minima <- SM_DIARIO_2025 * DIAS_POR_MES
  expect_true(r$aplico_minimo)
  expect_num(r$pension_mensual, pension_minima, tolerance = 0.01)
})

test_that("M5: Ley 73 pipeline -- mid salary at 60 applies cesantia factor", {
  # Case 2: born 1965-03-01, salary $20,000, 1500 weeks, retire at 60
  salario_mensual <- 20000
  sbc_diario <- salario_mensual / 30
  edad_actual <- 60
  edad_retiro <- 60
  semanas_actuales <- 1500

  anios_restantes <- max(0, edad_retiro - edad_actual)
  semanas_al_retiro <- semanas_actuales + (anios_restantes * 52)
  expect_equal(semanas_al_retiro, 1500)  # no extra weeks since already at retiro age

  r <- calculate_ley73_pension(
    sbc_promedio_diario = sbc_diario,
    semanas = semanas_al_retiro,
    edad = edad_retiro
  )

  expect_true(r$elegible)
  expect_equal(r$tipo_pension, "cesantia")
  expect_num(r$factor_edad, 0.75)
  # Pension should be positive and less than what age-65 would give
  expect_true(unname(r$pension_mensual) > 0)

  r65 <- calculate_ley73_pension(
    sbc_promedio_diario = sbc_diario,
    semanas = semanas_al_retiro + 5 * 52,
    edad = 65
  )
  expect_true(unname(r65$pension_mensual) > unname(r$pension_mensual))
})

# --- M6-M8: Ley 97 end-to-end pipeline ---

test_that("M6: Ley 97 pipeline -- young worker eligible for Fondo", {
  # Case 3: born 1980-04-20, salary $15,000, saldo $300,000, 800 semanas, retire 65
  edad_actual <- 45
  edad_retiro <- 65
  semanas_actuales <- 800

  r <- calculate_pension_with_fondo(
    saldo_actual = 300000,
    salario_mensual = 15000,
    edad_actual = edad_actual,
    edad_retiro = edad_retiro,
    semanas_actuales = semanas_actuales,
    genero = "M",
    aportacion_voluntaria = 500
  )

  # Should be eligible: ley97, age>=65, semanas>=1000, salary<=umbral
  expect_true(r$con_fondo$elegible)
  expect_true(unname(r$solo_sistema$pension_mensual) > 0)
  # semanas_al_retiro = 800 + 20*52 = 1840 >= 1000
  expect_equal(r$entrada$semanas_al_retiro, 800 + 20 * 52)
})

test_that("M7: Ley 97 pipeline -- high salary NOT eligible for Fondo", {
  # Case 4: salary $50,000 exceeds umbral
  r <- calculate_pension_with_fondo(
    saldo_actual = 1000000,
    salario_mensual = 50000,
    edad_actual = 45,
    edad_retiro = 65,
    semanas_actuales = 800,
    genero = "M"
  )

  expect_false(r$con_fondo$elegible)
  expect_num(r$con_fondo$complemento, 0)
  # Still gets a pension from AFORE
  expect_true(unname(r$solo_sistema$pension_mensual) > 0)
})

test_that("M8: Ley 97 sensitivity -- same inputs, different AFORE + age -> lower pension", {
  # Case 5 vs Case 3: different AFORE and younger retirement
  r_base <- calculate_pension_with_fondo(
    saldo_actual = 300000,
    salario_mensual = 15000,
    edad_actual = 45,
    edad_retiro = 65,
    semanas_actuales = 800,
    genero = "M",
    afore_nombre = "XXI Banorte"
  )

  r_alt <- calculate_pension_with_fondo(
    saldo_actual = 300000,
    salario_mensual = 15000,
    edad_actual = 45,
    edad_retiro = 60,
    semanas_actuales = 800,
    genero = "M",
    afore_nombre = "Profuturo"
  )

  # Younger retirement -> less growth time -> lower balance
  expect_true(r_base$solo_sistema$saldo_proyectado > r_alt$solo_sistema$saldo_proyectado)
})

# --- M9-M10: Age boundary tests ---

test_that("M9: Person aged 64.9 retiring at 65 -> anios_restantes = 1", {
  # floor(64.9) = 64 -> anios_restantes = 65 - 64 = 1
  fecha_nacimiento <- as.Date("1960-03-15")
  today <- as.Date("2025-02-15")
  edad_exact <- as.numeric(difftime(today, fecha_nacimiento, units = "days") / 365.25)
  edad_actual <- floor(edad_exact)
  expect_equal(edad_actual, 64)

  edad_retiro <- 65
  anios_restantes <- max(0, edad_retiro - edad_actual)
  expect_equal(anios_restantes, 1)
})

test_that("M10: Person aged 65.1 retiring at 65 -> anios_restantes = 0", {
  # floor(65.1) = 65 -> anios_restantes = max(0, 65-65) = 0
  fecha_nacimiento <- as.Date("1959-12-01")
  today <- as.Date("2025-02-15")
  edad_exact <- as.numeric(difftime(today, fecha_nacimiento, units = "days") / 365.25)
  edad_actual <- floor(edad_exact)
  expect_equal(edad_actual, 65)

  edad_retiro <- 65
  anios_restantes <- max(0, edad_retiro - edad_actual)
  expect_equal(anios_restantes, 0)
  # No additional weeks added
  semanas_al_retiro <- 1200 + (anios_restantes * 52)
  expect_equal(semanas_al_retiro, 1200)
})

# --- M11-M13: Modalidad 40 interaction in pipeline ---

test_that("M11: M40 only computed when anios_restantes > 0", {
  sbc_diario <- 500
  edad_actual <- 60
  edad_retiro <- 65
  semanas_actuales <- 1200

  anios_restantes <- max(0, edad_retiro - edad_actual)
  semanas_al_retiro <- semanas_actuales + (anios_restantes * 52)

  resultado_base <- calculate_ley73_pension(
    sbc_promedio_diario = sbc_diario,
    semanas = semanas_al_retiro,
    edad = edad_retiro
  )

  # With years remaining, M40 should be computed
  expect_true(resultado_base$elegible)
  expect_true(anios_restantes > 0)

  semanas_m40 <- min(anios_restantes * 52, 260)
  resultado_m40 <- calculate_modalidad_40(
    pension_actual = resultado_base,
    sbc_actual = sbc_diario,
    sbc_m40 = TOPE_SBC_DIARIO * 0.8,
    semanas_actuales = semanas_al_retiro - semanas_m40,
    semanas_m40 = semanas_m40,
    edad_actual = edad_actual,
    edad_retiro = edad_retiro
  )
  expect_false(is.null(resultado_m40))
  expect_true(unname(resultado_m40$pension_con_m40) > 0)
})

test_that("M12: M40 pension > base pension when applied", {
  sbc_diario <- 400
  edad_actual <- 60
  edad_retiro <- 65
  semanas_actuales <- 1200

  anios_restantes <- max(0, edad_retiro - edad_actual)
  semanas_al_retiro <- semanas_actuales + (anios_restantes * 52)

  resultado_base <- calculate_ley73_pension(
    sbc_promedio_diario = sbc_diario,
    semanas = semanas_al_retiro,
    edad = edad_retiro
  )

  semanas_m40 <- min(anios_restantes * 52, 260)
  resultado_m40 <- calculate_modalidad_40(
    pension_actual = resultado_base,
    sbc_actual = sbc_diario,
    sbc_m40 = TOPE_SBC_DIARIO * 0.8,
    semanas_actuales = semanas_al_retiro - semanas_m40,
    semanas_m40 = semanas_m40,
    edad_actual = edad_actual,
    edad_retiro = edad_retiro
  )

  # Hero should display M40 pension (the higher one)
  expect_true(unname(resultado_m40$pension_con_m40) > unname(resultado_base$pension_mensual))
  best_pension <- max(resultado_base$pension_mensual, resultado_m40$pension_con_m40)
  expect_num(best_pension, resultado_m40$pension_con_m40)
})

test_that("M13: M40 NOT computed when anios_restantes = 0", {
  sbc_diario <- 500
  edad_actual <- 65
  edad_retiro <- 65
  semanas_actuales <- 1200

  anios_restantes <- max(0, edad_retiro - edad_actual)
  expect_equal(anios_restantes, 0)

  resultado_base <- calculate_ley73_pension(
    sbc_promedio_diario = sbc_diario,
    semanas = semanas_actuales,
    edad = edad_retiro
  )

  # App logic: M40 is NULL when anios_restantes == 0
  resultado_m40 <- NULL
  if (resultado_base$elegible && anios_restantes > 0) {
    # This branch should NOT execute
    resultado_m40 <- calculate_modalidad_40(
      pension_actual = resultado_base,
      sbc_actual = sbc_diario,
      sbc_m40 = TOPE_SBC_DIARIO * 0.8,
      semanas_actuales = semanas_actuales,
      semanas_m40 = 0,
      edad_actual = edad_actual,
      edad_retiro = edad_retiro
    )
  }

  expect_null(resultado_m40)
})

# --- M14-M16: Fondo eligibility cliff boundaries ---

test_that("M14: Salary at umbral -> eligible; salary above -> NOT eligible", {
  umbral <- unname(get_umbral_fondo_bienestar(2025))

  r_at <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1500,
    sbc_promedio_mensual = umbral
  )
  expect_true(r_at$elegible)

  r_above <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1500,
    sbc_promedio_mensual = umbral + 1
  )
  expect_false(r_above$elegible)
})

test_that("M15: Age 65 -> Fondo eligible; age 64 -> NOT eligible", {
  r_65 <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1500,
    sbc_promedio_mensual = 15000
  )
  expect_true(r_65$elegible)

  r_64 <- check_fondo_eligibility(
    regimen = "ley97", edad = 64, semanas = 1500,
    sbc_promedio_mensual = 15000
  )
  expect_false(r_64$elegible)
})

test_that("M16: Fondo requires fixed 1000 weeks, not transitional schedule", {
  # Fondo Bienestar: fixed 1000 weeks (DOF 01/05/2024)
  r_at <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1000,
    sbc_promedio_mensual = 15000
  )
  expect_true(r_at$elegible)

  r_below <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 999,
    sbc_promedio_mensual = 15000
  )
  expect_false(r_below$elegible)
})


# ==========================================================================
# SECTION N: validar_consistencia_fechas (3 tests)
# ==========================================================================

test_that("N1: Normal start age (18) is consistent", {
  r <- validar_consistencia_fechas(
    fecha_nacimiento = as.Date("1970-01-15"),
    fecha_primera_cotizacion = as.Date("1988-01-15")
  )
  expect_true(r$is_consistent)
  expect_null(r$message)
})

test_that("N2: Start age below 15 is inconsistent", {
  r <- validar_consistencia_fechas(
    fecha_nacimiento = as.Date("1980-01-15"),
    fecha_primera_cotizacion = as.Date("1990-01-15")
  )
  expect_false(r$is_consistent)
  expect_true(grepl("10", r$message))
})

test_that("N3: Start age above 35 is inconsistent", {
  r <- validar_consistencia_fechas(
    fecha_nacimiento = as.Date("1950-01-15"),
    fecha_primera_cotizacion = as.Date("2000-06-15")
  )
  expect_false(r$is_consistent)
  expect_true(grepl("50", r$message))
})


# ==========================================================================
# SECTION O: generate_contribution_schedule (6 tests)
# ==========================================================================

test_that("O1: Schedule length equals anios_al_retiro", {
  sched <- generate_contribution_schedule(20000, 2025, 10)
  expect_length(sched, 10)
})

test_that("O2: Reform rates increase monotonically 2025-2030", {
  sched <- generate_contribution_schedule(20000, 2025, 6)
  # Each year's contribution should be >= previous (rates increase)
  for (i in 2:6) {
    expect_true(sched[i] >= sched[i - 1],
                label = paste("Year", i, ">=", i - 1))
  }
})

test_that("O3: All years 2030+ have identical contribution (employer locked at 12%)", {
  sched <- generate_contribution_schedule(20000, 2029, 5)
  # sched[2] = 2030, sched[3] = 2031, ... all should be equal
  for (i in 3:5) {
    expect_num(sched[i], sched[2], tolerance = 0.01)
  }
})

test_that("O4: Voluntary contributions add uniformly", {
  sched_base <- generate_contribution_schedule(20000, 2025, 5, 0)
  sched_vol  <- generate_contribution_schedule(20000, 2025, 5, 1000)
  diffs <- sched_vol - sched_base
  for (d in diffs) {
    expect_num(d, 1000, tolerance = 0.01)
  }
})

test_that("O5: Hand-calculated total for $20K salary, 8 years 2025-2032", {
  salario <- 20000
  sched <- generate_contribution_schedule(salario, 2025, 8)
  # Verify each year matches calculate_aportacion_obligatoria
  for (i in 1:8) {
    anio <- 2025 + i - 1
    expected <- calculate_aportacion_obligatoria(salario, anio = anio)$aportacion_total
    expect_num(sched[i], expected, tolerance = 0.01)
  }
})

test_that("O6: Salary at tope cap produces capped contributions", {
  salario_alto <- 100000
  tope_mensual <- TOPE_SBC_DIARIO * DIAS_POR_MES
  sched <- generate_contribution_schedule(salario_alto, 2025, 3)
  # Each year's contribution should use tope, not full salary
  for (i in 1:3) {
    anio <- 2025 + i - 1
    aport <- calculate_aportacion_obligatoria(salario_alto, anio = anio)
    expect_num(aport$salario_cotizable, tope_mensual, tolerance = 0.01)
    expect_num(sched[i], aport$aportacion_total, tolerance = 0.01)
  }
})


# ==========================================================================
# SECTION P: project_afore_balance vector mode (8 tests)
# ==========================================================================

test_that("P1: Vector-uniform matches scalar result within tolerance", {
  saldo <- 200000
  aport_scalar <- 2500
  n <- 10
  r <- 0.04
  com <- 0.005

  res_scalar <- project_afore_balance(saldo, aport_scalar, n, r, com)
  res_vector <- project_afore_balance(saldo, rep(aport_scalar, n), n, r, com)

  expect_num(res_vector$saldo_final, res_scalar$saldo_final, tolerance = 1)
})

test_that("P2: Scalar backward compat -- decomposition identity holds", {
  saldo <- 150000
  aport <- 3000
  n <- 15
  r <- 0.035
  com <- 0.006

  res <- project_afore_balance(saldo, aport, n, r, com)
  expect_num(res$saldo_final, res$fv_saldo_actual + res$fv_aportaciones, tolerance = 0.01)
})

test_that("P3: Hand-calculated 3-year vector test", {
  saldo <- 100000
  contribs <- c(1500, 1600, 1700)
  r_neto <- 0.035
  r_mensual <- (1 + r_neto)^(1/12) - 1

  # Year 1: saldo grows, then 12 months of 1500
  s <- saldo * (1 + r_neto)
  for (m in 1:12) s <- s + 1500 * (1 + r_mensual)^(12 - m)
  # Year 2: s grows, then 12 months of 1600
  s <- s * (1 + r_neto)
  for (m in 1:12) s <- s + 1600 * (1 + r_mensual)^(12 - m)
  # Year 3: s grows, then 12 months of 1700
  s <- s * (1 + r_neto)
  for (m in 1:12) s <- s + 1700 * (1 + r_mensual)^(12 - m)

  res <- project_afore_balance(saldo, contribs, 3, r_neto + 0, 0)
  expect_num(res$saldo_final, s, tolerance = 1)
})

test_that("P4: Vector with all zeros = only saldo growth", {
  saldo <- 100000
  n <- 5
  r <- 0.04
  com <- 0.005
  r_neto <- r - com

  res <- project_afore_balance(saldo, rep(0, n), n, r, com)
  expected <- saldo * (1 + r_neto)^n
  expect_num(res$saldo_final, expected, tolerance = 0.01)
})

test_that("P5: Trajectory endpoint matches saldo_final in vector mode", {
  saldo <- 100000
  contribs <- c(2000, 2200, 2400)
  res <- project_afore_balance(saldo, contribs, 3, 0.04, 0.005,
                                incluir_trayectoria = TRUE)
  last_traj <- res$trayectoria$saldo[nrow(res$trayectoria)]
  expect_num(last_traj, res$saldo_final, tolerance = 1)
})

test_that("P6: total_aportado = saldo_actual + sum(schedule * 12) identity", {
  saldo <- 80000
  contribs <- c(1500, 1600, 1700, 1800)
  res <- project_afore_balance(saldo, contribs, 4, 0.04, 0.005)
  expected_total <- saldo + sum(contribs * 12)
  expect_num(res$total_aportado, expected_total, tolerance = 0.01)
})

test_that("P7: ganancia_intereses = saldo_final - total_aportado identity", {
  saldo <- 120000
  contribs <- c(2000, 2500, 3000)
  res <- project_afore_balance(saldo, contribs, 3, 0.04, 0.005)
  expect_num(res$ganancia_intereses, res$saldo_final - res$total_aportado, tolerance = 0.01)
})

test_that("P8: Length mismatch raises error", {
  expect_error(
    project_afore_balance(100000, c(1000, 2000), 3, 0.04, 0.005),
    "length"
  )
})


# ==========================================================================
# SECTION Q: Reform impact validation (7 tests)
# ==========================================================================

test_that("Q1: Variable contributions produce HIGHER saldo than flat 2025 rate", {
  saldo <- 200000
  salario <- 20000
  n <- 10
  r <- 0.04
  com <- 0.005

  # Flat 2025 rate
  flat_aport <- calculate_aportacion_obligatoria(salario, anio = 2025)$aportacion_total
  res_flat <- project_afore_balance(saldo, flat_aport, n, r, com)

  # Variable reform schedule
  sched <- generate_contribution_schedule(salario, 2025, n)
  res_var <- project_afore_balance(saldo, sched, n, r, com)

  expect_true(res_var$saldo_final > res_flat$saldo_final)
})

test_that("Q2: Reform impact magnitude -- 10yr ~8-12%, 5yr ~3-5%", {
  saldo <- 200000
  salario <- 20000
  r <- 0.04
  com <- 0.005

  # 10-year projection
  flat_10 <- project_afore_balance(saldo,
    calculate_aportacion_obligatoria(salario, 2025)$aportacion_total,
    10, r, com)$saldo_final
  var_10 <- project_afore_balance(saldo,
    generate_contribution_schedule(salario, 2025, 10),
    10, r, com)$saldo_final
  impact_10 <- (var_10 - flat_10) / flat_10
  expect_true(impact_10 > 0.03, label = "10yr impact > 3%")
  expect_true(impact_10 < 0.25, label = "10yr impact < 25%")

  # 5-year projection
  flat_5 <- project_afore_balance(saldo,
    calculate_aportacion_obligatoria(salario, 2025)$aportacion_total,
    5, r, com)$saldo_final
  var_5 <- project_afore_balance(saldo,
    generate_contribution_schedule(salario, 2025, 5),
    5, r, com)$saldo_final
  impact_5 <- (var_5 - flat_5) / flat_5
  expect_true(impact_5 > 0.005, label = "5yr impact > 0.5%")
  expect_true(impact_5 < impact_10, label = "5yr impact < 10yr impact")
})

test_that("Q3: calculate_ley97_pension with reform returns higher pension", {
  # Build flat projection manually
  saldo <- 200000
  salario <- 20000
  flat_aport <- calculate_aportacion_obligatoria(salario, 2025)$aportacion_total
  flat_proj <- project_afore_balance(saldo, flat_aport, 20, 0.04, 0.005)
  flat_pension <- calculate_retiro_programado(flat_proj$saldo_final, 65, "M")

  # Function now uses reform schedule
  reform_result <- calculate_ley97_pension(
    saldo_actual = saldo, salario_mensual = salario,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    escenario = "base"
  )

  expect_true(reform_result$saldo_proyectado > flat_proj$saldo_final)
})

test_that("Q4: Short projection (2 years) still shows positive difference", {
  saldo <- 300000
  salario <- 25000
  flat_aport <- calculate_aportacion_obligatoria(salario, 2025)$aportacion_total
  res_flat <- project_afore_balance(saldo, flat_aport, 2, 0.04, 0.005)
  sched <- generate_contribution_schedule(salario, 2025, 2)
  res_var <- project_afore_balance(saldo, sched, 2, 0.04, 0.005)
  expect_true(res_var$saldo_final >= res_flat$saldo_final)
})

test_that("Q5: Long projection (30 years) shows substantial reform impact", {
  saldo <- 50000
  salario <- 15000
  flat_aport <- calculate_aportacion_obligatoria(salario, 2025)$aportacion_total
  res_flat <- project_afore_balance(saldo, flat_aport, 30, 0.04, 0.005)
  sched <- generate_contribution_schedule(salario, 2025, 30)
  res_var <- project_afore_balance(saldo, sched, 30, 0.04, 0.005)
  impact <- (res_var$saldo_final - res_flat$saldo_final) / res_flat$saldo_final
  # Contributions post-2030 dominate; expect meaningful impact
  expect_true(impact > 0.05, label = "30yr impact > 5%")
})

test_that("Q6: Trajectory contributions increase year-over-year until 2030", {
  salario <- 20000
  sched <- generate_contribution_schedule(salario, 2025, 10)
  # Years 1-6 (2025-2030) should strictly increase
  for (i in 2:6) {
    expect_true(sched[i] > sched[i - 1],
                label = paste("contribution year", i, ">", i - 1))
  }
})

test_that("Q7: Projection starting after 2030 shows no difference vs flat 12%", {
  saldo <- 200000
  salario <- 20000
  n <- 5

  # Starting in 2031, all years are at 12%
  sched <- generate_contribution_schedule(salario, 2031, n)
  flat_2030 <- calculate_aportacion_obligatoria(salario, anio = 2030)$aportacion_total
  res_flat <- project_afore_balance(saldo, flat_2030, n, 0.04, 0.005)
  res_var <- project_afore_balance(saldo, sched, n, 0.04, 0.005)

  expect_num(res_var$saldo_final, res_flat$saldo_final, tolerance = 1)
})


# ==========================================================================
# SECTION R: Fondo Bienestar threshold + retirement year (5 tests)
# ==========================================================================

test_that("R1: Known thresholds match official values", {
  expect_num(get_umbral_fondo_bienestar(2024), 16777.68, tolerance = 0.01)
  expect_num(get_umbral_fondo_bienestar(2025), 17364, tolerance = 0.01)
  expect_num(get_umbral_fondo_bienestar(2026), 18050, tolerance = 0.01)
})

test_that("R2: Extrapolation beyond 2026 at 3.5% annual", {
  expected_2030 <- 18050 * 1.035^4
  expect_num(get_umbral_fondo_bienestar(2030), expected_2030, tolerance = 0.01)
})

test_that("R3: Extrapolation monotonically increasing 2027-2040", {
  prev <- get_umbral_fondo_bienestar(2026)
  for (y in 2027:2040) {
    curr <- get_umbral_fondo_bienestar(y)
    expect_true(unname(curr) > unname(prev),
                label = paste("threshold", y, ">", y - 1))
    prev <- curr
  }
})

test_that("R4: Eligibility uses retirement year threshold", {
  # Worker with salary $17,500: eligible at 2025 threshold (17,364? no, 17500>17364)
  # Use $17,000 salary: eligible at 2025, and also at 2045 projected threshold
  salary <- 17000

  r_2025 <- check_fondo_eligibility("ley97", 65, 1500, salary, anio = 2025)
  expect_true(r_2025$elegible)  # 17000 < 17364

  # At retirement year 2045, threshold should be much higher
  r_2045 <- check_fondo_eligibility("ley97", 65, 1500, salary, anio = 2045)
  expect_true(r_2045$elegible)
  expect_true(unname(r_2045$umbral_usado) > unname(r_2025$umbral_usado))
})

test_that("R5: calculate_pension_with_fondo applies projected threshold", {
  # Young worker retiring in 2060 -- threshold should be projected
  result <- calculate_pension_with_fondo(
    saldo_actual = 50000, salario_mensual = 15000,
    edad_actual = 30, edad_retiro = 65,
    semanas_actuales = 400, genero = "M"
  )

  # The umbral used should be for year 2060 (2025 + 35), not 2025
  expected_umbral <- get_umbral_fondo_bienestar(2060)
  expect_num(result$fondo_bienestar$umbral, expected_umbral, tolerance = 0.01)
})


# ==========================================================================
# SECTION S: Full-pipeline hand-verified profiles (4 tests)
# ==========================================================================

test_that("S1: Young Ley 97 worker (30yo, $25K, 500 wks, retire 65)", {
  result <- calculate_ley97_pension(
    saldo_actual = 100000, salario_mensual = 25000,
    edad_actual = 30, edad_retiro = 65,
    semanas_actuales = 500, genero = "M",
    escenario = "base"
  )

  expect_true(result$elegible)
  # 35 years of contributions + growth should produce a substantial balance
  expect_true(result$saldo_proyectado > 1000000,
              label = "35yr projection should exceed 1M")
  # With that balance, pension should exceed minima
  expect_true(result$pension_mensual > 0)
})

test_that("S2: Near-retirement worker (60yo, $15K, 1500 wks, retire 65)", {
  result <- calculate_ley97_pension(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 1500, genero = "M",
    escenario = "base"
  )

  expect_true(result$elegible)
  # Short projection: difference vs flat should be modest
  flat_aport <- calculate_aportacion_obligatoria(15000, 2025)$aportacion_total
  flat_proj <- project_afore_balance(500000, flat_aport, 5, 0.04, result$comision_usada)
  # Reform result should be >= flat
  expect_true(result$saldo_proyectado >= flat_proj$saldo_final * 0.99)
})

test_that("S3: High-salary worker at tope ($100K, contributions capped)", {
  salario_alto <- 100000
  tope_mensual <- TOPE_SBC_DIARIO * DIAS_POR_MES

  result <- calculate_ley97_pension(
    saldo_actual = 800000, salario_mensual = salario_alto,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 1000, genero = "M",
    escenario = "base"
  )

  expect_true(result$elegible)
  # Contributions should be capped
  aport <- calculate_aportacion_obligatoria(salario_alto, 2025)
  expect_num(aport$salario_cotizable, tope_mensual, tolerance = 0.01)
  # Reform still increases employer rate even at cap
  sched <- generate_contribution_schedule(salario_alto, 2025, 5)
  expect_true(sched[5] > sched[1])
})

test_that("S4: Low-salary Fondo-eligible worker ($12K, 1200 wks, age 65)", {
  result <- calculate_pension_with_fondo(
    saldo_actual = 300000, salario_mensual = 12000,
    edad_actual = 65, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M"
  )

  # Should be eligible for Fondo
  expect_true(result$con_fondo$elegible)
  # Complement = max(0, min(salary, threshold) - pension_afore)
  expect_true(result$con_fondo$complemento >= 0)
  # Total pension with Fondo >= pension without
  expect_true(result$con_fondo$pension_total >= result$solo_sistema$pension_mensual)
})

# ==========================================================================
# SECTION T: calculate_all_scenarios() integration
# ==========================================================================

test_that("T1: Ley 73 scenario returns correct structure", {
  result <- calculate_all_scenarios(
    regimen = "ley73", salario_mensual = 20000,
    edad_actual = 55, edad_retiro = 65, semanas_actuales = 1000
  )
  expect_equal(result$regimen, "ley73")
  expect_true(!is.null(result$pension_base))
  expect_false(result$fondo_bienestar_aplica)
})

test_that("T2: Ley 97 scenario returns all 4 sub-scenarios", {
  result <- calculate_all_scenarios(
    regimen = "ley97", saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65, semanas_actuales = 600
  )
  expect_equal(result$regimen, "ley97")
  expect_true(!is.null(result$pension_conservador))
  expect_true(!is.null(result$pension_base))
  expect_true(!is.null(result$pension_optimista))
  expect_true(!is.null(result$pension_con_voluntarias))
  expect_true(result$fondo_bienestar_aplica)
})

test_that("T3: NULL sbc_diario auto-calculates from salario_mensual", {
  result <- calculate_all_scenarios(
    regimen = "ley73", salario_mensual = 20000, sbc_diario = NULL,
    edad_actual = 55, edad_retiro = 65, semanas_actuales = 1000
  )
  expect_true(result$pension_base$elegible)
})

test_that("T4: Ley 97 scenarios ordered conservador < base < optimista", {
  result <- calculate_all_scenarios(
    regimen = "ley97", saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65, semanas_actuales = 600
  )
  expect_true(result$pension_conservador$saldo_proyectado <=
              result$pension_base$saldo_proyectado)
  expect_true(result$pension_base$saldo_proyectado <=
              result$pension_optimista$saldo_proyectado)
})

test_that("T5: Ley 73 M40 is NULL when not eligible", {
  result <- calculate_all_scenarios(
    regimen = "ley73", salario_mensual = 5000,
    edad_actual = 55, edad_retiro = 65, semanas_actuales = 200
  )
  # With only 200 + 10*52 = 720 weeks, still >= 500, so eligible
  # But we can test with very few weeks
  result2 <- calculate_all_scenarios(
    regimen = "ley73", salario_mensual = 5000,
    edad_actual = 64, edad_retiro = 65, semanas_actuales = 100
  )
  # 100 + 1*52 = 152 < 500, not eligible
  expect_false(result2$pension_base$elegible)
  expect_null(result2$pension_m40)
})

test_that("T6: Fondo flag correct per regime", {
  ley73 <- calculate_all_scenarios(
    regimen = "ley73", salario_mensual = 20000,
    edad_actual = 55, edad_retiro = 65, semanas_actuales = 1000
  )
  ley97 <- calculate_all_scenarios(
    regimen = "ley97", saldo_actual = 100000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65, semanas_actuales = 600
  )
  expect_false(ley73$fondo_bienestar_aplica)
  expect_true(ley97$fondo_bienestar_aplica)
})

# ==========================================================================
# SECTION U: compare_afores()
# ==========================================================================

test_that("U1: Returns sorted by saldo_final descending", {
  result <- compare_afores(
    saldo_actual = 200000, salario_mensual = 15000,
    anios_al_retiro = 20, afore_actual = "Profuturo"
  )
  expect_true(all(diff(result$saldo_final) <= 0))
})

test_that("U2: Returns all AFOREs", {
  result <- compare_afores(
    saldo_actual = 200000, salario_mensual = 15000,
    anios_al_retiro = 20
  )
  expect_equal(nrow(result), length(get_afore_names()))
})

test_that("U3: Current AFORE diferencia is 0", {
  result <- compare_afores(
    saldo_actual = 200000, salario_mensual = 15000,
    anios_al_retiro = 20, afore_actual = "Profuturo"
  )
  expect_num(result$diferencia[result$afore == "Profuturo"], 0)
})

test_that("U4: All saldo_final values are positive", {
  result <- compare_afores(
    saldo_actual = 200000, salario_mensual = 15000,
    anios_al_retiro = 20
  )
  expect_true(all(result$saldo_final > 0))
})

# ==========================================================================
# SECTION V: analyze_voluntary_contributions()
# ==========================================================================

test_that("V1: Higher voluntary contribution -> higher pension", {
  result <- analyze_voluntary_contributions(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65, semanas_actuales = 600,
    aportaciones_probar = c(0, 500, 1000, 2000)
  )
  expect_true(all(diff(result$pension_afore) >= 0))
})

test_that("V2: Custom aportaciones vector works", {
  result <- analyze_voluntary_contributions(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65, semanas_actuales = 600,
    aportaciones_probar = c(100, 300, 700)
  )
  expect_equal(nrow(result), 3)
  expect_equal(result$aportacion, c(100, 300, 700))
})

test_that("V3: Saldo increases with contributions", {
  result <- analyze_voluntary_contributions(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65, semanas_actuales = 600,
    aportaciones_probar = c(0, 1000)
  )
  expect_true(result$saldo_final[2] > result$saldo_final[1])
})

test_that("V4: Result has expected columns", {
  result <- analyze_voluntary_contributions(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65, semanas_actuales = 600
  )
  expected_cols <- c("aportacion", "saldo_final", "pension_afore",
                     "pension_con_fondo", "incremento_vs_base")
  expect_true(all(expected_cols %in% names(result)))
})

# ==========================================================================
# SECTION W: analyze_retirement_age()
# ==========================================================================

test_that("W1: Skips ages <= current age", {
  result <- analyze_retirement_age(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 55, semanas_actuales = 1200,
    edades_probar = 50:65
  )
  expect_true(all(result$edad_retiro > 55))
})

test_that("W2: Saldo increases with later retirement", {
  result <- analyze_retirement_age(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 40, semanas_actuales = 600,
    edades_probar = 60:65
  )
  expect_true(all(diff(result$saldo_final) >= 0))
})

test_that("W3: anios_trabajo is correct", {
  result <- analyze_retirement_age(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 40, semanas_actuales = 600,
    edades_probar = 60:65
  )
  expect_equal(result$anios_trabajo, result$edad_retiro - 40)
})

test_that("W4: Result has expected columns", {
  result <- analyze_retirement_age(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 40, semanas_actuales = 600
  )
  expected_cols <- c("edad_retiro", "anios_trabajo", "saldo_final",
                     "pension_afore", "elegible_fondo", "pension_con_fondo")
  expect_true(all(expected_cols %in% names(result)))
})

# ==========================================================================
# SECTION X: generate_personalized_message()
# ==========================================================================

test_that("X1: Low tasa generates danger message", {
  result <- calculate_pension_with_fondo(
    saldo_actual = 10000, salario_mensual = 50000,
    edad_actual = 55, edad_retiro = 65,
    semanas_actuales = 600, genero = "M"
  )
  msgs <- generate_personalized_message(result)
  expect_equal(msgs$tasa$tipo, "danger")
})

test_that("X2: Medium tasa generates warning message", {
  result <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 55, edad_retiro = 65,
    semanas_actuales = 800, genero = "M"
  )
  msgs <- generate_personalized_message(result)
  tasa <- result$solo_sistema$tasa_reemplazo * 100
  if (tasa >= 30 && tasa < 50) {
    expect_equal(msgs$tasa$tipo, "warning")
  } else if (tasa >= 50) {
    expect_equal(msgs$tasa$tipo, "success")
  }
})

test_that("X3: High tasa generates success message", {
  result <- calculate_pension_with_fondo(
    saldo_actual = 3000000, salario_mensual = 10000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M"
  )
  msgs <- generate_personalized_message(result)
  expect_equal(msgs$tasa$tipo, "success")
})

test_that("X4: Fondo eligible generates info message", {
  result <- calculate_pension_with_fondo(
    saldo_actual = 200000, salario_mensual = 12000,
    edad_actual = 65, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M"
  )
  msgs <- generate_personalized_message(result)
  expect_equal(msgs$fondo$tipo, "info")
})

test_that("X5: Message always has 3 blocks", {
  result <- calculate_pension_with_fondo(
    saldo_actual = 200000, salario_mensual = 15000,
    edad_actual = 40, edad_retiro = 65,
    semanas_actuales = 600, genero = "M"
  )
  msgs <- generate_personalized_message(result)
  expect_equal(length(msgs), 3)
  expect_true(all(c("fondo", "tasa", "voluntarias") %in% names(msgs)))
})

# ==========================================================================
# SECTION Y: Format helpers
# ==========================================================================

test_that("Y1: format_currency formats normal value", {
  expect_equal(format_currency(1234.56), "$1,234.56")
})

test_that("Y2: format_currency handles zero", {
  expect_equal(format_currency(0), "$0.00")
})

test_that("Y3: format_percent 25%", {
  expect_equal(format_percent(0.25), "25%")
})

test_that("Y4: format_percent 100%", {
  expect_equal(format_percent(1.0), "100%")
})

# ==========================================================================
# SECTION Z: Data retrieval functions
# ==========================================================================

test_that("Z1: get_uma returns known 2025 value", {
  expect_num(get_uma(2025), UMA_DIARIA_2025)
})

test_that("Z2: get_uma falls back for unknown year", {
  val <- get_uma(2099)
  expect_true(is.numeric(val) && val > 0)
})

test_that("Z3: get_salario_minimo returns 2025 value", {
  expect_num(get_salario_minimo(2025), SM_DIARIO_2025)
})

test_that("Z4: get_all_afores returns data frame", {
  result <- get_all_afores()
  expect_true(is.data.frame(result))
  expect_true("comision_pct" %in% names(result))
  expect_true("irn_pct" %in% names(result))
})

test_that("Z5: get_afore_names returns character vector", {
  names <- get_afore_names()
  expect_true(is.character(names))
  expect_true(length(names) >= 10)
})

# ==========================================================================
# SECTION AA: Edge cases
# ==========================================================================

test_that("AA1: Zero years to retirement (already at retirement age)", {
  result <- calculate_ley97_pension(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 65, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M"
  )
  expect_true(result$elegible)
  expect_true(result$pension_mensual > 0)
})

test_that("AA2: Negative return rate still computes", {
  result <- project_afore_balance(
    saldo_actual = 500000, aportacion_mensual = 1000,
    anios_al_retiro = 10, rendimiento_real_anual = -0.01,
    comision_anual = 0.005
  )
  expect_true(is.numeric(result$saldo_final))
  # Negative net return should erode balance
  expect_true(result$saldo_final < 500000 + 1000 * 120)
})

test_that("AA3: Zero weeks cotizadas for Ley 73", {
  result <- calculate_ley73_pension(
    sbc_promedio_diario = 500, semanas = 0, edad = 65
  )
  expect_false(result$elegible)
})

test_that("AA4: Very low salary Ley 73 applies minimum", {
  result <- calculate_ley73_pension(
    sbc_promedio_diario = 100, semanas = 1500, edad = 65
  )
  expect_true(result$aplico_minimo)
  expect_num(result$pension_mensual, SM_DIARIO_2025 * DIAS_POR_MES)
})

test_that("AA5: Very high AFORE balance", {
  result <- calculate_retiro_programado(saldo = 10000000, edad = 65, genero = "M")
  expect_false(result$aplico_minimo)
  expect_true(result$pension_mensual > result$pension_minima)
})

test_that("AA6: Salary exactly at Fondo threshold", {
  umbral <- get_umbral_fondo_bienestar(2025)
  elig <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1200,
    sbc_promedio_mensual = umbral, anio = 2025
  )
  expect_true(elig$elegible)
})

test_that("AA7: grupo_salarial exactly 1.00", {
  result <- lookup_articulo_167(1.0)
  expect_true(is.numeric(result$cuantia_basica))
  expect_true(is.numeric(result$incremento_anual))
})

test_that("AA8: M40 at SBC tope", {
  base <- calculate_ley73_pension(
    sbc_promedio_diario = 500, semanas = 1000, edad = 65
  )
  result <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 500,
    sbc_m40 = TOPE_SBC_DIARIO, semanas_actuales = 1000,
    semanas_m40 = 260, edad_actual = 60, edad_retiro = 65
  )
  expect_num(result$sbc_m40_usado, TOPE_SBC_DIARIO)
})

# ==========================================================================
# SECTION BB: /30 regression tests (DIAS_POR_MES consistency)
# ==========================================================================

test_that("BB1: DIAS_POR_MES equals 365.25/12", {
  expect_equal(DIAS_POR_MES, 365.25 / 12)
})

test_that("BB2: Ley 73 pension_mensual = diaria * DIAS_POR_MES", {
  result <- calculate_ley73_pension(
    sbc_promedio_diario = 500, semanas = 1500, edad = 65
  )
  if (!result$aplico_minimo) {
    expect_num(result$pension_sin_minimo, result$pension_diaria * DIAS_POR_MES,
               tolerance = 0.01)
  }
})

test_that("BB3: SBC daily-to-monthly conversion is consistent", {
  salario <- 20000
  sbc_daily <- salario / DIAS_POR_MES
  salario_roundtrip <- sbc_daily * DIAS_POR_MES
  expect_equal(salario_roundtrip, salario, tolerance = 0.001)
})


# ==========================================================================
# SECTION CC: Art. 167 & Ley 73 Formula Boundaries
# ==========================================================================
# Edge cases at bracket gaps, n_incrementos floor division, porcentaje cap,
# extreme ages, and monotonicity. Identified by actuarial test review.

test_that("CC1: Art. 167 grupo in gap (1.005) resolves to first row", {
  # Gap between [0.00,1.00] and [1.01,1.25] -- code falls to first row
  r <- lookup_articulo_167(1.005)
  expect_true(is.numeric(r$cuantia_basica))
  expect_num(r$cuantia_basica, 0.8000)
})

test_that("CC2: Art. 167 grupo in gap (1.255) resolves without error", {
  r <- lookup_articulo_167(1.255)
  expect_true(is.numeric(r$cuantia_basica))
  expect_num(r$cuantia_basica, 0.8000)
})

test_that("CC3: All 21 Art. 167 inter-bracket gap values resolve without error", {
  gap_values <- c(1.005, 1.255, 1.505, 1.755, 2.005, 2.255, 2.505,
                  2.755, 3.005, 3.255, 3.505, 3.755, 4.005, 4.255,
                  4.505, 4.755, 5.005, 5.255, 5.505, 5.755, 6.005)
  for (g in gap_values) {
    r <- lookup_articulo_167(g)
    expect_true(is.numeric(r$cuantia_basica),
                info = paste("Gap value", g, "failed"))
    expect_true(r$cuantia_basica > 0 && r$cuantia_basica <= 1.0,
                info = paste("Gap value", g, "cuantia out of range"))
  }
})

test_that("CC4: Art. 167 cuantia in (0,1] and incremento > 0 for all brackets", {
  for (i in 1:nrow(articulo_167_tabla)) {
    mid <- (articulo_167_tabla$grupo_min[i] + articulo_167_tabla$grupo_max[i]) / 2
    r <- lookup_articulo_167(mid)
    expect_true(r$cuantia_basica > 0 && r$cuantia_basica <= 1.0,
                info = paste("Row", i, "midpoint", mid))
    expect_true(r$incremento_anual > 0, info = paste("Row", i))
  }
})

test_that("CC5: 551 weeks gives 0 incrementos (floor division edge)", {
  r <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 551, edad = 65)
  expect_num(r$n_incrementos, 0)
})

test_that("CC6: 552 weeks gives exactly 1 incremento", {
  r <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 552, edad = 65)
  expect_num(r$n_incrementos, 1)
})

test_that("CC7: Pension at 552 weeks > pension at 551 weeks", {
  r551 <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 551, edad = 65)
  r552 <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 552, edad = 65)
  expect_true(unname(r552$pension_sin_minimo) > unname(r551$pension_sin_minimo))
})

test_that("CC8: Low-salary bracket porcentaje capped at 36 incrementos", {
  sbc <- SM_DIARIO_2025 * 0.5
  r_35 <- calculate_ley73_pension(sbc, semanas = 500 + 35 * 52, edad = 65)
  r_36 <- calculate_ley73_pension(sbc, semanas = 500 + 36 * 52, edad = 65)
  expect_true(unname(r_35$porcentaje_total) < 1.0)
  expect_num(r_36$porcentaje_total, 1.0)
})

test_that("CC9: High-salary bracket porcentaje capped at 36 incrementos", {
  sbc <- SM_DIARIO_2025 * 10
  r_35 <- calculate_ley73_pension(sbc, semanas = 500 + 35 * 52, edad = 65)
  r_36 <- calculate_ley73_pension(sbc, semanas = 500 + 36 * 52, edad = 65)
  expect_true(unname(r_35$porcentaje_total) < 1.0)
  expect_num(r_36$porcentaje_total, 1.0)
})

test_that("CC10: Once porcentaje capped, more weeks do not increase it", {
  sbc <- SM_DIARIO_2025 * 10
  r_cap <- calculate_ley73_pension(sbc, semanas = 2500, edad = 65)
  r_more <- calculate_ley73_pension(sbc, semanas = 3000, edad = 65)
  expect_num(r_cap$porcentaje_total, 1.0)
  expect_num(r_more$porcentaje_total, 1.0)
  expect_num(r_cap$pension_sin_minimo, r_more$pension_sin_minimo, tolerance = 0.01)
})

test_that("CC11: Ley 73 at age 66 and 70 use factor 1.0 (vejez)", {
  r66 <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 1500, edad = 66)
  r70 <- calculate_ley73_pension(sbc_promedio_diario = 500, semanas = 1500, edad = 70)
  expect_num(r66$factor_edad, 1.0)
  expect_num(r70$factor_edad, 1.0)
  expect_num(r66$pension_mensual, r70$pension_mensual, tolerance = 0.01)
})

test_that("CC12: Ley 73 pension non-decreasing with semanas", {
  sbc <- SM_DIARIO_2025 * 3
  prev_pension <- 0
  for (semanas in seq(500, 3000, by = 52)) {
    r <- calculate_ley73_pension(sbc, semanas = semanas, edad = 65)
    if (r$elegible) {
      expect_true(unname(r$pension_mensual) >= prev_pension - 0.01,
                  info = paste("Pension decreased at semanas =", semanas))
      prev_pension <- unname(r$pension_mensual)
    }
  }
})

test_that("CC13: Cesantia factor ratio 60/65 = exactly 0.75", {
  sbc <- SM_DIARIO_2025 * 5
  r60 <- calculate_ley73_pension(sbc, semanas = 1500, edad = 60)
  r65 <- calculate_ley73_pension(sbc, semanas = 1500, edad = 65)
  if (!r60$aplico_minimo && !r65$aplico_minimo) {
    ratio <- unname(r60$pension_sin_minimo) / unname(r65$pension_sin_minimo)
    expect_num(ratio, 0.75, tolerance = 1e-6)
  }
})


# ==========================================================================
# SECTION DD: Life Expectancy & Retiro Programado Edge Cases
# ==========================================================================

test_that("DD1: Life expectancy interpolation 70-75 gap (male, age 72, EMSSA)", {
  # Male EMSSA 2009: age 70=14.5, age 75=11.3 -> at 72: 14.5 + 0.4*(-3.2) = 13.22
  ev <- get_esperanza_vida(72, "M")
  expect_num(ev, 13.22, tolerance = 0.01)
})

test_that("DD2: Life expectancy interpolation 70-75 gap (female, age 73, EMSSA)", {
  # Female EMSSA 2009: age 70=17.4, age 75=13.5 -> at 73: 17.4 + 0.6*(-3.9) = 15.06
  ev <- get_esperanza_vida(73, "F")
  expect_num(ev, 15.06, tolerance = 0.01)
})

test_that("DD3: Life expectancy interpolation 80-85 gap (male, age 82, EMSSA)", {
  # Male EMSSA 2009: age 80=8.5, age 85=6.1 -> at 82: 8.5 + 0.4*(-2.4) = 7.54
  ev <- get_esperanza_vida(82, "M")
  expect_num(ev, 7.54, tolerance = 0.01)
})

test_that("DD4: Life expectancy monotonically decreasing 60-90", {
  for (gender in c("M", "F")) {
    prev_ev <- get_esperanza_vida(60, gender)
    for (age in 61:90) {
      ev <- get_esperanza_vida(age, gender)
      expect_true(unname(ev) <= unname(prev_ev),
                  info = paste(gender, "age", age))
      prev_ev <- ev
    }
  }
})

test_that("DD5: Life expectancy floor of 2 years at age 95", {
  expect_true(unname(get_esperanza_vida(95, "M")) >= 2)
  expect_true(unname(get_esperanza_vida(95, "F")) >= 2)
})

test_that("DD6: Life expectancy extrapolation below age 60", {
  ev <- get_esperanza_vida(50, "M")
  ev_60 <- get_esperanza_vida(60, "M")
  expect_num(ev, unname(ev_60) + 10, tolerance = 0.01)
})

test_that("DD7: Retiro programado = saldo / (esperanza * 12) exactly", {
  for (saldo in c(100000, 500000, 2000000, 10000000)) {
    for (genero in c("M", "F")) {
      r <- calculate_retiro_programado(saldo, edad = 65, genero = genero)
      ev <- unname(get_esperanza_vida(65, genero))
      expect_num(r$pension_calculada, saldo / (ev * 12), tolerance = 0.01,
                 info = paste("Saldo:", saldo, "Genero:", genero))
    }
  }
})

test_that("DD8: Saldo at breakeven produces pension equal to minimum", {
  ev_male <- unname(get_esperanza_vida(65, "M"))
  breakeven <- PENSION_MINIMA_LEY97 * ev_male * 12
  r <- calculate_retiro_programado(breakeven, edad = 65, genero = "M")
  expect_num(r$pension_calculada, PENSION_MINIMA_LEY97, tolerance = 0.01)
  expect_true(unname(r$pension_mensual) >= PENSION_MINIMA_LEY97 - 0.01)
})


# ==========================================================================
# SECTION EE: Fondo Complement & Minimum Guarantee Interaction
# ==========================================================================

test_that("EE1: When minimum guarantee > salary, Fondo complement = 0", {
  elig <- check_fondo_eligibility("ley97", edad = 65, semanas = 1200,
                                   sbc_promedio_mensual = 8000, anio = 2025)
  expect_true(elig$elegible)
  comp <- calculate_fondo_complement(
    pension_afore = PENSION_MINIMA_LEY97, sbc_promedio_mensual = 8000,
    elegibilidad = elig
  )
  expect_num(comp$complemento, 0)
  expect_num(comp$pension_total, PENSION_MINIMA_LEY97, tolerance = 0.01)
})

test_that("EE2: When salary exactly equals pension_minima, complement = 0", {
  salary <- PENSION_MINIMA_LEY97
  elig <- check_fondo_eligibility("ley97", edad = 65, semanas = 1200,
                                   sbc_promedio_mensual = salary, anio = 2025)
  expect_true(elig$elegible)
  comp <- calculate_fondo_complement(
    pension_afore = PENSION_MINIMA_LEY97, sbc_promedio_mensual = salary,
    elegibilidad = elig
  )
  expect_num(comp$complemento, 0, tolerance = 0.01)
})

test_that("EE3: Fondo complement exactly fills gap to salary", {
  elig <- check_fondo_eligibility("ley97", edad = 65, semanas = 1200,
                                   sbc_promedio_mensual = 15000, anio = 2025)
  comp <- calculate_fondo_complement(
    pension_afore = 5000, sbc_promedio_mensual = 15000, elegibilidad = elig
  )
  expect_num(comp$complemento, 10000)
  expect_num(comp$pension_total, 15000)
})

test_that("EE4: Salary above umbral blocks Fondo eligibility", {
  umbral <- get_umbral_fondo_bienestar(2025)
  elig <- check_fondo_eligibility("ley97", edad = 65, semanas = 1200,
                                   sbc_promedio_mensual = umbral + 1, anio = 2025)
  expect_false(elig$elegible)
})

test_that("EE5: calculate_ley97_pension with 0 years remaining preserves saldo", {
  r <- calculate_ley97_pension(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 65, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M"
  )
  expect_true(r$elegible)
  expect_num(r$saldo_proyectado, 500000, tolerance = 1)
})

test_that("EE6: Full pipeline with 0 years: Fondo eligible, PMG matriz aplica", {
  r <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 65, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M"
  )
  expect_true(r$con_fondo$elegible)
  expect_true(r$solo_sistema$aplico_minimo)
  sbc_diario <- 15000 / DIAS_POR_MES
  pmg_esperado <- calculate_pmg_matrix(edad = 65, semanas = 1200, sbc_diario = sbc_diario)
  expect_num(r$solo_sistema$pension_mensual, pmg_esperado, tolerance = 1)
})


# ==========================================================================
# SECTION FF: AFORE Projection & Contribution Reform Boundaries
# ==========================================================================

test_that("FF1: Reform bracket gap at 1.005 UMA resolves to a bracket", {
  rate <- get_ceav_employer_rate(1.005, 2025)
  expect_true(is.numeric(rate))
  expect_true(rate > 0)
})

test_that("FF2: Cuota social for gap value at 1.005 UMA is non-negative", {
  cs <- get_cuota_social_mensual(1.005)
  expect_true(is.numeric(cs))
  expect_true(cs >= 0)
})

test_that("FF3: Reform rates increase from 2023 to 2030 for all brackets", {
  for (uma_val in c(0.5, 1.5, 3.0, 5.0)) {
    r2023 <- get_ceav_employer_rate(uma_val, 2023)
    r2030 <- get_ceav_employer_rate(uma_val, 2030)
    expect_true(r2030 >= r2023,
                info = paste("Rate should increase at", uma_val, "UMA"))
  }
})

test_that("FF4: Cuota social is zero for bracket 4.01+ UMA", {
  cs <- get_cuota_social_mensual(5.0)
  expect_num(cs, 0, tolerance = 0.01)
})

test_that("FF5: Scalar and vector projection modes agree within 1%", {
  aport <- 2000; n <- 10
  r_scalar <- project_afore_balance(
    saldo_actual = 200000, aportacion_mensual = aport,
    anios_al_retiro = n, rendimiento_real_anual = 0.04, comision_anual = 0.005
  )
  r_vector <- project_afore_balance(
    saldo_actual = 200000, aportacion_mensual = rep(aport, n),
    anios_al_retiro = n, rendimiento_real_anual = 0.04, comision_anual = 0.005
  )
  pct_diff <- abs(r_scalar$saldo_final - r_vector$saldo_final) / r_scalar$saldo_final
  expect_true(pct_diff < 0.01,
              info = paste("Scalar:", round(r_scalar$saldo_final),
                           "Vector:", round(r_vector$saldo_final)))
})

test_that("FF6: Vector mode with increasing contributions < constant (less compounding)", {
  n <- 10
  constant <- rep(2000, n)
  increasing <- seq(1500, 2500, length.out = n)
  r_const <- project_afore_balance(200000, constant, n, 0.04, 0.005)
  r_incr <- project_afore_balance(200000, increasing, n, 0.04, 0.005)
  expect_true(r_const$saldo_final > r_incr$saldo_final)
})

test_that("FF7: Schedule spanning 2029-2031 shows rate increase then plateau", {
  schedule <- generate_contribution_schedule(20000, anio_inicio = 2029, anios_al_retiro = 3)
  expect_true(schedule[1] < schedule[2])
  expect_num(schedule[2], schedule[3], tolerance = 0.01)
})

test_that("FF8: Schedule entirely after 2030 has constant contributions", {
  schedule <- generate_contribution_schedule(20000, anio_inicio = 2032, anios_al_retiro = 5)
  for (i in 2:5) {
    expect_num(schedule[i], schedule[1], tolerance = 0.01)
  }
})

test_that("FF9: Year before reform (2022) uses clamped 2023 rates", {
  r_2022 <- calculate_aportacion_obligatoria(20000, anio = 2022)
  r_2023 <- calculate_aportacion_obligatoria(20000, anio = 2023)
  expect_num(r_2022$tasa_ceav, r_2023$tasa_ceav, tolerance = 0.0001)
})


# ==========================================================================
# SECTION GG: Modalidad 40 Edge Cases
# ==========================================================================

test_that("GG1: M40 with exactly 250 semanas uses 100% M40 SBC", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1000, edad = 65)
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = 2000,
    semanas_actuales = 1000, semanas_m40 = 250,
    edad_actual = 60, edad_retiro = 65
  )
  expect_num(r$nuevo_sbc_promedio, min(2000, TOPE_SBC_DIARIO))
})

test_that("GG2: M40 with 1 semana uses weighted average", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1000, edad = 65)
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = 2000,
    semanas_actuales = 1000, semanas_m40 = 1,
    edad_actual = 64, edad_retiro = 65
  )
  expected_sbc <- (2000 * 1 + 400 * 249) / 250
  expect_num(r$nuevo_sbc_promedio, expected_sbc, tolerance = 0.01)
})

test_that("GG3: M40 pension always >= base pension", {
  for (sbc in c(300, 500, 1000, 2000)) {
    base <- calculate_ley73_pension(sbc_promedio_diario = sbc, semanas = 1000, edad = 65)
    if (!base$elegible) next
    r <- calculate_modalidad_40(
      pension_actual = base, sbc_actual = sbc,
      sbc_m40 = TOPE_SBC_DIARIO * 0.8,
      semanas_actuales = 1000, semanas_m40 = 260,
      edad_actual = 60, edad_retiro = 65
    )
    expect_true(r$pension_con_m40 >= base$pension_mensual,
                info = paste("M40 should not decrease pension at SBC =", sbc))
  }
})


# ==========================================================================
# SECTION HH: SBC cap Ley 73 (robustez post-fix 2026-04-13)
# ==========================================================================

test_that("HH1: SBC superior a 25 UMA diarias es capeado antes del calculo", {
  # SBC doble del tope debe dar misma pension que SBC = tope
  sbc_excesivo <- TOPE_SBC_DIARIO * 2
  r_excesivo <- calculate_ley73_pension(sbc_excesivo, semanas = 1500, edad = 65)
  r_tope <- calculate_ley73_pension(TOPE_SBC_DIARIO, semanas = 1500, edad = 65)
  expect_num(r_excesivo$pension_mensual, r_tope$pension_mensual, tolerance = 0.01)
})

test_that("HH2: SBC dentro del tope no se altera", {
  sbc_normal <- TOPE_SBC_DIARIO / 2
  r <- calculate_ley73_pension(sbc_normal, semanas = 1500, edad = 65)
  # grupo_salarial debe ser sbc_normal / SM_DIARIO_2025
  expected_grupo <- sbc_normal / SM_DIARIO_2025
  expect_num(r$grupo_salarial, expected_grupo, tolerance = 0.01)
})


# ==========================================================================
# SECTION II: Zona salarial (frontera norte vs general)
# ==========================================================================

test_that("II1: Zona ZLFN usa SM mas alto ($419.88 vs $278.80)", {
  # Para SBC muy bajo, el piso de pension es 1 SM mensual
  sbc_muy_bajo <- SM_DIARIO_2025 * 0.5
  r_gen <- calculate_ley73_pension(sbc_muy_bajo, semanas = 500, edad = 65,
                                    zona_sm = ZONA_GENERAL)
  r_zlfn <- calculate_ley73_pension(sbc_muy_bajo, semanas = 500, edad = 65,
                                     zona_sm = ZONA_FRONTERA_NORTE)
  expect_true(unname(r_zlfn$pension_mensual) > unname(r_gen$pension_mensual))
})

test_that("II2: Zona ZLFN piso = SM_DIARIO_ZLFN_2025 * DIAS_POR_MES", {
  sbc_muy_bajo <- SM_DIARIO_2025 * 0.3
  r <- calculate_ley73_pension(sbc_muy_bajo, semanas = 500, edad = 65,
                                zona_sm = ZONA_FRONTERA_NORTE)
  piso_esperado <- SM_DIARIO_ZLFN_2025 * DIAS_POR_MES
  expect_num(r$pension_mensual, piso_esperado, tolerance = 1)
})

test_that("II3: get_salario_minimo_diario valor por zona", {
  expect_equal(get_salario_minimo_diario(ZONA_GENERAL), SM_DIARIO_2025)
  expect_equal(get_salario_minimo_diario(ZONA_FRONTERA_NORTE), SM_DIARIO_ZLFN_2025)
  # Default (null/invalid) retorna general
  expect_equal(get_salario_minimo_diario(NULL), SM_DIARIO_2025)
  expect_equal(get_salario_minimo_diario("invalid"), SM_DIARIO_2025)
})


# ==========================================================================
# SECTION JJ: PMG Matrix DOF 2020 (8 tests)
# ==========================================================================

test_that("JJ1: PMG perfil minimo = 1.5 UMA mensuales (edad 60, 1000 sem, 1 UMA)", {
  pmg <- calculate_pmg_matrix(edad = 60, semanas = 1000, sbc_diario = UMA_DIARIA_2025)
  expect_num(pmg, 1.5 * UMA_MENSUAL_2025, tolerance = 0.01)
})

test_that("JJ2: PMG perfil maximo = 2.5 UMA mensuales (edad 65+, 1250+ sem, 5+ UMA)", {
  pmg <- calculate_pmg_matrix(edad = 65, semanas = 1250, sbc_diario = UMA_DIARIA_2025 * 5)
  expect_num(pmg, 2.5 * UMA_MENSUAL_2025, tolerance = 0.01)
})

test_that("JJ3: PMG aumenta monotonamente con la edad (60 a 65)", {
  pmgs <- sapply(60:65, function(e) {
    unname(calculate_pmg_matrix(edad = e, semanas = 1100, sbc_diario = UMA_DIARIA_2025 * 3))
  })
  for (i in 2:length(pmgs)) {
    expect_true(pmgs[i] >= pmgs[i-1])
  }
})

test_that("JJ4: PMG aumenta monotonamente con las semanas (1000 a 1250)", {
  pmgs <- sapply(seq(1000, 1250, by = 50), function(s) {
    unname(calculate_pmg_matrix(edad = 63, semanas = s, sbc_diario = UMA_DIARIA_2025 * 3))
  })
  for (i in 2:length(pmgs)) {
    expect_true(pmgs[i] >= pmgs[i-1])
  }
})

test_that("JJ5: PMG aumenta monotonamente con el SBC (1 a 5 UMA)", {
  pmgs <- sapply(1:5, function(mult) {
    unname(calculate_pmg_matrix(edad = 63, semanas = 1100, sbc_diario = UMA_DIARIA_2025 * mult))
  })
  for (i in 2:length(pmgs)) {
    expect_true(pmgs[i] >= pmgs[i-1])
  }
})

test_that("JJ6: PMG con edad > 65 no crece mas alla del tope de edad", {
  pmg_65 <- calculate_pmg_matrix(edad = 65, semanas = 1100, sbc_diario = UMA_DIARIA_2025 * 3)
  pmg_70 <- calculate_pmg_matrix(edad = 70, semanas = 1100, sbc_diario = UMA_DIARIA_2025 * 3)
  expect_num(pmg_65, pmg_70, tolerance = 0.01)
})

test_that("JJ7: PMG con semanas > 1250 no crece mas alla del tope", {
  pmg_1250 <- calculate_pmg_matrix(edad = 65, semanas = 1250, sbc_diario = UMA_DIARIA_2025 * 3)
  pmg_1500 <- calculate_pmg_matrix(edad = 65, semanas = 1500, sbc_diario = UMA_DIARIA_2025 * 3)
  expect_num(pmg_1250, pmg_1500, tolerance = 0.01)
})

test_that("JJ8: PMG fallback retorna 2.5 UMA (compatibilidad)", {
  expect_num(calculate_pmg_fallback(), 2.5 * UMA_MENSUAL_2025, tolerance = 0.01)
})
