// Mirror of R/constants.R - 2025 regulatory values
// Source: INEGI (UMA), CONASAMI (SM), DOF (Fondo), LSS (tope)

// Actuarial constants
export const DIAS_POR_MES = 30.4375; // 365.25 / 12
export const SEMANAS_POR_ANO = 52;

// UMA 2025 (INEGI/DOF)
export const UMA_DIARIA_2025 = 113.14;
export const UMA_MENSUAL_2025 = 3439.46;

// Salario Minimo 2025 (CONASAMI)
export const SM_DIARIO_2025 = 278.80;
export const SM_MENSUAL_2025 = 8474.52;

// Pension minima garantizada Ley 97: 2.5 UMA mensuales
export const PENSION_MINIMA_LEY97 = UMA_MENSUAL_2025 * 2.5; // 8598.65

// Pension minima Ley 73: 1 SM mensual (using actuarial conversion)
export const PENSION_MINIMA_LEY73 = SM_DIARIO_2025 * DIAS_POR_MES; // ~8485.975

// Tope de cotizacion: 25 UMA diarias (LSS Art. 28)
export const TOPE_SBC_DIARIO = UMA_DIARIA_2025 * 25; // 2828.50

// Fondo Bienestar (DOF 01/05/2024, effective 01/07/2024)
export const UMBRAL_FONDO_2025 = 17364;
export const SEMANAS_MIN_FONDO = 1000;

// ANIO_ACTUAL as defined in R code (note: hardcoded to 2025)
export const ANIO_ACTUAL = 2025;

// Factores de edad para cesantia (Ley 73, LSS Art. 171)
export const FACTORES_CESANTIA: Record<number, number> = {
  60: 0.75,
  61: 0.80,
  62: 0.85,
  63: 0.90,
  64: 0.95,
  65: 1.00,
};

// Rendimientos reales anuales por escenario
export const RENDIMIENTOS = {
  conservador: 0.03,
  base: 0.04,
  optimista: 0.05,
} as const;

// AFORE commissions 2025 (from afore_comisiones.csv)
// NOTE: CSV divides by 100 in R code, values below are already decimal
export const AFORE_COMISIONES_2025: Record<string, number> = {
  'Azteca': 0.0055,
  'Citibanamex': 0.0055,
  'Coppel': 0.0055,
  'Inbursa': 0.0055,
  'Invercap': 0.0055,
  'PensionISSSTE': 0.0052,
  'Principal': 0.0055,
  'Profuturo': 0.0055,
  'SURA': 0.0055,
  'XXI Banorte': 0.0055,
};

// Life expectancy (CONAPO-based, from R/data_tables.R)
export const ESPERANZA_VIDA_M: Record<number, number> = {
  60: 21.0, 61: 20.2, 62: 19.4, 63: 18.6, 64: 17.8,
  65: 17.0, 66: 16.3, 67: 15.5, 68: 14.8, 69: 14.1,
  70: 13.4, 75: 10.5, 80: 8.0, 85: 5.8, 90: 4.2,
};

export const ESPERANZA_VIDA_F: Record<number, number> = {
  60: 24.5, 61: 23.6, 62: 22.7, 63: 21.8, 64: 20.9,
  65: 20.0, 66: 19.2, 67: 18.3, 68: 17.5, 69: 16.7,
  70: 15.9, 75: 12.5, 80: 9.5, 85: 7.0, 90: 5.0,
};

// Transitional minimum weeks for Ley 97 (DOF 16/12/2020)
export function getSemanasMinLey97(anioRetiro: number): number {
  const base = 750;
  const incremento = 25;
  const anioInicio = 2021;
  const anioTope = 2031;
  const tope = 1000;
  if (anioRetiro <= anioInicio) return base;
  if (anioRetiro >= anioTope) return tope;
  return base + incremento * (anioRetiro - anioInicio);
}
