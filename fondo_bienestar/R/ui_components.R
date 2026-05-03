# R/ui_components.R - Tooltips, glossary, alerts, and misc UI components
# Simulador de Pension IMSS + Fondo Bienestar

# ============================================================================
# TOOLTIPS Y AYUDA
# ============================================================================

#' Crear icono de ayuda con tooltip
#' @param texto Texto del tooltip
#' @return HTML del icono
help_tooltip <- function(texto) {
  tags$span(
    class = "help-tooltip",
    `data-bs-toggle` = "tooltip",
    `data-bs-placement` = "top",
    title = texto,
    tags$i(class = "bi bi-question-circle text-muted ms-1")
  )
}

#' Crear input con label y tooltip de ayuda
#' @param input_fn Funcion del input (numericInput, selectInput, etc)
#' @param inputId ID del input
#' @param label Label del input
#' @param help_text Texto de ayuda
#' @param ... Otros argumentos para el input
#' @return HTML del input con ayuda
input_with_help <- function(input_fn, inputId, label, help_text, ...) {
  tagList(
    tags$label(
      `for` = inputId,
      class = "form-label",
      label,
      help_tooltip(help_text)
    ),
    input_fn(inputId, label = NULL, ...)
  )
}

# ============================================================================
# GLOSARIO
# ============================================================================

#' Definiciones del glosario
GLOSARIO <- list(
  "UMA" = "Unidad de Medida y Actualización. Indicador que reemplaza al salario mínimo para cálculos oficiales desde 2016.",

  "SBC" = "Salario Base de Cotización. El salario registrado ante el IMSS, que puede ser diferente al salario real.",

  "Semanas cotizadas" = "Número de semanas que tu empleador ha reportado al IMSS. Cada semana suma a tu historial.",

  "Cesantía" = "Pensión anticipada entre los 60 y 64 años. Tiene un factor de reducción (75% a los 60, hasta 95% a los 64).",

  "Vejez" = "Pensión completa a partir de los 65 años, sin factor de reducción.",

  "Retiro programado" = "Modalidad de pensión donde tu AFORE te paga mes a mes hasta agotar tu saldo. El monto se recalcula cada año.",

  "Renta vitalicia" = "Modalidad de pensión donde una aseguradora te paga de por vida a cambio de tu saldo AFORE.",

  "Densidad de cotización" = "Porcentaje de tu vida laboral en que has cotizado. Promedio nacional: ~50-65%.",

  "Fondo Bienestar" = "Fondo de Pensiones para el Bienestar (2024). Complementa pensiones de trabajadores con salario <= $17,364/mes hasta el 100% de su último salario.",

  "Modalidad 40" = "Continuación voluntaria en el régimen obligatorio. Permite a ex-trabajadores seguir cotizando para mejorar su pensión Ley 73.",

  "IRN" = "Indicador de Rendimiento Neto. Mide el rendimiento de una AFORE descontando comisiones. Mayor IRN = mejor desempeño.",

  "Ley 73" = "Sistema de pensión anterior a julio 1997. Pensión definida basada en salario y semanas. Generalmente más favorable.",

  "Ley 97" = "Sistema de pensión actual (AFORE). Cuenta individual donde cada quien ahorra para su propia pensión."
)

#' Crear panel de glosario
#' @return HTML del panel de glosario
glossary_panel <- function() {
  tags$div(
    class = "accordion",
    id = "glossaryAccordion",

    lapply(names(GLOSARIO), function(termino) {
      item_id <- gsub(" ", "_", termino)

      tags$div(
        class = "accordion-item",

        tags$h2(
          class = "accordion-header",
          tags$button(
            class = "accordion-button collapsed",
            type = "button",
            `data-bs-toggle` = "collapse",
            `data-bs-target` = paste0("#collapse_", item_id),
            termino
          )
        ),

        tags$div(
          id = paste0("collapse_", item_id),
          class = "accordion-collapse collapse",
          `data-bs-parent` = "#glossaryAccordion",

          tags$div(
            class = "accordion-body",
            GLOSARIO[[termino]]
          )
        )
      )
    })
  )
}

# ============================================================================
# MENSAJES DE ALERTA
# ============================================================================

#' Crear alerta con mensaje
#' @param mensaje Texto del mensaje
#' @param tipo "info", "success", "warning", "danger"
#' @param titulo Titulo opcional
#' @param dismissible Si TRUE, se puede cerrar
#' @return HTML de la alerta
alert_message <- function(mensaje, tipo = "info", titulo = NULL, dismissible = FALSE) {

  icon_class <- switch(tipo,
    "info" = "bi-info-circle",
    "success" = "bi-check-circle",
    "warning" = "bi-exclamation-triangle",
    "danger" = "bi-x-circle",
    "bi-info-circle"
  )

  alert_class <- paste("alert", paste0("alert-", tipo))
  if (dismissible) alert_class <- paste(alert_class, "alert-dismissible fade show")

  tags$div(
    class = alert_class,
    role = "alert",

    tags$i(class = paste(icon_class, "me-2")),

    if (!is.null(titulo)) {
      tags$strong(titulo, ": ")
    },

    mensaje,

    if (dismissible) {
      tags$button(
        type = "button",
        class = "btn-close",
        `data-bs-dismiss` = "alert",
        `aria-label` = "Close"
      )
    }
  )
}

# ============================================================================
# PANEL TECNICO
# ============================================================================

# ============================================================================
# FORMATEO ESPECIAL
# ============================================================================

#' Crear barra de progreso para tasa de reemplazo
#' @param tasa Tasa de reemplazo (0-1)
#' @return HTML de la barra
replacement_rate_bar <- function(tasa) {

  pct <- round(tasa * 100)

  bar_class <- if (pct < 30) {
    "bg-danger"
  } else if (pct < 50) {
    "bg-warning"
  } else if (pct < 70) {
    "bg-info"
  } else {
    "bg-success"
  }

  tags$div(
    class = "replacement-rate-container mt-2",

    tags$div(
      class = "d-flex justify-content-between mb-1",
      tags$small("Tasa de reemplazo"),
      tags$small(class = "fw-bold", paste0(pct, "%"))
    ),

    tags$div(
      class = "progress",
      style = "height: 8px;",
      tags$div(
        class = paste("progress-bar", bar_class),
        role = "progressbar",
        style = paste0("width: ", min(pct, 100), "%;"),
        `aria-valuenow` = pct,
        `aria-valuemin` = "0",
        `aria-valuemax` = "100"
      )
    )
  )
}
