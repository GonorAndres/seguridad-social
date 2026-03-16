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
    tags$meta(name = "description", content = "Simulador de pensión IMSS. Calcula tu pensión de Ley 73, Ley 97 y Fondo Bienestar en 5 minutos."),
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

      // Handle regime override toggle
      $(document).on('click', '#toggle_override', function(e) {
        e.preventDefault();
        var container = $('#regimen_override_container');
        if (container.is(':hidden')) {
          container.slideDown(200);
          $(this).find('span').text('Usar fecha automatica');
          Shiny.setInputValue('regimen_override_active', true);
        } else {
          container.slideUp(200);
          $(this).find('span').text('No es correcto? Corregir');
          Shiny.setInputValue('regimen_override_active', false, {priority: 'event'});
        }
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
        if (event.name === 'result_cards_frozen') {
          var btn = $('#calcular');
          btn.prop('disabled', false);
          btn.html('<i class=\"bi bi-calculator me-2\"></i>Calcular pensión');
        }
      });

      // Smooth scroll to top of results
      $(document).on('shiny:value', function(event) {
        if (event.name === 'result_cards_frozen') {
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
        tags$h1(class = "app-title", "Simulador de Pensión IMSS"),
        tags$p(
          class = "app-subtitle",
          "Conoce tu pensión. Actúa donde puedas."
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
                    help_tooltip("Tu fecha de nacimiento determina tu edad actual y años restantes al retiro")
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
                    "Género",
                    help_tooltip("Afecta la esperanza de vida usada en los cálculos de pensión")
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
                    help_tooltip("Entre 60 y 70 años. A los 65 tienes acceso al Fondo Bienestar")
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
                    "El Fondo Bienestar requiere 65 años mínimo"
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

              # Regimen - auto-detected from start date
              fluidRow(
                column(6,
                  dateInput(
                    "fecha_inicio_cotizacion",
                    label = tagList(
                      "Cuando empezaste a cotizar en el IMSS?",
                      help_tooltip("Fecha aproximada de tu primer empleo formal. Determina automáticamente tu régimen de pensión.")
                    ),
                    value = NULL,
                    min = "1950-01-01",
                    max = Sys.Date(),
                    format = "dd/mm/yyyy",
                    language = "es"
                  )
                ),
                column(6,
                  tags$div(
                    class = "mt-4 pt-1",
                    uiOutput("regimen_badge"),
                    tags$div(
                      id = "regimen_override_container",
                      style = "display: none;",
                      selectInput("regimen_manual", label = NULL,
                        choices = c("Ley 73 (antes julio 1997)" = "ley73",
                                    "Ley 97 (después julio 1997)" = "ley97"),
                        selected = "ley97"
                      )
                    )
                  )
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
                  ),
                  tags$a(
                    id = "estimar_semanas_link",
                    href = "#",
                    class = "form-text text-decoration-none d-block mt-1",
                    tags$i(class = "bi bi-calculator me-1"),
                    "Estimar con mi fecha de inicio"
                  ),
                  tags$small(
                    id = "semanas_estimate_text",
                    class = "form-text d-none",
                    ""
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

              # Info note for Ley 73 users (hidden by default)
              shinyjs::hidden(
                tags$div(
                  id = "ley73_afore_note",
                  class = "alert alert-info mb-4",
                  tags$i(class = "bi bi-info-circle"),
                  tags$div(
                    tags$strong("Ley 73: "),
                    "Tu pensión principal se calcula por fórmula (Art. 167), no por saldo AFORE. ",
                    "Sin embargo, si tienes saldo acumulado en tu AFORE, puedes retirarlo como complemento."
                  )
                )
              ),

              tags$div(
                id = "afore_fields_container",

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
                        "Aportación voluntaria mensual",
                        help_tooltip("Dinero adicional que TU decides aportar. Es la mejor herramienta para mejorar tu pensión")
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
                tagList(tags$i(class = "bi bi-calculator me-2"), "Calcular pensión"),
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
              tags$h4(class = "card-title mb-0", "Tu Pensión Estimada")
            ),

            tags$div(
              class = "card-body",

              # Results: Hero + Breakdown + Fondo status (FROZEN -- shows original)
              uiOutput("result_cards_frozen"),

              # Separador
              tags$hr(class = "my-4"),

              # Seccion: Explora tus opciones
              tags$div(
                class = "sensitivity-intro",
                tags$h5(
                  class = "sensitivity-title",
                  tags$i(class = "bi bi-sliders me-2"),
                  "Explora tus opciones"
                ),
                tags$p(
                  class = "sensitivity-subtitle",
                  "Mueve los controles para ver cómo cada cambio afecta tu pensión. ",
                  "El impacto se muestra debajo de cada control."
                )
              ),

              # Grid layout: antes/despues + sliders LEFT, chart RIGHT
              tags$div(
                class = "sensitivity-layout",

                # GRID AREA: antes-despues (row 0, col 0)
                tags$div(
                  class = "sensitivity-antes-despues",
                  uiOutput("antes_despues_box")
                ),

                # GRID AREA: sliders (row 1+, col 0)
                tags$div(
                  class = "sensitivity-sliders",

                  # Slider: Salario
                  tags$div(
                    class = "slider-container",
                    tags$div(
                      class = "slider-label",
                      tags$span(class = "label-text", "Salario mensual"),
                      tags$span(class = "label-value", id = "salario_value", "$20,000/mes")
                    ),
                    sliderInput(
                      "slider_salario",
                      label = NULL,
                      min = 5000,
                      max = 100000,
                      value = 20000,
                      step = 1000,
                      ticks = FALSE
                    ),
                    tags$div(class = "slider-impact", id = "salario_impact", "")
                  ),

                  # Slider: Voluntaria (hidden for Ley 73)
                  tags$div(id = "vol_slider_col",
                    tags$div(
                      class = "slider-container",
                      tags$div(
                        class = "slider-label",
                        tags$span(class = "label-text", "Aportación voluntaria"),
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
                      tags$div(class = "slider-impact", id = "vol_impact", "")
                    )
                  ),

                  # Slider: Edad de retiro
                  tags$div(
                    class = "slider-container",
                    tags$div(
                      class = "slider-label",
                      tags$span(class = "label-text", "Edad de retiro"),
                      tags$span(class = "label-value", id = "age_value", "65 años")
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
                  ),

                  # Slider: Semanas cotizadas
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
                  ),

                  # AFORE selector (hidden for Ley 73)
                  tags$div(id = "afore_slider_row",
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
                  ),

                  # Note for Ley 73 (hidden for Ley 97)
                  tags$div(
                    id = "ley73_sensitivity_note",
                    class = "ley73-sensitivity-note",
                    style = "display: none;",
                    tags$i(class = "bi bi-info-circle me-2"),
                    "Tu pensión Ley 73 se calcula por fórmula (Art. 167), no por saldo AFORE. ",
                    "Las aportaciones voluntarias y la AFORE no afectan tu pensión principal."
                  )
                ),

                # GRID AREA: chart (rows 0-1, col 1)
                tags$div(
                  class = "sensitivity-chart",

                  # Grafico de proyeccion
                  tags$div(
                    class = "chart-container",
                    tags$h6(class = "chart-title", "Proyección de tu saldo"),
                    plotly::plotlyOutput("proyeccion_chart", height = "350px")
                  ),

                  # Key message
                  key_message(
                    "Recuerda: ",
                    tags$strong("tus aportaciones voluntarias son la parte más segura"),
                    " de tu pensión. El Fondo Bienestar puede ayudar, pero su futuro es incierto."
                  )
                )
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
                      "Panel Técnico (supuestos y fórmulas)"
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
                tagList(tags$i(class = "bi bi-arrow-clockwise me-2"), "Nueva simulación"),
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
            tags$strong("estimación educativa"),
            ", no una garantía. Las leyes y políticas pueden cambiar."
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
  if (dir.exists("docs")) addResourcePath("docs", "docs")

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

  # Track previous eligibility state for cliff notifications
  prev_fondo_eligible <- reactiveVal(NULL)
  prev_aplico_minimo <- reactiveVal(NULL)

  # Track whether user manually edited fecha_inicio_cotizacion
  fecha_cotizacion_user_edited <- reactiveVal(FALSE)

  # Track whether regime override is active
  regimen_override_active_val <- reactiveVal(FALSE)

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
      showNotification("Debes tener al menos 18 años", type = "error")
      return()
    }

    # Validate retirement age is in valid range (explicit checks)
    if (is.na(input$edad_retiro) || input$edad_retiro < 60) {
      showNotification("La edad de retiro mínima es 60 años", type = "error")
      return()
    }
    if (input$edad_retiro > 70) {
      showNotification("La edad de retiro máxima es 70 años", type = "error")
      return()
    }

    # Validate retirement is in the future
    if (edad_actual >= input$edad_retiro) {
      showNotification(
        paste0("Tu edad actual (", floor(edad_actual), " años) ya supera o iguala la edad de retiro. ",
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
    if (input$salario_mensual < SALARIO_MINIMO_INPUT) {
      showNotification("El salario debe ser al menos $1,000 MXN", type = "error")
      return()
    }

    # Validate weeks are not negative
    if (is.na(input$semanas_cotizadas) || input$semanas_cotizadas < 0) {
      showNotification("Las semanas cotizadas no pueden ser negativas", type = "error")
      return()
    }

    # Validate fecha_inicio_cotizacion
    if (is.null(input$fecha_inicio_cotizacion) || is.na(input$fecha_inicio_cotizacion)) {
      showNotification("Por favor ingresa tu fecha de inicio de cotizacion", type = "error")
      return()
    }
    if (input$fecha_inicio_cotizacion > Sys.Date()) {
      showNotification("La fecha de inicio de cotizacion no puede ser futura", type = "error")
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

  # ==========================================================================
  # AUTO-FILL START DATE FROM BIRTH DATE
  # ==========================================================================

  observeEvent(input$fecha_nacimiento, {
    req(input$fecha_nacimiento)
    if (!fecha_cotizacion_user_edited()) {
      default_start <- input$fecha_nacimiento + as.difftime(18 * 365.25, units = "days")
      default_start <- max(as.Date("1950-01-01"), min(as.Date(default_start), Sys.Date()))
      updateDateInput(session, "fecha_inicio_cotizacion", value = default_start)
    }
  }, ignoreInit = FALSE)

  # ==========================================================================
  # AUTO-DETERMINE REGIME FROM START DATE + track manual edits
  # ==========================================================================

  observeEvent(input$fecha_inicio_cotizacion, {
    if (current_step() >= 2) fecha_cotizacion_user_edited(TRUE)
    req(input$fecha_inicio_cotizacion)
    if (!regimen_override_active_val()) {
      nuevo <- determinar_regimen(input$fecha_inicio_cotizacion)
      regimen_actual(nuevo)
      updateSelectInput(session, "regimen_manual", selected = nuevo)
    }
    # Cross-validate age at start
    if (!is.null(input$fecha_nacimiento) && !is.na(input$fecha_nacimiento)) {
      check <- validar_consistencia_fechas(input$fecha_nacimiento, input$fecha_inicio_cotizacion)
      if (!check$is_consistent) {
        showNotification(check$message, type = "warning", duration = 8)
      }
    }
  }, ignoreInit = TRUE)

  # Override toggle activation
  observeEvent(input$regimen_override_active, {
    regimen_override_active_val(isTRUE(input$regimen_override_active))
    if (!isTRUE(input$regimen_override_active)) {
      req(input$fecha_inicio_cotizacion)
      regimen_actual(determinar_regimen(input$fecha_inicio_cotizacion))
    }
  })

  # Manual regime selection when override is active
  observeEvent(input$regimen_manual, {
    if (regimen_override_active_val()) regimen_actual(input$regimen_manual)
  }, ignoreInit = TRUE)

  # ==========================================================================
  # REGIME BADGE
  # ==========================================================================

  output$regimen_badge <- renderUI({
    req(regimen_actual())
    if (regimen_actual() == "ley73") {
      badge_class <- "regime-badge ley73"
      icon <- "bi-shield-check"
      text <- "Ley 73"
      desc <- "Pensión definida"
    } else {
      badge_class <- "regime-badge ley97"
      icon <- "bi-piggy-bank"
      text <- "Ley 97"
      desc <- "Cuenta individual AFORE"
    }
    tagList(
      tags$div(class = badge_class,
        tags$i(class = paste("bi", icon, "me-2")),
        tags$strong(text),
        tags$span(class = "regime-desc", paste0(" - ", desc))
      ),
      tags$a(id = "toggle_override", href = "#",
        class = "form-text text-decoration-none d-block mt-1",
        tags$small(tags$i(class = "bi bi-pencil me-1"),
          tags$span("No es correcto? Corregir"))
      )
    )
  })

  # ==========================================================================
  # SEMANAS ESTIMATION FROM START DATE
  # ==========================================================================

  shinyjs::onclick("estimar_semanas_link", {
    req(input$fecha_inicio_cotizacion)
    years_working <- as.numeric(difftime(Sys.Date(), input$fecha_inicio_cotizacion, units = "days")) / 365.25
    if (years_working > 0) {
      estimated <- round(years_working * SEMANAS_POR_ANO * DENSIDAD_COTIZACION_DEFAULT)
      updateNumericInput(session, "semanas_cotizadas", value = estimated)
      shinyjs::removeClass("semanas_estimate_text", "d-none")
      shinyjs::html("semanas_estimate_text",
        paste0("Estimado: ~", estimated, " semanas (",
               round(years_working, 1), " años x 60% cotizando). Ajusta según tu caso."))
    }
  })

  # ==========================================================================
  # STEP 3 DIMMING FOR LEY 73
  # ==========================================================================

  observe({
    req(regimen_actual())
    if (regimen_actual() == "ley73") {
      shinyjs::addClass("afore_fields_container", "dimmed-fields")
      shinyjs::show("ley73_afore_note")
    } else {
      shinyjs::removeClass("afore_fields_container", "dimmed-fields")
      shinyjs::hide("ley73_afore_note")
    }
  })

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
      showNotification("La aportación voluntaria no puede ser negativa", type = "error")
      return()
    }

    # Calcular edad actual
    edad_actual <- as.numeric(difftime(Sys.Date(), input$fecha_nacimiento, units = "days")) / 365.25

    # Determinar regimen
    regimen <- regimen_actual()

    # Realizar calculo
    if (regimen == "ley73") {
      # Calcular pension Ley 73
      sbc_diario <- input$salario_mensual / DIAS_POR_MES
      anios_restantes <- max(0, input$edad_retiro - floor(edad_actual))
      semanas_al_retiro <- input$semanas_cotizadas + (anios_restantes * SEMANAS_POR_ANO)

      resultado_base <- calculate_ley73_pension(
        sbc_promedio_diario = sbc_diario,
        semanas = semanas_al_retiro,
        edad = input$edad_retiro
      )

      # Simular Modalidad 40 si aplica
      resultado_m40 <- NULL
      if (resultado_base$elegible && anios_restantes > 0) {
        semanas_m40 <- min(anios_restantes * SEMANAS_POR_ANO, MAX_SEMANAS_M40)
        resultado_m40 <- calculate_modalidad_40(
          pension_actual = resultado_base,
          sbc_actual = sbc_diario,
          sbc_m40 = TOPE_SBC_DIARIO * FACTOR_SBC_M40,
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
          genero = input$genero,
          fecha_inicio_cotizacion = input$fecha_inicio_cotizacion
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

    # Initialize cliff notification trackers
    if (res$regimen == "ley97") {
      prev_fondo_eligible(res$con_fondo$elegible)
      prev_aplico_minimo(res$solo_sistema$aplico_minimo %||% FALSE)
    } else {
      prev_fondo_eligible(NULL)
      prev_aplico_minimo(res$pension_base$aplico_minimo %||% FALSE)
    }

    # Actualizar sliders con valores iniciales
    updateSliderInput(session, "slider_salario", value = input$salario_mensual)
    updateSliderInput(session, "slider_voluntaria", value = input$aportacion_voluntaria)
    updateSliderInput(session, "slider_edad", value = input$edad_retiro)
    updateSliderInput(session, "slider_semanas", value = input$semanas_cotizadas)

    # Show/hide sensitivity elements based on regime
    if (regimen == "ley73") {
      shinyjs::hide("vol_slider_col")
      shinyjs::hide("afore_slider_row")
      shinyjs::show("ley73_sensitivity_note")
    } else {
      shinyjs::show("vol_slider_col")
      shinyjs::show("afore_slider_row")
      shinyjs::hide("ley73_sensitivity_note")
    }

    # Mostrar resultados
    shinyjs::hide("step3_panel")
    shinyjs::show("step4_panel")
    current_step(4)
    update_wizard_indicators(4)
  })

  # ==========================================================================
  # RENDERIZADO DE RESULTADOS
  # ==========================================================================

  # Results: Hero + Breakdown (FROZEN -- uses original results, not slider-modified)
  output$result_cards_frozen <- renderUI({
    req(resultados_originales())
    res <- resultados_originales()

    if (res$regimen == "ley73") {
      render_results_hero_ley73(res)
    } else {
      render_results_hero(res)
    }
  })

  # Antes / Despues comparison box (updates with slider changes)
  output$antes_despues_box <- renderUI({
    req(resultados(), resultados_originales())
    render_antes_despues_box(resultados_originales(), resultados())
  })

  # Fondo message and encouragement are now integrated into result_cards hero component

  # ==========================================================================
  # ANALISIS DE SENSIBILIDAD (con debounce)
  # ==========================================================================

  # Debounced values
  vol_debounced <- reactive({ input$slider_voluntaria }) |> debounce(300)
  edad_debounced <- reactive({ input$slider_edad }) |> debounce(300)
  semanas_debounced <- reactive({ input$slider_semanas }) |> debounce(300)
  afore_debounced <- reactive({ input$afore_comparar }) |> debounce(300)
  salario_debounced <- reactive({ input$slider_salario }) |> debounce(300)

  # Actualizar etiquetas de sliders (only when inputs exist)
  observe({
    req(input$slider_salario)
    shinyjs::html("salario_value", paste0("$", format(input$slider_salario, big.mark = ","), "/mes"))
  })

  observe({
    req(input$slider_voluntaria)
    shinyjs::html("vol_value", paste0("$", format(input$slider_voluntaria, big.mark = ","), "/mes"))
  })

  observe({
    req(input$slider_edad)
    shinyjs::html("age_value", paste0(input$slider_edad, " años"))
  })

  observe({
    req(input$slider_semanas)
    shinyjs::html("semanas_value", format(input$slider_semanas, big.mark = ","))
  })

  # ==========================================================================
  # RECALCULO UNIFICADO -- actualiza resultados() con valores de sliders
  # ==========================================================================
  observe({
    req(resultados_originales())
    res_orig <- resultados_originales()

    vol_actual <- vol_debounced() %||% res_orig$entrada$aportacion_voluntaria %||% 0
    edad_slider <- edad_debounced() %||% res_orig$entrada$edad_retiro
    semanas_slider <- semanas_debounced() %||% res_orig$entrada$semanas_actuales
    afore_actual <- afore_debounced() %||% res_orig$entrada$afore %||% "XXI Banorte"
    salario_slider <- salario_debounced() %||% res_orig$entrada$salario_mensual

    if (res_orig$regimen == "ley97") {
      tryCatch({
        res <- calculate_pension_with_fondo(
          saldo_actual = res_orig$entrada$saldo_actual,
          salario_mensual = salario_slider,
          edad_actual = res_orig$entrada$edad_actual,
          edad_retiro = edad_slider,
          semanas_actuales = semanas_slider,
          genero = res_orig$entrada$genero %||% "M",
          aportacion_voluntaria = vol_actual,
          afore_nombre = afore_actual,
          escenario = res_orig$entrada$escenario %||% "base"
        )
        res$regimen <- "ley97"
        res$fondo_aplica <- TRUE

        # Cliff notifications for Fondo eligibility
        prev_eligible <- isolate(prev_fondo_eligible())
        new_eligible <- res$con_fondo$elegible
        if (!is.null(prev_eligible) && prev_eligible != new_eligible) {
          if (!new_eligible) {
            showNotification(
              "Con estos cambios pierdes la elegibilidad para el Fondo de Bienestar",
              type = "warning", duration = 5
            )
          } else {
            showNotification(
              "Con estos cambios recuperas elegibilidad para el Fondo de Bienestar",
              type = "message", duration = 5
            )
          }
        }
        prev_fondo_eligible(new_eligible)

        # Cliff notifications for pension minima
        prev_minimo <- isolate(prev_aplico_minimo())
        new_minimo <- res$solo_sistema$aplico_minimo %||% FALSE
        if (!is.null(prev_minimo) && prev_minimo != new_minimo) {
          if (new_minimo) {
            showNotification(
              "Tu pensión ahora aplica el piso mínimo garantizado",
              type = "warning", duration = 5
            )
          }
        }
        prev_aplico_minimo(new_minimo)

        resultados(res)
      }, error = function(e) {
        message("[Sensitivity] Recalculation error: ", e$message)
        showNotification("Error en recálculo de sensibilidad", type = "warning", duration = 5)
        NULL
      })
    } else {
      tryCatch({
        sbc_diario <- salario_slider / DIAS_POR_MES
        anios_restantes <- max(0, edad_slider - res_orig$entrada$edad_actual)
        semanas_al_retiro <- semanas_slider + (anios_restantes * SEMANAS_POR_ANO)

        resultado_base <- calculate_ley73_pension(
          sbc_promedio_diario = sbc_diario,
          semanas = semanas_al_retiro,
          edad = edad_slider
        )

        resultado_m40 <- NULL
        if (resultado_base$elegible && anios_restantes > 0) {
          semanas_m40 <- min(anios_restantes * SEMANAS_POR_ANO, MAX_SEMANAS_M40)
          resultado_m40 <- calculate_modalidad_40(
            pension_actual = resultado_base,
            sbc_actual = sbc_diario,
            sbc_m40 = TOPE_SBC_DIARIO * FACTOR_SBC_M40,
            semanas_actuales = semanas_al_retiro - semanas_m40,
            semanas_m40 = semanas_m40,
            edad_actual = res_orig$entrada$edad_actual,
            edad_retiro = edad_slider
          )
        }

        res <- list(
          regimen = "ley73",
          pension_base = resultado_base,
          pension_m40 = resultado_m40,
          fondo_aplica = FALSE,
          entrada = list(
            salario_mensual = salario_slider,
            edad_actual = res_orig$entrada$edad_actual,
            edad_retiro = edad_slider,
            semanas_actuales = semanas_slider,
            genero = res_orig$entrada$genero
          )
        )
        resultados(res)
      }, error = function(e) {
        message("[Sensitivity] Recalculation error: ", e$message)
        showNotification("Error en recálculo de sensibilidad", type = "warning", duration = 5)
        NULL
      })
    }
  })

  # Calcular impacto de voluntarias
  observe({
    req(resultados_originales(), vol_debounced())
    res <- resultados_originales()

    if (vol_debounced() == (res$entrada$aportacion_voluntaria %||% 0)) {
      shinyjs::html("vol_impact", "")
      return()
    }

    if (res$regimen == "ley97") {
      tryCatch({
        shinyjs::removeClass(selector = "#vol_impact", class = "positive")
        shinyjs::removeClass(selector = "#vol_impact", class = "negative")

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

        pension_orig <- unname(res$solo_sistema$pension_mensual)
        pension_new <- unname(nuevo$con_acciones$pension_afore %||% nuevo$solo_sistema$pension_mensual)
        diferencia <- pension_new - pension_orig

        if (!is.null(diferencia) && length(diferencia) > 0 && diferencia != 0) {
          signo <- if (diferencia > 0) "+" else ""
          clase <- if (diferencia > 0) "positive" else "negative"
          shinyjs::html("vol_impact", paste0(
            format_currency(pension_orig), " &rarr; ",
            format_currency(pension_new), "/mes (",
            signo, format_currency(diferencia), ")"
          ))
          shinyjs::addClass(selector = "#vol_impact", class = clase)
        } else {
          shinyjs::html("vol_impact", "")
        }
      }, error = function(e) {
        message("[Impact] Error calculating voluntary impact: ", e$message)
        shinyjs::html("vol_impact", "")
      })
    }
  })

  # Calcular impacto de edad de retiro
  observe({
    req(resultados_originales(), edad_debounced())
    res <- resultados_originales()
    edad_slider <- edad_debounced()

    # Skip if same as original
    if (edad_slider == res$entrada$edad_retiro) {
      shinyjs::html("age_impact", "")
      return()
    }

    tryCatch({
      shinyjs::removeClass(selector = "#age_impact", class = "positive")
      shinyjs::removeClass(selector = "#age_impact", class = "negative")

      if (res$regimen == "ley97") {
        pension_orig <- unname(res$solo_sistema$pension_mensual)
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
        pension_new <- unname(nuevo$solo_sistema$pension_mensual)
        diferencia <- pension_new - pension_orig
      } else {
        pension_orig <- unname(res$pension_base$pension_mensual)
        # Ley 73: recalcular con nueva edad
        sbc_diario <- res$entrada$salario_mensual / DIAS_POR_MES
        anios_restantes <- max(0, edad_slider - res$entrada$edad_actual)
        semanas_al_retiro <- res$entrada$semanas_actuales + (anios_restantes * SEMANAS_POR_ANO)

        nuevo <- calculate_ley73_pension(
          sbc_promedio_diario = sbc_diario,
          semanas = semanas_al_retiro,
          edad = edad_slider
        )
        pension_new <- unname(nuevo$pension_mensual)
        diferencia <- pension_new - pension_orig
      }

      if (!is.null(diferencia) && length(diferencia) > 0 && diferencia != 0) {
        signo <- if (diferencia > 0) "+" else ""
        clase <- if (diferencia > 0) "positive" else "negative"
        shinyjs::html("age_impact", paste0(
          format_currency(pension_orig), " &rarr; ",
          format_currency(pension_new), "/mes (",
          signo, format_currency(diferencia), ")"
        ))
        shinyjs::addClass(selector = "#age_impact", class = clase)
      } else {
        shinyjs::html("age_impact", "")
      }
    }, error = function(e) {
      message("[Impact] Error calculating age impact: ", e$message)
      shinyjs::html("age_impact", "")
    })
  })

  # Calcular impacto de cambio de AFORE
  observe({
    req(resultados_originales(), input$afore_comparar)
    res <- resultados_originales()

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
      shinyjs::removeClass(selector = "#afore_impact", class = "positive")
      shinyjs::removeClass(selector = "#afore_impact", class = "negative")

      pension_orig <- unname(res$solo_sistema$pension_mensual)

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

      pension_new <- unname(nuevo$solo_sistema$pension_mensual)
      dif_pension <- pension_new - pension_orig
      dif_saldo <- (nuevo$solo_sistema$saldo_proyectado %||% 0) -
                   (res$solo_sistema$saldo_proyectado %||% 0)

      if (!is.null(dif_pension) && dif_pension != 0) {
        signo <- if (dif_pension > 0) "+" else ""
        clase <- if (dif_pension > 0) "positive" else "negative"
        shinyjs::html("afore_impact", paste0(
          format_currency(pension_orig), " &rarr; ",
          format_currency(pension_new), "/mes (",
          signo, format_currency(dif_pension), ")"
        ))
        shinyjs::addClass(selector = "#afore_impact", class = clase)
      } else if (!is.null(dif_saldo) && abs(dif_saldo) > 0) {
        signo <- if (dif_saldo > 0) "+" else ""
        clase <- if (dif_saldo > 0) "positive" else "negative"
        shinyjs::html("afore_impact",
          paste0(signo, format_currency(dif_saldo), " en saldo al retiro"))
        shinyjs::addClass(selector = "#afore_impact", class = clase)
      } else {
        shinyjs::html("afore_impact", "Comisiones similares, impacto mínimo")
      }
    }, error = function(e) {
      message("[Impact] Error calculating AFORE impact: ", e$message)
      shinyjs::html("afore_impact", "")
    })
  })

  # Calcular impacto de semanas cotizadas
  observe({
    req(resultados_originales(), semanas_debounced())
    res <- resultados_originales()
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
        pension_orig <- unname(res$solo_sistema$pension_mensual)
        # Ley 97: semanas affect eligibility, not AFORE balance directly
        anios_restantes <- max(0, res$entrada$edad_retiro - res$entrada$edad_actual)
        nuevo_semanas_retiro <- semanas_slider + (anios_restantes * SEMANAS_POR_ANO)

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

        pension_new <- unname(nuevo$solo_sistema$pension_mensual)
        dif_pension <- pension_new - pension_orig

        if (dif_pension != 0) {
          signo <- if (dif_pension > 0) "+" else ""
          clase <- if (dif_pension > 0) "positive" else "negative"
          shinyjs::html("semanas_impact", paste0(
            format_currency(pension_orig), " &rarr; ",
            format_currency(pension_new), "/mes (",
            signo, format_currency(dif_pension), ")"
          ))
          shinyjs::addClass(selector = "#semanas_impact", class = clase)
        } else if (nuevo$con_fondo$elegible != res$con_fondo$elegible) {
          if (nuevo$con_fondo$elegible) {
            shinyjs::html("semanas_impact", "Elegible para Fondo Bienestar")
            shinyjs::addClass(selector = "#semanas_impact", class = "positive")
          } else {
            shinyjs::html("semanas_impact", "No elegible para Fondo")
            shinyjs::addClass(selector = "#semanas_impact", class = "negative")
          }
        } else {
          shinyjs::html("semanas_impact",
            paste0(format(nuevo_semanas_retiro, big.mark = ","), " sem. al retiro"))
        }

      } else {
        pension_orig <- unname(res$pension_base$pension_mensual)
        # Ley 73: semanas directly affect pension via Art. 167
        sbc_diario <- res$entrada$salario_mensual / DIAS_POR_MES
        anios_restantes <- max(0, res$entrada$edad_retiro - res$entrada$edad_actual)
        semanas_al_retiro <- semanas_slider + (anios_restantes * SEMANAS_POR_ANO)

        nuevo <- calculate_ley73_pension(
          sbc_promedio_diario = sbc_diario,
          semanas = semanas_al_retiro,
          edad = res$entrada$edad_retiro
        )
        pension_new <- unname(nuevo$pension_mensual)
        diferencia <- pension_new - pension_orig

        if (!is.null(diferencia) && length(diferencia) > 0 && diferencia != 0) {
          signo <- if (diferencia > 0) "+" else ""
          clase <- if (diferencia > 0) "positive" else "negative"
          shinyjs::html("semanas_impact", paste0(
            format_currency(pension_orig), " &rarr; ",
            format_currency(pension_new), "/mes (",
            signo, format_currency(diferencia), ")"
          ))
          shinyjs::addClass(selector = "#semanas_impact", class = clase)
        } else {
          shinyjs::html("semanas_impact", "")
        }
      }
    }, error = function(e) {
      message("[Impact] Error calculating semanas impact: ", e$message)
      shinyjs::html("semanas_impact", "")
    })
  })

  # Calcular impacto de salario
  observe({
    req(resultados_originales(), salario_debounced())
    res <- resultados_originales()
    salario_slider <- salario_debounced()

    if (salario_slider == res$entrada$salario_mensual) {
      shinyjs::html("salario_impact", "")
      return()
    }

    tryCatch({
      shinyjs::removeClass(selector = "#salario_impact", class = "positive")
      shinyjs::removeClass(selector = "#salario_impact", class = "negative")

      if (res$regimen == "ley97") {
        pension_orig <- unname(res$solo_sistema$pension_mensual)
        nuevo <- calculate_pension_with_fondo(
          saldo_actual = res$entrada$saldo_actual,
          salario_mensual = salario_slider,
          edad_actual = res$entrada$edad_actual,
          edad_retiro = res$entrada$edad_retiro,
          semanas_actuales = res$entrada$semanas_actuales,
          genero = res$entrada$genero %||% "M",
          aportacion_voluntaria = 0,
          afore_nombre = res$entrada$afore %||% "XXI Banorte",
          escenario = res$entrada$escenario %||% "base"
        )
        pension_new <- unname(nuevo$solo_sistema$pension_mensual)
        diferencia <- pension_new - pension_orig
      } else {
        pension_orig <- unname(res$pension_base$pension_mensual)
        sbc_diario <- salario_slider / DIAS_POR_MES
        anios_restantes <- max(0, res$entrada$edad_retiro - res$entrada$edad_actual)
        semanas_al_retiro <- res$entrada$semanas_actuales + (anios_restantes * SEMANAS_POR_ANO)
        nuevo <- calculate_ley73_pension(
          sbc_promedio_diario = sbc_diario,
          semanas = semanas_al_retiro,
          edad = res$entrada$edad_retiro
        )
        pension_new <- unname(nuevo$pension_mensual)
        diferencia <- pension_new - pension_orig
      }

      if (!is.null(diferencia) && length(diferencia) > 0 && diferencia != 0) {
        signo <- if (diferencia > 0) "+" else ""
        clase <- if (diferencia > 0) "positive" else "negative"
        shinyjs::html("salario_impact", paste0(
          format_currency(pension_orig), " &rarr; ",
          format_currency(pension_new), "/mes (",
          signo, format_currency(diferencia), ")"
        ))
        shinyjs::addClass(selector = "#salario_impact", class = clase)
      } else {
        shinyjs::html("salario_impact", "")
      }
    }, error = function(e) {
      message("[Impact] Error calculating salary impact: ", e$message)
      shinyjs::html("salario_impact", "")
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
    req(resultados(), resultados_originales())
    res <- resultados()
    res_orig <- resultados_originales()

    if (res$regimen == "ley73") {
      # Ley 73: bar chart with 3 color states
      edad_mostrar <- max(60, min(70, res$entrada$edad_retiro))
      edad_original <- res_orig$entrada$edad_retiro

      # Extend chart to cover ages 60 through max(65, retirement age)
      edad_max_chart <- max(65, edad_mostrar)
      edades <- 60:edad_max_chart
      factores <- sapply(edades, function(e) {
        if (e <= 65) unname(FACTORES_CESANTIA[as.character(e)])
        else 1.0  # Full vejez pension at 66+
      })

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
          title = list(text = "Factor de Cesantía por Edad de Retiro", x = 0.5),
          xaxis = list(
            title = "Edad de retiro",
            tickvals = 60:65,
            dtick = 1
          ),
          yaxis = list(
            title = "Pensión mensual estimada",
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

      # Trace 2: With changes (current slider values, no voluntary) - dashed teal
      tray_cambios <- res$solo_sistema$trayectoria

      # Trace 3: With changes + voluntary contributions - solid teal
      tray_vol <- res$con_acciones$trayectoria

      plot_ly() |>
        add_trace(
          x = tray_orig$anio,
          y = tray_orig$saldo,
          type = "scatter",
          mode = "lines",
          name = "Cálculo original",
          line = list(color = "#c4a67a", dash = "dot", width = 2),
          hovertemplate = "Año %{x}: $%{y:,.0f}<extra></extra>"
        ) |>
        add_trace(
          x = tray_cambios$anio,
          y = tray_cambios$saldo,
          type = "scatter",
          mode = "lines",
          name = "Con cambios",
          line = list(color = "#0f766e", dash = "dash", width = 2),
          hovertemplate = "Año %{x}: $%{y:,.0f}<extra></extra>"
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
          hovertemplate = "Año %{x}: $%{y:,.0f}<extra></extra>"
        ) |>
        layout(
          xaxis = list(
            title = "Años hasta retiro",
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
            y = -0.25,
            font = list(size = 11)
          ),
          hovermode = "x unified",
          plot_bgcolor = "#fffbf0",
          paper_bgcolor = "#fffbf0",
          margin = list(t = 20, b = 80)
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
        tags$li(paste0("Régimen: ", if (res$regimen == "ley73") "Ley 73" else "Ley 97 (AFORE)")),
        tags$li(paste0("Rendimiento proyectado: ", rendimiento_texto)),
        if (res$regimen == "ley97") tags$li(paste0("AFORE: ", res$entrada$afore)),
        tags$li(paste0("Umbral Fondo Bienestar 2025: ", format_currency(UMBRAL_FONDO_BIENESTAR_2025))),
        tags$li(paste0("UMA diaria 2025: ", format_currency(UMA_DIARIA_2025))),
        tags$li(paste0("Salario mínimo 2025: ", format_currency(SM_DIARIO_2025), "/día"))
      ),

      tags$h6(class = "mt-3", "Fuentes de datos:"),
      tags$ul(
        tags$li("Tabla Articulo 167: Ley del Seguro Social 1973"),
        tags$li("UMA: INEGI / DOF"),
        tags$li("Salario mínimo: CONASAMI"),
        tags$li("Comisiones AFORE: CONSAR"),
        tags$li("Mortalidad: CONAPO / CNSF (simplificada)")
      ),

      tags$h6(class = "mt-3", "Limitaciones:"),
      tags$ul(
        tags$li("Esta es una estimación educativa, NO una garantía"),
        tags$li("Las leyes y políticas pueden cambiar"),
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
    tryCatch({
      html_content <- generate_technical_report(resultados())
      open_report_in_tab(html_content, "tecnico", "#0f766e", "#0d9488")
    }, error = function(e) {
      message("[Report] Error generating technical report: ", e$message)
      showNotification("Error al generar el reporte técnico", type = "error", duration = 5)
    })
  })

  # Ver resumen ejecutivo
  observeEvent(input$ver_resumen, {
    req(resultados())
    tryCatch({
      html_content <- generate_summary_report(resultados())
      open_report_in_tab(html_content, "resumen", "#db2777", "#ec4899")
    }, error = function(e) {
      message("[Report] Error generating summary report: ", e$message)
      showNotification("Error al generar el resumen ejecutivo", type = "error", duration = 5)
    })
  })

  # Ver reporte basico
  observeEvent(input$ver_reporte, {
    req(resultados())
    tryCatch({
      html_content <- generate_basic_report(resultados())
      open_report_in_tab(html_content, "reporte", "#0f766e", "#0d9488")
    }, error = function(e) {
      message("[Report] Error generating basic report: ", e$message)
      showNotification("Error al generar el reporte básico", type = "error", duration = 5)
    })
  })

  # Ver metodologia
  observeEvent(input$ver_metodologia, {
    tryCatch({
      html_content <- generate_methodology_html()
      open_report_in_tab(html_content, "metodologia", "#0f766e", "#0d9488")
    }, error = function(e) {
      message("[Report] Error generating methodology: ", e$message)
      showNotification("Error al generar la metodología", type = "error", duration = 5)
    })
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
