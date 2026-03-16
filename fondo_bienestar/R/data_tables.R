# R/data_tables.R - Funciones para consulta de tablas de datos
# Simulador de Pension IMSS + Fondo Bienestar

# ============================================================================
# TABLA ARTICULO 167 - LEY 73
# ============================================================================

#' Buscar cuantía básica e incremento anual según grupo salarial
#' @param grupo_salarial Salario expresado en veces el salario mínimo
#' @param tabla Data frame con la tabla del Artículo 167
#' @return Lista con cuantía_basica e incremento_anual
lookup_articulo_167 <- function(grupo_salarial, tabla = articulo_167_tabla) {
  # Encontrar la fila correspondiente al grupo salarial
  idx <- which(grupo_salarial >= tabla$grupo_min & grupo_salarial <= tabla$grupo_max)

  if (length(idx) == 0) {
    # Si el grupo excede el máximo, usar la última fila
    if (grupo_salarial > max(tabla$grupo_max)) {
      idx <- nrow(tabla)
    } else {
      # Si es menor al mínimo, usar la primera fila
      idx <- 1
    }
  }

  return(list(
    cuantia_basica = tabla$cuantia_basica[idx],
    incremento_anual = tabla$incremento_anual[idx]
  ))
}

# ============================================================================
# DATOS DE AFORES
# ============================================================================

#' Obtener lista de AFOREs disponibles
#' @return Vector con nombres de AFOREs
get_afore_names <- function() {
  return(afore_data$afore)
}

#' Obtener comisión de una AFORE para un año
#' @param afore_nombre Nombre de la AFORE
#' @param anio Año (2024 o 2025)
#' @return Comisión como decimal (ej: 0.0053 para 0.53%)
get_afore_comision <- function(afore_nombre, anio = 2025) {
  row <- afore_data[afore_data$afore == afore_nombre, ]
  if (nrow(row) == 0) {
    # Retornar promedio si no se encuentra
    return(mean(afore_data$comision_2025) / 100)
  }

  if (anio == 2024) {
    return(row$comision_2024 / 100)
  } else {
    return(row$comision_2025 / 100)
  }
}

#' Obtener IRN (Indicador de Rendimiento Neto) de una AFORE
#' @param afore_nombre Nombre de la AFORE
#' @return IRN como decimal
get_afore_irn <- function(afore_nombre) {
  row <- afore_data[afore_data$afore == afore_nombre, ]
  if (nrow(row) == 0) {
    return(mean(afore_data$irn_2024) / 100)
  }
  return(row$irn_2024 / 100)
}

#' Obtener datos completos de todas las AFOREs
#' @return Data frame con todas las AFOREs y sus datos
get_all_afores <- function() {
  df <- afore_data
  df$comision_pct <- paste0(df$comision_2025, "%")
  df$irn_pct <- paste0(df$irn_2024, "%")
  return(df)
}

# ============================================================================
# TABLAS DE MORTALIDAD (SIMPLIFICADA)
# ============================================================================

#' Obtener esperanza de vida segun edad y genero
#' Basado en tablas CONAPO 2024-2070 simplificadas
#' @param edad Edad actual
#' @param genero "M" para masculino, "F" para femenino
#' @return Anos de esperanza de vida restante
get_esperanza_vida <- function(edad, genero = "M") {
  # Esperanza de vida simplificada basada en CONAPO
  # Estos valores son aproximados para fines educativos

  # Validate inputs
 if (is.null(genero) || length(genero) == 0 || is.na(genero)) {
    genero <- "M"
  }
  if (is.null(edad) || length(edad) == 0 || is.na(edad)) {
    edad <- 65
  }

  if (genero == "F") {
    # Mujeres viven ~5 años más en promedio
    base <- c(
      "60" = 24.5, "61" = 23.6, "62" = 22.7, "63" = 21.8, "64" = 20.9,
      "65" = 20.0, "66" = 19.2, "67" = 18.3, "68" = 17.5, "69" = 16.7,
      "70" = 15.9, "75" = 12.5, "80" = 9.5, "85" = 7.0, "90" = 5.0
    )
  } else {
    # Hombres
    base <- c(
      "60" = 21.0, "61" = 20.2, "62" = 19.4, "63" = 18.6, "64" = 17.8,
      "65" = 17.0, "66" = 16.3, "67" = 15.5, "68" = 14.8, "69" = 14.1,
      "70" = 13.4, "75" = 10.5, "80" = 8.0, "85" = 5.8, "90" = 4.2
    )
  }

  edad_str <- as.character(edad)
  if (edad_str %in% names(base)) {
    return(base[edad_str])
  }

  # Interpolación lineal para edades no listadas
  edades <- as.numeric(names(base))
  valores <- as.numeric(base)

  if (edad < min(edades)) {
    return(valores[1] + (min(edades) - edad))
  }
  if (edad > max(edades)) {
    return(max(2, valores[length(valores)] - (edad - max(edades)) * 0.5))
  }

  # Interpolar
  idx_inf <- max(which(edades <= edad))
  idx_sup <- min(which(edades >= edad))

  if (idx_inf == idx_sup) {
    return(valores[idx_inf])
  }

  prop <- (edad - edades[idx_inf]) / (edades[idx_sup] - edades[idx_inf])
  return(valores[idx_inf] + prop * (valores[idx_sup] - valores[idx_inf]))
}

# ============================================================================
# VALIDACIONES
# ============================================================================

#' Validar datos de entrada del usuario
#' @param edad Edad actual
#' @param semanas Semanas cotizadas
#' @param sbc Salario Base de Cotización mensual
#' @param fecha_primera_cotizacion Fecha de primera cotización (opcional)
#' @return Lista con errores (vacía si todo es válido) y advertencias
validar_entrada <- function(edad, semanas, sbc, fecha_primera_cotizacion = NULL) {
  errores <- c()
  advertencias <- c()

  # Validar edad
  if (is.na(edad) || edad < 18 || edad > 90) {
    errores <- c(errores, "La edad debe estar entre 18 y 90 años")
  }

  # Validar semanas
  if (is.na(semanas) || semanas < 0) {
    errores <- c(errores, "Las semanas cotizadas no pueden ser negativas")
  }
  if (!is.na(semanas) && semanas > 3000) {
    advertencias <- c(advertencias, "Más de 3000 semanas es inusual, verifica el dato")
  }

  # Validar SBC
  if (is.na(sbc) || sbc < 0) {
    errores <- c(errores, "El salario no puede ser negativo")
  }

  # Validar consistencia edad-semanas
  if (!is.na(edad) && !is.na(semanas)) {
    max_semanas_posibles <- (edad - EDAD_MINIMA_TRABAJO) * SEMANAS_POR_ANO
    if (semanas > max_semanas_posibles) {
      errores <- c(errores,
        paste0("Con ", edad, " años, el máximo de semanas posibles es ",
               max_semanas_posibles))
    }
  }

  # Advertencia sobre tope de cotización
  if (!is.na(sbc)) {
    tope_mensual <- TOPE_SBC_DIARIO * DIAS_POR_MES
    if (sbc > tope_mensual) {
      advertencias <- c(advertencias,
        paste0("Tu salario excede el tope de cotización ($",
               format(round(tope_mensual, 0), big.mark = ","),
               "). Solo se considera hasta el tope."))
    }
  }

  return(list(
    valido = length(errores) == 0,
    errores = errores,
    advertencias = advertencias
  ))
}

#' Determinar régimen de ley según fecha de primera cotización
#' @param fecha_primera_cotizacion Fecha en formato Date o string "YYYY-MM-DD"
#' @return "ley73" si es antes de julio 1997, "ley97" si es después
determinar_regimen <- function(fecha_primera_cotizacion) {
  if (is.character(fecha_primera_cotizacion)) {
    fecha <- as.Date(fecha_primera_cotizacion)
  } else {
    fecha <- fecha_primera_cotizacion
  }

  fecha_corte <- as.Date("1997-07-01")

  if (fecha < fecha_corte) {
    return("ley73")
  } else {
    return("ley97")
  }
}

#' Validate consistency between birth date and start-of-contribution date
#' @param fecha_nacimiento Date of birth
#' @param fecha_primera_cotizacion Date of first IMSS contribution
#' @return List with is_consistent (logical) and message (character or NULL)
validar_consistencia_fechas <- function(fecha_nacimiento, fecha_primera_cotizacion) {
  if (is.null(fecha_nacimiento) || is.null(fecha_primera_cotizacion)) {
    return(list(is_consistent = TRUE, message = NULL))
  }
  edad_inicio <- as.numeric(difftime(fecha_primera_cotizacion, fecha_nacimiento, units = "days")) / 365.25
  if (edad_inicio < 15) {
    return(list(is_consistent = FALSE,
      message = paste0("Tu fecha sugiere que empezaste a cotizar a los ", round(edad_inicio),
                       " años. Verifica que sea correcta.")))
  }
  if (edad_inicio > 35) {
    return(list(is_consistent = FALSE,
      message = paste0("Tu fecha sugiere que empezaste a cotizar a los ", round(edad_inicio),
                       " años, lo cual es inusual. Verifica la fecha.")))
  }
  return(list(is_consistent = TRUE, message = NULL))
}
