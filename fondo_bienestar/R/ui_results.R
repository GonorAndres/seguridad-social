# R/ui_results.R - Result cards and hero display
# Simulador de Pension IMSS + Fondo Bienestar

# ============================================================================
# COMPONENTES DEL WIZARD
# ============================================================================

# ============================================================================
# TARJETAS DE RESULTADOS
# ============================================================================

#' Crear tarjeta de resultado de pension
#' @param title Titulo de la tarjeta
#' @param amount Monto de pension
#' @param subtitle Subtitulo o descripcion
#' @param badge_text Texto del badge (opcional)
#' @param badge_class Clase del badge ("success", "warning", etc)
#' @param card_class Clase adicional de la tarjeta
#' @param show_star Mostrar estrella en empowerment card
#' @return HTML de la tarjeta
result_card <- function(title,
                         amount,
                         subtitle,
                         badge_text = NULL,
                         badge_class = "primary",
                         card_class = "baseline",
                         show_star = FALSE) {

  tags$div(
    class = paste("result-card", card_class),

    if (show_star) {
      tags$div(class = "empowerment-star", tags$i(class = "bi bi-star-fill"))
    },

    tags$h5(class = "card-title mb-2", title),

    tags$div(
      class = "pension-amount",
      format_currency(amount),
      tags$span(class = "pension-period", "/mes")
    ),

    if (!is.null(badge_text)) {
      tags$span(
        class = paste("badge", paste0("bg-", badge_class), "mt-2"),
        badge_text
      )
    },

    tags$p(class = "card-text text-muted mt-2 mb-0", subtitle)
  )
}

#' Detect which result scenario to display
#' @param resultado Result from calculate_pension_with_fondo
#' @return String identifying the scenario
detect_result_scenario <- function(resultado) {
  tiene_voluntarias <- (resultado$entrada$aportacion_voluntaria %||% 0) > 0
  fondo_elegible <- resultado$con_fondo$elegible
  aplico_minimo_base <- resultado$solo_sistema$aplico_minimo %||% FALSE
  aplico_minimo_acciones <- resultado$con_acciones$aplico_minimo %||% FALSE
  pension_diff <- resultado$con_acciones$pension_afore - resultado$solo_sistema$pension_mensual

  if (fondo_elegible && tiene_voluntarias &&
      resultado$con_acciones$pension_afore > resultado$con_fondo$pension_total) {
    # Voluntary contributions push AFORE pension above Fondo cap
    return(SCENARIO_FONDO_VOLUNTARY)
  } else if (fondo_elegible) {
    return(SCENARIO_FONDO_ELIGIBLE)
  } else if (aplico_minimo_base && aplico_minimo_acciones && tiene_voluntarias) {
    return(SCENARIO_MINIMO)
  } else if (tiene_voluntarias && pension_diff > 0) {
    return(SCENARIO_VOLUNTARY_IMPROVEMENT)
  } else {
    return(SCENARIO_BASE)
  }
}

#' Render hero + breakdown results for Ley 97
#' @param resultado Result from calculate_pension_with_fondo
#' @return HTML tagList with hero card, breakdown, and fondo status
render_results_hero <- function(resultado) {
  scenario <- detect_result_scenario(resultado)

  # Determine hero amount and details based on scenario
  if (scenario == SCENARIO_FONDO_VOLUNTARY) {
    # Voluntary contributions beat the Fondo cap
    hero_amount <- resultado$con_acciones$pension_afore
    hero_label <- "TU PENSION ESTIMADA (CON APORTACIONES)"
    tasa <- hero_amount / resultado$entrada$salario_mensual
    show_minimo_tag <- resultado$con_acciones$aplico_minimo %||% FALSE
  } else if (scenario == SCENARIO_FONDO_ELIGIBLE) {
    hero_amount <- resultado$con_fondo$pension_total
    hero_label <- "TU PENSION ESTIMADA (CON FONDO BIENESTAR)"
    tasa <- resultado$con_fondo$tasa_reemplazo
    show_minimo_tag <- FALSE
  } else if (scenario == SCENARIO_VOLUNTARY_IMPROVEMENT) {
    hero_amount <- resultado$con_acciones$pension_afore
    hero_label <- "TU PENSION ESTIMADA (CON APORTACIONES)"
    tasa <- hero_amount / resultado$entrada$salario_mensual
    show_minimo_tag <- resultado$con_acciones$aplico_minimo %||% FALSE
  } else {
    hero_amount <- resultado$solo_sistema$pension_mensual
    hero_label <- "TU PENSION ESTIMADA"
    tasa <- resultado$solo_sistema$tasa_reemplazo
    show_minimo_tag <- resultado$solo_sistema$aplico_minimo %||% FALSE
  }

  # Build hero card
  hero <- tags$div(
    class = "result-hero",
    `aria-label` = paste0("Tu pension estimada: ", format_currency(hero_amount), " por mes"),
    role = "region",
    tags$div(class = "result-hero-label", hero_label),
    tags$div(
      class = "result-hero-amount",
      format_currency(hero_amount),
      tags$span(class = "period", " /mes")
    ),
    tags$div(
      class = "result-hero-badge",
      paste0(round(tasa * 100), "% de tu salario")
    ),
    if (show_minimo_tag) {
      tags$div(class = "result-hero-tag", "Pension Minima Garantizada")
    }
  )

  # Build breakdown panel
  breakdown_rows <- list()

  # Detect if minimum guarantee applies
  aplico_minimo_flag <- resultado$solo_sistema$aplico_minimo %||% FALSE

  if (aplico_minimo_flag) {
    # When minimum applies, show detailed breakdown: calculated vs guaranteed
    pension_real <- resultado$solo_sistema$pension_calculada %||% resultado$solo_sistema$pension_mensual
    pension_min <- resultado$solo_sistema$pension_minima %||% PENSION_MINIMA_LEY97
    saldo_necesario <- resultado$solo_sistema$saldo_minimo_para_superar_garantia %||% 0
    saldo_actual_proy <- resultado$solo_sistema$saldo_proyectado %||% 0
    pct_del_minimo <- if (saldo_necesario > 0) min(100, round(saldo_actual_proy / saldo_necesario * 100)) else 100

    # Row: Calculated pension from AFORE
    breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
      class = "breakdown-row minimum-info",
      tags$span(
        class = "breakdown-label",
        tags$i(class = "bi bi-calculator"),
        "Pensión calculada de tu AFORE"
      ),
      tags$span(class = "breakdown-value",
        paste0(format_currency(pension_real), "/mes"))
    )

    # Row: Guaranteed minimum pension (floor)
    breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
      class = "breakdown-row minimum-info",
      tags$span(
        class = "breakdown-label",
        tags$i(class = "bi bi-shield-fill-check"),
        "Pensión mínima garantizada (piso legal)"
      ),
      tags$span(class = "breakdown-value",
        paste0(format_currency(pension_min), "/mes"))
    )

    # Row: Progress toward exceeding minimum
    breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
      class = "breakdown-row",
      tags$span(
        class = "breakdown-label",
        tags$i(class = "bi bi-graph-up-arrow"),
        "Avance hacia superar el mínimo"
      ),
      tags$span(class = "breakdown-value",
        paste0(pct_del_minimo, "% (", format_currency(saldo_actual_proy),
               " de ", format_currency(saldo_necesario), ")"))
    )
  } else {
    # Row 1: Base AFORE pension (simple view when no minimum)
    breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
      class = "breakdown-row",
      tags$span(
        class = "breakdown-label",
        tags$i(class = "bi bi-bank"),
        "Pension AFORE (solo sistema)"
      ),
      tags$span(class = "breakdown-value",
        paste0(format_currency(resultado$solo_sistema$pension_mensual), "/mes"))
    )
  }

  # Row 2: Voluntary contributions (if they make a difference)
  tiene_voluntarias <- (resultado$entrada$aportacion_voluntaria %||% 0) > 0
  pension_diff <- resultado$con_acciones$pension_afore - resultado$solo_sistema$pension_mensual
  saldo_diff <- resultado$con_acciones$saldo_proyectado - resultado$solo_sistema$saldo_proyectado

  if (tiene_voluntarias) {
    if (pension_diff > 0) {
      breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
        class = "breakdown-row highlight",
        tags$span(
          class = "breakdown-label",
          tags$i(class = "bi bi-plus-circle"),
          paste0("Aportaciones voluntarias ($",
            format(round(resultado$entrada$aportacion_voluntaria), big.mark = ","), "/mes)")
        ),
        tags$span(class = "breakdown-value",
          paste0("+", format_currency(pension_diff), "/mes"))
      )
    } else if (saldo_diff > 0) {
      breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
        class = "breakdown-row highlight",
        tags$span(
          class = "breakdown-label",
          tags$i(class = "bi bi-plus-circle"),
          paste0("Aportaciones voluntarias ($",
            format(round(resultado$entrada$aportacion_voluntaria), big.mark = ","), "/mes)")
        ),
        tags$span(class = "breakdown-value",
          paste0("+", format_currency(saldo_diff), " saldo"))
      )
    }
  }

  # Row 3: Fondo complement (only if eligible)
  fondo_elegible <- resultado$con_fondo$elegible
  if (fondo_elegible && resultado$con_fondo$complemento > 0) {
    if (scenario == SCENARIO_FONDO_VOLUNTARY) {
      # Vol contribs exceed Fondo cap -- Fondo not needed
      breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
        class = "breakdown-row",
        tags$span(
          class = "breakdown-label",
          tags$i(class = "bi bi-shield-check"),
          "Fondo Bienestar"
        ),
        tags$span(class = "breakdown-value fondo-not-needed",
          "No necesario")
      )
    } else {
      # Show Fondo complement
      complemento_con_vol <- resultado$con_acciones$complemento_fondo %||% resultado$con_fondo$complemento
      breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
        class = "breakdown-row highlight",
        tags$span(
          class = "breakdown-label",
          tags$i(class = "bi bi-shield-check"),
          "Complemento Fondo Bienestar"
        ),
        tags$span(class = "breakdown-value",
          paste0("+", format_currency(complemento_con_vol), "/mes"))
      )
      # Explain Fondo-masking when voluntary contributions are active
      if (tiene_voluntarias && saldo_diff > 0) {
        fondo_sin_vol <- resultado$con_fondo$complemento
        fondo_con_vol <- complemento_con_vol
        if (fondo_sin_vol > fondo_con_vol) {
          breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
            class = "breakdown-row fondo-dependency-note",
            tags$span(
              class = "breakdown-label",
              tags$i(class = "bi bi-info-circle"),
              paste0("Tus aportaciones reducen tu dependencia del Fondo (",
                format_currency(fondo_sin_vol), " ", "→", " ",
                format_currency(fondo_con_vol), ")")
            )
          )
        }
      }
    }
  }

  # Total row (only if there are additions)
  if (length(breakdown_rows) > 1) {
    breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
      class = "breakdown-row total",
      tags$span(class = "breakdown-label", "Total pensión mensual"),
      tags$span(class = "breakdown-value", paste0(format_currency(hero_amount), "/mes"))
    )
  }

  # Saldo info row
  saldo_to_show <- if (tiene_voluntarias) {
    resultado$con_acciones$saldo_proyectado
  } else {
    resultado$solo_sistema$saldo_proyectado
  }
  breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
    class = "breakdown-row",
    tags$span(
      class = "breakdown-label",
      tags$i(class = "bi bi-piggy-bank"),
      "Saldo AFORE proyectado al retiro"
    ),
    tags$span(class = "breakdown-value", format_currency(saldo_to_show))
  )

  breakdown <- tags$div(
    class = "result-breakdown",
    tags$div(class = "result-breakdown-header", "Desglose de tu pensión"),
    tagList(breakdown_rows)
  )

  # Fondo status inline
  fondo_status <- if (resultado$con_fondo$elegible) {
    tags$div(
      class = "fondo-status-inline eligible",
      tags$i(class = "bi bi-check-circle-fill"),
      tags$span(
        tags$strong("Elegible para Fondo Bienestar. "),
        "Recuerda: es un programa nuevo (2024) y su sostenibilidad no está garantizada."
      )
    )
  } else {
    tags$div(
      class = "fondo-status-inline not-eligible",
      tags$i(class = "bi bi-info-circle"),
      tags$span(
        tags$strong("No elegible para Fondo Bienestar. "),
        resultado$fondo_bienestar$razon_no_elegible
      )
    )
  }

  # Minimum note (when minimum guarantee applies)
  minimum_note <- if (aplico_minimo_flag) {
    saldo_necesario_note <- resultado$solo_sistema$saldo_minimo_para_superar_garantia %||% 0
    tags$div(
      class = "minimum-note",
      tags$i(class = "bi bi-lightbulb"),
      tags$div(
        "Tu salario SI mejora tu saldo proyectado. Cuando tu saldo supere ",
        tags$strong(format_currency(saldo_necesario_note)),
        ", tu pensión real superará la mínima garantizada. ",
        "Aumentar aportaciones voluntarias o retrasar el retiro te acercan a este punto."
      )
    )
  } else {
    NULL
  }

  # Encouragement (inline, not separate)
  tasa_base <- resultado$solo_sistema$tasa_reemplazo
  encouragement <- if (tasa_base < 0.4 && !resultado$con_fondo$elegible) {
    encouragement_message(resultado)
  } else {
    NULL
  }

  tagList(hero, breakdown, minimum_note, fondo_status, encouragement)
}

#' Render hero + breakdown results for Ley 73
#' @param res Result list with regimen = "ley73"
#' @return HTML tagList with hero card and breakdown
render_results_hero_ley73 <- function(res) {
  # Early return for ineligible workers (< 500 weeks or < 60 years)
  if (!res$pension_base$elegible) {
    semanas_actuales <- res$entrada$semanas_actuales %||% 0
    edad_retiro <- res$entrada$edad_retiro %||% 65
    anios_restantes <- max(0, edad_retiro - (res$entrada$edad_actual %||% 40))
    semanas_al_retiro <- semanas_actuales + (anios_restantes * SEMANAS_POR_ANO)
    semanas_faltantes <- max(0, 500 - semanas_al_retiro)

    hero <- tags$div(
      class = "result-hero",
      tags$div(class = "result-hero-label", "RESULTADO DE TU SIMULACION"),
      tags$div(
        class = "result-hero-amount",
        style = "font-size: 1.5rem;",
        "Aun no cumples los requisitos"
      ),
      tags$div(class = "result-hero-badge", "No elegible para pension Ley 73")
    )

    reason <- tags$div(
      class = "result-breakdown",
      tags$div(class = "result-breakdown-header", "Que necesitas"),
      tags$div(
        class = "breakdown-row",
        tags$span(
          class = "breakdown-label",
          tags$i(class = "bi bi-exclamation-triangle"),
          res$pension_base$mensaje
        )
      ),
      if (semanas_faltantes > 0) {
        tags$div(
          class = "breakdown-row",
          tags$span(
            class = "breakdown-label",
            tags$i(class = "bi bi-calendar-check"),
            paste0("Te faltan ", format(semanas_faltantes, big.mark = ","),
                   " semanas (", round(semanas_faltantes / SEMANAS_POR_ANO, 1),
                   " anos aprox.) para llegar al minimo de 500")
          )
        )
      }
    )

    guidance <- tags$div(
      class = "fondo-eligible-callout",
      tags$i(class = "bi bi-lightbulb me-2"),
      tags$strong("Modalidad 40: "),
      "Si dejaste de cotizar, puedes inscribirte en Modalidad 40 para seguir ",
      "sumando semanas y mejorar tu pension. Consulta con tu subdelegacion IMSS."
    )

    return(tagList(hero, reason, guidance))
  }

  pension_base <- res$pension_base$pension_mensual
  pension_m40 <- if (!is.null(res$pension_m40)) res$pension_m40$pension_con_m40 else pension_base

  # Hero shows the best available pension
  best_pension <- max(pension_base, pension_m40)
  m40_active <- !is.null(res$pension_m40) && pension_m40 > pension_base
  tasa <- if (m40_active) {
    res$pension_m40$nueva_pension_detalle$tasa_reemplazo %||% res$pension_base$tasa_reemplazo
  } else {
    res$pension_base$tasa_reemplazo
  }
  show_minimo <- res$pension_base$aplico_minimo %||% FALSE

  hero <- tags$div(
    class = "result-hero",
    tags$div(class = "result-hero-label", "TU PENSION LEY 73 ESTIMADA"),
    tags$div(
      class = "result-hero-amount",
      format_currency(best_pension),
      tags$span(class = "period", " /mes")
    ),
    tags$div(
      class = "result-hero-badge",
      paste0(round(tasa * 100), "% de tu salario")
    ),
    if (m40_active) {
      tags$div(class = "result-hero-tag m40-tag",
        tags$i(class = "bi bi-arrow-up-circle me-1"),
        "Incluye Modalidad 40"
      )
    },
    if (m40_active) {
      tags$div(class = "result-hero-base-pension",
        paste0("Sin Modalidad 40: ", format_currency(pension_base), "/mes")
      )
    },
    if (show_minimo) {
      tags$div(class = "result-hero-tag", "Pension Minima Garantizada")
    }
  )

  # Breakdown (only reached when elegible = TRUE, ineligible returns early above)
  breakdown_rows <- list()

  if (show_minimo) {
    # When minimum applies, show calculated vs guaranteed
    pension_sin_min <- res$pension_base$pension_sin_minimo %||% pension_base
    pension_min_val <- SM_DIARIO_2025 * DIAS_POR_MES  # 1 SM mensual

    breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
      class = "breakdown-row minimum-info",
      tags$span(
        class = "breakdown-label",
        tags$i(class = "bi bi-calculator"),
        paste0("Pensión calculada Ley 73 (", res$pension_base$tipo_pension, ")")
      ),
      tags$span(class = "breakdown-value",
        paste0(format_currency(pension_sin_min), "/mes"))
    )

    breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
      class = "breakdown-row minimum-info",
      tags$span(
        class = "breakdown-label",
        tags$i(class = "bi bi-shield-fill-check"),
        "Pensión mínima garantizada (1 SM)"
      ),
      tags$span(class = "breakdown-value",
        paste0(format_currency(pension_min_val), "/mes"))
    )
  } else {
    # Normal view when pension exceeds minimum
    breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
      class = "breakdown-row",
      tags$span(
        class = "breakdown-label",
        tags$i(class = "bi bi-bank"),
        paste0("Pension Ley 73 (", res$pension_base$tipo_pension, ")")
      ),
      tags$span(class = "breakdown-value",
        paste0(format_currency(pension_base), "/mes"))
    )
  }

  # Factor info
  breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
    class = "breakdown-row",
    tags$span(
      class = "breakdown-label",
      tags$i(class = "bi bi-percent"),
      paste0("Factor de edad (", res$entrada$edad_retiro, " años)")
    ),
    tags$span(class = "breakdown-value",
      paste0(round(res$pension_base$factor_edad * 100), "%"))
  )

  # M40 improvement (if available and different from base)
  if (!is.null(res$pension_m40) && res$pension_m40$incremento_mensual > 0) {
    breakdown_rows[[length(breakdown_rows) + 1]] <- tags$div(
      class = "breakdown-row highlight",
      tags$span(
        class = "breakdown-label",
        tags$i(class = "bi bi-arrow-up-circle"),
        "Con Modalidad 40"
      ),
      tags$span(class = "breakdown-value",
        paste0(format_currency(pension_m40), "/mes (+",
          format_currency(res$pension_m40$incremento_mensual), ")"))
    )
  }

  breakdown <- tags$div(
    class = "result-breakdown",
    tags$div(class = "result-breakdown-header", "Desglose de tu pensión"),
    tagList(breakdown_rows)
  )

  # M40 cost callout
  m40_callout <- if (!is.null(res$pension_m40) && res$pension_m40$incremento_mensual > 0) {
    tags$div(
      class = "m40-cost-callout",
      tags$i(class = "bi bi-info-circle me-2"),
      tags$strong("Modalidad 40: "),
      paste0("Costo mensual de ", format_currency(res$pension_m40$cuota_mensual_m40),
        " por ", res$pension_m40$meses_m40, " meses. ",
        "Recuperas la inversion en ~", res$pension_m40$meses_recuperacion, " meses. ",
        res$pension_m40$recomendacion)
    )
  }

  # Minimum note for Ley 73
  minimum_note_73 <- if (show_minimo) {
    tags$div(
      class = "minimum-note",
      tags$i(class = "bi bi-lightbulb"),
      tags$div(
        "Tu pensión calculada está por debajo del salario mínimo, por lo que recibes la pensión mínima garantizada. ",
        "Aumentar tus semanas cotizadas o mejorar tu promedio salarial (por ejemplo con Modalidad 40) puede superar este piso."
      )
    )
  } else {
    NULL
  }

  # Fondo status for Ley 73 (always not applicable)
  fondo_status <- tags$div(
    class = "fondo-status-inline not-eligible",
    tags$i(class = "bi bi-info-circle"),
    tags$span("Ley 73: El Fondo Bienestar no aplica. Tu pensión definida ya es generalmente mejor.")
  )

  tagList(hero, breakdown, m40_callout, minimum_note_73, fondo_status)
}

# ============================================================================
# MENSAJES DE ALIENTO
# ============================================================================

#' Crear mensaje de aliento basado en los resultados
#' @param resultado Resultado del calculo
#' @return HTML del mensaje de aliento
encouragement_message <- function(resultado) {
  # Determinar situacion
  tasa <- resultado$solo_sistema$tasa_reemplazo
  fondo_elegible <- resultado$con_fondo$elegible
  tiene_voluntarias <- resultado$entrada$aportacion_voluntaria > 0

  if (tasa >= 0.7) {
    # Buena situacion
    return(tags$div(
      class = "encouragement-message success",
      tags$div(
        class = "encouragement-title",
        tags$i(class = "bi bi-emoji-smile"),
        "Vas por buen camino"
      ),
      tags$p(
        class = "encouragement-text",
        "Tu pensión proyectada es razonable. Sigue así y considera aumentar ",
        "tus aportaciones voluntarias para aún más tranquilidad."
      )
    ))
  } else if (tasa >= 0.4) {
    # Situacion intermedia
    return(tags$div(
      class = "encouragement-message",
      tags$div(
        class = "encouragement-title",
        tags$i(class = "bi bi-lightbulb"),
        "Hay oportunidad de mejorar"
      ),
      tags$p(
        class = "encouragement-text",
        "Tu pensión cubre parte de tus necesidades. La buena noticia: ",
        tags$strong("pequeñas acciones hoy hacen gran diferencia mañana."),
        " Usa los controles abajo para ver el impacto."
      ),
      tags$div(
        class = "encouragement-actions",
        tags$span(class = "encouragement-action", "Aumentar aportación voluntaria"),
        tags$span(class = "encouragement-action", "Revisar tu AFORE"),
        tags$span(class = "encouragement-action", "Considerar edad de retiro")
      )
    ))
  } else {
    # Situacion que necesita atencion
    return(tags$div(
      class = "encouragement-message warning",
      tags$div(
        class = "encouragement-title",
        tags$i(class = "bi bi-exclamation-triangle"),
        "Atención: Tu pensión necesita refuerzo"
      ),
      tags$p(
        class = "encouragement-text",
        "Una pensión del ", round(tasa * 100), "% de tu salario es baja, pero ",
        tags$strong("esto NO es una sentencia."),
        " Muchas personas han mejorado dramáticamente su situación con acciones consistentes."
      ),
      tags$div(
        class = "encouragement-actions",
        tags$span(class = "encouragement-action", "Empezar aportaciones voluntarias"),
        tags$span(class = "encouragement-action", "Cambiar a mejor AFORE"),
        tags$span(class = "encouragement-action", "Retrasar retiro si es posible")
      )
    ))
  }
}
