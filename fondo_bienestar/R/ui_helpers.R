# R/ui_helpers.R - Funciones auxiliares para la interfaz de usuario
# Simulador de Pension IMSS + Fondo Bienestar - Version 1.0

# ============================================================================
# TEMA DE LA APLICACION
# ============================================================================

#' Crear tema personalizado para la aplicacion
#' @return Objeto bs_theme de bslib
pension_theme <- function() {
  bslib::bs_theme(
    version = 5,  # Bootstrap 5

    # Colores primarios - Trust Navy & Teal
    primary = "#1a365d",     # Navy 700
    secondary = "#0d9488",   # Teal 600
    success = "#059669",     # Green 600
    warning = "#d97706",     # Amber 600
    danger = "#dc2626",      # Red 600
    info = "#3182ce",        # Blue 500

    # Tipografia - System fonts for performance
    base_font = bslib::font_collection(
      "-apple-system", "BlinkMacSystemFont", "Segoe UI", "Roboto",
      "Helvetica Neue", "Arial", "sans-serif"
    ),
    heading_font = bslib::font_collection(
      "-apple-system", "BlinkMacSystemFont", "Segoe UI", "Roboto",
      "Helvetica Neue", "Arial", "sans-serif"
    ),
    code_font = bslib::font_collection("SFMono-Regular", "Menlo", "Monaco", "Consolas", "monospace"),

    # Variables personalizadas
    "body-bg" = "#f8fafc",
    "card-bg" = "#ffffff",
    "border-radius" = "0.5rem",
    "border-radius-lg" = "0.75rem",

    # Tamanos de fuente
    "font-size-base" = "1rem",
    "h1-font-size" = "2rem",
    "h2-font-size" = "1.5rem",
    "h3-font-size" = "1.25rem"
  )
}

# ============================================================================
# LANDING PAGE COMPONENTS
# ============================================================================

#' Crear seccion hero de la landing page
#' @return HTML de la seccion hero
hero_section <- function() {
  tags$div(
    class = "hero-section",

    tags$div(
      class = "hero-content",

      # Thesis
      tags$h1(
        class = "hero-thesis",
        "Tu pension es tuya. Conocerla te da poder."
      ),

      # Subtitle
      tags$p(
        class = "hero-subtitle",
        "Millones de trabajadores mexicanos no conocen su pension real.",
        "Esta herramienta cambia eso en 5 minutos."
      ),

      # Value Propositions
      tags$div(
        class = "hero-value-props",
        value_prop_item("bi-clock", "Calcula en 5 minutos"),
        value_prop_item("bi-book", "Entiende Ley 73, 97 y Bienestar"),
        value_prop_item("bi-lightning-charge", "Descubre que hacer HOY"),
        value_prop_item("bi-shield-lock", "Sin registro, 100% privado")
      ),

      # CTAs
      tags$div(
        class = "hero-ctas",
        tags$button(
          id = "start_wizard",
          class = "hero-cta-primary",
          tags$i(class = "bi bi-calculator me-2"),
          "Calcular mi pension"
        ),
        tags$button(
          id = "show_context",
          class = "hero-cta-secondary",
          tags$i(class = "bi bi-info-circle me-2"),
          "Quiero entender primero"
        )
      ),

      # Trust Indicators
      trust_indicators()
    )
  )
}

#' Crear item de propuesta de valor
#' @param icon Clase del icono Bootstrap
#' @param text Texto de la propuesta
#' @return HTML del item
value_prop_item <- function(icon, text) {
  tags$div(
    class = "value-prop",
    tags$i(class = icon),
    tags$span(text)
  )
}

#' Crear indicadores de confianza
#' @return HTML de los indicadores
trust_indicators <- function() {
  tags$div(
    class = "trust-indicators",

    tags$div(
      class = "trust-item",
      tags$span(class = "trust-number", "100%"),
      tags$span(class = "trust-label", "Gratuito")
    ),

    tags$div(
      class = "trust-item",
      tags$span(class = "trust-number", "0"),
      tags$span(class = "trust-label", "Datos compartidos")
    ),

    tags$div(
      class = "trust-item",
      tags$span(class = "trust-number", "2025"),
      tags$span(class = "trust-label", "Datos actualizados")
    )
  )
}

#' Crear seccion de contexto educativo
#' @return HTML de la seccion de contexto
context_section <- function() {
  tags$div(
    id = "context_section",
    class = "context-section",
    style = "display: none;",

    tags$div(
      class = "context-header",
      tags$h2(class = "context-title", "Entendiendo el Sistema de Pensiones en Mexico"),
      tags$p(class = "context-subtitle", "Una breve historia y lo que significa para ti")
    ),

    # Timeline
    tags$h5(class = "mb-3", tags$i(class = "bi bi-clock-history me-2 text-primary"), "Historia del sistema"),
    pension_timeline(),

    tags$hr(class = "my-4"),

    # Comparison Table
    tags$h5(class = "mb-3", tags$i(class = "bi bi-table me-2 text-primary"), "Comparacion honesta"),
    comparison_table(),

    tags$hr(class = "my-4"),

    # Control Framework
    tags$h5(class = "mb-3", tags$i(class = "bi bi-bullseye me-2 text-primary"), "Que puedes controlar?"),
    control_framework(),

    tags$hr(class = "my-4"),

    # Key Message
    key_message(
      "El Fondo Bienestar puede ser excelente, pero ",
      tags$strong("tus aportaciones voluntarias son la parte MAS SEGURA"),
      " de tu pension. Enfoca tu energia en lo que controlas."
    ),

    # CTA to start
    tags$div(
      class = "text-center mt-4",
      tags$button(
        id = "start_wizard_from_context",
        class = "btn btn-primary btn-lg",
        tags$i(class = "bi bi-arrow-right me-2"),
        "Ahora si, calcular mi pension"
      )
    )
  )
}

#' Crear timeline del sistema de pensiones
#' @return HTML del timeline
pension_timeline <- function() {
  tags$div(
    class = "timeline",

    timeline_item(
      year = "1973",
      title = "Ley del Seguro Social",
      description = "Pension definida basada en semanas y salario. Si empezaste antes de julio 1997, estas aqui."
    ),

    timeline_item(
      year = "1997",
      title = "Sistema AFOREs",
      description = "Cuentas individuales. Tu pension depende de lo que ahorres. La mayoria de trabajadores actuales."
    ),

    timeline_item(
      year = "2020",
      title = "Reforma de Pensiones",
      description = "Reduce requisito a 1,000 semanas. Aumenta aportaciones patronales gradualmente hasta 2030."
    ),

    timeline_item(
      year = "2024",
      title = "Fondo de Pensiones para el Bienestar",
      description = "Complementa pensiones hasta el 100% del ultimo salario. Programa nuevo, sostenibilidad por confirmar."
    )
  )
}

#' Crear item del timeline
#' @param year Ano del evento
#' @param title Titulo del evento
#' @param description Descripcion del evento
#' @return HTML del item
timeline_item <- function(year, title, description) {
  tags$div(
    class = "timeline-item",
    tags$div(class = "timeline-dot"),
    tags$span(class = "timeline-year", year),
    tags$div(class = "timeline-title", title),
    tags$p(class = "timeline-desc", description)
  )
}

#' Crear tabla de comparacion de sistemas
#' @return HTML de la tabla
comparison_table <- function() {
  tags$div(
    class = "comparison-table-container",
    tags$table(
      class = "comparison-table",
      tags$thead(
        tags$tr(
          tags$th("Sistema"),
          tags$th("Lo Bueno"),
          tags$th("Lo Incierto")
        )
      ),
      tags$tbody(
        tags$tr(
          tags$td(tags$strong("Ley 73")),
          tags$td(class = "col-good", "Pension definida, certeza, generalmente mejor"),
          tags$td(class = "col-uncertain", "Solo para quienes empezaron antes de julio 1997")
        ),
        tags$tr(
          tags$td(tags$strong("Ley 97 (AFORE)")),
          tags$td(class = "col-good", "Tu dinero, transparencia, portabilidad"),
          tags$td(class = "col-uncertain", "Pensiones bajas (15-35% del salario tipicamente)")
        ),
        tags$tr(
          tags$td(tags$strong("Fondo Bienestar")),
          tags$td(class = "col-good", "Puede complementar hasta 100% del salario"),
          tags$td(class = "col-uncertain", "Programa nuevo (2024), sostenibilidad a largo plazo incierta")
        )
      )
    )
  )
}

#' Crear framework de control
#' @return HTML del framework
control_framework <- function() {
  tags$div(
    class = "control-framework",

    # Green Zone
    tags$div(
      class = "control-zone green",
      tags$div(class = "control-zone-title", "TU CONTROLAS"),
      tags$ul(
        class = "control-zone-items list-unstyled mb-0",
        tags$li("Aportaciones voluntarias"),
        tags$li("Eleccion de AFORE"),
        tags$li("Edad de retiro"),
        tags$li("Continuidad laboral")
      )
    ),

    # Yellow Zone
    tags$div(
      class = "control-zone yellow",
      tags$div(class = "control-zone-title", "INFLUENCIA PARCIAL"),
      tags$ul(
        class = "control-zone-items list-unstyled mb-0",
        tags$li("Rendimientos AFORE"),
        tags$li("Salario futuro"),
        tags$li("Semanas cotizadas")
      )
    ),

    # Red Zone
    tags$div(
      class = "control-zone red",
      tags$div(class = "control-zone-title", "NO CONTROLAS"),
      tags$ul(
        class = "control-zone-items list-unstyled mb-0",
        tags$li("Futuro del Fondo Bienestar"),
        tags$li("Cambios en leyes"),
        tags$li("Esperanza de vida"),
        tags$li("Inflacion")
      )
    )
  )
}

#' Crear mensaje clave
#' @param ... Contenido del mensaje
#' @return HTML del mensaje
key_message <- function(...) {
  tags$div(
    class = "key-message",
    tags$i(class = "bi bi-lightbulb-fill"),
    tags$div(
      class = "key-message-text",
      ...
    )
  )
}

# ============================================================================
# COMPONENTES DEL WIZARD
# ============================================================================

#' Crear encabezado del wizard con pasos
#' @param current_step Paso actual (1-4)
#' @return HTML del encabezado
wizard_header <- function(current_step = 1) {
  steps <- c(
    "Datos Personales",
    "Datos Laborales",
    "AFORE y Aportaciones",
    "Resultados"
  )

  tags$div(
    class = "wizard-header",
    tags$div(
      class = "wizard-steps",
      lapply(1:4, function(i) {
        step_class <- "wizard-step"
        if (i < current_step) step_class <- paste(step_class, "completed")
        if (i == current_step) step_class <- paste(step_class, "active")

        tagList(
          if (i > 1) tags$span(class = "wizard-line"),
          tags$div(
            class = step_class,
            id = paste0("step", i, "_indicator"),
            tags$span(class = "step-number", i),
            tags$span(class = "step-label d-none d-md-inline", steps[i])
          )
        )
      })
    )
  )
}

#' Crear panel de un paso del wizard
#' @param step_id ID del paso (ej: "step1")
#' @param title Titulo del paso
#' @param content Contenido del paso (tagList)
#' @param show_prev Mostrar boton anterior
#' @param show_next Mostrar boton siguiente
#' @param next_label Texto del boton siguiente
#' @param hidden Si TRUE, el panel inicia oculto
#' @return HTML del panel
wizard_panel <- function(step_id,
                          title,
                          content,
                          show_prev = TRUE,
                          show_next = TRUE,
                          next_label = "Siguiente",
                          hidden = FALSE) {

  panel <- tags$div(
    id = paste0(step_id, "_panel"),
    class = "wizard-panel card shadow-sm",

    tags$div(
      class = "card-header bg-white border-0 pt-4",
      tags$h4(class = "card-title mb-0", title)
    ),

    tags$div(
      class = "card-body",
      content
    ),

    tags$div(
      class = "card-footer bg-white border-0 d-flex justify-content-between pb-4",

      # Boton anterior
      if (show_prev) {
        actionButton(
          paste0("prev_", step_id),
          tagList(tags$i(class = "bi bi-arrow-left me-2"), "Anterior"),
          class = "btn btn-outline-secondary"
        )
      } else {
        tags$div()  # Placeholder vacio
      },

      # Boton siguiente
      if (show_next) {
        actionButton(
          paste0("next_", step_id),
          tagList(next_label, tags$i(class = "bi bi-arrow-right ms-2")),
          class = "btn btn-primary"
        )
      } else {
        tags$div()
      }
    )
  )

  if (hidden) {
    shinyjs::hidden(panel)
  } else {
    panel
  }
}

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

#' Crear las tres tarjetas de resultados
#' @param resultado Resultado de calculate_pension_with_fondo
#' @return HTML con las tres tarjetas
render_result_cards <- function(resultado) {

  # Tarjeta 1: Solo sistema
  card1 <- result_card(
    title = "SOLO SISTEMA",
    amount = resultado$solo_sistema$pension_mensual,
    subtitle = "Tu AFORE sin complementos",
    badge_text = paste0(round(resultado$solo_sistema$tasa_reemplazo * 100), "% de tu salario"),
    badge_class = "secondary",
    card_class = "baseline"
  )

  # Tarjeta 2: Con Fondo Bienestar
  if (resultado$con_fondo$elegible) {
    card2 <- result_card(
      title = "+ FONDO BIENESTAR",
      amount = resultado$con_fondo$pension_total,
      subtitle = "Si el Fondo existe cuando te jubiles",
      badge_text = "Elegible",
      badge_class = "success",
      card_class = "fondo"
    )
  } else {
    card2 <- result_card(
      title = "+ FONDO BIENESTAR",
      amount = 0,  # Show $0 when not eligible (not the same as Card 1)
      subtitle = "No elegible para este programa",
      badge_text = "No aplica",
      badge_class = "secondary",
      card_class = "fondo disabled"
    )
  }

  # Tarjeta 3: Con tus acciones (shows AFORE-only pension to display true impact)
  # Calculate pension and saldo differences
  pension_diff <- resultado$con_acciones$pension_afore - resultado$solo_sistema$pension_mensual
  saldo_diff <- resultado$con_acciones$saldo_proyectado - resultado$solo_sistema$saldo_proyectado
  tiene_voluntarias <- (resultado$entrada$aportacion_voluntaria %||% 0) > 0

  # When pension minimum applies to both, show saldo increase instead
  if (pension_diff == 0 && tiene_voluntarias && saldo_diff > 0) {
    badge_text <- paste0("+", format_currency(saldo_diff), " saldo")
    subtitle_text <- "Pension minima garantizada (saldo mayor)"
  } else if (pension_diff > 0) {
    badge_text <- paste0("+", format_currency(pension_diff), "/mes")
    subtitle_text <- "Tu pension AFORE con aportaciones voluntarias"
  } else {
    badge_text <- "Sin aportaciones extra"
    subtitle_text <- "Agrega aportaciones voluntarias para mejorar"
  }

  card3 <- result_card(
    title = "+ TUS ACCIONES",
    amount = resultado$con_acciones$pension_afore,
    subtitle = subtitle_text,
    badge_text = badge_text,
    badge_class = "warning",
    card_class = "empowerment",
    show_star = TRUE
  )

  fluidRow(
    class = "result-cards-container stagger-children",
    column(4, class = "col-md-4 mb-3 animate-fadeInUp", card1),
    column(4, class = "col-md-4 mb-3 animate-fadeInUp", card2),
    column(4, class = "col-md-4 mb-3 animate-fadeInUp", card3)
  )
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
        "Tu pension proyectada es razonable. Sigue asi y considera aumentar ",
        "tus aportaciones voluntarias para aun mas tranquilidad."
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
        "Tu pension cubre parte de tus necesidades. La buena noticia: ",
        tags$strong("pequenas acciones hoy hacen gran diferencia manana."),
        " Usa los controles abajo para ver el impacto."
      ),
      tags$div(
        class = "encouragement-actions",
        tags$span(class = "encouragement-action", "Aumentar aportacion voluntaria"),
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
        "Atencion: Tu pension necesita refuerzo"
      ),
      tags$p(
        class = "encouragement-text",
        "Una pension del ", round(tasa * 100), "% de tu salario es baja, pero ",
        tags$strong("esto NO es una sentencia."),
        " Muchas personas han mejorado dramaticamente su situacion con acciones consistentes."
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
  "UMA" = "Unidad de Medida y Actualizacion. Indicador que reemplaza al salario minimo para calculos oficiales desde 2016.",

  "SBC" = "Salario Base de Cotizacion. El salario registrado ante el IMSS, que puede ser diferente al salario real.",

  "Semanas cotizadas" = "Numero de semanas que tu empleador ha reportado al IMSS. Cada semana suma a tu historial.",

  "Cesantia" = "Pension anticipada entre los 60 y 64 anos. Tiene un factor de reduccion (75% a los 60, hasta 95% a los 64).",

  "Vejez" = "Pension completa a partir de los 65 anos, sin factor de reduccion.",

  "Retiro programado" = "Modalidad de pension donde tu AFORE te paga mes a mes hasta agotar tu saldo. El monto se recalcula cada ano.",

  "Renta vitalicia" = "Modalidad de pension donde una aseguradora te paga de por vida a cambio de tu saldo AFORE.",

  "Densidad de cotizacion" = "Porcentaje de tu vida laboral en que has cotizado. Promedio nacional: ~50-65%.",

  "Fondo Bienestar" = "Fondo de Pensiones para el Bienestar (2024). Complementa pensiones de trabajadores con salario <= $17,364/mes hasta el 100% de su ultimo salario.",

  "Modalidad 40" = "Continuacion voluntaria en el regimen obligatorio. Permite a ex-trabajadores seguir cotizando para mejorar su pension Ley 73.",

  "IRN" = "Indicador de Rendimiento Neto. Mide el rendimiento de una AFORE descontando comisiones. Mayor IRN = mejor desempeno.",

  "Ley 73" = "Sistema de pension anterior a julio 1997. Pension definida basada en salario y semanas. Generalmente mas favorable.",

  "Ley 97" = "Sistema de pension actual (AFORE). Cuenta individual donde cada quien ahorra para su propia pension."
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

#' Crear panel tecnico colapsable con supuestos
#' @param resultado Resultado de calculate_pension_with_fondo
#' @return HTML del panel tecnico
technical_panel <- function(resultado) {

  tags$div(
    class = "card mt-4",

    tags$div(
      class = "card-header bg-light",
      tags$a(
        class = "btn btn-link text-decoration-none",
        `data-bs-toggle` = "collapse",
        href = "#technicalCollapse",
        role = "button",
        tags$i(class = "bi bi-gear me-2"),
        "Panel Tecnico (ver supuestos y formulas)"
      )
    ),

    tags$div(
      id = "technicalCollapse",
      class = "collapse",

      tags$div(
        class = "card-body",

        tags$h6("Supuestos utilizados:"),
        tags$ul(
          tags$li(paste0("Rendimiento real: ", format_percent(resultado$entrada$escenario %>%
            switch("conservador" = 0.03, "base" = 0.04, "optimista" = 0.05, 0.04)))),
          tags$li(paste0("AFORE: ", resultado$entrada$afore)),
          tags$li(paste0("Umbral Fondo Bienestar: ", format_currency(get_umbral_fondo_bienestar(ANIO_ACTUAL)))),
          tags$li(paste0("UMA diaria ", ANIO_ACTUAL, ": ", format_currency(UMA_DIARIA_2025))),
          tags$li(paste0("Salario minimo ", ANIO_ACTUAL, ": ", format_currency(SM_DIARIO_2025)))
        ),

        tags$h6(class = "mt-3", "Notas importantes:"),
        tags$ul(
          tags$li("Esta es una estimacion educativa, no una garantia."),
          tags$li("Las leyes y politicas pueden cambiar."),
          tags$li("El Fondo Bienestar es un programa nuevo (2024) con sostenibilidad incierta."),
          tags$li("Consulta tu estado de cuenta oficial en IMSS y tu AFORE.")
        ),

        tags$div(
          class = "mt-3",
          tags$a(
            href = "https://www.imss.gob.mx/",
            target = "_blank",
            class = "btn btn-outline-secondary btn-sm me-2",
            tags$i(class = "bi bi-box-arrow-up-right me-1"),
            "IMSS"
          ),
          tags$a(
            href = "https://www.consar.gob.mx/",
            target = "_blank",
            class = "btn btn-outline-secondary btn-sm",
            tags$i(class = "bi bi-box-arrow-up-right me-1"),
            "CONSAR"
          )
        )
      )
    )
  )
}

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

# ============================================================================
# COMPONENTES DE DOCUMENTOS
# ============================================================================

#' Crear seccion de visualizacion de documentos
#' @return HTML de la seccion de documentos
download_section <- function() {
  tags$div(
    class = "download-section mt-4 p-4 bg-light rounded-3",

    tags$h5(
      class = "mb-3",
      tags$i(class = "bi bi-file-earmark-text me-2"),
      "Ver tus resultados"
    ),

    # First row: Documento Tecnico + Resumen Ejecutivo
    fluidRow(
      class = "mb-3",
      column(6,
        actionButton(
          "ver_tecnico",
          tagList(
            tags$i(class = "bi bi-file-text me-2"),
            "Documento Tecnico",
            tags$br(),
            tags$small(class = "text-muted", "Metodologia y formulas")
          ),
          class = "btn btn-outline-primary w-100 py-3"
        )
      ),
      column(6,
        actionButton(
          "ver_resumen",
          tagList(
            tags$i(class = "bi bi-file-earmark-richtext me-2"),
            "Resumen Ejecutivo",
            tags$br(),
            tags$small(class = "text-muted", "Para ti y tu familia")
          ),
          class = "btn btn-outline-secondary w-100 py-3"
        )
      )
    ),

    # Second row: Reporte Basico + Metodologia
    fluidRow(
      column(6,
        actionButton(
          "ver_reporte",
          tagList(
            tags$i(class = "bi bi-printer me-2"),
            "Reporte Basico",
            tags$br(),
            tags$small(class = "text-muted", "Para imprimir")
          ),
          class = "btn btn-outline-info w-100 py-3"
        )
      ),
      column(6,
        actionButton(
          "ver_metodologia",
          tagList(
            tags$i(class = "bi bi-book me-2"),
            "Metodologia",
            tags$br(),
            tags$small(class = "text-muted", "Como calculamos")
          ),
          class = "btn btn-outline-dark w-100 py-3"
        )
      )
    )
  )
}
