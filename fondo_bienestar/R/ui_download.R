# R/ui_download.R - Download/document section
# Simulador de Pension IMSS + Fondo Bienestar

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
            "Documento Técnico",
            tags$br(),
            tags$small(class = "text-muted", "Metodología y fórmulas")
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
            "Reporte Básico",
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
            "Metodología",
            tags$br(),
            tags$small(class = "text-muted", "Como calculamos")
          ),
          class = "btn btn-outline-dark w-100 py-3"
        )
      )
    )
  )
}
