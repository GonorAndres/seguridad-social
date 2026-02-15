# tests/testthat/test_calculations.R
# Comprehensive actuarial test suite for pension simulator
# 92 test cases across 13 sections (A-M)
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

# Constants (mirrored from global.R)
ANIO_ACTUAL           <<- 2025
UMA_DIARIA_2025       <<- 113.14
UMA_MENSUAL_2025      <<- 3439.46
SM_DIARIO_2025        <<- 278.80
SM_MENSUAL_2025       <<- 8474.52
UMBRAL_FONDO_BIENESTAR_2025 <<- 17364
TOPE_SBC_DIARIO       <<- UMA_DIARIA_2025 * 25
RENDIMIENTO_CONSERVADOR <<- 0.03
RENDIMIENTO_BASE      <<- 0.04
RENDIMIENTO_OPTIMISTA <<- 0.05
FACTORES_CESANTIA     <<- c("60"=0.75, "61"=0.80, "62"=0.85,
                            "63"=0.90, "64"=0.95, "65"=1.00)

# Utility functions from global.R needed by sourced files
format_currency <<- function(x) {
  paste0("$", format(round(x, 2), big.mark = ",", nsmall = 2))
}
format_percent <<- function(x) paste0(round(x * 100, 1), "%")
get_umbral_fondo_bienestar <<- function(anio) {
  umbrales <- c("2024" = 16777.68, "2025" = 17364, "2026" = 18050)
  if (as.character(anio) %in% names(umbrales)) return(umbrales[as.character(anio)])
  return(umbrales[length(umbrales)])
}
`%||%` <<- function(x, y) if (is.null(x) || length(x) == 0) y else x

# Source calculation files
source(file.path(r_dir, "data_tables.R"))
source(file.path(r_dir, "calculations.R"))
source(file.path(r_dir, "fondo_bienestar.R"))

# Convenience constant
DIAS_POR_MES <- 30.4375  # 365.25 / 12

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

test_that("D1: 2025 uses patron rate 7.75%", {
  r <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2025)
  # tasa_total = 0.0775 + 0.01125 + 0.00225 = 0.091
  expect_num(r$tasa_total, 0.091, tolerance = 1e-6)
  expect_num(r$aportacion_total, 20000 * 0.091, tolerance = 0.01)
})

test_that("D2: 2023 uses patron rate 6.20%", {
  r <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2023)
  expected_total <- 0.0620 + 0.01125 + 0.00225  # = 0.0755
  expect_num(r$tasa_total, expected_total, tolerance = 1e-6)
})

test_that("D3: 2030 and beyond uses patron rate 12%", {
  r_2030 <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2030)
  r_2035 <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2035)
  expected_total <- 0.12 + 0.01125 + 0.00225  # = 0.1335
  expect_num(r_2030$tasa_total, expected_total, tolerance = 1e-6)
  expect_num(r_2035$tasa_total, expected_total, tolerance = 1e-6)
})

test_that("D4: Year before 2023 defaults to 2025 rate", {
  r <- calculate_aportacion_obligatoria(salario_mensual = 20000, anio = 2020)
  expect_num(r$tasa_total, 0.091, tolerance = 1e-6)
})

test_that("D5: Salary above tope is capped", {
  tope_mensual <- TOPE_SBC_DIARIO * 30
  r <- calculate_aportacion_obligatoria(salario_mensual = 200000, anio = 2025)
  expect_num(r$salario_cotizable, tope_mensual)
  expect_true(unname(r$aportacion_total) < 200000 * unname(r$tasa_total))
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
  # Male, age 65: esperanza = 17.0, meses = 204
  r <- calculate_retiro_programado(saldo = 2000000, edad = 65, genero = "M")
  expect_num(r$esperanza_vida, 17.0)
  expect_num(r$meses_esperados, 204)
  expected_pension <- 2000000 / 204
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
  meses <- 204  # male, age 65

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

test_that("G2: Cuota mensual = SBC_M40_real * 30 * 10.075%", {
  base <- calculate_ley73_pension(sbc_promedio_diario = 400, semanas = 1200, edad = 65)
  sbc_m40 <- 1000
  r <- calculate_modalidad_40(
    pension_actual = base, sbc_actual = 400, sbc_m40 = sbc_m40,
    semanas_actuales = 1200, semanas_m40 = 260,
    edad_actual = 60, edad_retiro = 65
  )
  expected_cuota <- sbc_m40 * 30 * 0.10075
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

test_that("H3: Less than 1000 weeks is not eligible", {
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

test_that("K1: get_esperanza_vida male at 65 = 17.0", {
  expect_num(get_esperanza_vida(65, "M"), 17.0)
})

test_that("K2: get_esperanza_vida female at 65 = 20.0", {
  expect_num(get_esperanza_vida(65, "F"), 20.0)
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
  ev70 <- unname(get_esperanza_vida(70, "M"))  # 13.4
  ev75 <- unname(get_esperanza_vida(75, "M"))  # 10.5
  expect_true(ev71 < ev70)
  expect_true(ev71 > ev75)
})

test_that("K5: Life expectancy below minimum age extrapolates upward", {
  ev55 <- unname(get_esperanza_vida(55, "M"))
  ev60 <- unname(get_esperanza_vida(60, "M"))  # 21.0
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

  # Known AFORE: comision as decimal
  com <- get_afore_comision("XXI Banorte")
  expect_num(com, 0.51 / 100, tolerance = 1e-6)

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

test_that("L1: Different AFORE -> different comision -> different projected balance", {
  args <- list(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 45, edad_retiro = 65,
    semanas_actuales = 800, genero = "M",
    aportacion_voluntaria = 0, escenario = "base"
  )
  r1 <- do.call(calculate_pension_with_fondo, c(args, afore_nombre = "XXI Banorte"))
  r2 <- do.call(calculate_pension_with_fondo, c(args, afore_nombre = "Profuturo"))
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
  # semanas_actuales=739 -> semanas_al_retiro=999 (not eligible)
  # semanas_actuales=741 -> semanas_al_retiro=1001 (eligible)
  r_below <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 739, genero = "M"
  )
  r_above <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 15000,
    edad_actual = 60, edad_retiro = 65,
    semanas_actuales = 741, genero = "M"
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

test_that("M16: Semanas 1000 at retiro -> eligible; 999 -> NOT eligible", {
  r_1000 <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 1000,
    sbc_promedio_mensual = 15000
  )
  expect_true(r_1000$elegible)

  r_999 <- check_fondo_eligibility(
    regimen = "ley97", edad = 65, semanas = 999,
    sbc_promedio_mensual = 15000
  )
  expect_false(r_999$elegible)
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
