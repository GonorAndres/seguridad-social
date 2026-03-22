// Independent pension calculator derived from Mexican regulation
// NOT a port of R code -- formulas from LSS Art. 167, DOF decrees
// Used to compute expected values for Playwright test assertions

import {
  DIAS_POR_MES,
  SM_DIARIO_2025,
  PENSION_MINIMA_LEY97,
  UMBRAL_FONDO_2025,
  SEMANAS_MIN_FONDO,
  ANIO_ACTUAL,
  FACTORES_CESANTIA,
  ESPERANZA_VIDA_M,
  ESPERANZA_VIDA_F,
  getSemanasMinLey97,
} from './constants';
import { lookupArticulo167 } from './art167-table';

// ============================================================================
// LEY 73 PENSION (Defined Benefit)
// ============================================================================

export interface Ley73Result {
  pensionMensual: number;
  pensionSinMinimo: number;
  elegible: boolean;
  grupoSalarial: number;
  cuantiaBasica: number;
  incrementoAnual: number;
  nIncrementos: number;
  porcentajeTotal: number;
  factorEdad: number;
  tasaReemplazo: number;
  aplicoMinimo: boolean;
  tipoPension: 'vejez' | 'cesantia';
}

/**
 * Calculate Ley 73 pension.
 * Formula: LSS Art. 167 cuantia + incrementos * factor_edad
 */
export function calculateLey73Pension(
  salarioMensual: number,
  semanas: number,
  edadRetiro: number,
): Ley73Result {
  const sbcDiario = salarioMensual / DIAS_POR_MES;

  // Eligibility checks
  if (semanas < 500 || edadRetiro < 60) {
    return {
      pensionMensual: 0,
      pensionSinMinimo: 0,
      elegible: false,
      grupoSalarial: 0,
      cuantiaBasica: 0,
      incrementoAnual: 0,
      nIncrementos: 0,
      porcentajeTotal: 0,
      factorEdad: 0,
      tasaReemplazo: 0,
      aplicoMinimo: false,
      tipoPension: edadRetiro >= 65 ? 'vejez' : 'cesantia',
    };
  }

  // Step 1: Salary group
  const grupoSalarial = sbcDiario / SM_DIARIO_2025;

  // Step 2: Art. 167 lookup
  const { cuantia, incremento } = lookupArticulo167(grupoSalarial);

  // Step 3: Increments (complete years over 500 weeks)
  const nIncrementos = Math.max(0, Math.floor((semanas - 500) / 52));
  const totalIncrementos = nIncrementos * incremento;

  // Step 4: Total percentage (capped at 100%)
  const porcentajeTotal = Math.min(cuantia + totalIncrementos, 1.0);

  // Step 5: Age factor
  let factorEdad: number;
  let tipoPension: 'vejez' | 'cesantia';
  if (edadRetiro >= 65) {
    factorEdad = 1.0;
    tipoPension = 'vejez';
  } else {
    factorEdad = FACTORES_CESANTIA[edadRetiro] ?? 0.75;
    tipoPension = 'cesantia';
  }

  // Step 6: Calculate pension
  const pensionDiaria = sbcDiario * porcentajeTotal * factorEdad;
  const pensionSinMinimo = pensionDiaria * DIAS_POR_MES;

  // Minimum: 1 SM mensual
  const pensionMinima = SM_DIARIO_2025 * DIAS_POR_MES;
  const aplicoMinimo = pensionSinMinimo < pensionMinima;
  const pensionMensual = Math.max(pensionSinMinimo, pensionMinima);

  // Replacement rate
  const tasaReemplazo = pensionMensual / salarioMensual;

  return {
    pensionMensual,
    pensionSinMinimo,
    elegible: true,
    grupoSalarial,
    cuantiaBasica: cuantia,
    incrementoAnual: incremento,
    nIncrementos,
    porcentajeTotal,
    factorEdad,
    tasaReemplazo,
    aplicoMinimo,
    tipoPension,
  };
}

// ============================================================================
// LEY 97 PENSION (Individual Account)
// ============================================================================

export interface Ley97Result {
  pensionMensual: number;
  pensionCalculada: number;
  pensionMinima: number;
  elegible: boolean;
  saldoProyectado: number;
  esperanzaVida: number;
  tasaReemplazo: number;
  aplicoMinimo: boolean;
  semanasAlRetiro: number;
  semanasMinimas: number;
}

/**
 * Get life expectancy for given age and gender.
 * Uses exact lookup from mortality table (no interpolation for standard ages).
 */
function getEsperanzaVida(edad: number, genero: 'M' | 'F'): number {
  const table = genero === 'F' ? ESPERANZA_VIDA_F : ESPERANZA_VIDA_M;
  if (edad in table) return table[edad];

  // Linear interpolation for non-tabulated ages
  const ages = Object.keys(table).map(Number).sort((a, b) => a - b);
  if (edad < ages[0]) return table[ages[0]] + (ages[0] - edad);
  if (edad > ages[ages.length - 1]) return Math.max(2, table[ages[ages.length - 1]] - (edad - ages[ages.length - 1]) * 0.5);

  let lower = ages[0], upper = ages[ages.length - 1];
  for (let i = 0; i < ages.length - 1; i++) {
    if (edad >= ages[i] && edad <= ages[i + 1]) {
      lower = ages[i];
      upper = ages[i + 1];
      break;
    }
  }
  const prop = (edad - lower) / (upper - lower);
  return table[lower] + prop * (table[upper] - table[lower]);
}

/**
 * Calculate Ley 97 pension for a worker already at retirement (0 years remaining).
 * Simplified: no compounding, no contribution schedule.
 * saldo_final = saldo_actual (no projection needed).
 */
export function calculateLey97PensionAtRetirement(
  saldoActual: number,
  salarioMensual: number,
  edadRetiro: number,
  semanasActuales: number,
  genero: 'M' | 'F',
  edadActual: number,
): Ley97Result {
  const aniosRestantes = Math.max(0, edadRetiro - edadActual);
  const semanasAlRetiro = semanasActuales + (aniosRestantes * 52);
  const anioRetiro = ANIO_ACTUAL + aniosRestantes;
  const semanasMinimas = getSemanasMinLey97(anioRetiro);

  const elegible = semanasAlRetiro >= semanasMinimas;

  if (!elegible) {
    return {
      pensionMensual: 0,
      pensionCalculada: 0,
      pensionMinima: PENSION_MINIMA_LEY97,
      elegible: false,
      saldoProyectado: saldoActual,
      esperanzaVida: getEsperanzaVida(edadRetiro, genero),
      tasaReemplazo: 0,
      aplicoMinimo: false,
      semanasAlRetiro,
      semanasMinimas,
    };
  }

  // For 0 years remaining: no projection, balance stays the same
  const saldoFinal = saldoActual;
  const esperanzaVida = getEsperanzaVida(edadRetiro, genero);
  const mesesEsperados = esperanzaVida * 12;
  const pensionCalculada = saldoFinal / mesesEsperados;
  const aplicoMinimo = pensionCalculada < PENSION_MINIMA_LEY97;
  const pensionMensual = Math.max(pensionCalculada, PENSION_MINIMA_LEY97);
  const tasaReemplazo = pensionMensual / salarioMensual;

  return {
    pensionMensual,
    pensionCalculada,
    pensionMinima: PENSION_MINIMA_LEY97,
    elegible: true,
    saldoProyectado: saldoFinal,
    esperanzaVida,
    tasaReemplazo,
    aplicoMinimo,
    semanasAlRetiro,
    semanasMinimas,
  };
}

// ============================================================================
// FONDO BIENESTAR
// ============================================================================

export interface FondoResult {
  elegible: boolean;
  complemento: number;
  pensionTotal: number;
  pensionObjetivo: number;
  umbral: number;
}

/**
 * Check Fondo Bienestar eligibility and calculate complement.
 * DOF 01/05/2024 decree.
 */
export function calculateFondoBienestar(
  pensionAfore: number,
  salarioMensual: number,
  edadRetiro: number,
  semanasAlRetiro: number,
  anioRetiro: number,
): FondoResult {
  const umbral = UMBRAL_FONDO_2025; // For 2025 retirement year

  const elegible =
    edadRetiro >= 65 &&
    semanasAlRetiro >= SEMANAS_MIN_FONDO &&
    salarioMensual <= umbral;

  if (!elegible) {
    return {
      elegible: false,
      complemento: 0,
      pensionTotal: pensionAfore,
      pensionObjetivo: 0,
      umbral,
    };
  }

  const pensionObjetivo = Math.min(salarioMensual, umbral);
  const complemento = Math.max(0, pensionObjetivo - pensionAfore);
  const pensionTotal = pensionAfore + complemento;

  return {
    elegible: true,
    complemento,
    pensionTotal,
    pensionObjetivo,
    umbral,
  };
}

// ============================================================================
// FULL PIPELINE (combines Ley 97 + Fondo for 0-years-remaining profiles)
// ============================================================================

export interface FullLey97Result {
  soloSistema: Ley97Result;
  fondo: FondoResult;
  heroPension: number;      // What the hero should display
  heroReplacement: number;  // Replacement rate for hero
}

export function calculateFullLey97Pipeline(
  saldoActual: number,
  salarioMensual: number,
  edadRetiro: number,
  semanasActuales: number,
  genero: 'M' | 'F',
  edadActual: number,
): FullLey97Result {
  const soloSistema = calculateLey97PensionAtRetirement(
    saldoActual, salarioMensual, edadRetiro, semanasActuales, genero, edadActual
  );

  const aniosRestantes = Math.max(0, edadRetiro - edadActual);
  const semanasAlRetiro = semanasActuales + aniosRestantes * 52;
  const anioRetiro = ANIO_ACTUAL + aniosRestantes;

  const fondo = calculateFondoBienestar(
    soloSistema.pensionMensual,
    salarioMensual,
    edadRetiro,
    semanasAlRetiro,
    anioRetiro,
  );

  // Hero displays Fondo total if eligible, otherwise solo sistema
  const heroPension = fondo.elegible ? fondo.pensionTotal : soloSistema.pensionMensual;
  const heroReplacement = heroPension / salarioMensual;

  return { soloSistema, fondo, heroPension, heroReplacement };
}
