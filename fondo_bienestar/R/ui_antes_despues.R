# R/ui_antes_despues.R - Antes/Despues comparison
# Simulador de Pension IMSS + Fondo Bienestar

# ============================================================================
# ANTES / DESPUES COMPARISON
# ============================================================================

#' Extract headline pension from a result object
#' @param resultado Result list from calculate_pension_with_fondo or Ley 73 calc
#' @return Single numeric pension amount (monthly)
get_hero_pension <- function(resultado) {
  if (!is.null(resultado$regimen) && resultado$regimen == REGIMEN_LEY73) {
    pension_base <- if (resultado$pension_base$elegible) resultado$pension_base$pension_mensual else 0
    pension_m40 <- if (!is.null(resultado$pension_m40)) resultado$pension_m40$pension_con_m40 else pension_base
    return(max(pension_base, pension_m40))
  }

  # Ley 97: use detect_result_scenario

  scenario <- detect_result_scenario(resultado)

  if (scenario == SCENARIO_FONDO_VOLUNTARY) {
    resultado$con_acciones$pension_afore
  } else if (scenario == SCENARIO_FONDO_ELIGIBLE) {
    resultado$con_fondo$pension_total
  } else if (scenario == SCENARIO_VOLUNTARY_IMPROVEMENT) {
    resultado$con_acciones$pension_afore
  } else {
    resultado$solo_sistema$pension_mensual
  }
}

#' Render antes/despues comparison box
#' @param res_orig Original result (from resultados_originales)
#' @param res_current Current result (from resultados, after slider changes)
#' @return HTML div with comparison
render_antes_despues_box <- function(res_orig, res_current) {
  pension_antes <- get_hero_pension(res_orig)
  pension_despues <- get_hero_pension(res_current)
  diferencia <- pension_despues - pension_antes

  if (abs(diferencia) < 0.01) {
    # Neutral state -- no changes yet
    return(tags$div(
      class = "antes-despues-box neutral",
      tags$div(class = "antes-despues-header", "Impacto de tus cambios"),
      tags$div(
        class = "antes-despues-neutral-msg",
        tags$i(class = "bi bi-sliders me-2"),
        "Mueve un control para ver el impacto"
      )
    ))
  }

  pct_change <- if (pension_antes > 0) diferencia / pension_antes * 100 else 0
  diff_class <- if (diferencia > 0) "positive" else "negative"
  diff_sign <- if (diferencia > 0) "+" else ""

  # Format the difference text
  diff_text <- if (pension_antes > 0) {
    paste0(diff_sign, format_currency(diferencia), "/mes (",
           diff_sign, round(pct_change, 1), "%)")
  } else {
    paste0(diff_sign, format_currency(diferencia), "/mes")
  }

  tags$div(
    class = paste("antes-despues-box", diff_class),
    tags$div(class = "antes-despues-header", "Impacto de tus cambios"),
    tags$div(
      class = "antes-despues-body",
      tags$div(
        class = "antes-col",
        tags$div(class = "ad-label", "Antes"),
        tags$div(class = "ad-amount", paste0(format_currency(pension_antes), "/mes"))
      ),
      tags$div(class = "antes-despues-arrow", `aria-hidden` = "true", HTML("&#8594;")),
      tags$span(class = "visually-hidden", "cambia a"),
      tags$div(
        class = "despues-col",
        tags$div(class = "ad-label", "Despues"),
        tags$div(class = "ad-amount", paste0(format_currency(pension_despues), "/mes"))
      )
    ),
    tags$div(
      class = paste("antes-despues-diff", diff_class),
      diff_text
    )
  )
}
