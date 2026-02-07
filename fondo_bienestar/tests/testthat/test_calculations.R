# tests/testthat/test_calculations.R
# Unit tests para las formulas de pension

library(testthat)

# Cargar funciones (asumiendo que se ejecuta desde la raiz del proyecto)
source("../../global.R")

# ============================================================================
# TESTS LEY 73
# ============================================================================

test_that("Ley 73: Lookup Articulo 167 funciona correctamente", {
  # Grupo salarial 1.0 debe retornar cuantia basica 80%
  result <- lookup_articulo_167(1.0)
  expect_equal(result$cuantia_basica, 0.80)
  expect_equal(result$incremento_anual, 0.00563)

  # Grupo salarial 2.15 debe retornar el grupo 2.01-2.25
  result <- lookup_articulo_167(2.15)
  expect_equal(result$cuantia_basica, 0.3765)
  expect_equal(result$incremento_anual, 0.01756)

  # Grupo salarial mayor a 6 debe retornar el ultimo grupo
  result <- lookup_articulo_167(10.0)
  expect_equal(result$cuantia_basica, 0.13)
  expect_equal(result$incremento_anual, 0.0245)
})

test_that("Ley 73: No elegible con menos de 500 semanas", {
  result <- calculate_ley73_pension(
    sbc_promedio = 300,
    semanas = 400,
    edad = 65,
    sm_vigente = SM_DIARIO_2025
  )

  expect_false(result$elegible)
  expect_equal(result$pension_mensual, 0)
})

test_that("Ley 73: Calculo correcto con 1800 semanas y 65 anos", {
  # Ejemplo del plan: SBC promedio $500/dia, 1800 semanas, edad 65
  result <- calculate_ley73_pension(
    sbc_promedio = 500,
    semanas = 1800,
    edad = 65,
    sm_vigente = 278.80,  # SM 2025
    tipo_pension = "vejez"
  )

  expect_true(result$elegible)
  expect_true(result$pension_mensual > 10000)  # Deberia ser ~$12,457
  expect_true(result$pension_mensual < 15000)
  expect_equal(result$detalles$factor_edad, 1.0)  # 65 anos = 100%
})

test_that("Ley 73: Factor de cesantia aplicado correctamente", {
  result_60 <- calculate_ley73_pension(
    sbc_promedio = 400,
    semanas = 1000,
    edad = 60,
    tipo_pension = "cesantia"
  )

  result_65 <- calculate_ley73_pension(
    sbc_promedio = 400,
    semanas = 1000,
    edad = 65,
    tipo_pension = "vejez"
  )

  # La pension a los 60 debe ser menor (75%) que a los 65 (100%)
  expect_true(result_60$elegible)
  expect_true(result_65$elegible)
  expect_true(result_60$pension_mensual < result_65$pension_mensual)
  expect_equal(result_60$detalles$factor_edad, 0.75)
})

test_that("Ley 73: Pension minima aplicada cuando corresponde", {
  # Salario muy bajo que resultaria en pension menor al minimo
  result <- calculate_ley73_pension(
    sbc_promedio = 100,  # Muy bajo
    semanas = 500,
    edad = 65
  )

  expect_true(result$elegible)
  expect_true(result$aplica_pension_minima)
  expect_true(result$pension_mensual >= SM_MENSUAL_2025)
})

# ============================================================================
# TESTS LEY 97
# ============================================================================

test_that("Ley 97: Proyeccion de saldo AFORE funciona", {
  result <- project_afore_balance(
    saldo_actual = 100000,
    aportacion_mensual = 1000,
    aportacion_voluntaria = 500,
    anos_al_retiro = 10,
    rendimiento_real = 0.04,
    comision_afore = 0.0053
  )

  expect_true(result$saldo_proyectado > 100000)  # Debe crecer
  expect_true(result$saldo_proyectado > 200000)  # Con aportaciones
})

test_that("Ley 97: No elegible con menos de 1000 semanas", {
  result <- calculate_ley97_pension(
    saldo_afore = 500000,
    edad_retiro = 65,
    genero = "M",
    semanas = 800
  )

  expect_false(result$elegible)
  expect_equal(result$pension_mensual, 0)
})

test_that("Ley 97: Calculo de pension con saldo suficiente", {
  result <- calculate_ley97_pension(
    saldo_afore = 1000000,
    edad_retiro = 65,
    genero = "M",
    semanas = 1200
  )

  expect_true(result$elegible)
  expect_true(result$pension_mensual > 0)
})

# ============================================================================
# TESTS FONDO BIENESTAR
# ============================================================================

test_that("Fondo Bienestar: No elegible para Ley 73", {
  result <- check_fondo_bienestar_eligibility(
    regimen = "ley73",
    sbc_promedio_mensual = 15000,
    edad = 65,
    semanas = 1500
  )

  expect_false(result$elegible)
  expect_equal(result$tipo_exclusion, "regimen")
})

test_that("Fondo Bienestar: No elegible si salario > umbral", {
  umbral <- get_umbral_fondo_bienestar(2025)

  result <- check_fondo_bienestar_eligibility(
    regimen = "ley97",
    sbc_promedio_mensual = umbral + 1000,  # Por encima del umbral
    edad = 65,
    semanas = 1200
  )

  expect_false(result$elegible)
  expect_equal(result$tipo_exclusion, "salario")
})

test_that("Fondo Bienestar: Elegible si cumple todos los requisitos", {
  umbral <- get_umbral_fondo_bienestar(2025)

  result <- check_fondo_bienestar_eligibility(
    regimen = "ley97",
    sbc_promedio_mensual = umbral - 2000,  # Por debajo del umbral
    edad = 65,
    semanas = 1200
  )

  expect_true(result$elegible)
  expect_null(result$tipo_exclusion)
})

test_that("Fondo Bienestar: Complemento calculado correctamente", {
  elegibilidad <- list(elegible = TRUE, umbral = 17364, tipo_exclusion = NULL)

  result <- calculate_fondo_bienestar_complement(
    pension_afore = 5000,
    sbc_promedio_mensual = 15000,
    elegibilidad = elegibilidad
  )

  expect_true(result$aplica)
  expect_equal(result$complemento, 10000)  # 15000 - 5000
  expect_equal(result$pension_total, 15000)  # 100% reemplazo
})

test_that("Fondo Bienestar: Sin complemento si pension >= salario", {
  elegibilidad <- list(elegible = TRUE, umbral = 17364, tipo_exclusion = NULL)

  result <- calculate_fondo_bienestar_complement(
    pension_afore = 16000,
    sbc_promedio_mensual = 15000,
    elegibilidad = elegibilidad
  )

  expect_false(result$aplica)
  expect_equal(result$complemento, 0)
  expect_equal(result$pension_total, 16000)  # Pension AFORE sin cambio
})

# ============================================================================
# TESTS DE VALIDACION
# ============================================================================

test_that("Validacion: Detecta edad invalida", {
  result <- validar_entrada(
    edad = 150,  # Invalido
    semanas = 500,
    sbc = 15000
  )

  expect_false(result$valido)
  expect_true(length(result$errores) > 0)
})

test_that("Validacion: Detecta semanas inconsistentes con edad", {
  result <- validar_entrada(
    edad = 25,
    semanas = 2000,  # Imposible con 25 anos
    sbc = 15000
  )

  expect_false(result$valido)
})

test_that("Validacion: Advierte sobre tope de cotizacion", {
  result <- validar_entrada(
    edad = 50,
    semanas = 1500,
    sbc = 100000  # Excede tope
  )

  expect_true(length(result$advertencias) > 0)
})

# ============================================================================
# TESTS DE FUNCIONES AUXILIARES
# ============================================================================

test_that("get_esperanza_vida retorna valores razonables", {
  ev_60_m <- get_esperanza_vida(60, "M")
  ev_60_f <- get_esperanza_vida(60, "F")
  ev_70_m <- get_esperanza_vida(70, "M")

  expect_true(ev_60_m > 15 && ev_60_m < 30)
  expect_true(ev_60_f > ev_60_m)  # Mujeres viven mas
  expect_true(ev_70_m < ev_60_m)  # Mayor edad = menor esperanza
})

test_that("get_umbral_fondo_bienestar retorna valores por ano", {
  umbral_2024 <- get_umbral_fondo_bienestar(2024)
  umbral_2025 <- get_umbral_fondo_bienestar(2025)

  expect_equal(umbral_2024, 16777.68)
  expect_equal(umbral_2025, 17364)
})

test_that("format_currency formatea correctamente", {
  expect_equal(format_currency(15000), "$15,000.00")
  expect_equal(format_currency(1234567.89), "$1,234,567.89")
})

test_that("determinar_regimen clasifica correctamente", {
  expect_equal(determinar_regimen("1990-01-01"), "ley73")
  expect_equal(determinar_regimen("2000-01-01"), "ley97")
  expect_equal(determinar_regimen("1997-06-30"), "ley73")
  expect_equal(determinar_regimen("1997-07-01"), "ley97")
})
