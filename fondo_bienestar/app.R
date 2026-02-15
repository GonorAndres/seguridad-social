# app.R - Simulador de Pension IMSS + Fondo Bienestar
# Version 1.0 - Aplicacion principal R Shiny
#
# Ejecutar con: shiny::runApp()

# ============================================================================
# DEPENDENCIAS Y DATOS
# ============================================================================
# Source global.R explicitly so everything is in the global environment.
# Shiny also sources global.R, but scoping can cause issues with <<-.

source("global.R", local = FALSE)

# ============================================================================
# UI - INTERFAZ DE USUARIO
# ============================================================================

ui <- bslib::page_fluid(
  # Tema personalizado
  theme = pension_theme(),

  # Recursos externos
  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$link(rel = "icon", type = "image/svg+xml", href = "favicon.svg"),
    tags$meta(name = "description", content = "Simulador de pension IMSS. Calcula tu pension de Ley 73, Ley 97 y Fondo Bienestar en 5 minutos."),
    tags$link(
      rel = "stylesheet",
      href = "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css"
    ),
    tags$link(rel = "stylesheet", href = "styles.css"),
    # JavaScript for interactivity
    tags$script(HTML("
      // Debug: Log Shiny connection status
      $(document).on('shiny:connected', function() {
        console.log('Shiny connected successfully!');

        // Initialize Bootstrap 5 tooltips
        var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle=\"tooltip\"]'));
        tooltipTriggerList.map(function(el) {
          return new bootstrap.Tooltip(el);
        });
      });

      $(document).on('shiny:disconnected', function() {
        console.log('Shiny disconnected!');
      });

      // Handle regimen radio card clicks - send to Shiny manually
      $(document).on('click', '.radio-card', function() {
        var radio = $(this).find('input[type=\"radio\"]');
        radio.prop('checked', true);
        var value = radio.val();
        console.log('Regimen changed to: ' + value);
        Shiny.setInputValue('regimen', value);

        // Update visual state
        $('.radio-card').removeClass('selected');
        $(this).addClass('selected');
      });

      // Landing page interactions
      $(document).on('click', '#start_wizard, #start_wizard_from_context', function() {
        console.log('Starting wizard...');
        Shiny.setInputValue('start_wizard_click', Date.now());
      });

      $(document).on('click', '#show_context', function() {
        console.log('Showing context...');
        $('#context_section').slideToggle(400);
        $(this).text(function(i, text) {
          return text.indexOf('Quiero entender') > -1 ? 'Ocultar contexto' : 'Quiero entender primero';
        });
      });

      // Loading state for calculate button
      $(document).on('click', '#calcular', function() {
        var btn = $(this);
        btn.prop('disabled', true);
        btn.html('<span class=\"spinner-border spinner-border-sm me-2\" role=\"status\"></span>Calculando...');
      });

      // Re-enable button when results load
      $(document).on('shiny:value', function(event) {
        if (event.name === 'result_cards') {
          var btn = $('#calcular');
          btn.prop('disabled', false);
          btn.html('<i class=\"bi bi-calculator me-2\"></i>Calcular pension');
        }
      });

      // Smooth scroll to top of results
      $(document).on('shiny:value', function(event) {
        if (event.name === 'result_cards') {
          setTimeout(function() {
            $('html, body').animate({ scrollTop: $('#step4_panel').offset().top - 20 }, 400);
          }, 100);
        }
      });
    "))
  ),

  # Habilitar shinyjs
  shinyjs::useShinyjs(),

  # ========== LANDING PAGE ==========
  tags$div(
    id = "landing_page",

    # Hero Section
    hero_section(),

    # Context Section (hidden by default)
    div(
      class = "container-fluid",
      style = "max-width: 1200px;",
      context_section()
    )
  ),

  # ========== WIZARD MODE (hidden initially) ==========
  shinyjs::hidden(
    div(
      id = "wizard_mode",

      # Header de la aplicacion (wizard mode)
      tags$div(
        class = "app-header wizard-mode",
        tags$h1(class = "app-title", "Simulador de Pension IMSS"),
        tags$p(
          class = "app-subtitle",
          "Conoce tu pension. Actua donde puedas."
        )
      ),

      # Contenedor principal
      div(
        class = "container-fluid",
        style = "max-width: 1200px;",

        # ========== WIZARD HEADER ==========
        tags$div(
          class = "wizard-header",
          tags$div(
            class = "wizard-steps",
            # Step 1
            tags$div(
              id = "step1_indicator",
              class = "wizard-step active",
              tags$span(class = "step-number", "1"),
              tags$span(class = "step-label d-none d-md-block", "Datos Personales")
            ),
            tags$span(class = "wizard-line"),
            # Step 2
            tags$div(
              id = "step2_indicator",
              class = "wizard-step",
              tags$span(class = "step-number", "2"),
              tags$span(class = "step-label d-none d-md-block", "Datos Laborales")
            ),
            tags$span(class = "wizard-line"),
            # Step 3
            tags$div(
              id = "step3_indicator",
              class = "wizard-step",
              tags$span(class = "step-number", "3"),
              tags$span(class = "step-label d-none d-md-block", "AFORE")
            ),
            tags$span(class = "wizard-line"),
            # Step 4
            tags$div(
              id = "step4_indicator",
              class = "wizard-step",
              tags$span(class = "step-number", "4"),
              tags$span(class = "step-label d-none d-md-block", "Resultados")
            )
          )
        ),

        # ========== STEP 1: DATOS PERSONALES ==========
        tags$div(
          id = "step1_panel",
          class = "wizard-panel card shadow-sm",

          tags$div(
            class = "card-header bg-surface border-0 pt-4",
            tags$h4(class = "card-title mb-0", "Datos Personales")
          ),

          tags$div(
            class = "card-body",

            fluidRow(
              column(6,
                dateInput(
                  "fecha_nacimiento",
                  label = tagList(
                    "Fecha de nacimiento",
                    help_tooltip("Tu fecha de nacimiento determina tu edad actual y anos restantes al retiro")
                  ),
                  value = "1985-01-15",
                  min = "1940-01-01",
                  max = Sys.Date() - 365*18,
                  format = "dd/mm/yyyy",
                  language = "es"
                )
              ),

              column(6,
                radioButtons(
                  "genero",
                  label = tagList(
                    "Genero",
                    help_tooltip("Afecta la esperanza de vida usada en los calculos de pension")
                  ),
                  choices = c("Masculino" = "M", "Femenino" = "F"),
                  selected = "M",
                  inline = TRUE
                )
              )
            ),

            fluidRow(
              column(6,
                numericInput(
                  "edad_retiro",
                  label = tagList(
                    "Edad de retiro deseada",
                    help_tooltip("Entre 60 y 70 anos. A los 65 tienes acceso al Fondo Bienestar")
                  ),
                  value = 65,
                  min = 60,
                  max = 70,
                  step = 1
                )
              ),

              column(6,
                tags$div(
                  class = "mt-4 pt-2",
                  tags$small(
                    class = "text-muted",
                    tags$i(class = "bi bi-info-circle me-1"),
                    "El Fondo Bienestar requiere 65 anos minimo"
                  )
                )
              )
            )
          ),

          tags$div(
            class = "card-footer bg-surface border-0 d-flex justify-content-between pb-4",
            actionButton(
              "back_to_landing",
              tagList(tags$i(class = "bi bi-arrow-left me-2"), "Volver"),
              class = "btn btn-outline-secondary"
            ),
            actionButton(
              "next_step1",
              tagList("Siguiente", tags$i(class = "bi bi-arrow-right ms-2")),
              class = "btn btn-primary"
            )
          )
        ),

        # ========== STEP 2: DATOS LABORALES ==========
        shinyjs::hidden(
          tags$div(
            id = "step2_panel",
            class = "wizard-panel card shadow-sm",

            tags$div(
              class = "card-header bg-surface border-0 pt-4",
              tags$h4(class = "card-title mb-0", "Datos Laborales")
            ),

            tags$div(
              class = "card-body",

              # Regimen
              tags$label(
                class = "form-label",
                "Cuando comenzaste a cotizar en el IMSS?",
                help_tooltip("Determina si estas bajo Ley 73 (mejor pension) o Ley 97 (AFORE)")
              ),

              tags$div(
                class = "radio-card-group mb-4",

                tags$label(
                  class = "radio-card",
                  id = "card_ley73",
                  tags$input(
                    type = "radio",
                    name = "regimen",
                    value = "ley73",
                    id = "regimen_ley73"
                  ),
                  tags$div(class = "radio-title", "Antes del 1 julio 1997"),
                  tags$div(class = "radio-description", "Ley 73 - Pension definida (generalmente mejor)")
                ),

                tags$label(
                  class = "radio-card selected",
                  id = "card_ley97",
                  tags$input(
                    type = "radio",
                    name = "regimen",
                    value = "ley97",
                    id = "regimen_ley97",
                    checked = "checked"
                  ),
                  tags$div(class = "radio-title", "Despues del 1 julio 1997"),
                  tags$div(class = "radio-description", "Ley 97 - Cuenta individual AFORE")
                )
              ),

              fluidRow(
                column(6,
                  numericInput(
                    "salario_mensual",
                    label = tagList(
                      "Salario mensual actual (MXN)",
                      help_tooltip("Tu salario bruto mensual. Si difiere de tu SBC, usa el SBC")
                    ),
                    value = 20000,
                    min = 1000,
                    max = 500000,
                    step = 500
                  )
                ),

                column(6,
                  numericInput(
                    "semanas_cotizadas",
                    label = tagList(
                      "Semanas cotizadas",
                      help_tooltip("Consulta en IMSS Digital o en tu reporte de semanas cotizadas")
                    ),
                    value = 500,
                    min = 0,
                    max = 3000,
                    step = 1
                  ),
                  tags$a(
                    href = "https://serviciosdigitales.imss.gob.mx/",
                    target = "_blank",
                    class = "form-text text-decoration-none",
                    tags$i(class = "bi bi-box-arrow-up-right me-1"),
                    "Consultar en IMSS Digital"
                  )
                )
              )
            ),

            tags$div(
              class = "card-footer bg-surface border-0 d-flex justify-content-between pb-4",
              actionButton(
                "prev_step2",
                tagList(tags$i(class = "bi bi-arrow-left me-2"), "Anterior"),
                class = "btn btn-outline-secondary"
              ),
              actionButton(
                "next_step2",
                tagList("Siguiente", tags$i(class = "bi bi-arrow-right ms-2")),
                class = "btn btn-primary"
              )
            )
          )
        ),

        # ========== STEP 3: AFORE Y APORTACIONES ==========
        shinyjs::hidden(
          tags$div(
            id = "step3_panel",
            class = "wizard-panel card shadow-sm",

            tags$div(
              class = "card-header bg-surface border-0 pt-4",
              tags$h4(class = "card-title mb-0", "AFORE y Aportaciones")
            ),

            tags$div(
              class = "card-body",

              fluidRow(
                column(6,
                  selectInput(
                    "afore_actual",
                    label = tagList(
                      "Tu AFORE actual",
                      help_tooltip("Si no sabes cual es, consulta en e-SAR o llama a CONSAR")
                    ),
                    choices = NULL,  # Se llena en el server
                    selected = NULL
                  ),
                  tags$a(
                    href = "https://www.e-sar.com.mx/",
                    target = "_blank",
                    class = "form-text text-decoration-none",
                    tags$i(class = "bi bi-box-arrow-up-right me-1"),
                    "Consultar tu AFORE en e-SAR"
                  )
                ),

                column(6,
                  numericInput(
                    "saldo_afore",
                    label = tagList(
                      "Saldo actual en AFORE (MXN)",
                      help_tooltip("Consulta tu estado de cuenta. Incluye RCV, vivienda y voluntarias")
                    ),
                    value = 200000,
                    min = 0,
                    max = 50000000,
                    step = 1000
                  )
                )
              ),

              tags$hr(class = "my-4"),

              fluidRow(
                column(6,
                  numericInput(
                    "aportacion_voluntaria",
                    label = tagList(
                      "Aportacion voluntaria mensual",
                      help_tooltip("Dinero adicional que TU decides aportar. Es la mejor herramienta para mejorar tu pension")
                    ),
                    value = 0,
                    min = 0,
                    max = 50000,
                    step = 100
                  ),
                  tags$small(
                    class = "form-text",
                    tags$i(class = "bi bi-lightbulb text-warning me-1"),
                    "Incluso $500/mes pueden hacer gran diferencia"
                  )
                ),

                column(6,
                  selectInput(
                    "escenario",
                    label = tagList(
                      "Escenario de rendimiento",
                      help_tooltip("Conservador: 3% real. Base: 4% real. Optimista: 5% real")
                    ),
                    choices = c(
                      "Conservador (3% real)" = "conservador",
                      "Base (4% real)" = "base",
                      "Optimista (5% real)" = "optimista"
                    ),
                    selected = "base"
                  )
                )
              )
            ),

            tags$div(
              class = "card-footer bg-surface border-0 d-flex justify-content-between pb-4",
              actionButton(
                "prev_step3",
                tagList(tags$i(class = "bi bi-arrow-left me-2"), "Anterior"),
                class = "btn btn-outline-secondary"
              ),
              actionButton(
                "calcular",
                tagList(tags$i(class = "bi bi-calculator me-2"), "Calcular pension"),
                class = "btn btn-primary btn-lg"
              )
            )
          )
        ),

        # ========== STEP 4: RESULTADOS ==========
        shinyjs::hidden(
          tags$div(
            id = "step4_panel",
            class = "wizard-panel card shadow-sm",

            tags$div(
              class = "card-header bg-surface border-0 pt-4",
              tags$h4(class = "card-title mb-0", "Tu Pension Estimada")
            ),

            tags$div(
              class = "card-body",

              # Results: Hero + Breakdown + Fondo status
              uiOutput("result_cards"),

              # Separador
              tags$hr(class = "my-4"),

              # Seccion: Que puedes hacer?
              tags$h5(
                class = "mb-3",
                tags$i(class = "bi bi-sliders me-2 text-teal"),
                "Que puedes hacer?"
              ),

              # Key message
              key_message(
                "Recuerda: ",
                tags$strong("tus aportaciones voluntarias son la parte mas segura"),
                " de tu pension. El Fondo Bienestar puede ayudar, pero su futuro es incierto."
              ),

              # Sliders de sensibilidad (2x2 grid)
              fluidRow(
                column(6,
                  tags$div(
                    class = "slider-container",
                    tags$div(
                      class = "slider-label",
                      tags$span(class = "label-text", "Aportacion voluntaria"),
                      tags$span(class = "label-value", id = "vol_value", "$0/mes")
                    ),
                    sliderInput(
                      "slider_voluntaria",
                      label = NULL,
                      min = 0,
                      max = 5000,
                      value = 0,
                      step = 100,
                      ticks = FALSE
                    ),
                    tags$div(class = "slider-impact positive", id = "vol_impact", "")
                  )
                ),

                column(6,
                  tags$div(
                    class = "slider-container",
                    tags$div(
                      class = "slider-label",
                      tags$span(class = "label-text", "Edad de retiro"),
                      tags$span(class = "label-value", id = "age_value", "65 anos")
                    ),
                    sliderInput(
                      "slider_edad",
                      label = NULL,
                      min = 60,
                      max = 70,
                      value = 65,
                      step = 1,
                      ticks = FALSE
                    ),
                    tags$div(class = "slider-impact", id = "age_impact", "")
                  )
                )
              ),

              fluidRow(
                column(6,
                  tags$div(
                    class = "slider-container",
                    tags$div(
                      class = "slider-label",
                      tags$span(class = "label-text", "Semanas cotizadas"),
                      tags$span(class = "label-value", id = "semanas_value", "500")
                    ),
                    sliderInput(
                      "slider_semanas",
                      label = NULL,
                      min = 0,
                      max = 3000,
                      value = 500,
                      step = 10,
                      ticks = FALSE
                    ),
                    tags$div(class = "slider-impact", id = "semanas_impact", "")
                  )
                ),

                column(6,
                  tags$div(
                    class = "slider-container",
                    tags$div(
                      class = "slider-label",
                      tags$span(class = "label-text", "Cambiar AFORE a"),
                      uiOutput("afore_value_display")
                    ),
                    uiOutput("afore_selector_results"),
                    tags$div(class = "slider-impact", id = "afore_impact", "")
                  )
                )
              ),

              # Grafico de proyeccion
              tags$div(
                class = "chart-container",
                tags$h6(class = "chart-title", "Proyeccion de tu saldo"),
                plotly::plotlyOutput("proyeccion_chart", height = "350px")
              ),

              # Panel tecnico
              tags$div(
                class = "accordion mt-4",
                id = "technicalAccordion",

                tags$div(
                  class = "accordion-item technical-panel",
                  tags$h2(
                    class = "accordion-header",
                    tags$button(
                      class = "accordion-button collapsed",
                      type = "button",
                      `data-bs-toggle` = "collapse",
                      `data-bs-target` = "#technicalCollapse",
                      tags$i(class = "bi bi-gear me-2"),
                      "Panel Tecnico (supuestos y formulas)"
                    )
                  ),
                  tags$div(
                    id = "technicalCollapse",
                    class = "accordion-collapse collapse",
                    `data-bs-parent` = "#technicalAccordion",
                    tags$div(
                      class = "accordion-body",
                      uiOutput("technical_details")
                    )
                  )
                )
              ),

              # Download Section
              download_section()
            ),

            tags$div(
              class = "card-footer bg-surface border-0 d-flex justify-content-between pb-4",
              actionButton(
                "modificar_datos",
                tagList(tags$i(class = "bi bi-pencil me-2"), "Modificar datos"),
                class = "btn btn-outline-secondary"
              ),
              actionButton(
                "nueva_simulacion",
                tagList(tags$i(class = "bi bi-arrow-clockwise me-2"), "Nueva simulacion"),
                class = "btn btn-outline-primary"
              )
            )
          )
        ),

        # Footer / Disclaimer
        tags$div(
          class = "app-footer",
          tags$p(
            tags$i(class = "bi bi-exclamation-triangle me-1"),
            "Esta es una ",
            tags$strong("estimacion educativa"),
            ", no una garantia. Las leyes y politicas pueden cambiar."
          ),
          tags$p(
            "Consulta tu estado de cuenta oficial en ",
            tags$a(href = "https://www.imss.gob.mx/", target = "_blank", "IMSS"),
            " y ",
            tags$a(href = "https://www.consar.gob.mx/", target = "_blank", "CONSAR"),
            "."
          ),
          tags$p(
            class = "mb-0 mt-3",
            tags$small(
              "Desarrollado con ",
              tags$i(class = "bi bi-heart-fill text-danger"),
              " para los trabajadores mexicanos | 2025"
            )
          )
        )
      )
    )
  )
)

# ============================================================================
# SERVER - LOGICA DEL SERVIDOR
# ============================================================================

server <- function(input, output, session) {

  # ==========================================================================
  # RESOURCE PATHS
  # ==========================================================================
  addResourcePath("docs", "docs")

  # ==========================================================================
  # ERROR HANDLING - Log errors to console
  # ==========================================================================
  options(shiny.error = function() {
    cat("\n=== SHINY ERROR ===\n")
    cat(geterrmessage(), "\n")
    traceback()
    cat("===================\n")
  })

  # ==========================================================================
  # ESTADO REACTIVO
  # ==========================================================================

  # Paso actual del wizard
  current_step <- reactiveVal(1)

  # Resultados del calculo
  resultados <- reactiveVal(NULL)

  # Resultados originales (baseline fijo para el grafico)
  resultados_originales <- reactiveVal(NULL)

  # Regimen seleccionado (reactivo)
  regimen_actual <- reactiveVal("ley97")

  # ==========================================================================
  # INICIALIZACION
  # ==========================================================================

  # Llenar lista de AFOREs
  observe({
    afores <- get_afore_names()
    updateSelectInput(session, "afore_actual", choices = afores, selected = "XXI Banorte")
  })

  # ==========================================================================
  # LANDING PAGE -> WIZARD TRANSITION
  # ==========================================================================

  observeEvent(input$start_wizard_click, {
    shinyjs::hide("landing_page")
    shinyjs::show("wizard_mode")
  })

  observeEvent(input$back_to_landing, {
    shinyjs::hide("wizard_mode")
    shinyjs::show("landing_page")
  })

  # ==========================================================================
  # NAVEGACION DEL WIZARD
  # ==========================================================================

  # Funcion para actualizar indicadores del wizard
  update_wizard_indicators <- function(step) {
    for (i in 1:4) {
      if (i < step) {
        shinyjs::removeClass(paste0("step", i, "_indicator"), "active")
        shinyjs::addClass(paste0("step", i, "_indicator"), "completed")
      } else if (i == step) {
        shinyjs::removeClass(paste0("step", i, "_indicator"), "completed")
        shinyjs::addClass(paste0("step", i, "_indicator"), "active")
      } else {
        shinyjs::removeClass(paste0("step", i, "_indicator"), "active")
        shinyjs::removeClass(paste0("step", i, "_indicator"), "completed")
      }
    }
  }

  # Step 1 -> Step 2
  observeEvent(input$next_step1, {
    # Validate fecha_nacimiento is not empty/invalid
    if (is.null(input$fecha_nacimiento) || is.na(input$fecha_nacimiento)) {
      showNotification("Por favor ingresa tu fecha de nacimiento", type = "error")
      return()
    }

    # Validate genero and edad_retiro exist
    req(input$genero, input$edad_retiro)

    edad_actual <- as.numeric(difftime(Sys.Date(), input$fecha_nacimiento, units = "days")) / 365.25

    if (edad_actual < 18) {
      showNotification("Debes tener al menos 18 anos", type = "error")
      return()
    }

    # Validate retirement age is in valid range (explicit checks)
    if (is.na(input$edad_retiro) || input$edad_retiro < 60) {
      showNotification("La edad de retiro minima es 60 anos", type = "error")
      return()
    }
    if (input$edad_retiro > 70) {
      showNotification("La edad de retiro maxima es 70 anos", type = "error")
      return()
    }

    # Validate retirement is in the future
    if (edad_actual >= input$edad_retiro) {
      showNotification(
        paste0("Tu edad actual (", floor(edad_actual), " anos) ya supera o iguala la edad de retiro. ",
               "Ajusta la edad de retiro o verifica tu fecha de nacimiento."),
        type = "error",
        duration = 8
      )
      return()
    }

    shinyjs::hide("step1_panel")
    shinyjs::show("step2_panel")
    current_step(2)
    update_wizard_indicators(2)
  })

  # Step 2 -> Step 1
  observeEvent(input$prev_step2, {
    shinyjs::hide("step2_panel")
    shinyjs::show("step1_panel")
    current_step(1)
    update_wizard_indicators(1)
  })

  # Step 2 -> Step 3
  observeEvent(input$next_step2, {
    # Validate salary is not negative (explicit check first)
    if (is.na(input$salario_mensual) || input$salario_mensual < 0) {
      showNotification("El salario no puede ser negativo", type = "error")
      return()
    }

    # Validate salary minimum
    if (input$salario_mensual < 1000) {
      showNotification("El salario debe ser al menos $1,000 MXN", type = "error")
      return()
    }

    # Validate weeks are not negative
    if (is.na(input$semanas_cotizadas) || input$semanas_cotizadas < 0) {
      showNotification("Las semanas cotizadas no pueden ser negativas", type = "error")
      return()
    }

    shinyjs::hide("step2_panel")
    shinyjs::show("step3_panel")
    current_step(3)
    update_wizard_indicators(3)
  })

  # Step 3 -> Step 2
  observeEvent(input$prev_step3, {
    shinyjs::hide("step3_panel")
    shinyjs::show("step2_panel")
    current_step(2)
    update_wizard_indicators(2)
  })

  # Detectar cambio de regimen via JavaScript setInputValue
  # Cross-validate regimen with birth date (warning only, non-blocking)
  observeEvent(input$regimen, {
    req(input$regimen)

    # Update reactive value first
    regimen_actual(input$regimen)

    # Cross-validation with birth date if available
    if (!is.null(input$fecha_nacimiento) && !is.na(input$fecha_nacimiento)) {
      birth_year <- as.numeric(format(input$fecha_nacimiento, "%Y"))

      # If born after 1979, they likely started working after 1997
      if (input$regimen == "ley73" && birth_year > 1979) {
        showNotification(
          paste0("Nota: Si naciste en ", birth_year, ", es probable que hayas empezado ",
                 "a cotizar despues de 1997 (Ley 97). Verifica tu regimen en tu estado de cuenta IMSS."),
          type = "warning",
          duration = 10
        )
      }

      # If born before 1960, they definitely are Ley 73
      if (input$regimen == "ley97" && birth_year < 1960) {
        showNotification(
          paste0("Nota: Si naciste en ", birth_year, ", es muy probable que estes bajo Ley 73. ",
                 "Verifica tu regimen en tu estado de cuenta IMSS."),
          type = "warning",
          duration = 10
        )
      }
    }

    # Visual updates handled by JavaScript
  }, ignoreNULL = TRUE, ignoreInit = TRUE)

  # ==========================================================================
  # CALCULO PRINCIPAL
  # ==========================================================================

  observeEvent(input$calcular, {
    req(input$fecha_nacimiento, input$salario_mensual, input$semanas_cotizadas)

    # Validate AFORE balance is not negative
    if (is.na(input$saldo_afore) || input$saldo_afore < 0) {
      showNotification("El saldo de AFORE no puede ser negativo", type = "error")
      return()
    }

    # Validate voluntary contribution is not negative
    if (is.na(input$aportacion_voluntaria) || input$aportacion_voluntaria < 0) {
      showNotification("La aportacion voluntaria no puede ser negativa", type = "error")
      return()
    }

    # Calcular edad actual
    edad_actual <- as.numeric(difftime(Sys.Date(), input$fecha_nacimiento, units = "days")) / 365.25

    # Determinar regimen
    regimen <- regimen_actual()

    # Realizar calculo
    if (regimen == "ley73") {
      # Calcular pension Ley 73
      sbc_diario <- input$salario_mensual / 30
      anios_restantes <- max(0, input$edad_retiro - floor(edad_actual))
      semanas_al_retiro <- input$semanas_cotizadas + (anios_restantes * 52)

      resultado_base <- calculate_ley73_pension(
        sbc_promedio_diario = sbc_diario,
        semanas = semanas_al_retiro,
        edad = input$edad_retiro
      )

      # Simular Modalidad 40 si aplica
      resultado_m40 <- NULL
      if (resultado_base$elegible && anios_restantes > 0) {
        semanas_m40 <- min(anios_restantes * 52, 260)
        resultado_m40 <- calculate_modalidad_40(
          pension_actual = resultado_base,
          sbc_actual = sbc_diario,
          sbc_m40 = TOPE_SBC_DIARIO * 0.8,
          semanas_actuales = semanas_al_retiro - semanas_m40,
          semanas_m40 = semanas_m40,
          edad_actual = floor(edad_actual),
          edad_retiro = input$edad_retiro
        )
      }

      res <- list(
        regimen = "ley73",
        pension_base = resultado_base,
        pension_m40 = resultado_m40,
        fondo_aplica = FALSE,
        entrada = list(
          salario_mensual = input$salario_mensual,
          edad_actual = floor(edad_actual),
          edad_retiro = input$edad_retiro,
          semanas_actuales = input$semanas_cotizadas,
          genero = input$genero
        )
      )

    } else {
      # Calcular pension Ley 97 con Fondo Bienestar
      res <- calculate_pension_with_fondo(
        saldo_actual = input$saldo_afore,
        salario_mensual = input$salario_mensual,
        edad_actual = floor(edad_actual),
        edad_retiro = input$edad_retiro,
        semanas_actuales = input$semanas_cotizadas,
        genero = input$genero,
        aportacion_voluntaria = input$aportacion_voluntaria,
        afore_nombre = input$afore_actual,
        escenario = input$escenario
      )
      res$regimen <- "ley97"
      res$fondo_aplica <- TRUE
    }

    resultados(res)
    resultados_originales(res)

    # Actualizar sliders con valores iniciales
    updateSliderInput(session, "slider_voluntaria", value = input$aportacion_voluntaria)
    updateSliderInput(session, "slider_edad", value = input$edad_retiro)
    updateSliderInput(session, "slider_semanas", value = input$semanas_cotizadas)

    # Mostrar resultados
    shinyjs::hide("step3_panel")
    shinyjs::show("step4_panel")
    current_step(4)
    update_wizard_indicators(4)
  })

  # ==========================================================================
  # RENDERIZADO DE RESULTADOS
  # ==========================================================================

  # Results: Hero + Breakdown
  output$result_cards <- renderUI({
    req(resultados())
    res <- resultados()

    if (res$regimen == "ley73") {
      render_results_hero_ley73(res)
    } else {
      render_results_hero(res)
    }
  })

  # Fondo message and encouragement are now integrated into result_cards hero component

  # ==========================================================================
  # ANALISIS DE SENSIBILIDAD (con debounce)
  # ==========================================================================

  # Debounced values
  vol_debounced <- reactive({ input$slider_voluntaria }) |> debounce(300)
  edad_debounced <- reactive({ input$slider_edad }) |> debounce(300)
  semanas_debounced <- reactive({ input$slider_semanas }) |> debounce(300)

  # Actualizar etiquetas de sliders (only when inputs exist)
  observe({
    req(input$slider_voluntaria)
    shinyjs::html("vol_value", paste0("$", format(input$slider_voluntaria, big.mark = ","), "/mes"))
  })

  observe({
    req(input$slider_edad)
    shinyjs::html("age_value", paste0(input$slider_edad, " anos"))
  })

  observe({
    req(input$slider_semanas)
    shinyjs::html("semanas_value", format(input$slider_semanas, big.mark = ","))
  })

  # Calcular impacto de voluntarias
  observe({
    req(resultados(), vol_debounced())
    res <- resultados()

    if (res$regimen == "ley97") {
      tryCatch({
        # Recalcular con nueva aportacion
        nuevo <- calculate_pension_with_fondo(
          saldo_actual = res$entrada$saldo_actual,
          salario_mensual = res$entrada$salario_mensual,
          edad_actual = res$entrada$edad_actual,
          edad_retiro = res$entrada$edad_retiro,
          semanas_actuales = res$entrada$semanas_actuales,
          genero = res$entrada$genero %||% "M",
          aportacion_voluntaria = vol_debounced(),
          afore_nombre = res$entrada$afore %||% "XXI Banorte",
          escenario = res$entrada$escenario %||% "base"
        )

        diferencia <- nuevo$con_acciones$diferencia_vs_base
        if (!is.null(diferencia) && length(diferencia) > 0 && diferencia > 0) {
          shinyjs::html("vol_impact",
            paste0("+", format_currency(diferencia), "/mes"))
          shinyjs::addClass(selector = "#vol_impact", class = "positive")
        } else {
          shinyjs::html("vol_impact", "")
        }
      }, error = function(e) {
        shinyjs::html("vol_impact", "")
      })
    }
  })

  # Calcular impacto de edad de retiro
  observe({
    req(resultados(), edad_debounced())
    res <- resultados()
    edad_slider <- edad_debounced()

    # Skip if same as original
    if (edad_slider == res$entrada$edad_retiro) {
      shinyjs::html("age_impact", "")
      return()
    }

    tryCatch({
      if (res$regimen == "ley97") {
        # Recalcular con nueva edad
        nuevo <- calculate_pension_with_fondo(
          saldo_actual = res$entrada$saldo_actual,
          salario_mensual = res$entrada$salario_mensual,
          edad_actual = res$entrada$edad_actual,
          edad_retiro = edad_slider,
          semanas_actuales = res$entrada$semanas_actuales,
          genero = res$entrada$genero %||% "M",
          aportacion_voluntaria = 0,
          afore_nombre = res$entrada$afore %||% "XXI Banorte",
          escenario = res$entrada$escenario %||% "base"
        )
        diferencia <- nuevo$solo_sistema$pension_mensual - res$solo_sistema$pension_mensual
      } else {
        # Ley 73: recalcular con nueva edad
        sbc_diario <- res$entrada$salario_mensual / 30
        anios_restantes <- max(0, edad_slider - res$entrada$edad_actual)
        semanas_al_retiro <- res$entrada$semanas_actuales + (anios_restantes * 52)

        nuevo <- calculate_ley73_pension(
          sbc_promedio_diario = sbc_diario,
          semanas = semanas_al_retiro,
          edad = edad_slider
        )
        diferencia <- nuevo$pension_mensual - res$pension_base$pension_mensual
      }

      if (!is.null(diferencia) && length(diferencia) > 0 && diferencia != 0) {
        signo <- if (diferencia > 0) "+" else ""
        clase <- if (diferencia > 0) "positive" else "negative"
        shinyjs::html("age_impact",
          paste0(signo, format_currency(diferencia), "/mes"))
        shinyjs::removeClass(selector = "#age_impact", class = "positive")
        shinyjs::removeClass(selector = "#age_impact", class = "negative")
        shinyjs::addClass(selector = "#age_impact", class = clase)
      } else {
        shinyjs::html("age_impact", "")
      }
    }, error = function(e) {
      shinyjs::html("age_impact", "")
    })
  })

  # Calcular impacto de cambio de AFORE
  observe({
    req(resultados(), input$afore_comparar)
    res <- resultados()

    # Only applies to Ley 97
    if (res$regimen != "ley97") {
      shinyjs::html("afore_impact", "")
      return()
    }

    # Skip if same as original
    if (input$afore_comparar == res$entrada$afore) {
      shinyjs::html("afore_impact", "")
      return()
    }

    tryCatch({
      nuevo <- calculate_pension_with_fondo(
        saldo_actual = res$entrada$saldo_actual,
        salario_mensual = res$entrada$salario_mensual,
        edad_actual = res$entrada$edad_actual,
        edad_retiro = res$entrada$edad_retiro,
        semanas_actuales = res$entrada$semanas_actuales,
        genero = res$entrada$genero %||% "M",
        aportacion_voluntaria = 0,
        afore_nombre = input$afore_comparar,
        escenario = res$entrada$escenario %||% "base"
      )

      dif_pension <- nuevo$solo_sistema$pension_mensual - res$solo_sistema$pension_mensual
      dif_saldo <- (nuevo$solo_sistema$saldo_proyectado %||% 0) -
                   (res$solo_sistema$saldo_proyectado %||% 0)

      shinyjs::removeClass(selector = "#afore_impact", class = "positive")
      shinyjs::removeClass(selector = "#afore_impact", class = "negative")

      if (!is.null(dif_pension) && dif_pension != 0) {
        # Pension changed -- show pension difference
        signo <- if (dif_pension > 0) "+" else ""
        clase <- if (dif_pension > 0) "positive" else "negative"
        shinyjs::html("afore_impact",
          paste0(signo, format_currency(dif_pension), "/mes"))
        shinyjs::addClass(selector = "#afore_impact", class = clase)
      } else if (!is.null(dif_saldo) && abs(dif_saldo) > 100) {
        # Pension floored at minimum but saldo differs -- show saldo difference
        signo <- if (dif_saldo > 0) "+" else ""
        clase <- if (dif_saldo > 0) "positive" else "negative"
        shinyjs::html("afore_impact",
          paste0(signo, format_currency(dif_saldo), " en saldo"))
        shinyjs::addClass(selector = "#afore_impact", class = clase)
      } else {
        shinyjs::html("afore_impact", "")
      }
    }, error = function(e) {
      shinyjs::html("afore_impact", "")
    })
  })

  # Calcular impacto de semanas cotizadas
  observe({
    req(resultados(), semanas_debounced())
    res <- resultados()
    semanas_slider <- semanas_debounced()

    # Skip if same as original
    if (semanas_slider == res$entrada$semanas_actuales) {
      shinyjs::html("semanas_impact", "")
      return()
    }

    tryCatch({
      shinyjs::removeClass(selector = "#semanas_impact", class = "positive")
      shinyjs::removeClass(selector = "#semanas_impact", class = "negative")

      if (res$regimen == "ley97") {
        # Ley 97: semanas affect eligibility, not AFORE balance directly
        anios_restantes <- max(0, res$entrada$edad_retiro - res$entrada$edad_actual)
        nuevo_semanas_retiro <- semanas_slider + (anios_restantes * 52)
        orig_semanas_retiro <- res$entrada$semanas_actuales + (anios_restantes * 52)

        # Recalculate to check pension and Fondo eligibility changes
        nuevo <- calculate_pension_with_fondo(
          saldo_actual = res$entrada$saldo_actual,
          salario_mensual = res$entrada$salario_mensual,
          edad_actual = res$entrada$edad_actual,
          edad_retiro = res$entrada$edad_retiro,
          semanas_actuales = semanas_slider,
          genero = res$entrada$genero %||% "M",
          aportacion_voluntaria = 0,
          afore_nombre = res$entrada$afore %||% "XXI Banorte",
          escenario = res$entrada$escenario %||% "base"
        )

        dif_pension <- nuevo$solo_sistema$pension_mensual - res$solo_sistema$pension_mensual

        if (dif_pension != 0) {
          # Pension changed (e.g., crossed eligibility threshold)
          signo <- if (dif_pension > 0) "+" else ""
          clase <- if (dif_pension > 0) "positive" else "negative"
          shinyjs::html("semanas_impact",
            paste0(signo, format_currency(dif_pension), "/mes"))
          shinyjs::addClass(selector = "#semanas_impact", class = clase)
        } else if (nuevo$con_fondo$elegible != res$con_fondo$elegible) {
          # Fondo Bienestar eligibility changed
          if (nuevo$con_fondo$elegible) {
            shinyjs::html("semanas_impact", "Elegible para Fondo Bienestar")
            shinyjs::addClass(selector = "#semanas_impact", class = "positive")
          } else {
            shinyjs::html("semanas_impact", "No elegible para Fondo")
            shinyjs::addClass(selector = "#semanas_impact", class = "negative")
          }
        } else {
          # Show semanas al retiro count as informational
          shinyjs::html("semanas_impact",
            paste0(format(nuevo_semanas_retiro, big.mark = ","), " sem. al retiro"))
        }

      } else {
        # Ley 73: semanas directly affect pension via Art. 167
        sbc_diario <- res$entrada$salario_mensual / 30
        anios_restantes <- max(0, res$entrada$edad_retiro - res$entrada$edad_actual)
        semanas_al_retiro <- semanas_slider + (anios_restantes * 52)

        nuevo <- calculate_ley73_pension(
          sbc_promedio_diario = sbc_diario,
          semanas = semanas_al_retiro,
          edad = res$entrada$edad_retiro
        )
        diferencia <- nuevo$pension_mensual - res$pension_base$pension_mensual

        if (!is.null(diferencia) && length(diferencia) > 0 && diferencia != 0) {
          signo <- if (diferencia > 0) "+" else ""
          clase <- if (diferencia > 0) "positive" else "negative"
          shinyjs::html("semanas_impact",
            paste0(signo, format_currency(diferencia), "/mes"))
          shinyjs::addClass(selector = "#semanas_impact", class = clase)
        } else {
          shinyjs::html("semanas_impact", "")
        }
      }
    }, error = function(e) {
      shinyjs::html("semanas_impact", "")
    })
  })

  # AFORE selector en resultados
  output$afore_selector_results <- renderUI({
    selectInput(
      "afore_comparar",
      label = NULL,
      choices = get_afore_names(),
      selected = input$afore_actual
    )
  })

  output$afore_value_display <- renderUI({
    tags$span(class = "label-value", input$afore_actual)
  })

  # ==========================================================================
  # GRAFICO DE PROYECCION
  # ==========================================================================

  output$proyeccion_chart <- plotly::renderPlotly({
    req(resultados(), resultados_originales(), vol_debounced(), edad_debounced(), semanas_debounced())
    res <- resultados()
    res_orig <- resultados_originales()
    vol_actual <- vol_debounced() %||% 0
    edad_slider <- edad_debounced() %||% res$entrada$edad_retiro
    semanas_slider <- semanas_debounced() %||% res$entrada$semanas_actuales

    # Get selected AFORE (falls back to original if not selected)
    afore_to_use <- if (!is.null(input$afore_comparar) && input$afore_comparar != "") {
      input$afore_comparar
    } else {
      res$entrada$afore
    }

    if (res$regimen == "ley73") {
      # Ley 73: bar chart with 3 color states
      edad_mostrar <- max(60, min(65, edad_slider))
      edad_original <- res_orig$entrada$edad_retiro

      edades <- 60:65
      factores <- c(0.75, 0.80, 0.85, 0.90, 0.95, 1.00)

      # Calcular pension base a 65 anos (100%)
      pension_base_65 <- res$pension_base$pension_mensual / res$pension_base$factor_edad
      pensiones <- pension_base_65 * factores

      # 3 color states: slider-selected (teal), original (magenta), other (golden)
      colores <- ifelse(edades == edad_mostrar, "#0f766e",
                   ifelse(edades == edad_original & edad_original != edad_mostrar, "#db2777", "#c4a67a"))

      plot_ly(
        x = edades,
        y = pensiones,
        type = "bar",
        marker = list(color = colores),
        text = paste0(factores * 100, "%"),
        textposition = "outside",
        hovertemplate = "Edad %{x}: %{y:$,.0f}/mes (%{text})<extra></extra>"
      ) |>
        layout(
          title = list(text = "Factor de Cesantia por Edad de Retiro", x = 0.5),
          xaxis = list(
            title = "Edad de retiro",
            tickvals = 60:65,
            dtick = 1
          ),
          yaxis = list(
            title = "Pension mensual estimada",
            tickformat = "$,.0f"
          ),
          plot_bgcolor = "#fffbf0",
          paper_bgcolor = "#fffbf0",
          margin = list(t = 50)
        ) |>
        config(displayModeBar = FALSE)

    } else {
      # Ley 97: 3-trace overlay chart

      # Trace 1: Original calculation (fixed baseline, dotted golden)
      tray_orig <- res_orig$solo_sistema$trayectoria
      if (is.null(tray_orig)) {
        return(NULL)
      }

      # Trace 2: With changes (slider age/semanas/AFORE, no voluntary) - dashed teal
      res_cambios <- calculate_pension_with_fondo(
        saldo_actual = res$entrada$saldo_actual,
        salario_mensual = res$entrada$salario_mensual,
        edad_actual = res$entrada$edad_actual,
        edad_retiro = edad_slider,
        semanas_actuales = semanas_slider,
        genero = res$entrada$genero,
        aportacion_voluntaria = 0,
        afore_nombre = afore_to_use,
        escenario = res$entrada$escenario
      )
      tray_cambios <- res_cambios$solo_sistema$trayectoria

      # Trace 3: With changes + voluntary contributions - solid teal
      res_vol <- calculate_pension_with_fondo(
        saldo_actual = res$entrada$saldo_actual,
        salario_mensual = res$entrada$salario_mensual,
        edad_actual = res$entrada$edad_actual,
        edad_retiro = edad_slider,
        semanas_actuales = semanas_slider,
        genero = res$entrada$genero,
        aportacion_voluntaria = max(500, vol_actual),
        afore_nombre = afore_to_use,
        escenario = res$entrada$escenario
      )
      tray_vol <- res_vol$con_acciones$trayectoria

      plot_ly() |>
        add_trace(
          x = tray_orig$anio,
          y = tray_orig$saldo,
          type = "scatter",
          mode = "lines",
          name = "Calculo original",
          line = list(color = "#c4a67a", dash = "dot", width = 2),
          hovertemplate = "Ano %{x}: $%{y:,.0f}<extra></extra>"
        ) |>
        add_trace(
          x = tray_cambios$anio,
          y = tray_cambios$saldo,
          type = "scatter",
          mode = "lines",
          name = "Con cambios",
          line = list(color = "#0f766e", dash = "dash", width = 2),
          hovertemplate = "Ano %{x}: $%{y:,.0f}<extra></extra>"
        ) |>
        add_trace(
          x = tray_vol$anio,
          y = tray_vol$saldo,
          type = "scatter",
          mode = "lines",
          name = "+ Tus aportaciones",
          line = list(color = "#0f766e", width = 3),
          fill = "tonexty",
          fillcolor = "rgba(15, 118, 110, 0.1)",
          hovertemplate = "Ano %{x}: $%{y:,.0f}<extra></extra>"
        ) |>
        layout(
          xaxis = list(
            title = "Anos hasta retiro",
            gridcolor = "#fde6c4"
          ),
          yaxis = list(
            title = "Saldo acumulado (MXN)",
            tickformat = "$,.0f",
            gridcolor = "#fde6c4"
          ),
          legend = list(
            orientation = "h",
            x = 0.5,
            xanchor = "center",
            y = -0.15
          ),
          hovermode = "x unified",
          plot_bgcolor = "#fffbf0",
          paper_bgcolor = "#fffbf0",
          margin = list(t = 20)
        ) |>
        config(
          displayModeBar = TRUE,
          modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d", "zoomIn2d", "zoomOut2d"),
          displaylogo = FALSE
        )
    }
  })

  # ==========================================================================
  # PANEL TECNICO
  # ==========================================================================

  output$technical_details <- renderUI({
    req(resultados())
    res <- resultados()

    # Handle NULL or missing escenario (e.g., for Ley 73)
    escenario_val <- res$entrada$escenario
    if (is.null(escenario_val) || length(escenario_val) != 1) {
      escenario_val <- "base"
    }
    rendimiento_texto <- switch(escenario_val,
      "conservador" = "3% real (conservador)",
      "base" = "4% real (base)",
      "optimista" = "5% real (optimista)",
      "4% real"
    )

    tagList(
      tags$h6("Supuestos utilizados:"),
      tags$ul(
        tags$li(paste0("Regimen: ", if (res$regimen == "ley73") "Ley 73" else "Ley 97 (AFORE)")),
        tags$li(paste0("Rendimiento proyectado: ", rendimiento_texto)),
        if (res$regimen == "ley97") tags$li(paste0("AFORE: ", res$entrada$afore)),
        tags$li(paste0("Umbral Fondo Bienestar 2025: ", format_currency(UMBRAL_FONDO_BIENESTAR_2025))),
        tags$li(paste0("UMA diaria 2025: ", format_currency(UMA_DIARIA_2025))),
        tags$li(paste0("Salario minimo 2025: ", format_currency(SM_DIARIO_2025), "/dia"))
      ),

      tags$h6(class = "mt-3", "Fuentes de datos:"),
      tags$ul(
        tags$li("Tabla Articulo 167: Ley del Seguro Social 1973"),
        tags$li("UMA: INEGI / DOF"),
        tags$li("Salario minimo: CONASAMI"),
        tags$li("Comisiones AFORE: CONSAR"),
        tags$li("Mortalidad: CONAPO / CNSF (simplificada)")
      ),

      tags$h6(class = "mt-3", "Limitaciones:"),
      tags$ul(
        tags$li("Esta es una estimacion educativa, NO una garantia"),
        tags$li("Las leyes y politicas pueden cambiar"),
        tags$li("El Fondo Bienestar (2024) tiene sostenibilidad incierta"),
        tags$li("Los rendimientos pasados no garantizan rendimientos futuros"),
        tags$li("No incluye efectos de inflacion futura no proyectada")
      ),

      tags$div(
        class = "mt-3",
        tags$a(
          href = "https://www.imss.gob.mx/",
          target = "_blank",
          class = "btn btn-outline-secondary btn-sm me-2",
          "IMSS"
        ),
        tags$a(
          href = "https://www.consar.gob.mx/",
          target = "_blank",
          class = "btn btn-outline-secondary btn-sm me-2",
          "CONSAR"
        ),
        tags$a(
          href = "https://www.gob.mx/conasami",
          target = "_blank",
          class = "btn btn-outline-secondary btn-sm",
          "CONASAMI"
        )
      )
    )
  })

  # ==========================================================================
  # ACCIONES ADICIONALES
  # ==========================================================================

  # Volver a modificar datos
  observeEvent(input$modificar_datos, {
    shinyjs::hide("step4_panel")
    shinyjs::show("step1_panel")
    current_step(1)
    update_wizard_indicators(1)
  })

  # ==========================================================================
  # VISUALIZACION DE REPORTES (HTML en nueva pestana del navegador)
  # ==========================================================================

  # Temp file tracking for session cleanup
  session_temp_files <- character(0)
  session$onSessionEnded(function() {
    for (f in session_temp_files) {
      if (file.exists(f)) try(file.remove(f), silent = TRUE)
    }
  })

  # Helper: write HTML to www/ temp file and open in new tab
  open_report_in_tab <- function(html_content, prefix, print_btn_color, print_btn_hover) {
    # Wrap with print button
    html_with_print <- paste0(
      "<!DOCTYPE html><html><head><meta charset='UTF-8'>",
      "<style>",
      "@media print { .no-print { display: none !important; } body { padding: 20px; } }",
      ".print-section { position: fixed; bottom: 20px; right: 20px; z-index: 1000; }",
      ".print-btn { background: ", print_btn_color, "; color: white; border: none; padding: 15px 30px; ",
      "font-size: 16px; border-radius: 8px; cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.3); }",
      ".print-btn:hover { background: ", print_btn_hover, "; }",
      "</style>",
      "</head><body>",
      gsub(".*<body>|</body>.*", "", html_content),
      "<div class='print-section no-print'>",
      "<button class='print-btn' onclick='window.print()'>Imprimir / Guardar PDF</button>",
      "</div>",
      "</body></html>"
    )

    # Write to www/ with unique filename
    filename <- paste0(prefix, "_", format(Sys.time(), "%Y%m%d%H%M%S"), "_",
                       sample(1000:9999, 1), ".html")
    filepath <- file.path("www", filename)
    writeLines(html_with_print, filepath)
    session_temp_files <<- c(session_temp_files, filepath)

    # Open in new browser tab
    shinyjs::runjs(paste0("window.open('", filename, "', '_blank');"))
  }

  # Ver documento tecnico
  observeEvent(input$ver_tecnico, {
    req(resultados())
    html_content <- generate_technical_report(resultados())
    open_report_in_tab(html_content, "tecnico", "#0f766e", "#0d9488")
  })

  # Ver resumen ejecutivo
  observeEvent(input$ver_resumen, {
    req(resultados())
    html_content <- generate_summary_report(resultados())
    open_report_in_tab(html_content, "resumen", "#db2777", "#ec4899")
  })

  # Ver reporte basico
  observeEvent(input$ver_reporte, {
    req(resultados())
    html_content <- generate_basic_report(resultados())
    open_report_in_tab(html_content, "reporte", "#0f766e", "#0d9488")
  })

  # Ver metodologia
  observeEvent(input$ver_metodologia, {
    html_content <- generate_methodology_html()
    open_report_in_tab(html_content, "metodologia", "#0f766e", "#0d9488")
  })

  # Nueva simulacion button - goes back to landing page
  observeEvent(input$nueva_simulacion, {
    shinyjs::hide("step4_panel")
    shinyjs::show("step1_panel")
    shinyjs::hide("wizard_mode")
    shinyjs::show("landing_page")
    current_step(1)
    update_wizard_indicators(1)
    resultados(NULL)
  })

}

# ============================================================================
# EJECUTAR APLICACION
# ============================================================================

shinyApp(ui = ui, server = server)
