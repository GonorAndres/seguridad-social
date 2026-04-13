// Mirror of R/constants.R - 2025 regulatory values
// Source: INEGI (UMA), CONASAMI (SM), DOF (Fondo), LSS (tope)

// Actuarial constants
export const DIAS_POR_MES = 30.4375; // 365.25 / 12
export const SEMANAS_POR_ANO = 52;

// UMA 2025 (INEGI/DOF) - valor diario oficial, mensual derivado con 30.4375
export const UMA_DIARIA_2025 = 113.14;
export const UMA_MENSUAL_2025 = UMA_DIARIA_2025 * DIAS_POR_MES; // 3443.70

// Salario Minimo 2025 (CONASAMI)
export const SM_DIARIO_2025 = 278.80;
export const SM_MENSUAL_2025 = SM_DIARIO_2025 * DIAS_POR_MES; // ~8486.0
export const SM_DIARIO_ZLFN_2025 = 419.88;
export const SM_MENSUAL_ZLFN_2025 = SM_DIARIO_ZLFN_2025 * DIAS_POR_MES; // ~12780.1

// Pension minima garantizada Ley 97 fallback: 2.5 UMA mensuales
// (produccion ahora usa matriz DOF 2020 en R/pmg_matrix.R; esto sigue siendo
// el tope superior de la matriz y el fallback)
export const PENSION_MINIMA_LEY97 = UMA_MENSUAL_2025 * 2.5; // 8609.25

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

// Life expectancy: EMSSA 2009 (CNSF) - ver R/data_tables.R
export const ESPERANZA_VIDA_M: Record<number, number> = {
  60: 22.5, 61: 21.7, 62: 20.8, 63: 20.0, 64: 19.2,
  65: 18.4, 66: 17.6, 67: 16.8, 68: 16.0, 69: 15.3,
  70: 14.5, 75: 11.3, 80: 8.5, 85: 6.1, 90: 4.3,
};

export const ESPERANZA_VIDA_F: Record<number, number> = {
  60: 25.8, 61: 24.9, 62: 24.1, 63: 23.2, 64: 22.4,
  65: 21.5, 66: 20.7, 67: 19.8, 68: 19.0, 69: 18.2,
  70: 17.4, 75: 13.5, 80: 10.1, 85: 7.3, 90: 5.1,
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
