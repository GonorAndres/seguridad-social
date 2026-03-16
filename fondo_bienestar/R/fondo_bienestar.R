# R/fondo_bienestar.R - Lógica del Fondo de Pensiones para el Bienestar
# Simulador de Pensión IMSS + Fondo Bienestar
#
# Decreto: DOF 01/05/2024
# Entrada en vigor: 01/07/2024

# ============================================================================
# ELEGIBILIDAD
# ============================================================================

#' Verificar elegibilidad para el Fondo de Pensiones para el Bienestar
#'
#' Requisitos:
#' - Trabajador bajo Ley 97 (IMSS) o Ley ISSSTE 2007
#' - Edad mínima: 65 años
#' - Semanas cotizadas: 1,000 mínimo
#' - Salario (SBC promedio): <= Umbral del Fondo
#'
#' @param regimen "ley97" o "ley73" (Ley 73 NO es elegible)
#' @param edad Edad al momento del retiro
#' @param semanas Semanas cotizadas
#' @param sbc_promedio_mensual Promedio del SBC de las últimas 240 semanas (mensual)
#' @param anio Año para determinar umbral
#' @return Lista con elegibilidad y razón
check_fondo_eligibility <- function(regimen,
                                     edad,
                                     semanas,
                                     sbc_promedio_mensual,
                                     anio = ANIO_ACTUAL) {

  umbral <- get_umbral_fondo_bienestar(anio)

  # Lista de verificaciones
  checks <- list(
    regimen_valido = list(
      cumple = (regimen == "ley97"),
      mensaje = if (regimen == "ley97") {
        "Régimen Ley 97: Elegible"
      } else {
        "Régimen Ley 73: NO elegible (tu pensión ya es mejor)"
      }
    ),
    edad_minima = list(
      cumple = (edad >= 65),
      mensaje = if (edad >= 65) {
        paste0("Cumples con la edad mínima de 65 años")
      } else {
        paste0("Necesitas tener al menos 65 años para acceder al Fondo. Hoy tienes ", edad, ".")
      }
    ),
    semanas_minimas = list(
      cumple = (semanas >= get_semanas_minimas_ley97(anio)),
      mensaje = if (semanas >= get_semanas_minimas_ley97(anio)) {
        paste0("Cumples con las ", format(get_semanas_minimas_ley97(anio), big.mark = ","),
               " semanas mínimas cotizadas")
      } else {
        paste0("Necesitas al menos ", format(get_semanas_minimas_ley97(anio), big.mark = ","),
               " semanas cotizadas para retiro en ", anio, ". Hoy llevas ",
               format(round(semanas), big.mark = ","), ".")
      }
    ),
    salario_bajo_umbral = list(
      cumple = (sbc_promedio_mensual <= umbral),
      mensaje = if (sbc_promedio_mensual <= umbral) {
        paste0("Tu salario está dentro del límite del Fondo")
      } else {
        paste0("El Fondo Bienestar es para salarios menores a $",
               format(round(umbral), big.mark = ","),
               "/mes. Tu salario actual lo supera.")
      }
    )
  )

  # Determinar elegibilidad total
  elegible <- all(sapply(checks, function(x) x$cumple))

  # Razón principal de no elegibilidad
  razon_no_elegible <- NULL
  if (!elegible) {
    for (nombre in names(checks)) {
      if (!checks[[nombre]]$cumple) {
        razon_no_elegible <- checks[[nombre]]$mensaje
        break
      }
    }
  }

  return(list(
    elegible = elegible,
    checks = checks,
    razon_no_elegible = razon_no_elegible,
    umbral_usado = umbral,
    anio = anio
  ))
}

# ============================================================================
# CALCULO DEL COMPLEMENTO
# ============================================================================

#' Calcular complemento del Fondo de Pensiones para el Bienestar
#'
#' El Fondo complementa la pensión AFORE hasta alcanzar el 100%
#' del último salario (o el umbral, lo que sea menor).
#'
#' @param pension_afore Pensión mensual calculada de la AFORE
#' @param sbc_promedio_mensual Promedio SBC últimas 240 semanas (mensual)
#' @param elegibilidad Resultado de check_fondo_eligibility
#' @return Lista con complemento y pension total
calculate_fondo_complement <- function(pension_afore,
                                        sbc_promedio_mensual,
                                        elegibilidad) {

  # Si no es elegible, no hay complemento
  if (!elegibilidad$elegible) {
    return(list(
      complemento = 0,
      pension_total = pension_afore,
      pension_afore = pension_afore,
      elegible = FALSE,
      razon = elegibilidad$razon_no_elegible,
      tasa_reemplazo_sin_fondo = pension_afore / sbc_promedio_mensual,
      tasa_reemplazo_con_fondo = pension_afore / sbc_promedio_mensual
    ))
  }

  umbral <- elegibilidad$umbral_usado

  # El objetivo es llegar al 100% del último salario
  # PERO tope en el umbral del Fondo
  pension_objetivo <- min(sbc_promedio_mensual, umbral)

  # Complemento = objetivo - pension AFORE
  complemento <- max(0, pension_objetivo - pension_afore)

  pension_total <- pension_afore + complemento

  return(list(
    complemento = complemento,
    pension_total = pension_total,
    pension_afore = pension_afore,
    pension_objetivo = pension_objetivo,
    elegible = TRUE,
    umbral = umbral,
    tasa_reemplazo_sin_fondo = pension_afore / sbc_promedio_mensual,
    tasa_reemplazo_con_fondo = pension_total / sbc_promedio_mensual
  ))
}

# ============================================================================
# FUNCION PRINCIPAL DE FONDO BIENESTAR
# ============================================================================

#' Calcular pensión completa con Fondo Bienestar
#'
#' Combina el cálculo de Ley 97 con el complemento del Fondo
#'
#' @param saldo_actual Saldo actual en AFORE
#' @param salario_mensual Salario mensual actual
#' @param edad_actual Edad actual
#' @param edad_retiro Edad de retiro (default 65 para Fondo)
#' @param semanas_actuales Semanas cotizadas actuales
#' @param genero "M" o "F"
#' @param aportacion_voluntaria Aportación voluntaria mensual
#' @param afore_nombre Nombre de la AFORE
#' @param escenario "conservador", "base", u "optimista"
#' @return Lista completa con todos los escenarios
calculate_pension_with_fondo <- function(saldo_actual,
                                          salario_mensual,
                                          edad_actual,
                                          edad_retiro = 65,
                                          semanas_actuales,
                                          genero = "M",
                                          aportacion_voluntaria = 0,
                                          afore_nombre = "XXI Banorte",
                                          escenario = "base") {

  años_restantes <- max(0, edad_retiro - edad_actual)
  semanas_al_retiro <- semanas_actuales + (años_restantes * SEMANAS_POR_ANO)

  # ============ ESCENARIO 1: Solo sistema (AFORE sin Fondo) ============
  pension_solo_sistema <- calculate_ley97_pension(
    saldo_actual = saldo_actual,
    salario_mensual = salario_mensual,
    edad_actual = edad_actual,
    edad_retiro = edad_retiro,
    semanas_actuales = semanas_actuales,
    genero = genero,
    aportacion_voluntaria = 0,
    afore_nombre = afore_nombre,
    escenario = escenario
  )

  # ============ ESCENARIO 2: Con Fondo Bienestar ============

  # Verificar elegibilidad
  # Nota: Usamos salario_mensual como proxy del SBC promedio
  # En implementación real, debería ser el promedio de 240 semanas
  # Usamos año de retiro para el umbral proyectado del Fondo
  anio_retiro <- ANIO_ACTUAL + años_restantes
  elegibilidad <- check_fondo_eligibility(
    regimen = "ley97",
    edad = edad_retiro,
    semanas = semanas_al_retiro,
    sbc_promedio_mensual = salario_mensual,
    anio = anio_retiro
  )

  # Calcular complemento
  complemento_fondo <- calculate_fondo_complement(
    pension_afore = pension_solo_sistema$pension_mensual,
    sbc_promedio_mensual = salario_mensual,
    elegibilidad = elegibilidad
  )

  # ============ ESCENARIO 3: Con tus acciones (voluntarias) ============
  pension_con_acciones <- calculate_ley97_pension(
    saldo_actual = saldo_actual,
    salario_mensual = salario_mensual,
    edad_actual = edad_actual,
    edad_retiro = edad_retiro,
    semanas_actuales = semanas_actuales,
    genero = genero,
    aportacion_voluntaria = aportacion_voluntaria,
    afore_nombre = afore_nombre,
    escenario = escenario
  )

  # Complemento del Fondo para escenario con acciones
  complemento_con_acciones <- calculate_fondo_complement(
    pension_afore = pension_con_acciones$pension_mensual,
    sbc_promedio_mensual = salario_mensual,
    elegibilidad = elegibilidad
  )

  # ============ RESUMEN ============

  return(list(
    # Datos de entrada
    entrada = list(
      saldo_actual = saldo_actual,
      salario_mensual = salario_mensual,
      edad_actual = edad_actual,
      edad_retiro = edad_retiro,
      semanas_actuales = semanas_actuales,
      semanas_al_retiro = semanas_al_retiro,
      años_restantes = años_restantes,
      genero = genero,
      aportacion_voluntaria = aportacion_voluntaria,
      afore = afore_nombre,
      escenario = escenario
    ),

    # Escenario 1: Solo sistema
    solo_sistema = list(
      pension_mensual = pension_solo_sistema$pension_mensual,
      pension_calculada = pension_solo_sistema$pension_calculada,
      pension_minima = pension_solo_sistema$pension_minima,
      saldo_minimo_para_superar_garantia = pension_solo_sistema$saldo_minimo_para_superar_garantia,
      saldo_proyectado = pension_solo_sistema$saldo_proyectado,
      trayectoria = pension_solo_sistema$trayectoria,
      tasa_reemplazo = pension_solo_sistema$tasa_reemplazo,
      aplico_minimo = pension_solo_sistema$aplico_minimo
    ),

    # Escenario 2: Con Fondo Bienestar
    con_fondo = list(
      elegible = elegibilidad$elegible,
      checks = elegibilidad$checks,
      pension_afore = complemento_fondo$pension_afore,
      complemento = complemento_fondo$complemento,
      pension_total = complemento_fondo$pension_total,
      tasa_reemplazo = complemento_fondo$tasa_reemplazo_con_fondo
    ),

    # Escenario 3: Con tus acciones
    con_acciones = list(
      pension_afore = pension_con_acciones$pension_mensual,
      pension_calculada = pension_con_acciones$pension_calculada,
      pension_minima = pension_con_acciones$pension_minima,
      saldo_minimo_para_superar_garantia = pension_con_acciones$saldo_minimo_para_superar_garantia,
      saldo_proyectado = pension_con_acciones$saldo_proyectado,
      trayectoria = pension_con_acciones$trayectoria,
      complemento_fondo = complemento_con_acciones$complemento,
      pension_total = if (elegibilidad$elegible) {
        complemento_con_acciones$pension_total
      } else {
        pension_con_acciones$pension_mensual
      },
      aportacion_total_mes = pension_con_acciones$aportacion_total,
      diferencia_vs_base = pension_con_acciones$pension_mensual -
                           pension_solo_sistema$pension_mensual,
      aplico_minimo = pension_con_acciones$aplico_minimo
    ),

    # Información del Fondo
    fondo_bienestar = list(
      elegible = elegibilidad$elegible,
      umbral = elegibilidad$umbral_usado,
      razon_no_elegible = elegibilidad$razon_no_elegible,
      advertencia = if (elegibilidad$elegible) {
        paste0("El Fondo Bienestar es nuevo (2024) y su sostenibilidad ",
               "a largo plazo no está garantizada. Tus aportaciones ",
               "voluntarias son la parte más segura de tu pensión.")
      } else {
        NULL
      }
    )
  ))
}

# ============================================================================
# ANALISIS DE SENSIBILIDAD
# ============================================================================

#' Analizar impacto de diferentes aportaciones voluntarias
#'
#' @param ... Parámetros base del trabajador
#' @param aportaciones_probar Vector de aportaciones a probar
#' @return Data frame con resultados
analyze_voluntary_contributions <- function(saldo_actual,
                                             salario_mensual,
                                             edad_actual,
                                             edad_retiro = 65,
                                             semanas_actuales,
                                             genero = "M",
                                             afore_nombre = "XXI Banorte",
                                             aportaciones_probar = c(0, 500, 1000, 1500, 2000)) {

  resultados <- data.frame(
    aportacion = numeric(),
    saldo_final = numeric(),
    pension_afore = numeric(),
    pension_con_fondo = numeric(),
    incremento_vs_base = numeric(),
    stringsAsFactors = FALSE
  )

  for (aport in aportaciones_probar) {
    calculo <- calculate_pension_with_fondo(
      saldo_actual = saldo_actual,
      salario_mensual = salario_mensual,
      edad_actual = edad_actual,
      edad_retiro = edad_retiro,
      semanas_actuales = semanas_actuales,
      genero = genero,
      aportacion_voluntaria = aport,
      afore_nombre = afore_nombre
    )

    resultados <- rbind(resultados, data.frame(
      aportacion = aport,
      saldo_final = calculo$con_acciones$saldo_proyectado,
      pension_afore = calculo$con_acciones$pension_afore,
      pension_con_fondo = calculo$con_acciones$pension_total,
      incremento_vs_base = calculo$con_acciones$diferencia_vs_base,
      stringsAsFactors = FALSE
    ))
  }

  return(resultados)
}

#' Analizar impacto de diferentes edades de retiro
#'
#' @param ... Parámetros base del trabajador
#' @param edades_probar Vector de edades a probar
#' @return Data frame con resultados
analyze_retirement_age <- function(saldo_actual,
                                    salario_mensual,
                                    edad_actual,
                                    semanas_actuales,
                                    genero = "M",
                                    aportacion_voluntaria = 0,
                                    afore_nombre = "XXI Banorte",
                                    edades_probar = 60:70) {

  resultados <- data.frame(
    edad_retiro = numeric(),
    anios_trabajo = numeric(),
    saldo_final = numeric(),
    pension_afore = numeric(),
    elegible_fondo = logical(),
    pension_con_fondo = numeric(),
    stringsAsFactors = FALSE
  )

  for (edad in edades_probar) {
    if (edad <= edad_actual) next

    calculo <- calculate_pension_with_fondo(
      saldo_actual = saldo_actual,
      salario_mensual = salario_mensual,
      edad_actual = edad_actual,
      edad_retiro = edad,
      semanas_actuales = semanas_actuales,
      genero = genero,
      aportacion_voluntaria = aportacion_voluntaria,
      afore_nombre = afore_nombre
    )

    resultados <- rbind(resultados, data.frame(
      edad_retiro = edad,
      anios_trabajo = edad - edad_actual,
      saldo_final = calculo$solo_sistema$saldo_proyectado,
      pension_afore = calculo$solo_sistema$pension_mensual,
      elegible_fondo = calculo$con_fondo$elegible,
      pension_con_fondo = calculo$con_fondo$pension_total,
      stringsAsFactors = FALSE
    ))
  }

  return(resultados)
}

# ============================================================================
# MENSAJES Y RECOMENDACIONES
# ============================================================================

#' Generar mensaje personalizado basado en resultados
#'
#' @param resultado Resultado de calculate_pension_with_fondo
#' @return Lista de mensajes
generate_personalized_message <- function(resultado) {

  mensajes <- list()

  # Mensaje sobre el Fondo
  if (resultado$fondo_bienestar$elegible) {
    diferencia <- resultado$con_fondo$pension_total - resultado$solo_sistema$pension_mensual
    mensajes$fondo <- list(
      tipo = "info",
      titulo = "Eres elegible para el Fondo Bienestar",
      texto = paste0(
        "El Fondo puede complementar tu pensión con $",
        format(round(diferencia), big.mark = ","),
        " adicionales al mes. Sin embargo, recuerda que es un ",
        "programa nuevo y su continuidad depende de decisiones políticas futuras."
      )
    )
  } else {
    mensajes$fondo <- list(
      tipo = "warning",
      titulo = "No eres elegible para el Fondo Bienestar",
      texto = resultado$fondo_bienestar$razon_no_elegible
    )
  }

  # Mensaje sobre tasa de reemplazo
  tasa <- resultado$solo_sistema$tasa_reemplazo * 100
  if (tasa < 30) {
    mensajes$tasa <- list(
      tipo = "danger",
      titulo = "Tu pensión será significativamente menor a tu salario",
      texto = paste0(
        "Tu pensión será aproximadamente el ", round(tasa), "% de tu salario actual. ",
        "Considera aumentar tus aportaciones voluntarias o retrasar tu retiro."
      )
    )
  } else if (tasa < 50) {
    mensajes$tasa <- list(
      tipo = "warning",
      titulo = "Tu pensión cubrirá parte de tu salario",
      texto = paste0(
        "Tu pensión será aproximadamente el ", round(tasa), "% de tu salario actual. ",
        "Las aportaciones voluntarias pueden ayudar a mejorar este porcentaje."
      )
    )
  } else {
    mensajes$tasa <- list(
      tipo = "success",
      titulo = "Tu pensión tendrá buena cobertura",
      texto = paste0(
        "Tu pensión será aproximadamente el ", round(tasa), "% de tu salario actual."
      )
    )
  }

  # Mensaje sobre aportaciones voluntarias
  if (resultado$entrada$aportacion_voluntaria > 0) {
    diferencia <- resultado$con_acciones$diferencia_vs_base
    mensajes$voluntarias <- list(
      tipo = "success",
      titulo = "Tus aportaciones voluntarias hacen diferencia",
      texto = paste0(
        "Con $", format(round(resultado$entrada$aportacion_voluntaria), big.mark = ","),
        " mensuales de aportación voluntaria, tu pensión aumenta en $",
        format(round(diferencia), big.mark = ","), " al mes."
      )
    )
  } else {
    mensajes$voluntarias <- list(
      tipo = "info",
      titulo = "Las aportaciones voluntarias son tu mejor herramienta",
      texto = paste0(
        "Aún $500 mensuales pueden hacer una diferencia significativa ",
        "en tu pensión final. Es la parte de tu jubilación que TÚ controlas."
      )
    )
  }

  return(mensajes)
}
