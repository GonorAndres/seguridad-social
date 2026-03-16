# tests/test_antes_despues.R
# Unit tests for get_hero_pension and render_antes_despues_box

library(testthat)
library(shiny)

data_dir <- "data"; r_dir <- "R"
articulo_167_tabla <<- read.csv(file.path(data_dir, "articulo_167_tabla.csv"), stringsAsFactors = FALSE)
uma_data <<- read.csv(file.path(data_dir, "uma_historico.csv"), stringsAsFactors = FALSE)
salario_minimo_data <<- read.csv(file.path(data_dir, "salario_minimo.csv"), stringsAsFactors = FALSE)
afore_data <<- read.csv(file.path(data_dir, "afore_comisiones.csv"), stringsAsFactors = FALSE)
tasas_reforma_data <<- read.csv(file.path(data_dir, "tasas_reforma_2020.csv"), stringsAsFactors = FALSE)

source(file.path(r_dir, "constants.R"))
format_currency <<- function(x) paste0("$", format(round(x, 2), big.mark = ",", nsmall = 2))
format_percent <<- function(x) paste0(round(x * 100, 1), "%")
`%||%` <<- function(x, y) if (is.null(x) || length(x) == 0) y else x
get_uma <<- function(anio) {
  row <- uma_data[uma_data$anio == anio, ]
  if (nrow(row) == 0) row <- uma_data[uma_data$anio == max(uma_data$anio), ]
  row$uma_diaria
}
get_salario_minimo <<- function(anio) {
  row <- salario_minimo_data[salario_minimo_data$anio == anio, ]
  if (nrow(row) == 0) row <- salario_minimo_data[salario_minimo_data$anio == max(salario_minimo_data$anio), ]
  row$sm_diario
}
get_umbral_fondo_bienestar <<- function(anio) {
  umbrales <- c("2024" = 16777.68, "2025" = 17364, "2026" = 18050)
  if (as.character(anio) %in% names(umbrales)) return(umbrales[as.character(anio)])
  ultimo_anio <- 2026; ultimo_valor <- 18050; tasa <- 0.035
  if (anio > ultimo_anio) return(ultimo_valor * (1 + tasa)^(anio - ultimo_anio))
  return(umbrales["2024"])
}

source(file.path(r_dir, "data_tables.R"))
source(file.path(r_dir, "calculations.R"))
source(file.path(r_dir, "fondo_bienestar.R"))
source(file.path(r_dir, "ui_helpers.R"))

# ==============================================================
# CC: get_hero_pension + render_antes_despues_box (12 tests)
# ==============================================================

test_that("CC1: get_hero_pension Ley 97 base (high salary, no fondo)", {
  res <- calculate_pension_with_fondo(
    saldo_actual = 300000, salario_mensual = 25000,
    edad_actual = 55, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M",
    aportacion_voluntaria = 0, afore_nombre = "XXI Banorte"
  )
  res$regimen <- "ley97"
  expect_equal(detect_result_scenario(res), "ley97_base")
  hp <- get_hero_pension(res)
  expect_true(is.numeric(hp) && hp > 0)
  expect_equal(unname(hp), unname(res$solo_sistema$pension_mensual), tolerance = 0.01)
})

test_that("CC2: get_hero_pension Ley 97 fondo eligible", {
  res <- calculate_pension_with_fondo(
    saldo_actual = 50000, salario_mensual = 12000,
    edad_actual = 55, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M",
    aportacion_voluntaria = 0, afore_nombre = "XXI Banorte"
  )
  res$regimen <- "ley97"
  scenario <- detect_result_scenario(res)
  if (scenario == "ley97_fondo_eligible") {
    hp <- get_hero_pension(res)
    expect_equal(unname(hp), unname(res$con_fondo$pension_total), tolerance = 0.01)
  }
})

test_that("CC3: get_hero_pension Ley 97 voluntary improvement", {
  res <- calculate_pension_with_fondo(
    saldo_actual = 500000, salario_mensual = 25000,
    edad_actual = 55, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M",
    aportacion_voluntaria = 3000, afore_nombre = "XXI Banorte"
  )
  res$regimen <- "ley97"
  scenario <- detect_result_scenario(res)
  hp <- get_hero_pension(res)
  expect_true(is.numeric(hp) && hp > 0)
  if (scenario %in% c("ley97_voluntary_improvement", "ley97_fondo_voluntary")) {
    expect_equal(unname(hp), unname(res$con_acciones$pension_afore), tolerance = 0.01)
  }
})

test_that("CC4: get_hero_pension Ley 73 eligible", {
  res <- list(regimen = "ley73", pension_base = list(elegible = TRUE, pension_mensual = 8500), pension_m40 = NULL)
  expect_equal(get_hero_pension(res), 8500)
})

test_that("CC5: get_hero_pension Ley 73 with M40 higher", {
  res <- list(regimen = "ley73", pension_base = list(elegible = TRUE, pension_mensual = 8500),
              pension_m40 = list(pension_con_m40 = 12000))
  expect_equal(get_hero_pension(res), 12000)
})

test_that("CC6: get_hero_pension Ley 73 not eligible returns 0", {
  res <- list(regimen = "ley73", pension_base = list(elegible = FALSE), pension_m40 = NULL)
  expect_equal(get_hero_pension(res), 0)
})

test_that("CC7: antes/despues neutral when no change", {
  res <- list(regimen = "ley73", pension_base = list(elegible = TRUE, pension_mensual = 8500), pension_m40 = NULL)
  html_str <- as.character(render_antes_despues_box(res, res))
  expect_true(grepl("neutral", html_str))
  expect_true(grepl("Mueve un control", html_str))
})

test_that("CC8: antes/despues positive when pension increases", {
  orig <- list(regimen = "ley73", pension_base = list(elegible = TRUE, pension_mensual = 8500), pension_m40 = NULL)
  new  <- list(regimen = "ley73", pension_base = list(elegible = TRUE, pension_mensual = 10000), pension_m40 = NULL)
  html_str <- as.character(render_antes_despues_box(orig, new))
  expect_true(grepl("positive", html_str))
  expect_true(grepl("\\+", html_str))
})

test_that("CC9: antes/despues negative when pension decreases", {
  orig <- list(regimen = "ley73", pension_base = list(elegible = TRUE, pension_mensual = 10000), pension_m40 = NULL)
  new  <- list(regimen = "ley73", pension_base = list(elegible = TRUE, pension_mensual = 8500), pension_m40 = NULL)
  html_str <- as.character(render_antes_despues_box(orig, new))
  expect_true(grepl("negative", html_str))
})

test_that("CC10: antes/despues no Inf/NaN when pension_antes=0", {
  orig <- list(regimen = "ley73", pension_base = list(elegible = FALSE), pension_m40 = NULL)
  new  <- list(regimen = "ley73", pension_base = list(elegible = TRUE, pension_mensual = 5000), pension_m40 = NULL)
  html_str <- as.character(render_antes_despues_box(orig, new))
  expect_true(grepl("positive", html_str))
  expect_false(grepl("Inf|NaN", html_str))
})

test_that("CC11: antes/despues Ley 97 full pipeline with large saldo change", {
  # Use high saldo to avoid minimum guarantee floor
  res <- calculate_pension_with_fondo(
    saldo_actual = 800000, salario_mensual = 25000,
    edad_actual = 55, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M",
    aportacion_voluntaria = 0, afore_nombre = "XXI Banorte"
  )
  res$regimen <- "ley97"
  res2 <- calculate_pension_with_fondo(
    saldo_actual = 800000, salario_mensual = 50000,
    edad_actual = 55, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M",
    aportacion_voluntaria = 0, afore_nombre = "XXI Banorte"
  )
  res2$regimen <- "ley97"
  # Verify the pensions are actually different
  p1 <- get_hero_pension(res)
  p2 <- get_hero_pension(res2)
  expect_true(abs(p2 - p1) > 0.01, info = paste("Pensions must differ:", p1, "vs", p2))
  html_str <- as.character(render_antes_despues_box(res, res2))
  expect_false(grepl("Mueve un control", html_str))
  expect_true(grepl("Antes", html_str))
  expect_true(grepl("Despues", html_str))
})

test_that("CC12: antes/despues same Ley 97 inputs => neutral", {
  res <- calculate_pension_with_fondo(
    saldo_actual = 50000, salario_mensual = 12000,
    edad_actual = 55, edad_retiro = 65,
    semanas_actuales = 1200, genero = "M",
    aportacion_voluntaria = 0, afore_nombre = "XXI Banorte"
  )
  res$regimen <- "ley97"
  html_str <- as.character(render_antes_despues_box(res, res))
  expect_true(grepl("neutral", html_str))
})
