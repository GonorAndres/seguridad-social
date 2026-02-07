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
library(dplyr)       # Manipulacion de datos
library(scales)      # Formateo de numeros

# ============================================================================
# CARGAR ARCHIVOS FUENTE
# ============================================================================

source("R/data_tables.R")
source("R/calculations.R")
source("R/fondo_bienestar.R")
source("R/ui_helpers.R")

# ============================================================================
# CARGAR DATOS ESTATICOS (UNA SOLA VEZ)
# ============================================================================

# Tabla del Articulo 167 - Ley 73
articulo_167_tabla <- read.csv("data/articulo_167_tabla.csv", stringsAsFactors = FALSE)

# Valores historicos de UMA
uma_data <- read.csv("data/uma_historico.csv", stringsAsFactors = FALSE)

# Valores historicos del salario minimo
salario_minimo_data <- read.csv("data/salario_minimo.csv", stringsAsFactors = FALSE)

# Comisiones y rendimientos de AFOREs
afore_data <- read.csv("data/afore_comisiones.csv", stringsAsFactors = FALSE)

# ============================================================================
# CONSTANTES GLOBALES
# ============================================================================

# Ano actual para calculos
ANIO_ACTUAL <- 2025

# UMA 2025
UMA_DIARIA_2025 <- 113.14
UMA_MENSUAL_2025 <- 3439.46

# Salario minimo 2025
SM_DIARIO_2025 <- 278.80
SM_MENSUAL_2025 <- 8474.52

# Umbral Fondo Bienestar 2025 (promedio SBC IMSS)
UMBRAL_FONDO_BIENESTAR_2025 <- 17364

# Tope de cotizacion (25 UMAs)
TOPE_SBC_DIARIO <- UMA_DIARIA_2025 * 25  # ~2828.50

# Escenarios de rendimiento real
RENDIMIENTO_CONSERVADOR <- 0.03  # 3%
RENDIMIENTO_BASE <- 0.04         # 4%
RENDIMIENTO_OPTIMISTA <- 0.05    # 5%

# Factores de edad para cesantia (Ley 73)
FACTORES_CESANTIA <- c(
  "60" = 0.75,
  "61" = 0.80,
  "62" = 0.85,
  "63" = 0.90,
  "64" = 0.95,
  "65" = 1.00
)

# Colores del tema
COLOR_NAVY <- "#1a365d"
COLOR_TEAL <- "#319795"

# ============================================================================
# FUNCIONES UTILITARIAS GLOBALES
# ============================================================================

#' Formatear numero como moneda mexicana
#' @param x Numero a formatear
#' @return String formateado como "$X,XXX.XX"
format_currency <- function(x) {
  paste0("$", format(round(x, 2), big.mark = ",", nsmall = 2))
}

#' Formatear numero como moneda para LaTeX/PDF
#' @param x Numero a formatear
#' @return String formateado con $ escapado para LaTeX
format_currency_latex <- function(x) {
  paste0("\\$", format(round(x, 2), big.mark = ",", nsmall = 2))
}

#' Formatear numero como porcentaje
#' @param x Numero a formatear (0.05 = 5%)
#' @return String formateado como "5.0%"
format_percent <- function(x) {
  paste0(round(x * 100, 1), "%")
}

#' Formatear numero como porcentaje para LaTeX/PDF
#' @param x Numero a formatear (0.05 = 5%)
#' @return String formateado con % escapado para LaTeX
format_percent_latex <- function(x) {
  paste0(round(x * 100, 1), "\\%")
}

#' Obtener valor de UMA para un ano especifico
#' @param anio Ano a consultar
#' @return UMA diaria del ano, o el mas reciente si no existe
get_uma <- function(anio) {
  row <- uma_data[uma_data$anio == anio, ]
  if (nrow(row) == 0) {
    # Retornar el mas reciente
    row <- uma_data[uma_data$anio == max(uma_data$anio), ]
  }
  return(row$uma_diaria)
}

#' Obtener salario minimo para un ano especifico
#' @param anio Ano a consultar
#' @return Salario minimo diario del ano
get_salario_minimo <- function(anio) {
  row <- salario_minimo_data[salario_minimo_data$anio == anio, ]
  if (nrow(row) == 0) {
    row <- salario_minimo_data[salario_minimo_data$anio == max(salario_minimo_data$anio), ]
  }
  return(row$sm_diario)
}

#' Obtener umbral del Fondo Bienestar para un ano
#' @param anio Ano a consultar
#' @return Umbral mensual en pesos
get_umbral_fondo_bienestar <- function(anio) {
  umbrales <- c(
    "2024" = 16777.68,
    "2025" = 17364,
    "2026" = 18050  # estimado
  )
  if (as.character(anio) %in% names(umbrales)) {
    return(umbrales[as.character(anio)])
  }
  # Retornar el mas reciente conocido

return(umbrales[length(umbrales)])
}
