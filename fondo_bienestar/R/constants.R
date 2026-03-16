# R/constants.R - Single source of truth for all project constants
# Simulador de Pension IMSS + Fondo Bienestar
#
# No Shiny dependency. Sourced by both global.R and tests.
# Uses plain <- assignment; global.R sources with local = FALSE.

# ============================================================================
# ACTUARIAL CONSTANTS
# ============================================================================

DIAS_POR_MES <- 30.4375          # 365.25 / 12, actuarial standard
SEMANAS_POR_ANO <- 52
EDAD_MINIMA_TRABAJO <- 18
DENSIDAD_COTIZACION_DEFAULT <- 0.60
MAX_SEMANAS_M40 <- 260           # 5 years max for Modalidad 40
FACTOR_SBC_M40 <- 0.8            # 80% of SBC cap for M40 simulation
SALARIO_MINIMO_INPUT <- 1000     # Minimum salary input validation ($1,000 MXN)

# ============================================================================
# REGULATORY CONSTANTS (2025)
# ============================================================================

ANIO_ACTUAL <- 2025

# UMA 2025
UMA_DIARIA_2025 <- 113.14
UMA_MENSUAL_2025 <- 3439.46

# Salario minimo 2025
SM_DIARIO_2025 <- 278.80
SM_MENSUAL_2025 <- 8474.52

# Fondo Bienestar (DOF 01/05/2024)
UMBRAL_FONDO_BIENESTAR_2025 <- 17364   # Promedio SBC IMSS
SEMANAS_MIN_FONDO_BIENESTAR <- 1000    # Fixed per decree, NOT the transitional Ley 97 schedule

# Tope de cotizacion (25 UMAs)
TOPE_SBC_DIARIO <- UMA_DIARIA_2025 * 25  # ~2828.50

# Pension minima garantizada Ley 97 (2.5 UMA mensuales)
PENSION_MINIMA_LEY97 <- UMA_MENSUAL_2025 * 2.5

# ============================================================================
# REGIME & SCENARIO IDENTIFIERS
# ============================================================================

REGIMEN_LEY73 <- "ley73"
REGIMEN_LEY97 <- "ley97"

# Escenarios de rendimiento
ESCENARIO_CONSERVADOR <- "conservador"
ESCENARIO_BASE <- "base"
ESCENARIO_OPTIMISTA <- "optimista"

# Rendimiento real por escenario
RENDIMIENTO_CONSERVADOR <- 0.03  # 3%
RENDIMIENTO_BASE <- 0.04         # 4%
RENDIMIENTO_OPTIMISTA <- 0.05    # 5%

RENDIMIENTO_POR_ESCENARIO <- c(
  conservador = RENDIMIENTO_CONSERVADOR,
  base = RENDIMIENTO_BASE,
  optimista = RENDIMIENTO_OPTIMISTA
)

# Result scenario identifiers (from detect_result_scenario)
SCENARIO_FONDO_VOLUNTARY     <- "ley97_fondo_voluntary"
SCENARIO_FONDO_ELIGIBLE      <- "ley97_fondo_eligible"
SCENARIO_MINIMO              <- "ley97_minimo"
SCENARIO_VOLUNTARY_IMPROVEMENT <- "ley97_voluntary_improvement"
SCENARIO_BASE                <- "ley97_base"

# Factores de edad para cesantia (Ley 73)
FACTORES_CESANTIA <- c(
  "60" = 0.75,
  "61" = 0.80,
  "62" = 0.85,
  "63" = 0.90,
  "64" = 0.95,
  "65" = 1.00
)

# Retiro subcuenta employer rate (fixed, not affected by 2020 reform)
TASA_RETIRO_PATRON <- 0.02  # 2%

# Worker CEAV rate (fixed)
TASA_TRABAJADOR_CEAV <- 0.01125  # 1.125%

# ============================================================================
# TRANSITIONAL MINIMUM WEEKS (DOF 16/12/2020 reform)
# ============================================================================

#' Get minimum weeks required for Ley 97 pension based on retirement year
#'
#' DOF 2020 reform: minimum weeks start at 750 in 2021, increase by 25/year,
#' cap at 1000 in 2031+.
#'
#' @param anio_retiro Year of retirement
#' @return Minimum weeks required
get_semanas_minimas_ley97 <- function(anio_retiro) {
  base <- 750
  incremento <- 25
  anio_inicio <- 2021
  anio_tope <- 2031
  tope <- 1000
  if (anio_retiro <= anio_inicio) return(base)
  if (anio_retiro >= anio_tope) return(tope)
  return(base + incremento * (anio_retiro - anio_inicio))
}
