# global.R - Carga de paquetes y archivos fuente
# REQUERIDO para shinyapps.io

# ============================================================================
# CONFIGURAR PANDOC (instalado via R package)
# ============================================================================

pandoc_path <- path.expand("~/.local/share/r-pandoc/3.9")
if (dir.exists(pandoc_path)) {
  Sys.setenv(RSTUDIO_PANDOC = pandoc_path)
}

# ============================================================================
# PAQUETES REQUERIDOS
# ============================================================================

library(shiny)
library(bslib)       # Bootstrap 5 theming
library(shinyjs)     # Para navegacion del wizard
library(plotly)      # Graficos interactivos

# ============================================================================
# CARGAR DATOS ESTATICOS (UNA SOLA VEZ) - ANTES de los source files
# ============================================================================

# Tabla del Articulo 167 - Ley 73
articulo_167_tabla <<- read.csv("data/articulo_167_tabla.csv", stringsAsFactors = FALSE)

# Valores historicos de UMA
uma_data <<- read.csv("data/uma_historico.csv", stringsAsFactors = FALSE)

# Valores historicos del salario minimo
salario_minimo_data <<- read.csv("data/salario_minimo.csv", stringsAsFactors = FALSE)

# Comisiones y rendimientos de AFOREs
afore_data <<- read.csv("data/afore_comisiones.csv", stringsAsFactors = FALSE)

# Tasas de aportacion reforma 2020 (DOF 16/12/2020)
tasas_reforma_data <<- read.csv("data/tasas_reforma_2020.csv", stringsAsFactors = FALSE)

# ============================================================================
# CONSTANTES GLOBALES (from R/constants.R)
# ============================================================================

source("R/constants.R", local = FALSE)

# ============================================================================
# FUNCIONES UTILITARIAS GLOBALES
# ============================================================================

#' Null-coalescing operator (if x is NULL, return y)
`%||%` <<- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

#' Formatear numero como moneda mexicana
format_currency <<- function(x) {
  paste0("$", format(round(x, 2), big.mark = ",", nsmall = 2))
}

#' Formatear numero como moneda para LaTeX/PDF
format_currency_latex <<- function(x) {
  paste0("\\$", format(round(x, 2), big.mark = ",", nsmall = 2))
}

#' Formatear numero como porcentaje
format_percent <<- function(x) {
  paste0(round(x * 100, 1), "%")
}

#' Formatear numero como porcentaje para LaTeX/PDF
format_percent_latex <<- function(x) {
  paste0(round(x * 100, 1), "\\%")
}

#' Obtener valor de UMA para un ano especifico
get_uma <<- function(anio) {
  row <- uma_data[uma_data$anio == anio, ]
  if (nrow(row) == 0) {
    row <- uma_data[uma_data$anio == max(uma_data$anio), ]
  }
  return(row$uma_diaria)
}

#' Obtener salario minimo para un ano especifico
get_salario_minimo <<- function(anio) {
  row <- salario_minimo_data[salario_minimo_data$anio == anio, ]
  if (nrow(row) == 0) {
    row <- salario_minimo_data[salario_minimo_data$anio == max(salario_minimo_data$anio), ]
  }
  return(row$sm_diario)
}

#' Obtener umbral del Fondo Bienestar para un ano
#'
#' Para anos conocidos (2024-2026) usa valores oficiales/estimados.
#' Para anos futuros (>2026) extrapola al 3.5% anual desde el ultimo
#' valor conocido. Simplificacion documentada: el IMSS ajusta en base
#' al SBC promedio real, que historicamente crece ~3-4% real.
#'
#' @param anio Ano para el cual obtener el umbral
#' @return Umbral mensual en pesos
get_umbral_fondo_bienestar <<- function(anio) {
  umbrales <- c(
    "2024" = 16777.68,
    "2025" = 17364,
    "2026" = 18050  # estimado
  )
  if (as.character(anio) %in% names(umbrales)) {
    return(umbrales[as.character(anio)])
  }
  # Extrapolacion: 3.5% anual desde ultimo valor conocido
  ultimo_anio <- 2026
  ultimo_valor <- 18050
  tasa_crecimiento <- 0.035
  if (anio > ultimo_anio) {
    return(ultimo_valor * (1 + tasa_crecimiento)^(anio - ultimo_anio))
  }
  # Para anos antes de 2024, usar 2024

  return(umbrales["2024"])
}

# ============================================================================
# CARGAR ARCHIVOS FUENTE (DESPUES de datos y constantes)
# ============================================================================

source("R/data_tables.R")
source("R/pmg_matrix.R")
source("R/calculations.R")
source("R/fondo_bienestar.R")
source("R/ui_theme.R")
source("R/ui_landing.R")
source("R/ui_results.R")
source("R/ui_antes_despues.R")
source("R/ui_components.R")
source("R/ui_download.R")

source("R/document_generators.R")
