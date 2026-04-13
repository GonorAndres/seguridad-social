# R/pmg_matrix.R - Pension Minima Garantizada (PMG) Ley 97 post-reforma DOF 2020
# Simulador de Pension IMSS + Fondo Bienestar
#
# Fuente: DOF 16-dic-2020, reforma LSS Art. 170 + CONSAR "Guia PMG 2021"
# La reforma 2020 sustituyo la PMG fija de 1 SMG por una matriz en funcion de:
#   1. Edad al momento del retiro (60-65+)
#   2. Semanas cotizadas (1000, 1150, 1250+)
#   3. SBC promedio (en UMAs)
#
# Los valores publicos publicados por CONSAR se encuentran en rango:
#   - Perfil minimo (60 anos, 1000 semanas, 1 UMA SBC): ~1.5 UMA mensuales
#   - Perfil maximo (65 anos, 1250+ semanas, 5+ UMA SBC): ~2.5 UMA mensuales
#
# Implementacion: aproximacion lineal indexada a UMA vigente. Esta es una
# simplificacion de la matriz oficial de 6x3x5 = 90 celdas; conserva los
# extremos y la monotonia en las tres dimensiones. Para rigor regulatorio
# exacto, sustituir con la tabla publicada anual por CONSAR.

# ============================================================================
# COMPONENTES DE LA MATRIZ PMG
# ============================================================================

#' Factor de edad para PMG (0 a 1)
#' @param edad Edad al retiro
#' @return Factor entre 0 (60 anos) y 1 (65+ anos)
pmg_factor_edad <- function(edad) {
  edad <- max(60, min(65, edad))
  (edad - 60) / 5
}

#' Factor de semanas para PMG (0 a 1)
#' @param semanas Semanas cotizadas al retiro
#' @return Factor entre 0 (1000 semanas) y 1 (1250+ semanas)
pmg_factor_semanas <- function(semanas) {
  max(0, min(1, (semanas - 1000) / 250))
}

#' Factor de SBC para PMG (0 a 1)
#' @param sbc_uma SBC diario en multiplos de UMA
#' @return Factor entre 0 (1 UMA) y 1 (5+ UMA)
pmg_factor_sbc <- function(sbc_uma) {
  max(0, min(1, (sbc_uma - 1) / 4))
}

# ============================================================================
# CALCULO DE PMG (MATRIZ)
# ============================================================================

#' Calcular Pension Minima Garantizada via matriz DOF 2020
#'
#' Aproxima la matriz PMG publicada por CONSAR post-reforma 2020.
#' Rango de salida: 1.5 UMA mensuales (perfil basico) a 2.5 UMA
#' mensuales (perfil contributivo maximo).
#'
#' @param edad Edad al momento del retiro
#' @param semanas Semanas cotizadas al retiro
#' @param sbc_diario SBC diario del trabajador (pesos)
#' @param uma_mensual UMA mensual vigente (default: 2025)
#' @return Pension minima garantizada mensual en pesos
calculate_pmg_matrix <- function(edad,
                                  semanas,
                                  sbc_diario,
                                  uma_mensual = UMA_MENSUAL_2025,
                                  uma_diaria = UMA_DIARIA_2025) {
  # Sanitizar entradas
  if (is.null(edad) || is.na(edad)) edad <- 65
  if (is.null(semanas) || is.na(semanas)) semanas <- 1000
  if (is.null(sbc_diario) || is.na(sbc_diario)) sbc_diario <- uma_diaria

  sbc_uma <- sbc_diario / uma_diaria

  # Factores normalizados [0, 1]
  f_edad <- pmg_factor_edad(edad)
  f_semanas <- pmg_factor_semanas(semanas)
  f_sbc <- pmg_factor_sbc(sbc_uma)

  # Multiplicador de UMA mensual
  # Base 1.5 + hasta 0.4 por edad + 0.3 por semanas + 0.3 por SBC = max 2.5
  factor_pmg <- 1.5 + 0.4 * f_edad + 0.3 * f_semanas + 0.3 * f_sbc

  return(uma_mensual * factor_pmg)
}

#' PMG fallback simple (piso conservador 2.5 UMA)
#'
#' Se usa si calculate_pmg_matrix falla o para validaciones cruzadas.
#' Equivale al tope superior de la matriz (perfil contributivo maximo).
#'
#' @return Pension minima garantizada mensual (2.5 UMA mensuales)
calculate_pmg_fallback <- function(uma_mensual = UMA_MENSUAL_2025) {
  return(uma_mensual * 2.5)
}
