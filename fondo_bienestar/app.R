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
    tags$script(async = NA, src = "https://www.googletagmanager.com/gtag/js?id=G-098V02NCB0"),
    tags$script(HTML("window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','G-098V02NCB0');")),
    tags$script(HTML("!function(t,e){var o,n,p,r;e.__SV||(window.posthog=e,e._i=[],e.init=function(i,s,a){function g(t,e){var o=e.split('.');2==o.length&&(t=t[o[0]],e=o[1]),t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}}(p=t.createElement('script')).type='text/javascript',p.crossOrigin='anonymous',p.async=!0,p.src=s.api_host+'/static/array.js',(r=t.getElementsByTagName('script')[0]).parentNode.insertBefore(p,r);var u=e;for(void 0!==a?u=e[a]=[]:a='posthog',u.people=u.people||[],u.toString=function(t){var e='posthog';return'posthog'!==a&&(e+='.'+a),t||(e+=' (stub)'),e},u.people.toString=function(){return u.toString(1)+'.people (stub)'},o='init capture register register_once unregister opt_in_capturing opt_out_capturing has_opted_in_capturing has_opted_out_capturing identify alias people.set people.set_once set_config reset get_distinct_id getFeatureFlag getFeatureFlagPayload isFeatureEnabled reloadFeatureFlags group updateEarlyAccessFeatureEnrollment getEarlyAccessFeatures getActiveMatchingSurveys getSurveys onFeatureFlags onSessionId'.split(' '),n=0;n<o.length;n++)g(u,o[n]);e._i.push([i,s,a])},e.__SV=1)}(document,window.posthog||[]);posthog.init('phc_DYrSznvPeJuXPHgj2Nw9BIluiGdwkbuSSih3lu6PtmH',{api_host:'https://us.i.posthog.com',autocapture:false,capture_pageview:true});")),
    tags$meta(name = "description", content = "Simulador de pensión IMSS. Calcula tu pensión de Ley 73, Ley 97 y Fondo Bienestar en 5 minutos."),
    tags$link(
      rel = "stylesheet",
      href = "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css"
    ),
    tags$link(rel = "stylesheet", href = "styles.css"),
    # JavaScript for interactivity
    tags$script(HTML("
      // ============================================================
      // PostHog analytics helper (mirrors portafolio pattern)
      // ============================================================
      window.trackEvent = function(name, props) {
        try {
          if (typeof window.posthog !== 'undefined' && window.posthog && typeof window.posthog.capture === 'function') {
            var payload = Object.assign(
              { site: window.location.hostname, app: 'simulador-pension' },
              props || {}
            );
            window.posthog.capture(name, payload);
          }
        } catch (e) { console.warn('trackEvent error:', e); }
      };
      // Allow server-side triggering via Shiny.setInputValue('__track__', {...})
      if (typeof Shiny !== 'undefined') {
        Shiny.addCustomMessageHandler('track_event', function(msg) {
          window.trackEvent(msg.name, msg.props);
        });
      }

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
          window.trackEvent('regime_override_toggled', { state: 'on' });
        } else {
          container.slideUp(200);
          $(this).find('span').text('No es correcto? Corregir');
          Shiny.setInputValue('regimen_override_active', false, {priority: 'event'});
          window.trackEvent('regime_override_toggled', { state: 'off' });
        }
      });

      // Landing page interactions
      $(document).on('click', '#start_wizard, #start_wizard_from_context', function() {
        console.log('Starting wizard...');
        Shiny.setInputValue('start_wizard_click', Date.now());
        window.trackEvent('wizard_started', { from: this.id });
      });

      // Step navigation tracking (next/prev)
      $(document).on('click', '[id^=next_step], [id^=prev_step]', function() {
        var id = this.id;
        var direction = id.indexOf('next_') === 0 ? 'forward' : 'back';
        var m = id.match(/(\\d+)/);
        var step = m ? parseInt(m[1], 10) : null;
        window.trackEvent('step_nav', { direction: direction, from_step: step });
      });

      // External reference links (IMSS / CONSAR / CONASAMI / IMSS Digital)
      $(document).on('click', 'a[href*=\"imss.gob.mx\"], a[href*=\"consar.gob.mx\"], a[href*=\"gob.mx/conasami\"]', function() {
        var href = $(this).attr('href') || '';
        var target = 'other';
        if (href.indexOf('consar') > -1) target = 'consar';
        else if (href.indexOf('conasami') > -1) target = 'conasami';
        else if (href.indexOf('imss.gob.mx') > -1) target = 'imss';
        else if (href.indexOf('serviciosdigitales') > -1) target = 'imss_digital';
        window.trackEvent('external_link_clicked', { target: target, href: href });
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
                        choices = c("Ley 73 (antes julio 1997)" = REGIMEN_LEY73,
                                    "Ley 97 (después julio 1997)" = REGIMEN_LEY97),
                        selected = REGIMEN_LEY97
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
              ),

              # Zona salarial (General vs Libre Frontera Norte)
              fluidRow(
                column(12,
                  tags$div(
                    class = "mt-3",
                    tags$label(
                      class = "form-label",
                      "Zona salarial:",
                      help_tooltip("CONASAMI publica dos salarios minimos: zona General ($278.80/dia) y Zona Libre de la Frontera Norte ($419.88/dia). La ZLFN aplica si trabajas en municipios fronterizos con EEUU y afecta el piso de pension Ley 73.")
                    ),
                    radioButtons(
                      "zona_sm",
                      label = NULL,
                      choices = c("General" = "general", "Frontera Norte (ZLFN)" = "zlfn"),
                      selected = "general",
                      inline = TRUE
                    )
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
                        "Conservador (3% real)" = ESCENARIO_CONSERVADOR,
                        "Base (4% real)" = ESCENARIO_BASE,
                        "Optimista (5% real)" = ESCENARIO_OPTIMISTA
                      ),
                      selected = ESCENARIO_BASE
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
  regimen_actual <- reactiveVal(REGIMEN_LEY97)

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
    if (regimen_actual() == REGIMEN_LEY73) {
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
    if (regimen_actual() == REGIMEN_LEY73) {
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
    if (regimen == REGIMEN_LEY73) {
      # Calcular pension Ley 73
      sbc_diario <- input$salario_mensual / DIAS_POR_MES
      anios_restantes <- max(0, input$edad_retiro - floor(edad_actual))
      semanas_al_retiro <- input$semanas_cotizadas + (anios_restantes * SEMANAS_POR_ANO)

      zona_sel <- input$zona_sm %||% ZONA_GENERAL

      resultado_base <- calculate_ley73_pension(
        sbc_promedio_diario = sbc_diario,
        semanas = semanas_al_retiro,
        edad = input$edad_retiro,
        zona_sm = zona_sel
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
          edad_retiro = input$edad_retiro,
          zona_sm = zona_sel
        )
      }

      res <- list(
        regimen = REGIMEN_LEY73,
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
      res$regimen <- REGIMEN_LEY97
      res$fondo_aplica <- TRUE
    }

    resultados(res)
    resultados_originales(res)

    # PostHog: calculation_done -- enviamos solo atributos no identificables
    tryCatch({
      age_bucket <- function(a) if (is.null(a) || is.na(a)) "unknown" else {
        if (a < 30) "<30" else if (a < 40) "30-39" else if (a < 50) "40-49"
        else if (a < 60) "50-59" else "60+"
      }
      track_props <- list(
        regimen = res$regimen,
        age_bucket = age_bucket(floor(edad_actual)),
        zona_sm = input$zona_sm %||% "general",
        fondo_elegible = if (res$regimen == REGIMEN_LEY97) isTRUE(res$con_fondo$elegible) else FALSE,
        aplico_minimo = if (res$regimen == REGIMEN_LEY97) {
          isTRUE(res$solo_sistema$aplico_minimo)
        } else {
          isTRUE(res$pension_base$aplico_minimo)
        },
        escenario = input$escenario %||% "base"
      )
      session$sendCustomMessage("track_event", list(
        name = "calculation_done", props = track_props
      ))
    }, error = function(e) {
      message("[PostHog] calculation_done track error: ", e$message)
    })

    # Initialize cliff notification trackers
    if (res$regimen == REGIMEN_LEY97) {
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
    if (regimen == REGIMEN_LEY73) {
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

    if (res$regimen == REGIMEN_LEY73) {
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

  # PostHog: sensitivity slider usage (debounced, only after first calc)
  track_sensitivity <- function(slider_name) {
    tryCatch({
      session$sendCustomMessage("track_event", list(
        name = "sensitivity_used", props = list(slider = slider_name)
      ))
    }, error = function(e) {
      message("[PostHog] sensitivity_used error: ", e$message)
    })
  }
  observeEvent(vol_debounced(), {
    req(resultados_originales())
    track_sensitivity("aportacion_voluntaria")
  }, ignoreInit = TRUE)
  observeEvent(edad_debounced(), {
    req(resultados_originales())
    track_sensitivity("edad_retiro")
  }, ignoreInit = TRUE)
  observeEvent(semanas_debounced(), {
    req(resultados_originales())
    track_sensitivity("semanas")
  }, ignoreInit = TRUE)
  observeEvent(salario_debounced(), {
    req(resultados_originales())
    track_sensitivity("salario")
  }, ignoreInit = TRUE)
  observeEvent(afore_debounced(), {
    req(resultados_originales())
    track_sensitivity("afore")
  }, ignoreInit = TRUE)

  # PostHog: zona_sm selection
  observeEvent(input$zona_sm, {
    tryCatch({
      session$sendCustomMessage("track_event", list(
        name = "zona_selected", props = list(zona = input$zona_sm)
      ))
    }, error = function(e) { NULL })
  }, ignoreInit = TRUE)

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

    if (res_orig$regimen == REGIMEN_LEY97) {
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
          escenario = res_orig$entrada$escenario %||% ESCENARIO_BASE
        )
        res$regimen <- REGIMEN_LEY97
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
        zona_sel <- input$zona_sm %||% ZONA_GENERAL

        resultado_base <- calculate_ley73_pension(
          sbc_promedio_diario = sbc_diario,
          semanas = semanas_al_retiro,
          edad = edad_slider,
          zona_sm = zona_sel
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
            edad_retiro = edad_slider,
            zona_sm = zona_sel
          )
        }

        res <- list(
          regimen = REGIMEN_LEY73,
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

  # ---- Impact helper functions ----

  # Render a pension diff label on an impact element
  render_impact_label <- function(impact_id, pension_orig, pension_new) {
    shinyjs::removeClass(selector = paste0("#", impact_id), class = "positive")
    shinyjs::removeClass(selector = paste0("#", impact_id), class = "negative")
    diferencia <- pension_new - pension_orig
    if (is.null(diferencia) || length(diferencia) == 0 || diferencia == 0) {
      shinyjs::html(impact_id, "")
      return(invisible(NULL))
    }
    signo <- if (diferencia > 0) "+" else ""
    clase <- if (diferencia > 0) "positive" else "negative"
    shinyjs::html(impact_id, paste0(
      format_currency(pension_orig), " &rarr; ",
      format_currency(pension_new), "/mes (",
      signo, format_currency(diferencia), ")"
    ))
    shinyjs::addClass(selector = paste0("#", impact_id), class = clase)
  }

  # Recalculate Ley 97 with overrides applied to original inputs
  recalculate_ley97 <- function(res_orig, overrides = list()) {
    args <- list(
      saldo_actual = res_orig$entrada$saldo_actual,
      salario_mensual = res_orig$entrada$salario_mensual,
      edad_actual = res_orig$entrada$edad_actual,
      edad_retiro = res_orig$entrada$edad_retiro,
      semanas_actuales = res_orig$entrada$semanas_actuales,
      genero = res_orig$entrada$genero %||% "M",
      aportacion_voluntaria = 0,
      afore_nombre = res_orig$entrada$afore %||% "XXI Banorte",
      escenario = res_orig$entrada$escenario %||% ESCENARIO_BASE
    )
    args <- modifyList(args, overrides)
    do.call(calculate_pension_with_fondo, args)
  }

  # Recalculate Ley 73 pension with optional overrides
  recalculate_ley73 <- function(res_orig, edad_retiro = NULL,
                                 semanas_actuales = NULL,
                                 salario_mensual = NULL) {
    sal <- salario_mensual %||% res_orig$entrada$salario_mensual
    edad_ret <- edad_retiro %||% res_orig$entrada$edad_retiro
    sem <- semanas_actuales %||% res_orig$entrada$semanas_actuales
    sbc_diario <- sal / DIAS_POR_MES
    anios_restantes <- max(0, edad_ret - res_orig$entrada$edad_actual)
    semanas_al_retiro <- sem + (anios_restantes * SEMANAS_POR_ANO)
    calculate_ley73_pension(
      sbc_promedio_diario = sbc_diario,
      semanas = semanas_al_retiro,
      edad = edad_ret,
      zona_sm = input$zona_sm %||% ZONA_GENERAL
    )
  }

  # ---- Impact observers ----

  # Calcular impacto de voluntarias
  observe({
    req(resultados_originales(), vol_debounced())
    res <- resultados_originales()
    if (vol_debounced() == (res$entrada$aportacion_voluntaria %||% 0)) {
      shinyjs::html("vol_impact", "")
      return()
    }
    if (res$regimen == REGIMEN_LEY97) {
      tryCatch({
        nuevo <- recalculate_ley97(res, list(aportacion_voluntaria = vol_debounced()))
        pension_orig <- unname(res$solo_sistema$pension_mensual)
        pension_new <- unname(nuevo$con_acciones$pension_afore %||% nuevo$solo_sistema$pension_mensual)
        render_impact_label("vol_impact", pension_orig, pension_new)
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
    if (edad_slider == res$entrada$edad_retiro) {
      shinyjs::html("age_impact", "")
      return()
    }
    tryCatch({
      if (res$regimen == REGIMEN_LEY97) {
        nuevo <- recalculate_ley97(res, list(edad_retiro = edad_slider))
        render_impact_label("age_impact",
          unname(res$solo_sistema$pension_mensual),
          unname(nuevo$solo_sistema$pension_mensual))
      } else {
        nuevo <- recalculate_ley73(res, edad_retiro = edad_slider)
        render_impact_label("age_impact",
          unname(res$pension_base$pension_mensual),
          unname(nuevo$pension_mensual))
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
    if (res$regimen != REGIMEN_LEY97) {
      shinyjs::html("afore_impact", "")
      return()
    }
    if (input$afore_comparar == res$entrada$afore) {
      shinyjs::html("afore_impact", "")
      return()
    }
    tryCatch({
      shinyjs::removeClass(selector = "#afore_impact", class = "positive")
      shinyjs::removeClass(selector = "#afore_impact", class = "negative")
      pension_orig <- unname(res$solo_sistema$pension_mensual)
      nuevo <- recalculate_ley97(res, list(afore_nombre = input$afore_comparar))
      pension_new <- unname(nuevo$solo_sistema$pension_mensual)
      dif_pension <- pension_new - pension_orig
      dif_saldo <- (nuevo$solo_sistema$saldo_proyectado %||% 0) -
                   (res$solo_sistema$saldo_proyectado %||% 0)

      if (!is.null(dif_pension) && dif_pension != 0) {
        render_impact_label("afore_impact", pension_orig, pension_new)
      } else if (!is.null(dif_saldo) && abs(dif_saldo) > 0) {
        signo <- if (dif_saldo > 0) "+" else ""
        clase <- if (dif_saldo > 0) "positive" else "negative"
        shinyjs::html("afore_impact",
          paste0(signo, format_currency(dif_saldo), " en saldo al retiro"))
        shinyjs::addClass(selector = paste0("#afore_impact"), class = clase)
      } else {
        shinyjs::html("afore_impact", "Comisiones similares, impacto m\u00ednimo")
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
    if (semanas_slider == res$entrada$semanas_actuales) {
      shinyjs::html("semanas_impact", "")
      return()
    }
    tryCatch({
      shinyjs::removeClass(selector = "#semanas_impact", class = "positive")
      shinyjs::removeClass(selector = "#semanas_impact", class = "negative")
      if (res$regimen == REGIMEN_LEY97) {
        pension_orig <- unname(res$solo_sistema$pension_mensual)
        nuevo <- recalculate_ley97(res, list(semanas_actuales = semanas_slider))
        pension_new <- unname(nuevo$solo_sistema$pension_mensual)
        dif_pension <- pension_new - pension_orig

        if (dif_pension != 0) {
          render_impact_label("semanas_impact", pension_orig, pension_new)
        } else if (nuevo$con_fondo$elegible != res$con_fondo$elegible) {
          if (nuevo$con_fondo$elegible) {
            shinyjs::html("semanas_impact", "Elegible para Fondo Bienestar")
            shinyjs::addClass(selector = "#semanas_impact", class = "positive")
          } else {
            shinyjs::html("semanas_impact", "No elegible para Fondo")
            shinyjs::addClass(selector = "#semanas_impact", class = "negative")
          }
        } else {
          anios_restantes <- max(0, res$entrada$edad_retiro - res$entrada$edad_actual)
          nuevo_semanas_retiro <- semanas_slider + (anios_restantes * SEMANAS_POR_ANO)
          shinyjs::html("semanas_impact",
            paste0(format(nuevo_semanas_retiro, big.mark = ","), " sem. al retiro"))
        }
      } else {
        nuevo <- recalculate_ley73(res, semanas_actuales = semanas_slider)
        render_impact_label("semanas_impact",
          unname(res$pension_base$pension_mensual),
          unname(nuevo$pension_mensual))
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
      if (res$regimen == REGIMEN_LEY97) {
        nuevo <- recalculate_ley97(res, list(salario_mensual = salario_slider))
        render_impact_label("salario_impact",
          unname(res$solo_sistema$pension_mensual),
          unname(nuevo$solo_sistema$pension_mensual))
      } else {
        nuevo <- recalculate_ley73(res, salario_mensual = salario_slider)
        render_impact_label("salario_impact",
          unname(res$pension_base$pension_mensual),
          unname(nuevo$pension_mensual))
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

    if (res$regimen == REGIMEN_LEY73) {
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
      escenario_val <- ESCENARIO_BASE
    }
    rendimiento_texto <- switch(escenario_val,
      "conservador" = "3% real (conservador)",
      "base" = "4% real (base)",
      "optimista" = "5% real (optimista)",
      "4% real"
    )

    zona_label <- switch(input$zona_sm %||% "general",
      "general" = "Zona General",
      "zlfn"    = "Zona Libre Frontera Norte",
      "Zona General"
    )
    sm_label <- if ((input$zona_sm %||% "general") == "zlfn") {
      format_currency(SM_DIARIO_ZLFN_2025)
    } else {
      format_currency(SM_DIARIO_2025)
    }

    tagList(
      tags$h6("Supuestos utilizados:"),
      tags$ul(
        tags$li(paste0("Régimen: ", if (res$regimen == REGIMEN_LEY73) "Ley 73" else "Ley 97 (AFORE)")),
        tags$li(paste0("Rendimiento proyectado: ", rendimiento_texto,
                       " (escenarios educativos, no predicciones)")),
        if (res$regimen == REGIMEN_LEY97) tags$li(paste0("AFORE: ", res$entrada$afore)),
        tags$li(paste0("Umbral Fondo Bienestar 2025: ",
                       format_currency(UMBRAL_FONDO_BIENESTAR_2025),
                       " (años posteriores: extrapolación 3.5% anual)")),
        tags$li(paste0("UMA diaria 2025: ", format_currency(UMA_DIARIA_2025))),
        tags$li(paste0("Salario mínimo 2025 (", zona_label, "): ", sm_label, "/día")),
        if (res$regimen == REGIMEN_LEY97) {
          tags$li("Pensión Mínima Garantizada: matriz DOF 2020 (edad × semanas × SBC, aprox. CONSAR)")
        },
        if (res$regimen == REGIMEN_LEY97) {
          tags$li("Esperanza de vida: EMSSA 2009 (tabla oficial CNSF para rentas vitalicias)")
        }
      ),

      tags$h6(class = "mt-3", "Fuentes de datos:"),
      tags$ul(
        tags$li("Tabla Articulo 167: Ley del Seguro Social 1973"),
        tags$li("Reforma pensiones: DOF 16-dic-2020"),
        tags$li("Fondo Bienestar: DOF 01-may-2024"),
        tags$li("UMA: INEGI / DOF"),
        tags$li("Salario mínimo (General y ZLFN): CONASAMI"),
        tags$li("Comisiones AFORE: CONSAR"),
        tags$li("Mortalidad: EMSSA 2009 (CNSF)")
      ),

      tags$h6(class = "mt-3", "Limitaciones:"),
      tags$ul(
        tags$li("Esta es una estimación educativa, NO una garantía"),
        tags$li("Las leyes y políticas pueden cambiar"),
        tags$li("El Fondo Bienestar (2024) tiene sostenibilidad incierta"),
        tags$li("La matriz PMG implementada es una aproximación pública de la tabla CONSAR"),
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

  # Helper: track report views via PostHog (server-side)
  track_report_view <- function(report_type) {
    tryCatch({
      session$sendCustomMessage("track_event", list(
        name = "report_viewed", props = list(type = report_type)
      ))
    }, error = function(e) {
      message("[PostHog] report_viewed track error: ", e$message)
    })
  }

  # Ver documento tecnico
  observeEvent(input$ver_tecnico, {
    req(resultados())
    tryCatch({
      html_content <- generate_technical_report(resultados())
      open_report_in_tab(html_content, "tecnico", "#0f766e", "#0d9488")
      track_report_view("tecnico")
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
      track_report_view("resumen")
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
      track_report_view("basico")
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
      track_report_view("metodologia")
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
