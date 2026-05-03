# tests/testthat/test_setup.R
# Shared test environment for all testthat test files
# Loads data, constants, utility functions, and calculation modules

# ==========================================================================
# DATA DIRECTORY DETECTION
# ==========================================================================

if (file.exists("data/articulo_167_tabla.csv")) {
  data_dir <- "data"; r_dir <- "R"
} else if (file.exists("../../data/articulo_167_tabla.csv")) {
  data_dir <- "../../data"; r_dir <- "../../R"
} else {
  stop("Cannot find project data. Run from project root or tests/testthat/.")
}

# ==========================================================================
# LOAD CSV DATA INTO GLOBAL ENVIRONMENT
# ==========================================================================

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

# ==========================================================================
# CONSTANTS (single source of truth)
# ==========================================================================

source(file.path(r_dir, "constants.R"))

# ==========================================================================
# UTILITY FUNCTIONS FROM global.R NEEDED BY SOURCED FILES
# ==========================================================================

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

# ==========================================================================
# SOURCE CALCULATION FILES
# ==========================================================================

source(file.path(r_dir, "data_tables.R"))
source(file.path(r_dir, "pmg_matrix.R"))
source(file.path(r_dir, "calculations.R"))
source(file.path(r_dir, "fondo_bienestar.R"))
