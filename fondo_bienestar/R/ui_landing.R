# R/ui_landing.R - Landing page components
# Simulador de Pension IMSS + Fondo Bienestar

# ============================================================================
# LANDING PAGE COMPONENTS
# ============================================================================

#' Crear seccion hero de la landing page
#' @return HTML de la seccion hero
hero_section <- function() {
  tags$div(
    class = "hero-section",
    role = "banner",

    tags$div(
      class = "hero-content",

      # Thesis
      tags$h1(
        class = "hero-thesis",
        "Tu pensión es tuya. Conocerla te da poder."
      ),

      # Subtitle
      tags$p(
        class = "hero-subtitle",
        "Millones de trabajadores mexicanos no conocen su pensión real.",
        "Esta herramienta cambia eso en 5 minutos."
      ),

      # Value Propositions
      tags$div(
        class = "hero-value-props",
        value_prop_item("bi-clock", "Calcula en 5 minutos"),
        value_prop_item("bi-book", "Entiende Ley 73, 97 y Bienestar"),
        value_prop_item("bi-lightning-charge", "Descubre qué hacer HOY"),
        value_prop_item("bi-shield-lock", "Sin registro, 100% privado")
      ),

      # CTAs
      tags$div(
        class = "hero-ctas",
        tags$button(
          id = "start_wizard",
          class = "hero-cta-primary",
          tags$i(class = "bi bi-calculator me-2"),
          "Calcular mi pensión"
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
      tags$span(class = "trust-number", format(Sys.Date(), "%Y")),
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
    tags$h5(class = "mb-3", tags$i(class = "bi bi-bullseye me-2 text-primary"), "¿Qué puedes controlar?"),
    control_framework(),

    tags$hr(class = "my-4"),

    # Key Message
    key_message(
      "El Fondo Bienestar puede ser excelente, pero ",
      tags$strong("tus aportaciones voluntarias son la parte MÁS SEGURA"),
      " de tu pensión. Enfoca tu energía en lo que controlas."
    ),

    # CTA to start
    tags$div(
      class = "text-center mt-4",
      tags$button(
        id = "start_wizard_from_context",
        class = "btn btn-primary btn-lg",
        tags$i(class = "bi bi-arrow-right me-2"),
        "Ahora sí, calcular mi pensión"
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
      description = "Pensión definida basada en semanas y salario. Si empezaste antes de julio 1997, estás aquí."
    ),

    timeline_item(
      year = "1997",
      title = "Sistema AFOREs",
      description = "Cuentas individuales. Tu pensión depende de lo que ahorres. La mayoría de trabajadores actuales."
    ),

    timeline_item(
      year = "2020",
      title = "Reforma de Pensiones",
      description = "Reduce requisito a 1,000 semanas. Aumenta aportaciones patronales gradualmente hasta 2030."
    ),

    timeline_item(
      year = "2024",
      title = "Fondo de Pensiones para el Bienestar",
      description = "Complementa pensiones hasta el 100% del último salario. Programa nuevo, sostenibilidad por confirmar."
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
