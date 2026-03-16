# R/document_generators.R - Funciones para generar documentos PDF/HTML
# Simulador de Pension IMSS + Fondo Bienestar - Version 1.0

# ============================================================================
# SHARED HELPERS FOR DOCUMENT GENERATORS
# ============================================================================

#' Format rendimiento label from escenario name
#' @param escenario Scenario name string
#' @return Formatted percentage string
format_rendimiento_escenario <- function(escenario) {
  esc <- escenario %||% ESCENARIO_BASE
  r <- RENDIMIENTO_POR_ESCENARIO[esc]
  if (is.na(r)) r <- RENDIMIENTO_BASE
  paste0(round(r * 100), "%")
}

# ============================================================================
# SHARED CSS STYLES FOR PROFESSIONAL HTML REPORTS
# ============================================================================

#' Get professional CSS styles for HTML documents
#' @return String with CSS styles
get_document_css <- function() {
  "
    /* Base styles */
    * { box-sizing: border-box; }

    body {
      font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
      line-height: 1.7;
      color: #334155;
      background: #ffffff;
      margin: 0;
      padding: 0;
    }

    /* Document container */
    .document-container {
      max-width: 850px;
      margin: 0 auto;
      padding: 50px 40px;
      background: white;
    }

    /* Fancy title with gradient underline */
    .doc-title {
      font-size: 32px;
      font-weight: 700;
      color: #0f766e;
      text-align: center;
      margin-bottom: 8px;
      letter-spacing: -0.5px;
    }
    .doc-title::after {
      content: '';
      display: block;
      width: 100px;
      height: 4px;
      background: linear-gradient(90deg, #db2777, #0f766e);
      margin: 15px auto 0;
      border-radius: 2px;
    }

    .doc-subtitle {
      text-align: center;
      color: #64748b;
      font-size: 16px;
      margin-bottom: 40px;
    }

    .doc-date {
      text-align: center;
      color: #c4a67a;
      font-size: 14px;
      margin-bottom: 30px;
    }

    /* Section headers with icon placeholder */
    .section-header {
      display: flex;
      align-items: center;
      gap: 12px;
      color: #0f766e;
      font-size: 20px;
      font-weight: 600;
      margin: 35px 0 15px;
      padding-bottom: 10px;
      border-bottom: 2px solid #e2e8f0;
    }

    .section-icon {
      width: 28px;
      height: 28px;
      background: linear-gradient(135deg, #db2777, #0f766e);
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-size: 14px;
    }

    h3 {
      color: #115e59;
      font-size: 17px;
      margin: 25px 0 12px;
      font-weight: 600;
    }

    /* Card-style data boxes */
    .data-card {
      background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
      border-radius: 12px;
      padding: 25px;
      margin: 20px 0;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);
    }

    /* Highlight box for key numbers */
    .highlight-box {
      background: linear-gradient(135deg, #f0fdfa 0%, #ccfbf1 100%);
      border-left: 4px solid #0d9488;
      border-radius: 0 12px 12px 0;
      padding: 30px;
      margin: 25px 0;
      text-align: center;
    }

    /* Big pension number */
    .pension-amount {
      font-size: 48px;
      font-weight: 700;
      color: #0f766e;
      text-align: center;
      line-height: 1.2;
    }
    .pension-period {
      font-size: 20px;
      color: #64748b;
      font-weight: 400;
    }

    .pension-label {
      font-size: 14px;
      color: #64748b;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 10px;
    }

    /* Styled tables */
    .styled-table {
      width: 100%;
      border-collapse: separate;
      border-spacing: 0;
      border-radius: 10px;
      overflow: hidden;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      margin: 20px 0;
    }
    .styled-table th {
      background: linear-gradient(135deg, #0f766e 0%, #115e59 100%);
      color: white;
      padding: 14px 18px;
      text-align: left;
      font-weight: 600;
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .styled-table td {
      padding: 14px 18px;
      border-bottom: 1px solid #e2e8f0;
      font-size: 15px;
    }
    .styled-table tr:nth-child(even) {
      background: #f8fafc;
    }
    .styled-table tr:last-child td {
      border-bottom: none;
    }
    .styled-table tr:hover {
      background: #f1f5f9;
    }

    /* Warning box */
    .warning-box {
      background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
      border-left: 4px solid #d97706;
      border-radius: 0 12px 12px 0;
      padding: 20px 25px;
      margin: 25px 0;
    }
    .warning-box strong {
      color: #92400e;
    }

    /* Info box */
    .info-box {
      background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
      border-left: 4px solid #3b82f6;
      border-radius: 0 12px 12px 0;
      padding: 20px 25px;
      margin: 25px 0;
    }

    /* Action box */
    .action-box {
      background: linear-gradient(135deg, #f0fdfa 0%, #ccfbf1 100%);
      border-left: 4px solid #0d9488;
      border-radius: 0 12px 12px 0;
      padding: 20px 25px;
      margin: 25px 0;
    }
    .action-title {
      font-weight: 700;
      color: #0d9488;
      margin-bottom: 12px;
      font-size: 16px;
    }

    /* Three column cards */
    .three-cards {
      display: flex;
      gap: 20px;
      margin: 25px 0;
      flex-wrap: wrap;
    }
    .three-cards .card {
      flex: 1;
      min-width: 200px;
      background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
      border-radius: 12px;
      padding: 25px 20px;
      text-align: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);
    }
    .three-cards .card.highlight {
      background: linear-gradient(135deg, #0f766e 0%, #115e59 100%);
      color: white;
    }
    .three-cards .card.highlight .card-label {
      color: rgba(255,255,255,0.8);
    }
    .three-cards .card.highlight .card-value {
      color: white;
    }
    .card-label {
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #64748b;
      margin-bottom: 8px;
    }
    .card-value {
      font-size: 24px;
      font-weight: 700;
      color: #0f766e;
    }
    .card-subtitle {
      font-size: 13px;
      color: #64748b;
      margin-top: 8px;
    }

    /* Formula box */
    .formula-box {
      background: #f1f5f9;
      border-radius: 8px;
      padding: 15px 20px;
      font-family: 'SF Mono', 'Consolas', monospace;
      font-size: 14px;
      color: #1e293b;
      margin: 15px 0;
      overflow-x: auto;
    }

    /* Lists */
    ul, ol {
      padding-left: 25px;
      margin: 15px 0;
    }
    li {
      margin: 10px 0;
      line-height: 1.6;
    }

    /* Links section */
    .links-section {
      background: #f8fafc;
      border-radius: 12px;
      padding: 25px;
      margin-top: 35px;
    }
    .links-section a {
      color: #0d9488;
      text-decoration: none;
      margin-right: 25px;
      font-weight: 500;
    }
    .links-section a:hover {
      text-decoration: underline;
    }

    /* Footer */
    .doc-footer {
      margin-top: 50px;
      padding-top: 25px;
      border-top: 2px solid #e2e8f0;
      text-align: center;
      font-size: 13px;
      color: #c4a67a;
    }

    /* Comparison arrows */
    .comparison-row {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 25px;
      margin: 25px 0;
      flex-wrap: wrap;
    }
    .comparison-item {
      text-align: center;
    }
    .comparison-arrow {
      font-size: 28px;
      color: #0d9488;
    }

    /* Print styles */
    @media print {
      body { padding: 0; }
      .document-container { padding: 20px; max-width: 100%; }
      .no-print { display: none !important; }
      .styled-table { box-shadow: none; }
      .data-card, .highlight-box, .warning-box, .info-box, .action-box {
        box-shadow: none;
        border: 1px solid #e2e8f0;
      }
    }
  "
}

# ============================================================================
# HTML REPORT SKELETON
# ============================================================================

#' Wrap report body content in a complete HTML document
#' @param title Document title (for <title> and heading)
#' @param subtitle Document subtitle
#' @param body_content HTML string with the report body
#' @param footer_lines Character vector of footer paragraphs
#' @param extra_css Additional CSS string (optional)
#' @return Complete HTML document string
html_report_skeleton <- function(title, body_content, extra_css = "") {
  css <- get_document_css()
  paste0(
    "<!DOCTYPE html>",
    "<html lang='es'>",
    "<head>",
    "<meta charset='UTF-8'>",
    "<meta name='viewport' content='width=device-width, initial-scale=1.0'>",
    "<title>", title, "</title>",
    "<style>", css, extra_css, "</style>",
    "</head>",
    "<body>",
    "<div class='document-container'>",
    body_content,
    "</div>",
    "</body>",
    "</html>"
  )
}

# ============================================================================
# SHARED CONTENT BLOCKS
# ============================================================================

#' Generate supuestos HTML list items for reports
#' @param entrada Input list from resultado$entrada
#' @return HTML string with <li> elements
generate_supuestos_html <- function(entrada) {
  paste0(
    "<li>Rendimiento real anual: ", format_rendimiento_escenario(entrada$escenario), "</li>",
    "<li>UMA ", ANIO_ACTUAL, ": $", UMA_DIARIA_2025, "/dia</li>",
    "<li>Salario m&iacute;nimo ", ANIO_ACTUAL, ": $", SM_DIARIO_2025, "/d&iacute;a</li>",
    "<li>Umbral Fondo Bienestar: $", format(UMBRAL_FONDO_BIENESTAR_2025, big.mark = ","), "/mes</li>",
    "<li>Esperanza de vida: Tablas CONAPO simplificadas</li>",
    "<li>Densidad de cotizaci&oacute;n futura: 100% (asume empleo continuo)</li>"
  )
}

#' Generate data sources HTML table rows for reports
#' @return HTML string with table rows
generate_fuentes_html <- function() {
  paste0(
    "<tr><td>Art. 167 LSS</td><td>Tabla de cuant&iacute;as b&aacute;sicas e incrementos</td></tr>",
    "<tr><td>INEGI/DOF</td><td>UMA ", ANIO_ACTUAL, ": $", UMA_DIARIA_2025, "/d&iacute;a</td></tr>",
    "<tr><td>CONASAMI</td><td>Salario M&iacute;nimo ", ANIO_ACTUAL, ": $", SM_DIARIO_2025, "/d&iacute;a</td></tr>",
    "<tr><td>CONSAR</td><td>Comisiones y rendimientos por AFORE</td></tr>",
    "<tr><td>CONAPO</td><td>Tablas de mortalidad simplificadas</td></tr>",
    "<tr><td>DOF/IMSS</td><td>Umbral Fondo Bienestar: $", format(UMBRAL_FONDO_BIENESTAR_2025, big.mark = ","), "/mes</td></tr>"
  )
}

#' Generate warning box HTML for reports
#' @return HTML string with disclaimer
generate_aviso_html <- function() {
  paste0(
    "<div class='warning-box'>",
    "<strong>&#9888; AVISO IMPORTANTE</strong><br>",
    "Este documento es una <strong>estimaci&oacute;n educativa</strong>, ",
    "NO una garant&iacute;a de pensi&oacute;n. Los resultados reales pueden variar. ",
    "Consulta a un profesional financiero antes de tomar decisiones.",
    "</div>"
  )
}

# ============================================================================
# METODOLOGIA PDF
# ============================================================================

#' Generar PDF de metodologia desde archivo markdown
#' @param md_file Path al archivo .md de metodologia
#' @param output_file Path al archivo PDF de salida
#' @return Path al archivo PDF generado, o NULL si falla
generate_methodology_pdf <- function(md_file, output_file) {
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    return(NULL)
  }

  tryCatch({
    # Create a temp Rmd with YAML header
    temp_rmd <- tempfile(fileext = ".Rmd")
    on.exit(unlink(temp_rmd), add = TRUE)

    # Read markdown content
    md_content <- readLines(md_file, warn = FALSE)

    # Add YAML header for PDF
    yaml_header <- c(
      "---",
      "title: 'Metodología del Simulador de Pensión IMSS'",
      "subtitle: 'Documentacion Tecnica'",
      paste0("date: '", format(Sys.Date(), "%d de %B de %Y"), "'"),
      "output:",
      "  pdf_document:",
      "    latex_engine: xelatex",
      "    toc: true",
      "    toc_depth: 3",
      "    number_sections: true",
      "header-includes:",
      "  - \\usepackage{booktabs}",
      "  - \\usepackage{longtable}",
      "---",
      ""
    )

    # Skip first line if it's a markdown title (# Metodologia...)
    if (length(md_content) > 0 && grepl("^#\\s", md_content[1])) {
      md_content <- md_content[-1]
    }

    # Combine
    full_content <- c(yaml_header, md_content)
    writeLines(full_content, temp_rmd)

    # Render to PDF
    output_pdf <- rmarkdown::render(
      input = temp_rmd,
      output_format = rmarkdown::pdf_document(
        latex_engine = "xelatex",
        toc = TRUE,
        toc_depth = 3,
        number_sections = TRUE
      ),
      output_dir = tempdir(),
      quiet = TRUE
    )

    file.copy(output_pdf, output_file, overwrite = TRUE)
    return(output_file)
  }, error = function(e) {
    message("Error generating methodology PDF: ", e$message)
    return(NULL)
  })
}

# ============================================================================
# DOCUMENTO BASICO PDF (R Markdown)
# ============================================================================

#' Generar documento basico en formato R Markdown (para PDF)
#' @param resultado Resultado del calculo de pension
#' @return String con contenido Rmd
generate_basic_rmd <- function(resultado) {
  es_ley73 <- resultado$regimen == REGIMEN_LEY73
  entrada <- resultado$entrada

  # YAML header
  yaml_header <- paste0(
    "---\n",
    "title: 'Tu Pensión Estimada'\n",
    "subtitle: 'Simulador IMSS + Fondo Bienestar'\n",
    "date: '", format(Sys.Date(), "%d de %B de %Y"), "'\n",
    "output:\n",
    "  pdf_document:\n",
    "    latex_engine: xelatex\n",
    "header-includes:\n",
    "  - \\usepackage{xcolor}\n",
    "  - \\definecolor{primary}{RGB}{15,118,110}\n",
    "  - \\definecolor{accent}{RGB}{219,39,119}\n",
    "---\n\n"
  )

  # Aviso importante
  aviso <- paste0(
    "**IMPORTANTE:** Esta es una estimación educativa, NO una garantía. ",
    "Las leyes y políticas pueden cambiar.\n\n"
  )

  # Datos ingresados
  datos <- paste0(
    "# Datos Ingresados\n\n",
    "| Variable | Valor |\n",
    "|----------|-------|\n",
    "| Salario mensual | ", format_currency_latex(entrada$salario_mensual), " |\n",
    "| Edad actual | ", entrada$edad_actual, " años |\n",
    "| Edad de retiro | ", entrada$edad_retiro, " años |\n"
  )

  if (!es_ley73) {
    datos <- paste0(datos,
      "| Saldo AFORE actual | ", format_currency_latex(entrada$saldo_actual), " |\n",
      "| AFORE | ", entrada$afore, " |\n",
      "| Aportación voluntaria | ", format_currency_latex(entrada$aportacion_voluntaria), "/mes |\n"
    )
  }
  datos <- paste0(datos, "\n\n")

  # Pension estimada
  if (es_ley73) {
    pension <- paste0(
      "# Tu Pensión Estimada\n\n",
      "## Ley 73 - Pensión Definida\n\n",
      "**Pensión mensual:** ", format_currency_latex(resultado$pension_base$pension_mensual), "\n\n",
      "**Tasa de reemplazo:** ", round(resultado$pension_base$tasa_reemplazo * 100, 1), "% de tu salario\n\n"
    )
  } else {
    pension <- paste0(
      "# Tu Pensión Estimada\n\n",
      "## Solo AFORE\n\n",
      "**Pensión mensual:** ", format_currency_latex(resultado$solo_sistema$pension_mensual), "\n\n",
      "**Tasa de reemplazo:** ", round(resultado$solo_sistema$tasa_reemplazo * 100, 1), "% de tu salario\n\n"
    )

    if (resultado$con_fondo$elegible) {
      pension <- paste0(pension,
        "## Con Fondo Bienestar\n\n",
        "Eres elegible para el Fondo de Pensiones para el Bienestar.\n\n",
        "**Pensión total:** ", format_currency_latex(resultado$con_fondo$pension_total), "/mes\n\n"
      )
    }

    pension <- paste0(pension,
      "## Con Tus Aportaciones Voluntarias\n\n",
      "**Pensión AFORE proyectada:** ", format_currency_latex(resultado$con_acciones$pension_afore), "/mes\n\n"
    )
  }

  # Recomendacion
  recomendacion <- paste0(
    "# Recomendacion\n\n",
    "Tus aportaciones voluntarias son la parte **MAS SEGURA** de tu pensión.",
    "Enfoca tu energia en lo que controlas.\n\n",
    "El Fondo Bienestar puede ayudar, pero es un programa nuevo (2024) y su futuro es incierto.\n\n"
  )

  # Links
  links <- paste0(
    "# Para Más Información\n\n",
    "- IMSS: https://www.imss.gob.mx/\n",
    "- CONSAR: https://www.consar.gob.mx/\n",
    "- e-SAR: https://www.e-sar.com.mx/\n\n",
    "---\n\n",
    "*Este documento es para uso personal e informativo.*\n"
  )

  # Combinar
  rmd_content <- paste0(
    yaml_header,
    aviso,
    datos,
    pension,
    recomendacion,
    links
  )

  return(rmd_content)
}

# ============================================================================
# DOCUMENTO TECNICO PDF (R Markdown)
# ============================================================================

#' Generar documento tecnico en formato R Markdown (para PDF)
#' @param resultado Resultado del calculo de pension
#' @return String con contenido Rmd
generate_technical_rmd <- function(resultado) {
  es_ley73 <- resultado$regimen == REGIMEN_LEY73
  entrada <- resultado$entrada

  # YAML header
  yaml_header <- paste0(
    "---\n",
    "title: 'Documento Técnico - Estimación de Pensión'\n",
    "subtitle: 'Simulador IMSS + Fondo Bienestar'\n",
    "date: '", format(Sys.Date(), "%d de %B de %Y"), "'\n",
    "output:\n",
    "  pdf_document:\n",
    "    latex_engine: xelatex\n",
    "    toc: true\n",
    "    toc_depth: 2\n",
    "    number_sections: true\n",
    "header-includes:\n",
    "  - \\usepackage{amsmath}\n",
    "  - \\usepackage{booktabs}\n",
    "  - \\usepackage{longtable}\n",
    "  - \\usepackage{xcolor}\n",
    "  - \\definecolor{primary}{RGB}{15,118,110}\n",
    "  - \\definecolor{accent}{RGB}{219,39,119}\n",
    "---\n\n"
  )

  # Resumen ejecutivo
  resumen <- paste0(
    "# Resumen Ejecutivo\n\n",
    "**Régimen:** ", if(es_ley73) "Ley 73 (1973)" else "Ley 97 (AFORE)", "\n\n"
  )

  if (es_ley73) {
    resumen <- paste0(resumen,
      "**Pensión mensual estimada:** ", format_currency_latex(resultado$pension_base$pension_mensual), "\n\n",
      "**Tasa de reemplazo:** ", round(resultado$pension_base$tasa_reemplazo * 100, 1), "% del salario\n\n",
      "**Elegibilidad:** ", if(resultado$pension_base$elegible) "Cumple requisitos" else "No cumple requisitos", "\n\n"
    )
  } else {
    resumen <- paste0(resumen,
      "**Pensión mensual estimada (solo AFORE):** ", format_currency_latex(resultado$solo_sistema$pension_mensual), "\n\n",
      "**Tasa de reemplazo:** ", round(resultado$solo_sistema$tasa_reemplazo * 100, 1), "% del salario\n\n",
      "**Elegibilidad Fondo Bienestar:** ", if(resultado$con_fondo$elegible) "Si" else "No", "\n\n"
    )
    if (resultado$con_fondo$elegible) {
      resumen <- paste0(resumen,
        "**Pensión con Fondo Bienestar:** ", format_currency_latex(resultado$con_fondo$pension_total), "\n\n"
      )
    }
  }

  # Datos de entrada
  datos_entrada <- paste0(
    "# Datos de Entrada\n\n",
    "| Variable | Valor |\n",
    "|----------|-------|\n",
    "| Salario mensual | ", format_currency_latex(entrada$salario_mensual), " |\n",
    "| Edad actual | ", entrada$edad_actual, " años |\n",
    "| Edad de retiro | ", entrada$edad_retiro, " años |\n",
    "| Semanas cotizadas | ", format(entrada$semanas_actuales, big.mark = ","), " |\n",
    "| Genero | ", if(entrada$genero == "M") "Masculino" else "Femenino", " |\n"
  )

  if (!es_ley73) {
    datos_entrada <- paste0(datos_entrada,
      "| Saldo actual AFORE | ", format_currency_latex(entrada$saldo_actual), " |\n",
      "| AFORE | ", entrada$afore, " |\n",
      "| Aportación voluntaria | ", format_currency_latex(entrada$aportacion_voluntaria), "/mes |\n",
      "| Escenario | ", entrada$escenario %||% "base", " |\n"
    )
  }

  datos_entrada <- paste0(datos_entrada, "\n\n")

  # Metodologia
  if (es_ley73) {
    metodologia <- paste0(
      "# Metodología\n\n",
      "## Cálculo Ley 73\n\n",
      "La pensión Ley 73 se calcula como una pensión definida basada en:\n\n",
      "- Salario promedio de las últimas 250 semanas cotizadas\n",
      "- Porcentaje según tabla del Artículo 167 de la LSS 1973\n",
      "- Factor de cesantía (si se jubila antes de los 65 años)\n\n",
      "**Fórmula:**\n\n",
      "$$Pensión = SBC_{promedio} \\times Factor_{Art.167} \\times Factor_{Cesantía}$$\n\n",
      "### Factor de Cesantía por Edad\n\n",
      "| Edad | Factor |\n",
      "|------|--------|\n",
      "| 60 | 75% |\n",
      "| 61 | 80% |\n",
      "| 62 | 85% |\n",
      "| 63 | 90% |\n",
      "| 64 | 95% |\n",
      "| 65+ | 100% |\n\n"
    )
  } else {
    metodologia <- paste0(
      "# Metodología\n\n",
      "## Cálculo Ley 97 (AFORE)\n\n",
      "La pensión Ley 97 se basa en el saldo acumulado en la cuenta individual:\n\n",
      "$$Saldo_{Final} = Saldo_{Actual} \\times (1 + r)^n + Aportaciones_{Futuras}$$\n\n",
      "Donde:\n\n",
      "- **r** = Rendimiento real anual (3-5% segun escenario)\n",
      "- **n** = Anos hasta el retiro\n\n",
      "## Pensión Mensual (Retiro Programado)\n\n",
      "$$Pensión_{Mensual} = \\frac{Saldo_{Final}}{Esperanza_{Vida} \\times 12}$$\n\n",
      "## Fondo de Pensiones para el Bienestar\n\n",
      "El Fondo complementa la pensión hasta el 100% del último salario si:\n\n",
      "- El trabajador tiene 65 años o más\n",
      "- El salario promedio es menor o igual al umbral ($17,364/mes en 2025)\n",
      "- La pensión AFORE es menor al 100% del salario\n\n",
      "$$Complemento = min(Salario - Pensión_{AFORE}, Pensión_{Garantizada})$$\n\n"
    )
  }

  # Resultados detallados
  if (es_ley73) {
    resultados_det <- paste0(
      "# Resultados Detallados\n\n",
      "| Concepto | Valor |\n",
      "|----------|-------|\n",
      "| Semanas cotizadas | ", format(resultado$entrada$semanas_actuales %||% 0, big.mark = ","), " |\n",
      "| Porcentaje Artículo 167 | ", round((resultado$pension_base$porcentaje_total %||% 0) * 100, 2), "% |\n",
      "| Factor de cesantía | ", round((resultado$pension_base$factor_edad %||% 1) * 100, 1), "% |\n",
      "| Pensión mensual | ", format_currency_latex(resultado$pension_base$pension_mensual), " |\n",
      "| Tasa de reemplazo | ", round(resultado$pension_base$tasa_reemplazo * 100, 1), "% |\n\n"
    )
  } else {
    resultados_det <- paste0(
      "# Resultados Detallados\n\n",
      "## Solo Sistema (AFORE)\n\n",
      "| Concepto | Valor |\n",
      "|----------|-------|\n",
      "| Saldo actual | ", format_currency_latex(entrada$saldo_actual), " |\n",
      "| Saldo proyectado al retiro | ", format_currency_latex(resultado$solo_sistema$saldo_proyectado %||% 0), " |\n",
      "| Pensión mensual | ", format_currency_latex(resultado$solo_sistema$pension_mensual), " |\n",
      "| Tasa de reemplazo | ", round(resultado$solo_sistema$tasa_reemplazo * 100, 1), "% |\n\n",
      "## Con Fondo Bienestar\n\n",
      "| Concepto | Valor |\n",
      "|----------|-------|\n",
      "| Elegible | ", if(resultado$con_fondo$elegible) "Si" else "No", " |\n"
    )
    if (resultado$con_fondo$elegible) {
      resultados_det <- paste0(resultados_det,
        "| Complemento mensual | ", format_currency_latex(resultado$con_fondo$complemento), " |\n",
        "| Pensión total | ", format_currency_latex(resultado$con_fondo$pension_total), " |\n\n"
      )
    } else {
      resultados_det <- paste0(resultados_det,
        "| Razon | ", resultado$fondo_bienestar$razon_no_elegible %||% "No cumple requisitos", " |\n\n"
      )
    }
    resultados_det <- paste0(resultados_det,
      "## Con Acciones Propias\n\n",
      "| Concepto | Valor |\n",
      "|----------|-------|\n",
      "| Aportación voluntaria mensual | ", format_currency_latex(entrada$aportacion_voluntaria), " |\n",
      "| Saldo proyectado | ", format_currency_latex(resultado$con_acciones$saldo_proyectado %||% 0), " |\n",
      "| Pensión AFORE | ", format_currency_latex(resultado$con_acciones$pension_afore), " |\n",
      "| Pensión total | ", format_currency_latex(resultado$con_acciones$pension_total), " |\n\n"
    )
  }

  # Supuestos y limitaciones
  supuestos <- paste0(
    "# Supuestos y Limitaciones\n\n",
    "**IMPORTANTE:** Esta es una estimación educativa, NO una garantía. Los resultados reales pueden variar significativamente.\n\n",
    "## Supuestos del Modelo\n\n",
    "- Rendimiento real anual: ", format_rendimiento_escenario(entrada$escenario), "\n",
    "- UMA 2025: $", UMA_DIARIA_2025, "/dia\n",
    "- Salario mínimo 2025: $278.80/día\n",
    "- Umbral Fondo Bienestar: $17,364/mes\n",
    "- Esperanza de vida: Tablas CONAPO simplificadas\n",
    "- Densidad de cotización futura: 100% (asume empleo continuo)\n\n",
    "## Limitaciones\n\n",
    "- No considera inflacion futura variable\n",
    "- No incluye beneficios adicionales (matrimonio, hijos, etc.)\n",
    "- El Fondo Bienestar es un programa nuevo (2024) con sostenibilidad incierta\n",
    "- Los rendimientos pasados no garantizan rendimientos futuros\n",
    "- Las leyes y políticas pueden cambiar\n\n"
  )

  # Fuentes de datos
  fuentes <- paste0(
    "# Fuentes de Datos\n\n",
    "| Dato | Fuente | Fecha |\n",
    "|------|--------|-------|\n",
    "| Tabla Artículo 167 | Ley del Seguro Social 1973 | Vigente |\n",
    "| UMA | INEGI / DOF | Enero 2025 |\n",
    "| Salario Mínimo | CONASAMI | Enero 2025 |\n",
    "| Comisiones AFORE | CONSAR | 2024-2025 |\n",
    "| Mortalidad | CONAPO / CNSF | Simplificada |\n",
    "| Umbral Fondo Bienestar | DOF / IMSS | 2025 |\n\n"
  )

  # Glosario
  glosario <- paste0(
    "# Glosario\n\n",
    "| Termino | Definicion |\n",
    "|---------|------------|\n",
    "| UMA | Unidad de Medida y Actualizacion |\n",
    "| SBC | Salario Base de Cotización |\n",
    "| Tasa de reemplazo | Porcentaje del último salario que representa la pensión |\n",
    "| Cesantía | Pensión anticipada entre los 60 y 64 años |\n",
    "| IRN | Indicador de Rendimiento Neto |\n\n"
  )

  # Combinar todo
  rmd_content <- paste0(
    yaml_header,
    resumen,
    datos_entrada,
    metodologia,
    resultados_det,
    supuestos,
    fuentes,
    glosario
  )

  return(rmd_content)
}

# ============================================================================
# DOCUMENTO TECNICO HTML
# ============================================================================

#' Generar documento tecnico HTML
#' @param resultado Resultado del calculo de pension
#' @return String HTML del documento
generate_technical_report <- function(resultado) {

  # Determinar tipo de regimen
  es_ley73 <- resultado$regimen == REGIMEN_LEY73

  # Datos de entrada
  entrada <- resultado$entrada

  # Construir body content
  body <- paste0(
    "<h1 class='doc-title'>Documento T&eacute;cnico</h1>",
    "<p class='doc-subtitle'>Estimaci&oacute;n de Pensi&oacute;n - Simulador IMSS + Fondo Bienestar</p>",

    "<div class='data-card' style='text-align: center;'>",
    "<strong>Fecha de generacion:</strong> ", format(Sys.Date(), "%d de %B de %Y"), "<br>",
    "<strong>Régimen:</strong> ", if(es_ley73) "Ley 73 (1973)" else "Ley 97 (AFORE)", "<br>",
    "<strong>Version del modelo:</strong> 1.0",
    "</div>",

    # Seccion 1: Resumen Ejecutivo
    "<div class='section-header'>",
    "<div class='section-icon'>1</div>",
    "<span>Resumen Ejecutivo</span>",
    "</div>",

    if (es_ley73) {
      paste0(
        "<div class='highlight-box'>",
        "<div class='pension-label'>Pensión mensual estimada</div>",
        "<div class='pension-amount'>", format_currency(resultado$pension_base$pension_mensual), "<span class='pension-period'>/mes</span></div>",
        "<div style='margin-top: 15px; color: #64748b;'>",
        round(resultado$pension_base$tasa_reemplazo * 100, 1), "% del salario | ",
        if(resultado$pension_base$elegible) "Cumple requisitos" else "No cumple requisitos",
        "</div>",
        "</div>"
      )
    } else {
      paste0(
        "<div class='highlight-box'>",
        "<div class='pension-label'>Pensión mensual estimada (solo AFORE)</div>",
        "<div class='pension-amount'>", format_currency(resultado$solo_sistema$pension_mensual), "<span class='pension-period'>/mes</span></div>",
        "<div style='margin-top: 15px; color: #64748b;'>",
        round(resultado$solo_sistema$tasa_reemplazo * 100, 1), "% del salario | ",
        "Fondo Bienestar: ", if(resultado$con_fondo$elegible) "Elegible" else "No elegible",
        "</div>",
        "</div>",
        if (resultado$con_fondo$elegible) {
          paste0("<p style='text-align: center;'><strong>Con Fondo Bienestar:</strong> ", format_currency(resultado$con_fondo$pension_total), "/mes</p>")
        } else ""
      )
    },

    # Seccion 2: Datos de Entrada
    "<div class='section-header'>",
    "<div class='section-icon'>2</div>",
    "<span>Datos de Entrada</span>",
    "</div>",

    "<table class='styled-table'>",
    "<tr><th>Variable</th><th>Valor</th></tr>",
    "<tr><td>Salario mensual</td><td><strong>", format_currency(entrada$salario_mensual), "</strong></td></tr>",
    "<tr><td>Edad actual</td><td>", entrada$edad_actual, " años</td></tr>",
    "<tr><td>Edad de retiro</td><td>", entrada$edad_retiro, " años</td></tr>",
    "<tr><td>Semanas cotizadas</td><td>", format(entrada$semanas_actuales, big.mark = ","), "</td></tr>",
    "<tr><td>Genero</td><td>", if(entrada$genero == "M") "Masculino" else "Femenino", "</td></tr>",

    if (!es_ley73) {
      paste0(
        "<tr><td>Saldo actual AFORE</td><td>", format_currency(entrada$saldo_actual), "</td></tr>",
        "<tr><td>AFORE</td><td>", entrada$afore, "</td></tr>",
        "<tr><td>Aportación voluntaria</td><td>", format_currency(entrada$aportacion_voluntaria), "/mes</td></tr>",
        "<tr><td>Escenario</td><td>", entrada$escenario, "</td></tr>"
      )
    } else "",

    "</table>",

    # Seccion 3: Metodologia
    "<div class='section-header'>",
    "<div class='section-icon'>3</div>",
    "<span>Metodología</span>",
    "</div>",

    if (es_ley73) {
      paste0(
        "<h3>3.1 Cálculo Ley 73</h3>",
        "<p>La pensión Ley 73 se calcula como una pensión definida basada en:</p>",
        "<ul>",
        "<li>Salario promedio de las ultimas 250 semanas cotizadas</li>",
        "<li>Porcentaje según tabla del Artículo 167 de la LSS 1973</li>",
        "<li>Factor de cesantía (si se jubila antes de los 65 años)</li>",
        "</ul>",
        "<div class='formula-box'>",
        "Pensión = SBC_promedio x Factor_Artículo_167 x Factor_Cesantía",
        "</div>",
        "<h3>Factor de Cesantía por Edad:</h3>",
        "<table class='styled-table' style='max-width: 300px;'>",
        "<tr><th>Edad</th><th>Factor</th></tr>",
        "<tr><td>60</td><td>75%</td></tr>",
        "<tr><td>61</td><td>80%</td></tr>",
        "<tr><td>62</td><td>85%</td></tr>",
        "<tr><td>63</td><td>90%</td></tr>",
        "<tr><td>64</td><td>95%</td></tr>",
        "<tr><td>65+</td><td>100%</td></tr>",
        "</table>"
      )
    } else {
      paste0(
        "<h3>3.1 Cálculo Ley 97 (AFORE)</h3>",
        "<p>La pensión Ley 97 se basa en el saldo acumulado en la cuenta individual:</p>",
        "<div class='formula-box'>",
        "Saldo_Final = Saldo_Actual x (1 + r)^n + Aportaciones_Futuras",
        "</div>",
        "<p>Donde:</p>",
        "<ul>",
        "<li><strong>r</strong> = Rendimiento real anual (3-5% segun escenario)</li>",
        "<li><strong>n</strong> = Anos hasta el retiro</li>",
        "</ul>",
        "<h3>3.2 Pensión Mensual (Retiro Programado)</h3>",
        "<div class='formula-box'>",
        "Pension_Mensual = Saldo_Final / (Esperanza_Vida_Meses)",
        "</div>",
        "<h3>3.3 Fondo de Pensiones para el Bienestar</h3>",
        "<p>El Fondo complementa la pensión hasta el 100% del último salario si:</p>",
        "<ul>",
        "<li>El trabajador tiene 65 años o más</li>",
        "<li>El salario promedio es menor o igual al umbral ($17,364/mes en 2025)</li>",
        "<li>La pensión AFORE es menor al 100% del salario</li>",
        "</ul>",
        "<div class='formula-box'>",
        "Complemento = min(Salario - Pension_AFORE, Pension_Garantizada)",
        "</div>"
      )
    },

    # Seccion 4: Resultados Detallados
    "<div class='section-header'>",
    "<div class='section-icon'>4</div>",
    "<span>Resultados Detallados</span>",
    "</div>",

    if (es_ley73) {
      paste0(
        "<table class='styled-table'>",
        "<tr><th>Concepto</th><th>Valor</th></tr>",
        "<tr><td>Semanas cotizadas</td><td>", format(resultado$entrada$semanas_actuales %||% 0, big.mark = ","), "</td></tr>",
        "<tr><td>Porcentaje Artículo 167</td><td>", round((resultado$pension_base$porcentaje_total %||% 0) * 100, 2), "%</td></tr>",
        "<tr><td>Factor de cesantía</td><td>", round((resultado$pension_base$factor_edad %||% 1) * 100, 1), "%</td></tr>",
        "<tr><td>Pensión mensual</td><td><strong>", format_currency(resultado$pension_base$pension_mensual), "</strong></td></tr>",
        "<tr><td>Tasa de reemplazo</td><td>", round(resultado$pension_base$tasa_reemplazo * 100, 1), "%</td></tr>",
        "</table>"
      )
    } else {
      paste0(
        "<h3>4.1 Solo Sistema (AFORE)</h3>",
        "<table class='styled-table'>",
        "<tr><th>Concepto</th><th>Valor</th></tr>",
        "<tr><td>Saldo actual</td><td>", format_currency(entrada$saldo_actual), "</td></tr>",
        "<tr><td>Saldo proyectado al retiro</td><td>", format_currency(resultado$solo_sistema$saldo_proyectado %||% 0), "</td></tr>",
        "<tr><td>Pensión mensual</td><td><strong>", format_currency(resultado$solo_sistema$pension_mensual), "</strong></td></tr>",
        "<tr><td>Tasa de reemplazo</td><td>", round(resultado$solo_sistema$tasa_reemplazo * 100, 1), "%</td></tr>",
        "</table>",

        "<h3>4.2 Con Fondo Bienestar</h3>",
        "<table class='styled-table'>",
        "<tr><th>Concepto</th><th>Valor</th></tr>",
        "<tr><td>Elegible</td><td>", if(resultado$con_fondo$elegible) "<strong style='color: #059669;'>Si</strong>" else "No", "</td></tr>",
        if (resultado$con_fondo$elegible) {
          paste0(
            "<tr><td>Complemento mensual</td><td>", format_currency(resultado$con_fondo$complemento), "</td></tr>",
            "<tr><td>Pensión total</td><td><strong>", format_currency(resultado$con_fondo$pension_total), "</strong></td></tr>"
          )
        } else {
          paste0("<tr><td>Razon</td><td>", resultado$fondo_bienestar$razon_no_elegible, "</td></tr>")
        },
        "</table>",

        "<h3>4.3 Con Acciones Propias</h3>",
        "<table class='styled-table'>",
        "<tr><th>Concepto</th><th>Valor</th></tr>",
        "<tr><td>Aportación voluntaria mensual</td><td>", format_currency(entrada$aportacion_voluntaria), "</td></tr>",
        "<tr><td>Saldo proyectado</td><td>", format_currency(resultado$con_acciones$saldo_proyectado %||% 0), "</td></tr>",
        "<tr><td>Pensión AFORE</td><td><strong>", format_currency(resultado$con_acciones$pension_afore), "</strong></td></tr>",
        "<tr><td>Pensión total</td><td><strong>", format_currency(resultado$con_acciones$pension_total), "</strong></td></tr>",
        "</table>"
      )
    },

    # Seccion 5: Supuestos y Limitaciones
    "<div class='section-header'>",
    "<div class='section-icon'>5</div>",
    "<span>Supuestos y Limitaciones</span>",
    "</div>",

    "<div class='warning-box'>",
    "<strong>Importante:</strong> Esta es una estimación educativa, NO una garantía. ",
    "Los resultados reales pueden variar significativamente.",
    "</div>",

    "<h3>5.1 Supuestos del Modelo</h3>",
    "<ul>", generate_supuestos_html(entrada), "</ul>",

    "<h3>5.2 Limitaciones</h3>",
    "<ul>",
    "<li>No considera inflacion futura variable</li>",
    "<li>No incluye beneficios adicionales (matrimonio, hijos, etc.)</li>",
    "<li>El Fondo Bienestar es un programa nuevo (2024) con sostenibilidad incierta</li>",
    "<li>Los rendimientos pasados no garantizan rendimientos futuros</li>",
    "<li>Las leyes y políticas pueden cambiar</li>",
    "</ul>",

    # Seccion 6: Fuentes de Datos
    "<div class='section-header'>",
    "<div class='section-icon'>6</div>",
    "<span>Fuentes de Datos</span>",
    "</div>",

    "<table class='styled-table'>",
    "<tr><th>Dato</th><th>Fuente</th><th>Fecha</th></tr>",
    "<tr><td>Tabla Artículo 167</td><td>Ley del Seguro Social 1973</td><td>Vigente</td></tr>",
    "<tr><td>UMA</td><td>INEGI / DOF</td><td>Enero 2025</td></tr>",
    "<tr><td>Salario Mínimo</td><td>CONASAMI</td><td>Enero 2025</td></tr>",
    "<tr><td>Comisiones AFORE</td><td>CONSAR</td><td>2024-2025</td></tr>",
    "<tr><td>Mortalidad</td><td>CONAPO / CNSF</td><td>Simplificada</td></tr>",
    "<tr><td>Umbral Fondo Bienestar</td><td>DOF / IMSS</td><td>2025</td></tr>",
    "</table>",

    # Seccion 7: Glosario
    "<div class='section-header'>",
    "<div class='section-icon'>7</div>",
    "<span>Glosario</span>",
    "</div>",

    "<table class='styled-table'>",
    "<tr><th>Termino</th><th>Definicion</th></tr>",
    "<tr><td>UMA</td><td>Unidad de Medida y Actualización. Indicador que reemplaza al salario mínimo para cálculos oficiales.</td></tr>",
    "<tr><td>SBC</td><td>Salario Base de Cotización. El salario registrado ante el IMSS.</td></tr>",
    "<tr><td>Tasa de reemplazo</td><td>Porcentaje del último salario que representa la pensión.</td></tr>",
    "<tr><td>Cesantía</td><td>Pensión anticipada entre los 60 y 64 años.</td></tr>",
    "<tr><td>IRN</td><td>Indicador de Rendimiento Neto. Mide el rendimiento de una AFORE descontando comisiones.</td></tr>",
    "</table>",

    # Footer
    "<div class='doc-footer'>",
    "<p>Documento generado autom&aacute;ticamente por el Simulador de Pensi&oacute;n IMSS + Fondo Bienestar</p>",
    "<p>Para m&aacute;s informaci&oacute;n, consulta: <a href='https://www.imss.gob.mx/'>IMSS</a> | ",
    "<a href='https://www.consar.gob.mx/'>CONSAR</a> | ",
    "<a href='https://www.e-sar.com.mx/'>e-SAR</a></p>",
    "</div>"
  )

  html <- html_report_skeleton("Documento T\u00e9cnico - Estimaci\u00f3n de Pensi\u00f3n", body)
  return(html)
}

# ============================================================================
# DOCUMENTO BASICO HTML (PRINT-FRIENDLY)
# ============================================================================

#' Generar reporte basico HTML (optimizado para impresion)
#' @param resultado Resultado del calculo de pension
#' @return String HTML del documento
generate_basic_report <- function(resultado) {

  # Determinar tipo de regimen
  es_ley73 <- resultado$regimen == REGIMEN_LEY73
  entrada <- resultado$entrada

  # Pension principal
  if (es_ley73) {
    pension_principal <- resultado$pension_base$pension_mensual %||% 0
    tasa_reemplazo <- resultado$pension_base$tasa_reemplazo %||% 0
  } else {
    pension_principal <- resultado$solo_sistema$pension_mensual %||% 0
    tasa_reemplazo <- resultado$solo_sistema$tasa_reemplazo %||% 0
  }

  # Construir body content
  body <- paste0(
    "<h1 class='doc-title'>Tu Pensi&oacute;n Estimada</h1>",
    "<p class='doc-subtitle'>Reporte b&aacute;sico para impresi&oacute;n</p>",
    "<p class='doc-date'>Generado el ", format(Sys.Date(), "%d de %B de %Y"), "</p>",

    # Big pension number
    "<div class='highlight-box'>",
    "<div class='pension-label'>Pensión mensual estimada</div>",
    "<div class='pension-amount'>", format_currency(pension_principal), "<span class='pension-period'>/mes</span></div>",
    "<div style='margin-top: 15px; color: #64748b;'>",
    round(tasa_reemplazo * 100), "% de tu salario actual",
    "</div>",
    "</div>",

    # Warning
    "<div class='warning-box'>",
    "<strong>Importante:</strong> Esta es una estimación educativa, NO una garantía. ",
    "Las leyes y programas pueden cambiar.",
    "</div>",

    # Data summary
    "<div class='section-header'>",
    "<div class='section-icon'>1</div>",
    "<span>Datos Ingresados</span>",
    "</div>",

    "<table class='styled-table'>",
    "<tr><th>Concepto</th><th>Valor</th></tr>",
    "<tr><td>Salario mensual</td><td><strong>", format_currency(entrada$salario_mensual), "</strong></td></tr>",
    "<tr><td>Edad actual</td><td>", entrada$edad_actual, " años</td></tr>",
    "<tr><td>Edad de retiro</td><td>", entrada$edad_retiro, " años</td></tr>",
    "<tr><td>Régimen</td><td>", if(es_ley73) "Ley 73" else "Ley 97 (AFORE)", "</td></tr>",

    if (!es_ley73) {
      paste0(
        "<tr><td>Saldo actual AFORE</td><td>", format_currency(entrada$saldo_actual), "</td></tr>",
        "<tr><td>Aportación voluntaria</td><td>", format_currency(entrada$aportacion_voluntaria), "/mes</td></tr>"
      )
    } else "",

    "</table>",

    # Results
    "<div class='section-header'>",
    "<div class='section-icon'>2</div>",
    "<span>Resultados</span>",
    "</div>",

    if (!es_ley73) {
      paste0(
        "<div class='three-cards'>",
        "<div class='card'>",
        "<div class='card-label'>Solo AFORE</div>",
        "<div class='card-value'>", format_currency(resultado$solo_sistema$pension_mensual), "</div>",
        "<div class='card-subtitle'>Tu pensión base</div>",
        "</div>",
        "<div class='card'>",
        "<div class='card-label'>+ Fondo Bienestar</div>",
        "<div class='card-value'>",
        if(resultado$con_fondo$elegible) format_currency(resultado$con_fondo$pension_total) else "N/A",
        "</div>",
        "<div class='card-subtitle'>",
        if(resultado$con_fondo$elegible) "Si el programa continua" else "No elegible",
        "</div>",
        "</div>",
        "<div class='card highlight'>",
        "<div class='card-label'>+ Tus Acciones</div>",
        "<div class='card-value'>", format_currency(resultado$con_acciones$pension_afore), "</div>",
        "<div class='card-subtitle'>Con aportaciones voluntarias</div>",
        "</div>",
        "</div>"
      )
    } else {
      paste0(
        "<div class='data-card' style='text-align: center;'>",
        "<div style='font-size: 14px; color: #64748b; margin-bottom: 10px;'>PENSIÓN LEY 73</div>",
        "<div style='font-size: 36px; font-weight: 700; color: #0f766e;'>",
        format_currency(resultado$pension_base$pension_mensual), "/mes</div>",
        "<div style='margin-top: 10px; color: #64748b;'>Pensión definida basada en semanas y salario</div>",
        "</div>"
      )
    },

    # Key takeaway
    "<div class='section-header'>",
    "<div class='section-icon'>3</div>",
    "<span>Lo Importante</span>",
    "</div>",

    "<div class='action-box'>",
    "<div class='action-title'>Recuerda</div>",
    "<p>Tus <strong>aportaciones voluntarias</strong> son la parte MAS SEGURA de tu pensión. ",
    "El Fondo Bienestar es un programa nuevo (2024) y su futuro es incierto.</p>",
    "</div>",

    # Links
    "<div class='links-section'>",
    "<strong>Consulta fuentes oficiales:</strong><br><br>",
    "<a href='https://www.imss.gob.mx/'>IMSS</a>",
    "<a href='https://www.consar.gob.mx/'>CONSAR</a>",
    "<a href='https://www.e-sar.com.mx/'>e-SAR</a>",
    "</div>",

    # Footer
    "<div class='doc-footer'>",
    "<p>Simulador de Pensi&oacute;n IMSS + Fondo Bienestar</p>",
    "<p>Este documento es para uso personal e informativo.</p>",
    "</div>"
  )

  html <- html_report_skeleton("Reporte B\u00e1sico - Pensi\u00f3n Estimada", body)
  return(html)
}

# ============================================================================
# METODOLOGIA HTML
# ============================================================================

#' Generar documento HTML de metodologia
#' @return String HTML del documento
generate_methodology_html <- function() {

  # Additional CSS for methodology
  extra_css <- "
    .toc {
      background: #f8fafc;
      border-radius: 12px;
      padding: 25px;
      margin: 30px 0;
    }
    .toc-title {
      font-weight: 600;
      color: #0f766e;
      margin-bottom: 15px;
    }
    .toc a {
      color: #0d9488;
      text-decoration: none;
      display: block;
      padding: 5px 0;
    }
    .toc a:hover {
      text-decoration: underline;
    }
    .factor-table {
      max-width: 300px;
    }
  "

  body <- paste0(
    "<h1 class='doc-title'>Metodolog&iacute;a del Simulador</h1>",
    "<p class='doc-subtitle'>C&oacute;mo calculamos tu pensi&oacute;n estimada</p>",
    "<p class='doc-date'>Version 1.0 - 2025</p>",

    # Table of Contents
    "<div class='toc'>",
    "<div class='toc-title'>Contenido</div>",
    "<a href='#intro'>1. Introduccion</a>",
    "<a href='#ley73'>2. Cálculo Ley 73</a>",
    "<a href='#ley97'>3. Cálculo Ley 97 (AFORE)</a>",
    "<a href='#fondo'>4. Fondo de Pensiones para el Bienestar</a>",
    "<a href='#supuestos'>5. Supuestos y Limitaciones</a>",
    "<a href='#fuentes'>6. Fuentes de Datos</a>",
    "</div>",

    # Section 1: Introduction
    "<div class='section-header' id='intro'>",
    "<div class='section-icon'>1</div>",
    "<span>Introduccion</span>",
    "</div>",

    "<p>Este simulador proporciona <strong>estimaciones educativas</strong> para ayudar ",
    "a los trabajadores mexicanos a entender y planificar su retiro bajo los diferentes ",
    "regímenes del sistema de seguridad social mexicano.</p>",

    "<div class='info-box'>",
    "<strong>Alcance:</strong> El simulador cubre Ley 73, Ley 97 (AFORE), y el Fondo de ",
    "Pensiones para el Bienestar (2024). Los resultados son estimaciones, no garantías.",
    "</div>",

    # Section 2: Ley 73
    "<div class='section-header' id='ley73'>",
    "<div class='section-icon'>2</div>",
    "<span>Cálculo Ley 73</span>",
    "</div>",

    "<p>La Ley del Seguro Social de 1973 establece un sistema de <strong>pensión definida</strong> ",
    "donde el monto depende de:</p>",

    "<ul>",
    "<li>Salario Base de Cotización promedio (últimas 250 semanas)</li>",
    "<li>Semanas cotizadas (mínimo 500)</li>",
    "<li>Edad al momento del retiro</li>",
    "</ul>",

    "<h3>Fórmula de Pensión</h3>",
    "<div class='formula-box'>",
    "Pensión = SBC_Promedio x Porcentaje_Artículo_167 x Factor_Cesantía",
    "</div>",

    "<h3>Factor de Cesantía por Edad</h3>",
    "<p>Para retiros antes de los 65 años:</p>",

    "<table class='styled-table factor-table'>",
    "<tr><th>Edad</th><th>Factor</th></tr>",
    "<tr><td>60 años</td><td>75%</td></tr>",
    "<tr><td>61 años</td><td>80%</td></tr>",
    "<tr><td>62 años</td><td>85%</td></tr>",
    "<tr><td>63 años</td><td>90%</td></tr>",
    "<tr><td>64 años</td><td>95%</td></tr>",
    "<tr><td>65+ años</td><td>100%</td></tr>",
    "</table>",

    "<h3>Requisitos</h3>",
    "<ul>",
    "<li>Mínimo 500 semanas cotizadas</li>",
    "<li>Edad mínima: 60 años (cesantía) o 65 años (vejez)</li>",
    "<li>Haber comenzado a cotizar antes del 1 de julio de 1997</li>",
    "</ul>",

    # Section 3: Ley 97
    "<div class='section-header' id='ley97'>",
    "<div class='section-icon'>3</div>",
    "<span>Cálculo Ley 97 (AFORE)</span>",
    "</div>",

    "<p>La Ley de 1997 establece un sistema de <strong>cuentas individuales</strong> ",
    "administradas por AFOREs. La pensión depende del saldo acumulado.</p>",

    "<h3>Proyeccion del Saldo</h3>",
    "<div class='formula-box'>",
    "Saldo_Final = Saldo_Actual x (1 + r)^n + Aportaciones_Futuras_Capitalizadas",
    "</div>",

    "<p>Donde:</p>",
    "<ul>",
    "<li><strong>r</strong> = Rendimiento real anual (3-5% segun escenario)</li>",
    "<li><strong>n</strong> = Anos hasta el retiro</li>",
    "</ul>",

    "<h3>Pensión Mensual (Retiro Programado)</h3>",
    "<div class='formula-box'>",
    "Pension_Mensual = Saldo_Final / (Esperanza_de_Vida x 12)",
    "</div>",

    "<h3>Aportaciones Obligatorias (2025)</h3>",
    "<table class='styled-table'>",
    "<tr><th>Concepto</th><th>% del SBC</th></tr>",
    "<tr><td>Patron (RCV)</td><td>5.15%</td></tr>",
    "<tr><td>Patrón (Cesantía)</td><td>3.15%</td></tr>",
    "<tr><td>Trabajador</td><td>1.125%</td></tr>",
    "<tr><td>Gobierno</td><td>0.225%</td></tr>",
    "<tr><td><strong>Total</strong></td><td><strong>9.65%</strong></td></tr>",
    "</table>",

    # Section 4: Fondo Bienestar
    "<div class='section-header' id='fondo'>",
    "<div class='section-icon'>4</div>",
    "<span>Fondo de Pensiones para el Bienestar</span>",
    "</div>",

    "<p>Creado en 2024, el Fondo complementa pensiones de trabajadores que cumplen ciertos requisitos ",
    "hasta alcanzar el 100% de su último salario.</p>",

    "<h3>Requisitos de Elegibilidad</h3>",
    "<ul>",
    "<li>Tener 65 años o más al momento de jubilarse</li>",
    "<li>Salario promedio menor o igual al umbral ($17,364/mes en 2025)</li>",
    "<li>La pensión AFORE sea menor al 100% del salario</li>",
    "</ul>",

    "<h3>Cálculo del Complemento</h3>",
    "<div class='formula-box'>",
    "Complemento = min(Salario - Pension_AFORE, Pension_Garantizada_Maxima)",
    "</div>",

    "<div class='warning-box'>",
    "<strong>Importante:</strong> El Fondo Bienestar es un programa nuevo (2024) y su ",
    "sostenibilidad a largo plazo no está garantizada. Tus aportaciones voluntarias son ",
    "la parte más segura de tu pensión.",
    "</div>",

    # Section 5: Supuestos
    "<div class='section-header' id='supuestos'>",
    "<div class='section-icon'>5</div>",
    "<span>Supuestos y Limitaciones</span>",
    "</div>",

    "<h3>Supuestos del Modelo</h3>",
    "<ul>",
    "<li>Rendimientos: 3% (conservador), 4% (base), 5% (optimista) real anual</li>",
    "<li>Densidad de cotización futura: 100% (empleo continuo)</li>",
    "<li>Esperanza de vida: Tablas CONAPO simplificadas</li>",
    "<li>Inflacion incorporada en rendimientos reales</li>",
    "</ul>",

    "<h3>Limitaciones</h3>",
    "<ul>",
    "<li>No considera variaciones en la inflacion futura</li>",
    "<li>No incluye beneficios adicionales (matrimonio, hijos, etc.)</li>",
    "<li>Los rendimientos pasados no garantizan rendimientos futuros</li>",
    "<li>Las leyes y políticas pueden cambiar</li>",
    "</ul>",

    # Section 6: Sources
    "<div class='section-header' id='fuentes'>",
    "<div class='section-icon'>6</div>",
    "<span>Fuentes de Datos</span>",
    "</div>",

    "<table class='styled-table'>",
    "<tr><th>Dato</th><th>Fuente</th></tr>",
    "<tr><td>Tabla Artículo 167</td><td>Ley del Seguro Social 1973</td></tr>",
    "<tr><td>UMA ", ANIO_ACTUAL, "</td><td>INEGI / DOF ($", UMA_DIARIA_2025, "/dia)</td></tr>",
    "<tr><td>Salario M&iacute;nimo ", ANIO_ACTUAL, "</td><td>CONASAMI ($", SM_DIARIO_2025, "/d&iacute;a)</td></tr>",
    "<tr><td>Comisiones AFORE</td><td>CONSAR 2024-2025</td></tr>",
    "<tr><td>Tablas de Mortalidad</td><td>CONAPO / CNSF</td></tr>",
    "<tr><td>Umbral Fondo Bienestar</td><td>DOF / IMSS ($", format(UMBRAL_FONDO_BIENESTAR_2025, big.mark = ","), "/mes)</td></tr>",
    "</table>",

    # Links
    "<div class='links-section'>",
    "<strong>Recursos Oficiales:</strong><br><br>",
    "<a href='https://www.imss.gob.mx/' target='_blank'>IMSS</a>",
    "<a href='https://www.consar.gob.mx/' target='_blank'>CONSAR</a>",
    "<a href='https://www.gob.mx/conasami' target='_blank'>CONASAMI</a>",
    "<a href='https://www.inegi.org.mx/' target='_blank'>INEGI</a>",
    "</div>",

    # Footer
    "<div class='doc-footer'>",
    "<p>Simulador de Pensi&oacute;n IMSS + Fondo Bienestar - Versi&oacute;n 1.0</p>",
    "<p>Documento generado autom&aacute;ticamente para fines educativos.</p>",
    "</div>"
  )

  html <- html_report_skeleton("Metodolog\u00eda - Simulador de Pensi\u00f3n IMSS", body, extra_css = extra_css)
  return(html)
}

# ============================================================================
# DOCUMENTO RESUMEN PDF (R Markdown)
# ============================================================================

#' Generar documento resumen en formato R Markdown (para PDF)
#' @param resultado Resultado del calculo de pension
#' @return String con contenido Rmd
generate_summary_rmd <- function(resultado) {
  es_ley73 <- resultado$regimen == REGIMEN_LEY73
  entrada <- resultado$entrada

  # Pension principal a mostrar (with NULL handling)
  if (es_ley73) {
    pension_principal <- resultado$pension_base$pension_mensual %||% 0
    tasa_reemplazo <- resultado$pension_base$tasa_reemplazo %||% 0
  } else {
    pension_principal <- resultado$solo_sistema$pension_mensual %||% 0
    tasa_reemplazo <- resultado$solo_sistema$tasa_reemplazo %||% 0
  }

  # YAML header
  yaml_header <- paste0(
    "---\n",
    "title: 'Resumen Ejecutivo - Tu Pensión'\n",
    "date: '", format(Sys.Date(), "%d de %B de %Y"), "'\n",
    "output:\n",
    "  pdf_document:\n",
    "    latex_engine: xelatex\n",
    "header-includes:\n",
    "  - \\usepackage{xcolor}\n",
    "  - \\definecolor{primary}{RGB}{15,118,110}\n",
    "  - \\pagenumbering{gobble}\n",
    "---\n\n"
  )

  # Pension principal
  pension_section <- paste0(
    "# ", format_currency_latex(pension_principal), "/mes\n\n",
    "Tu pensión estimada representa el **", round(tasa_reemplazo * 100), "%** de tu salario actual (",
    format_currency_latex(entrada$salario_mensual), ")\n\n"
  )

  # Comparacion (solo Ley 97)
  comparacion <- ""
  if (!es_ley73) {
    comparacion <- paste0(
      "---\n\n",
      "## Tres Escenarios\n\n",
      "| Escenario | Pensión Mensual |\n",
      "|-----------|----------------|\n",
      "| Solo AFORE | ", format_currency_latex(resultado$solo_sistema$pension_mensual), " |\n",
      "| + Fondo Bienestar | ",
      if(resultado$con_fondo$elegible) format_currency_latex(resultado$con_fondo$pension_total) else "No elegible",
      " |\n",
      "| + Tus Aportaciones | ", format_currency_latex(resultado$con_acciones$pension_afore), " |\n\n"
    )
  }

  # Mensaje clave
  mensaje <- paste0(
    "---\n\n",
    "## Lo Que Debes Saber\n\n",
    "**IMPORTANTE:** Esta es una estimación educativa, NO una garantía.\n\n",
    "El Fondo Bienestar es un programa nuevo (2024) y su futuro es incierto.\n\n",
    "Tus aportaciones voluntarias son la parte **MAS SEGURA** de tu pensión.\n\n"
  )

  # Acciones
  acciones <- paste0(
    "---\n\n",
    "## 3 Cosas que Puedes Hacer HOY\n\n",
    "1. **Aportaciones voluntarias:** Incluso $500/mes hacen diferencia.\n\n",
    "2. **Revisa tu AFORE:** Compara rendimientos en CONSAR.\n\n",
    "3. **Consulta tus semanas:** Verifica en IMSS Digital que esten todas.\n\n"
  )

  # Links
  links <- paste0(
    "---\n\n",
    "## Links Utiles\n\n",
    "- IMSS: https://www.imss.gob.mx/\n",
    "- CONSAR: https://www.consar.gob.mx/\n",
    "- e-SAR: https://www.e-sar.com.mx/\n",
    "- IMSS Digital: https://serviciosdigitales.imss.gob.mx/\n\n",
    "---\n\n",
    "*Generado por el Simulador de Pensión IMSS + Fondo Bienestar*\n"
  )

  # Combinar
  rmd_content <- paste0(
    yaml_header,
    pension_section,
    comparacion,
    mensaje,
    acciones,
    links
  )

  return(rmd_content)
}

# ============================================================================
# DOCUMENTO RESUMEN HTML
# ============================================================================

#' Generar documento resumen HTML (para no-tecnicos)
#' @param resultado Resultado del calculo de pension
#' @return String HTML del documento
generate_summary_report <- function(resultado) {

  # Determinar tipo de regimen
  es_ley73 <- resultado$regimen == REGIMEN_LEY73
  entrada <- resultado$entrada

  # Pension principal a mostrar (with NULL handling)
  if (es_ley73) {
    pension_principal <- resultado$pension_base$pension_mensual %||% 0
    tasa_reemplazo <- resultado$pension_base$tasa_reemplazo %||% 0
  } else {
    pension_principal <- resultado$solo_sistema$pension_mensual %||% 0
    tasa_reemplazo <- resultado$solo_sistema$tasa_reemplazo %||% 0
  }

  # Construir body content
  body <- paste0(
    "<h1 class='doc-title'>Tu Pensi&oacute;n Estimada</h1>",
    "<p class='doc-subtitle'>Resumen ejecutivo para ti y tu familia</p>",
    "<p class='doc-date'>", format(Sys.Date(), "%d de %B de %Y"), "</p>",

    # Numero grande
    "<div class='highlight-box'>",
    "<div class='pension-label'>Tu pensión mensual estimada</div>",
    "<div class='pension-amount'>",
    format_currency(pension_principal),
    "<span class='pension-period'>/mes</span>",
    "</div>",
    "</div>",

    # Comparacion con salario
    "<div class='comparison-row'>",
    "<div class='comparison-item'>",
    "<div class='card-label'>Tu salario actual</div>",
    "<div class='card-value'>", format_currency(entrada$salario_mensual), "</div>",
    "</div>",
    "<div class='comparison-arrow'>→</div>",
    "<div class='comparison-item'>",
    "<div class='card-label'>Tu pensión base</div>",
    "<div class='card-value' style='color: #0d9488;'>", round(tasa_reemplazo * 100), "% del salario</div>",
    "</div>",
    "</div>",

    # Tres tarjetas resumen
    if (!es_ley73) {
      paste0(
        "<div class='three-cards'>",
        "<div class='card'>",
        "<div class='card-label'>Solo AFORE</div>",
        "<div class='card-value'>", format_currency(resultado$solo_sistema$pension_mensual), "</div>",
        "<div class='card-subtitle'>Lo mínimo que tendrás</div>",
        "</div>",
        "<div class='card'>",
        "<div class='card-label'>+ Fondo Bienestar</div>",
        "<div class='card-value'>",
        if(resultado$con_fondo$elegible) format_currency(resultado$con_fondo$pension_total) else "N/A",
        "</div>",
        "<div class='card-subtitle'>",
        if(resultado$con_fondo$elegible) "Si el programa continua" else "No elegible",
        "</div>",
        "</div>",
        "<div class='card highlight'>",
        "<div class='card-label'>+ Tus Acciones</div>",
        "<div class='card-value'>", format_currency(resultado$con_acciones$pension_afore), "</div>",
        "<div class='card-subtitle'>Con aportaciones voluntarias</div>",
        "</div>",
        "</div>"
      )
    } else "",

    # Mensaje clave
    "<div class='warning-box'>",
    "<strong>Recuerda:</strong> Esta es una estimación educativa. Las leyes y programas ",
    "pueden cambiar. El Fondo Bienestar es nuevo (2024) y su futuro es incierto.",
    "</div>",

    # Acciones
    "<div class='action-box'>",
    "<div class='action-title'>3 Cosas que Puedes Hacer HOY</div>",
    "<ol style='margin: 0; padding-left: 25px;'>",
    "<li style='margin: 12px 0;'><strong>Aportaciones voluntarias:</strong> Incluso $500/mes hacen diferencia. Es la parte MAS SEGURA de tu pensión.</li>",
    "<li style='margin: 12px 0;'><strong>Revisa tu AFORE:</strong> Compara rendimientos en CONSAR. Un mejor AFORE puede darte miles de pesos mas.</li>",
    "<li style='margin: 12px 0;'><strong>Consulta tus semanas:</strong> Verifica en IMSS Digital que tengas todas tus semanas registradas.</li>",
    "</ol>",
    "</div>",

    # Links utiles
    "<div class='links-section'>",
    "<strong>Links utiles:</strong><br><br>",
    "<a href='https://www.imss.gob.mx/' target='_blank'>IMSS</a>",
    "<a href='https://www.consar.gob.mx/' target='_blank'>CONSAR</a>",
    "<a href='https://www.e-sar.com.mx/' target='_blank'>e-SAR</a>",
    "<a href='https://serviciosdigitales.imss.gob.mx/' target='_blank'>IMSS Digital</a>",
    "</div>",

    # Footer
    "<div class='doc-footer'>",
    "<p>Generado por el Simulador de Pensi&oacute;n IMSS + Fondo Bienestar</p>",
    "<p>Este documento es para uso personal e informativo.</p>",
    "</div>"
  )

  html <- html_report_skeleton("Tu Pensi\u00f3n - Resumen Ejecutivo", body)
  return(html)
}
