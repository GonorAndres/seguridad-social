# R/calculations.R - Funciones de calculo de pensiones
# Simulador de Pension IMSS + Fondo Bienestar
#
# Este archivo contiene las formulas actuariales para:
# - Ley 73: Pension por vejez y cesantia
# - Ley 97: Proyeccion AFORE y retiro programado
# - Modalidad 40: Continuacion voluntaria

# ============================================================================
# LEY 73 - CALCULO DE PENSION
# ============================================================================

#' Calcular pension bajo Ley 73 (Articulo 167)
#'
#' @param sbc_promedio_diario Promedio del SBC de las ultimas 250 semanas (diario)
#' @param semanas Semanas cotizadas totales
#' @param edad Edad al momento del retiro
#' @param sm_vigente Salario minimo diario vigente
#' @param tipo_pension "vejez" (65+) o "cesantia" (60-64)
#' @return Lista con pension mensual y detalles del calculo
calculate_ley73_pension <- function(sbc_promedio_diario,
                                     semanas,
                                     edad,
                                     sm_vigente = SM_DIARIO_2025,
                                     tipo_pension = "vejez") {

  # Validaciones basicas
  if (semanas < 500) {
    return(list(
      pension_mensual = 0,
      mensaje = "No cumple con el minimo de 500 semanas cotizadas",
      elegible = FALSE
    ))
  }

  if (edad < 60) {
    return(list(
      pension_mensual = 0,
      mensaje = "La edad minima para pension es 60 anos",
      elegible = FALSE
    ))
  }

  # Paso 1: Determinar grupo salarial (veces salario minimo)
  grupo_salarial <- sbc_promedio_diario / sm_vigente

  # Paso 2: Buscar cuantia basica e incremento en tabla Art. 167
  tabla_lookup <- lookup_articulo_167(grupo_salarial)
  cuantia_basica <- tabla_lookup$cuantia_basica
  incremento_anual <- tabla_lookup$incremento_anual

  # Paso 3: Calcular incrementos (anos completos sobre 500 semanas)
  n_incrementos <- max(0, floor((semanas - 500) / 52))
  total_incrementos <- n_incrementos * incremento_anual

  # Paso 4: Porcentaje total (tope 100%)
  porcentaje_total <- min(cuantia_basica + total_incrementos, 1.0)

  # Paso 5: Factor de edad (cesantia)
  if (edad >= 65) {
    factor_edad <- 1.0
    tipo_efectivo <- "vejez"
  } else {
    factor_edad <- FACTORES_CESANTIA[as.character(edad)]
    if (is.na(factor_edad)) factor_edad <- 0.75
    tipo_efectivo <- "cesantia"
  }

  # Paso 6: Calculo final
  # Nota: DIAS_POR_MES = 30.4375 (365.25/12), estandar actuarial

  pension_diaria <- sbc_promedio_diario * porcentaje_total * factor_edad
  pension_mensual <- pension_diaria * DIAS_POR_MES

  # Pension minima (1 SM mensual)
  pension_minima <- sm_vigente * DIAS_POR_MES
  pension_final <- max(pension_mensual, pension_minima)

  # Tasa de reemplazo
  salario_mensual <- sbc_promedio_diario * DIAS_POR_MES
  tasa_reemplazo <- pension_final / salario_mensual

  return(list(
    pension_mensual = pension_final,
    pension_sin_minimo = pension_mensual,
    pension_diaria = pension_diaria,
    elegible = TRUE,
    tipo_pension = tipo_efectivo,
    # Detalles del calculo
    grupo_salarial = grupo_salarial,
    cuantia_basica = cuantia_basica,
    incremento_anual = incremento_anual,
    n_incrementos = n_incrementos,
    total_incrementos = total_incrementos,
    porcentaje_total = porcentaje_total,
    factor_edad = factor_edad,
    tasa_reemplazo = tasa_reemplazo,
    aplico_minimo = pension_mensual < pension_minima,
    mensaje = paste0("Pension calculada bajo Ley 73 (", tipo_efectivo, ")")
  ))
}

# ============================================================================
# LEY 97 - PROYECCION DE SALDO AFORE
# ============================================================================

#' Proyectar saldo de cuenta AFORE a futuro
#'
#' @param saldo_actual Saldo actual en la AFORE
#' @param aportacion_mensual Aportacion mensual total (obligatoria + voluntaria).
#'   Scalar: usa formula cerrada (backward compat). Vector de longitud
#'   anios_al_retiro: computa iterativamente ano por ano (reforma 2020).
#' @param anios_al_retiro Anos restantes hasta el retiro
#' @param rendimiento_real_anual Tasa de rendimiento real anual (ej: 0.04 = 4%)
#' @param comision_anual Comision anual de la AFORE (ej: 0.0053 = 0.53%)
#' @param incluir_trayectoria Si TRUE, retorna la trayectoria ano por ano
#' @return Lista con saldo final y detalles
project_afore_balance <- function(saldo_actual,
                                   aportacion_mensual,
                                   anios_al_retiro,
                                   rendimiento_real_anual = RENDIMIENTO_BASE,
                                   comision_anual = 0.0053,
                                   incluir_trayectoria = FALSE) {

  # Rendimiento neto despues de comision
  r_neto <- rendimiento_real_anual - comision_anual

  # Tasa mensual equivalente
  r_mensual <- (1 + r_neto)^(1/12) - 1
  meses <- anios_al_retiro * 12

  # Detect variable contributions mode
  variable_contrib <- length(aportacion_mensual) > 1

  if (variable_contrib) {
    # Vector mode: year-by-year iterative computation
    stopifnot(length(aportacion_mensual) == anios_al_retiro)

    trayectoria <- NULL
    if (incluir_trayectoria) {
      trayectoria <- data.frame(
        anio = 0:anios_al_retiro,
        saldo = numeric(anios_al_retiro + 1)
      )
    }

    saldo_temp <- saldo_actual
    total_aportado_contrib <- 0

    for (i in 0:anios_al_retiro) {
      if (!is.null(trayectoria)) trayectoria$saldo[i + 1] <- saldo_temp
      if (i < anios_al_retiro) {
        aport_anio <- aportacion_mensual[i + 1]
        total_aportado_contrib <- total_aportado_contrib + (aport_anio * 12)
        # Apply interest to existing balance, then add monthly contributions
        saldo_temp <- saldo_temp * (1 + r_neto)
        for (m in 1:12) {
          saldo_temp <- saldo_temp + aport_anio * (1 + r_mensual)^(12 - m)
        }
      }
    }

    saldo_final <- saldo_temp
    total_aportado <- saldo_actual + total_aportado_contrib
    ganancia <- saldo_final - total_aportado

    return(list(
      saldo_final = saldo_final,
      fv_saldo_actual = NA,
      fv_aportaciones = NA,
      total_aportado = total_aportado,
      ganancia_intereses = ganancia,
      rendimiento_neto_usado = r_neto,
      meses_proyectados = meses,
      trayectoria = trayectoria
    ))

  } else {
    # Scalar mode: existing closed-form formula (backward compat)

    # Valor futuro del saldo actual
    fv_actual <- saldo_actual * (1 + r_neto)^anios_al_retiro

    # Valor futuro de las aportaciones (anualidad)
    if (abs(r_mensual) < 1e-10) {
      # Caso especial: rendimiento cero
      fv_aportaciones <- aportacion_mensual * meses
    } else {
      fv_aportaciones <- aportacion_mensual * ((1 + r_mensual)^meses - 1) / r_mensual
    }

    saldo_final <- fv_actual + fv_aportaciones

    # Calcular trayectoria si se solicita
    trayectoria <- NULL
    if (incluir_trayectoria) {
      trayectoria <- data.frame(
        anio = 0:anios_al_retiro,
        saldo = numeric(anios_al_retiro + 1)
      )

      saldo_temp <- saldo_actual
      for (i in 0:anios_al_retiro) {
        trayectoria$saldo[i + 1] <- saldo_temp
        if (i < anios_al_retiro) {
          saldo_temp <- saldo_temp * (1 + r_neto)
          for (m in 1:12) {
            saldo_temp <- saldo_temp + aportacion_mensual * (1 + r_mensual)^(12 - m)
          }
        }
      }
    }

    # Total aportado vs ganancia
    total_aportado <- saldo_actual + (aportacion_mensual * meses)
    ganancia <- saldo_final - total_aportado

    return(list(
      saldo_final = saldo_final,
      fv_saldo_actual = fv_actual,
      fv_aportaciones = fv_aportaciones,
      total_aportado = total_aportado,
      ganancia_intereses = ganancia,
      rendimiento_neto_usado = r_neto,
      meses_proyectados = meses,
      trayectoria = trayectoria
    ))
  }
}

#' Calcular aportacion mensual obligatoria a AFORE
#'
#' @param salario_mensual Salario mensual del trabajador
#' @param anio Ano para determinar tasa de aportacion
#' @return Aportacion mensual obligatoria
calculate_aportacion_obligatoria <- function(salario_mensual, anio = 2025) {
  # Aplicar tope de cotizacion
  tope_mensual <- TOPE_SBC_DIARIO * DIAS_POR_MES
  salario_cotizable <- min(salario_mensual, tope_mensual)

  # Determine salary bracket in UMA multiples
  salario_diario <- salario_cotizable / DIAS_POR_MES
  salario_uma <- salario_diario / UMA_DIARIA_2025

  # Look up tiered CEAV employer rate from reform data
  tasa_ceav_patron <- get_ceav_employer_rate(salario_uma, anio)

  # Total employer = 2% retiro (fixed) + CEAV (tiered)
  tasa_patron <- TASA_RETIRO_PATRON + tasa_ceav_patron

  # Worker: 1.125% fixed
  tasa_trabajador <- TASA_TRABAJADOR_CEAV

  # Government cuota social: fixed amount based on bracket, not % of salary
  cuota_social_mensual <- get_cuota_social_mensual(salario_uma)
  tasa_gobierno_efectiva <- if (salario_cotizable > 0) {
    cuota_social_mensual / salario_cotizable
  } else {
    0
  }

  tasa_total <- tasa_patron + tasa_trabajador + tasa_gobierno_efectiva
  aportacion_patron <- salario_cotizable * tasa_patron
  aportacion_trabajador <- salario_cotizable * tasa_trabajador
  aportacion_total <- aportacion_patron + aportacion_trabajador + cuota_social_mensual

  return(list(
    aportacion_total = aportacion_total,
    aportacion_patron = aportacion_patron,
    aportacion_trabajador = aportacion_trabajador,
    aportacion_gobierno = cuota_social_mensual,
    tasa_total = tasa_total,
    tasa_patron = tasa_patron,
    tasa_ceav = tasa_ceav_patron,
    salario_cotizable = salario_cotizable
  ))
}

#' Get tiered CEAV employer rate from DOF 2020 reform table
#' @param salario_uma Salary in UMA multiples
#' @param anio Year (2023-2030+)
#' @return CEAV employer rate as decimal
get_ceav_employer_rate <- function(salario_uma, anio) {
  # Clamp year column
  anio_col <- min(max(anio, 2023), 2030)
  col_name <- paste0("ceav_", anio_col)

  if (!exists("tasas_reforma_data") || is.null(tasas_reforma_data)) {
    # Fallback if data not loaded (e.g., in some test environments)
    return(0.0775)  # approximate 2025 average
  }

  # Find matching bracket
  idx <- which(salario_uma >= tasas_reforma_data$bracket_min_uma &
               salario_uma <= tasas_reforma_data$bracket_max_uma)
  if (length(idx) == 0) {
    # Default to highest bracket
    idx <- nrow(tasas_reforma_data)
  }

  rate <- tasas_reforma_data[[col_name]][idx[1]]
  return(rate / 100)  # Convert percentage to decimal
}

#' Get monthly government cuota social based on salary bracket
#' @param salario_uma Salary in UMA multiples
#' @return Monthly cuota social in pesos
get_cuota_social_mensual <- function(salario_uma) {
  if (!exists("tasas_reforma_data") || is.null(tasas_reforma_data)) {
    # Fallback
    return(UMA_DIARIA_2025 * 0.05177 * DIAS_POR_MES)
  }

  # Find matching bracket
  idx <- which(salario_uma >= tasas_reforma_data$bracket_min_uma &
               salario_uma <= tasas_reforma_data$bracket_max_uma)
  if (length(idx) == 0) {
    idx <- nrow(tasas_reforma_data)
  }

  cs_pct <- tasas_reforma_data$cs_pct_uma[idx[1]]
  # Cuota social = percentage of UMA daily * DIAS_POR_MES
  return(UMA_DIARIA_2025 * (cs_pct / 100) * DIAS_POR_MES)
}

#' Generar vector de aportaciones mensuales ano por ano
#'
#' Aplica las tasas de contribucion de la reforma 2020 para cada ano
#' de la proyeccion, en lugar de usar una tasa plana.
#'
#' @param salario_mensual Salario mensual del trabajador
#' @param anio_inicio Ano calendario de inicio de la proyeccion
#' @param anios_al_retiro Numero de anos a proyectar
#' @param aportacion_voluntaria Aportacion voluntaria mensual adicional
#' @return Vector numerico de longitud anios_al_retiro con aportacion mensual total por ano
generate_contribution_schedule <- function(salario_mensual,
                                            anio_inicio,
                                            anios_al_retiro,
                                            aportacion_voluntaria = 0) {
  schedule <- numeric(anios_al_retiro)
  for (i in seq_len(anios_al_retiro)) {
    anio <- anio_inicio + i - 1
    obligatoria <- calculate_aportacion_obligatoria(salario_mensual, anio = anio)
    schedule[i] <- obligatoria$aportacion_total + aportacion_voluntaria
  }
  return(schedule)
}

# ============================================================================
# LEY 97 - PENSION (RETIRO PROGRAMADO)
# ============================================================================

#' Calcular pension mensual por retiro programado
#'
#' @param saldo Saldo total en la AFORE al momento del retiro
#' @param edad Edad al momento del retiro
#' @param genero "M" o "F"
#' @return Lista con pension mensual y detalles
#'
#' @details
#' PENSION MINIMA GARANTIZADA (Ley 97):
#' - La pension minima garantizada es de 2.5 UMAs mensuales (~$8,598.65 en 2025)
#' - Se aplica cuando: saldo / (esperanza_vida * 12) < pension_minima
#' - Ejemplo: Con esperanza de vida de 17 anos (hombre a los 65):
#'   - Saldo necesario para superar minimo: $8,598.65 * 204 meses = $1,754,124
#' - Ejemplo: Con esperanza de vida de 20 anos (mujer a los 65):
#'   - Saldo necesario para superar minimo: $8,598.65 * 240 meses = $2,063,676
#' - Cuando aplica el minimo, las diferencias por genero/esperanza de vida
#'   quedan enmascaradas porque ambos reciben la pension minima garantizada.
#'
calculate_retiro_programado <- function(saldo, edad, genero = "M") {

  # Obtener esperanza de vida
  esperanza_vida <- get_esperanza_vida(edad, genero)

  # Formula simplificada de retiro programado
  # (En realidad es mas compleja con factores actuariales)
  meses_esperados <- esperanza_vida * 12

  # Pension calculada = saldo / meses esperados de vida
  pension_calculada <- saldo / meses_esperados

  # PENSION MINIMA GARANTIZADA (Ley 97)
  # - Se aplica como PISO (floor), no como techo
  # - Si pension_calculada < pension_minima, se otorga la minima
  # - Esto protege a trabajadores con saldos bajos
  # - Cuando aplica, enmascara diferencias por genero ya que ambos
  #   reciben el mismo monto minimo garantizado
  pension_minima <- UMA_MENSUAL_2025 * 2.5  # ~$8,598.65 en 2025

  aplico_minimo <- FALSE
  pension_mensual <- pension_calculada

  if (pension_calculada < pension_minima) {
    pension_mensual <- pension_minima
    aplico_minimo <- TRUE
  }

  return(list(
    pension_mensual = pension_mensual,
    pension_calculada = pension_calculada,  # Pension antes de aplicar minimo
    esperanza_vida = esperanza_vida,
    meses_esperados = meses_esperados,
    pension_minima = pension_minima,
    aplico_minimo = aplico_minimo,
    # Saldo necesario para superar la pension minima garantizada
    saldo_minimo_para_superar_garantia = pension_minima * meses_esperados,
    tipo = "retiro_programado"
  ))
}

#' Calcular pension bajo Ley 97 completa
#' Incluye proyeccion + conversion a pension
#'
#' @param saldo_actual Saldo actual en AFORE
#' @param salario_mensual Salario mensual actual
#' @param edad_actual Edad actual
#' @param edad_retiro Edad planeada de retiro
#' @param semanas_actuales Semanas cotizadas actuales
#' @param genero "M" o "F"
#' @param aportacion_voluntaria Aportacion voluntaria mensual adicional
#' @param afore_nombre Nombre de la AFORE (para comision)
#' @param escenario "conservador", "base", u "optimista"
#' @return Lista completa con proyeccion y pension
calculate_ley97_pension <- function(saldo_actual,
                                     salario_mensual,
                                     edad_actual,
                                     edad_retiro = 65,
                                     semanas_actuales,
                                     genero = "M",
                                     aportacion_voluntaria = 0,
                                     afore_nombre = "XXI Banorte",
                                     escenario = "base") {

  # Validar semanas minimas (transitional schedule per DOF 2020 reform)
  anios_restantes <- edad_retiro - edad_actual
  semanas_al_retiro <- semanas_actuales + (anios_restantes * SEMANAS_POR_ANO)
  anio_retiro <- ANIO_ACTUAL + anios_restantes
  semanas_minimas <- get_semanas_minimas_ley97(anio_retiro)

  if (semanas_al_retiro < semanas_minimas) {
    return(list(
      pension_mensual = 0,
      elegible = FALSE,
      mensaje = paste0("Se requieren ", format(semanas_minimas, big.mark = ","),
                      " semanas para retiro en ", anio_retiro, ". Tendras ",
                      round(semanas_al_retiro), " semanas al retiro.")
    ))
  }

  # Determinar rendimiento segun escenario
  rendimiento <- switch(escenario,
    "conservador" = RENDIMIENTO_CONSERVADOR,
    "base" = RENDIMIENTO_BASE,
    "optimista" = RENDIMIENTO_OPTIMISTA,
    RENDIMIENTO_BASE
  )

  # Obtener comision de la AFORE
  comision <- get_afore_comision(afore_nombre)

  # Aportacion obligatoria actual (para display)
  aport_obligatoria <- calculate_aportacion_obligatoria(salario_mensual)

  # Generar calendario de contribuciones con tasas de reforma 2020
  # Edge case: anios_restantes == 0 -> use scalar 0 (already at retirement)
  if (anios_restantes > 0) {
    contrib_schedule <- generate_contribution_schedule(
      salario_mensual = salario_mensual,
      anio_inicio = ANIO_ACTUAL,
      anios_al_retiro = anios_restantes,
      aportacion_voluntaria = aportacion_voluntaria
    )
  } else {
    contrib_schedule <- 0
  }

  # Proyectar saldo con contribuciones variables
  proyeccion <- project_afore_balance(
    saldo_actual = saldo_actual,
    aportacion_mensual = contrib_schedule,
    anios_al_retiro = anios_restantes,
    rendimiento_real_anual = rendimiento,
    comision_anual = comision,
    incluir_trayectoria = TRUE
  )

  # Calcular pension
  pension <- calculate_retiro_programado(
    saldo = proyeccion$saldo_final,
    edad = edad_retiro,
    genero = genero
  )

  # Tasa de reemplazo
  tasa_reemplazo <- pension$pension_mensual / salario_mensual

  return(list(
    pension_mensual = pension$pension_mensual,
    pension_calculada = pension$pension_calculada,
    pension_minima = pension$pension_minima,
    saldo_minimo_para_superar_garantia = pension$saldo_minimo_para_superar_garantia,
    elegible = TRUE,
    saldo_proyectado = proyeccion$saldo_final,
    trayectoria = proyeccion$trayectoria,
    esperanza_vida = pension$esperanza_vida,
    tasa_reemplazo = tasa_reemplazo,
    semanas_al_retiro = semanas_al_retiro,
    aportacion_obligatoria = aport_obligatoria$aportacion_total,
    aportacion_voluntaria = aportacion_voluntaria,
    aportacion_total = aport_obligatoria$aportacion_total + aportacion_voluntaria,
    rendimiento_usado = rendimiento,
    comision_usada = comision,
    aplico_minimo = pension$aplico_minimo,
    escenario = escenario,
    mensaje = "Pension calculada bajo Ley 97 (Retiro Programado)"
  ))
}

# ============================================================================
# MODALIDAD 40 - CONTINUACION VOLUNTARIA
# ============================================================================

#' Calcular impacto de Modalidad 40 en pension Ley 73
#'
#' Modalidad 40 permite a trabajadores fuera del mercado laboral
#' seguir cotizando voluntariamente para mejorar:
#' 1. Semanas cotizadas
#' 2. Promedio salarial (ultimas 250 semanas)
#'
#' @param pension_actual Resultado de calculate_ley73_pension sin M40
#' @param sbc_actual SBC diario actual del trabajador
#' @param sbc_m40 SBC diario que desea registrar en M40 (puede ser mayor)
#' @param semanas_actuales Semanas cotizadas actuales
#' @param semanas_m40 Semanas adicionales a cotizar via M40
#' @param edad_actual Edad actual
#' @param edad_retiro Edad de retiro deseada
#' @return Lista con pension mejorada y costo de M40
calculate_modalidad_40 <- function(pension_actual,
                                    sbc_actual,
                                    sbc_m40,
                                    semanas_actuales,
                                    semanas_m40,
                                    edad_actual,
                                    edad_retiro = 65) {

  # Validaciones
  max_sbc_m40 <- TOPE_SBC_DIARIO  # 25 UMAs
  sbc_m40_real <- min(sbc_m40, max_sbc_m40)

  # Cuota M40 (10.075% del SBC elegido)
  tasa_m40 <- 0.10075
  cuota_mensual_m40 <- sbc_m40_real * DIAS_POR_MES * tasa_m40

  # Semanas totales con M40
  semanas_totales <- semanas_actuales + semanas_m40

  # Nuevo SBC promedio (ponderado con ultimas 250 semanas)
  # Simplificacion: asumimos que M40 cubre todas las ultimas 250 semanas
  if (semanas_m40 >= 250) {
    nuevo_sbc_promedio <- sbc_m40_real
  } else {
    # Promedio ponderado
    semanas_nuevas <- min(semanas_m40, 250)
    semanas_viejas <- 250 - semanas_nuevas
    nuevo_sbc_promedio <- (sbc_m40_real * semanas_nuevas +
                           sbc_actual * semanas_viejas) / 250
  }

  # Recalcular pension con nuevos parametros
  sm_vigente <- SM_DIARIO_2025
  nueva_pension <- calculate_ley73_pension(
    sbc_promedio_diario = nuevo_sbc_promedio,
    semanas = semanas_totales,
    edad = edad_retiro,
    sm_vigente = sm_vigente
  )

  # Costo total de M40
  meses_m40 <- ceiling(semanas_m40 / 4.33)  # ~4.33 semanas por mes
  costo_total_m40 <- cuota_mensual_m40 * meses_m40

  # Beneficio (incremento en pension mensual)
  incremento_pension <- nueva_pension$pension_mensual - pension_actual$pension_mensual

  # Tiempo de recuperacion (meses)
  if (incremento_pension > 0) {
    meses_recuperacion <- ceiling(costo_total_m40 / incremento_pension)
  } else {
    meses_recuperacion <- Inf
  }

  return(list(
    pension_con_m40 = nueva_pension$pension_mensual,
    pension_sin_m40 = pension_actual$pension_mensual,
    incremento_mensual = incremento_pension,
    incremento_porcentaje = incremento_pension / pension_actual$pension_mensual,
    cuota_mensual_m40 = cuota_mensual_m40,
    meses_m40 = meses_m40,
    costo_total_m40 = costo_total_m40,
    meses_recuperacion = meses_recuperacion,
    sbc_m40_usado = sbc_m40_real,
    semanas_totales = semanas_totales,
    nuevo_sbc_promedio = nuevo_sbc_promedio,
    nueva_pension_detalle = nueva_pension,
    recomendacion = if (meses_recuperacion < 60) {
      "M40 es recomendable: recuperas la inversion en menos de 5 anos"
    } else if (meses_recuperacion < 120) {
      "M40 puede ser util: recuperas la inversion en 5-10 anos"
    } else {
      "M40 tiene beneficio limitado para tu caso"
    }
  ))
}

# ============================================================================
# FUNCIONES DE COMPARACION
# ============================================================================

#' Calcular todos los escenarios para un trabajador
#'
#' @param regimen "ley73" o "ley97"
#' @param ... Parametros del trabajador
#' @return Lista con todos los escenarios calculados
calculate_all_scenarios <- function(regimen,
                                     saldo_actual = 0,
                                     salario_mensual,
                                     sbc_diario = NULL,
                                     edad_actual,
                                     edad_retiro = 65,
                                     semanas_actuales,
                                     genero = "M",
                                     aportacion_voluntaria = 0,
                                     afore_nombre = "XXI Banorte") {

  if (is.null(sbc_diario)) {
    sbc_diario <- salario_mensual / DIAS_POR_MES
  }

  anios_restantes <- edad_retiro - edad_actual

  if (regimen == "ley73") {
    # ============ LEY 73 ============

    # Pension base
    pension_base <- calculate_ley73_pension(
      sbc_promedio_diario = sbc_diario,
      semanas = semanas_actuales + (anios_restantes * SEMANAS_POR_ANO),
      edad = edad_retiro
    )

    # Escenario con M40 (si tiene menos de 500 semanas o quiere mejorar)
    pension_m40 <- NULL
    if (pension_base$elegible) {
      # Simular M40 con SBC maximo
      semanas_m40 <- min(anios_restantes * SEMANAS_POR_ANO, MAX_SEMANAS_M40)
      sbc_m40 <- TOPE_SBC_DIARIO * FACTOR_SBC_M40

      pension_m40 <- calculate_modalidad_40(
        pension_actual = pension_base,
        sbc_actual = sbc_diario,
        sbc_m40 = sbc_m40,
        semanas_actuales = semanas_actuales + (anios_restantes * SEMANAS_POR_ANO) - semanas_m40,
        semanas_m40 = semanas_m40,
        edad_actual = edad_actual,
        edad_retiro = edad_retiro
      )
    }

    return(list(
      regimen = "ley73",
      pension_base = pension_base,
      pension_m40 = pension_m40,
      fondo_bienestar_aplica = FALSE,
      mensaje = "Ley 73: El Fondo Bienestar NO aplica. Tu pension ya es mejor."
    ))

  } else {
    # ============ LEY 97 ============

    # Escenario conservador
    pension_conservador <- calculate_ley97_pension(
      saldo_actual = saldo_actual,
      salario_mensual = salario_mensual,
      edad_actual = edad_actual,
      edad_retiro = edad_retiro,
      semanas_actuales = semanas_actuales,
      genero = genero,
      aportacion_voluntaria = 0,
      afore_nombre = afore_nombre,
      escenario = "conservador"
    )

    # Escenario base
    pension_base <- calculate_ley97_pension(
      saldo_actual = saldo_actual,
      salario_mensual = salario_mensual,
      edad_actual = edad_actual,
      edad_retiro = edad_retiro,
      semanas_actuales = semanas_actuales,
      genero = genero,
      aportacion_voluntaria = 0,
      afore_nombre = afore_nombre,
      escenario = "base"
    )

    # Escenario optimista
    pension_optimista <- calculate_ley97_pension(
      saldo_actual = saldo_actual,
      salario_mensual = salario_mensual,
      edad_actual = edad_actual,
      edad_retiro = edad_retiro,
      semanas_actuales = semanas_actuales,
      genero = genero,
      aportacion_voluntaria = 0,
      afore_nombre = afore_nombre,
      escenario = "optimista"
    )

    # Escenario con aportaciones voluntarias
    pension_con_voluntarias <- calculate_ley97_pension(
      saldo_actual = saldo_actual,
      salario_mensual = salario_mensual,
      edad_actual = edad_actual,
      edad_retiro = edad_retiro,
      semanas_actuales = semanas_actuales,
      genero = genero,
      aportacion_voluntaria = aportacion_voluntaria,
      afore_nombre = afore_nombre,
      escenario = "base"
    )

    return(list(
      regimen = "ley97",
      pension_conservador = pension_conservador,
      pension_base = pension_base,
      pension_optimista = pension_optimista,
      pension_con_voluntarias = pension_con_voluntarias,
      fondo_bienestar_aplica = TRUE
    ))
  }
}

#' Calcular impacto de cambiar de AFORE
#'
#' @param saldo_actual Saldo actual
#' @param salario_mensual Salario mensual
#' @param anios_al_retiro Anos restantes
#' @param afore_actual AFORE actual
#' @return Data frame comparando todas las AFOREs
compare_afores <- function(saldo_actual,
                            salario_mensual,
                            anios_al_retiro,
                            afore_actual = "Profuturo") {

  afores <- get_afore_names()
  resultados <- data.frame(
    afore = character(),
    comision = numeric(),
    irn = numeric(),
    saldo_final = numeric(),
    diferencia = numeric(),
    stringsAsFactors = FALSE
  )

  # Generar calendario de contribuciones con reforma 2020
  if (anios_al_retiro > 0) {
    contrib_schedule <- generate_contribution_schedule(
      salario_mensual = salario_mensual,
      anio_inicio = ANIO_ACTUAL,
      anios_al_retiro = anios_al_retiro
    )
  } else {
    contrib_schedule <- 0
  }

  for (afore in afores) {
    comision <- get_afore_comision(afore)
    irn <- get_afore_irn(afore)

    proyeccion <- project_afore_balance(
      saldo_actual = saldo_actual,
      aportacion_mensual = contrib_schedule,
      anios_al_retiro = anios_al_retiro,
      rendimiento_real_anual = irn,  # Usar IRN como proxy
      comision_anual = comision
    )

    resultados <- rbind(resultados, data.frame(
      afore = afore,
      comision = comision * 100,
      irn = irn * 100,
      saldo_final = proyeccion$saldo_final,
      diferencia = 0,
      stringsAsFactors = FALSE
    ))
  }

  # Calcular diferencia vs AFORE actual
  saldo_actual_afore <- resultados$saldo_final[resultados$afore == afore_actual]
  resultados$diferencia <- resultados$saldo_final - saldo_actual_afore

  # Ordenar por saldo final
  resultados <- resultados[order(-resultados$saldo_final), ]

  return(resultados)
}
