// CSS selectors and Shiny input IDs for the pension simulator

// Landing page
export const LANDING = {
  startWizard: '#start_wizard',
  showContext: '#show_context',
  heroSection: '.hero-section',
};

// Wizard navigation
export const WIZARD = {
  step1Panel: '#step1_panel',
  step2Panel: '#step2_panel',
  step3Panel: '#step3_panel',
  step4Panel: '#step4_panel',
  nextStep1: '#next_step1',
  nextStep2: '#next_step2',
  prevStep2: '#prev_step2',
  prevStep3: '#prev_step3',
  calcular: '#calcular',
  backToLanding: '#back_to_landing',
  modificarDatos: '#modificar_datos',
  nuevaSimulacion: '#nueva_simulacion',
};

// Step 1: Personal data (Shiny input IDs)
export const STEP1 = {
  fechaNacimiento: 'fecha_nacimiento',
  genero: 'genero',
  edadRetiro: 'edad_retiro',
};

// Step 2: Labor data
export const STEP2 = {
  fechaInicioCotizacion: 'fecha_inicio_cotizacion',
  salarioMensual: 'salario_mensual',
  semanasCotizadas: 'semanas_cotizadas',
  regimenBadge: '#regimen_badge',
  toggleOverride: '#toggle_override',
  regimenManual: 'regimen_manual',
};

// Step 3: AFORE
export const STEP3 = {
  aforeActual: 'afore_actual',
  saldoAfore: 'saldo_afore',
  aportacionVoluntaria: 'aportacion_voluntaria',
  escenario: 'escenario',
  aforeFieldsContainer: '#afore_fields_container',
  ley73AforeNote: '#ley73_afore_note',
};

// Step 4: Results
export const RESULTS = {
  heroAmount: '.result-hero-amount',
  heroBadge: '.result-hero-badge',
  heroTag: '.result-hero-tag',
  heroLabel: '.result-hero-label',
  breakdownContainer: '.result-breakdown',
  breakdownRow: '.breakdown-row',
  breakdownLabel: '.breakdown-label',
  breakdownValue: '.breakdown-value',
  fondoEligible: '.fondo-status-inline.eligible',
  fondoNotEligible: '.fondo-status-inline.not-eligible',
  fondoStatusInline: '.fondo-status-inline',
  minimumNote: '.minimum-note',
  resultCardsFrozen: '#result_cards_frozen',
};

// Sensitivity sliders
export const SLIDERS = {
  salario: 'slider_salario',
  voluntaria: 'slider_voluntaria',
  edad: 'slider_edad',
  semanas: 'slider_semanas',
  salarioImpact: '#salario_impact',
  volImpact: '#vol_impact',
  ageImpact: '#age_impact',
  semanasImpact: '#semanas_impact',
  volSliderCol: '#vol_slider_col',
  aforeSliderRow: '#afore_slider_row',
  ley73SensitivityNote: '#ley73_sensitivity_note',
};

// Chart
export const CHART = {
  proyeccion: '#proyeccion_chart',
};

// Technical details
export const TECHNICAL = {
  accordion: '#technicalAccordion',
  details: '#technical_details',
};
