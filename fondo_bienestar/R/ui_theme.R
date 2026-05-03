# R/ui_theme.R - Theme definition
# Simulador de Pension IMSS + Fondo Bienestar

# ============================================================================
# TEMA DE LA APLICACION
# ============================================================================

#' Crear tema personalizado para la aplicacion
#' @return Objeto bs_theme de bslib
pension_theme <- function() {
  bslib::bs_theme(
    version = 5,  # Bootstrap 5

    # Colores primarios - Professional Emerald & Amber
    primary = "#065f46",     # Emerald 800
    secondary = "#b45309",   # Amber 700
    success = "#059669",     # Emerald 600
    warning = "#d97706",     # Amber 600
    danger = "#dc2626",      # Red 600
    info = "#047857",        # Emerald 700

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
