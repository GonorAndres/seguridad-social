import { test, expect } from '@playwright/test';
import { runFullWizard, TestProfile } from '../helpers/shiny-helpers';
import { extractResults } from '../helpers/result-extractor';
import { calculateLey73Pension } from '../helpers/hand-calculator';
import { DIAS_POR_MES, SM_DIARIO_2025, SEMANAS_POR_ANO } from '../helpers/constants';

const TOLERANCE_PCT = 0.03;
const TOLERANCE_ABS = 300;

function assertPensionClose(actual: number, expected: number, label: string) {
  const diff = Math.abs(actual - expected);
  const pctDiff = expected > 0 ? diff / expected : diff;
  const passes = diff <= TOLERANCE_ABS || pctDiff <= TOLERANCE_PCT;
  expect(passes, `${label}: actual=$${actual.toFixed(0)} vs expected=$${expected.toFixed(0)} (diff=$${diff.toFixed(0)}, ${(pctDiff * 100).toFixed(1)}%)`).toBe(true);
}

// ============================================================================
// NOTE ON MODALIDAD 40:
// When anios_restantes > 0, the app automatically simulates Modalidad 40
// (voluntary contribution at 80% of SBC tope) and shows the M40-enhanced
// pension in the hero. The base Ley 73 pension appears in the breakdown.
// We validate:
//   1. The BASE pension formula (from breakdown or computed independently)
//   2. The HERO pension is >= base (M40 always improves it)
//   3. The hand-calculated base formula components are correct
// ============================================================================

// ============================================================================
// PROFILE A: LEY 73 VEJEZ (1 year to retirement at age 65)
// ============================================================================
// Born 1961-06-01 -> age ~64 -> 1 year remaining -> M40 simulated
// Base hand calculation (no M40):
//   semanas_al_retiro = 1552, grupo=1.178, bracket [1.01,1.25]
//   pension_base ~$9,339
// With M40: SBC weighted with tope -> higher pension -> hero shows M40 amount
// ============================================================================

test.describe('Profile A: Ley 73 Vejez', () => {
  const profile: TestProfile = {
    fechaNacimiento: '1961-06-01',
    genero: 'M',
    edadRetiro: 65,
    fechaInicioCotizacion: '1990-01-01',
    salarioMensual: 10000,
    semanasCotizadas: 1500,
  };

  const semanasAlRetiro = profile.semanasCotizadas + 1 * SEMANAS_POR_ANO;
  const expectedBase = calculateLey73Pension(
    profile.salarioMensual,
    semanasAlRetiro,
    profile.edadRetiro,
  );

  test('hero pension (with M40) is ABOVE base calculation', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    console.log(`Profile A - Hero (M40): $${result.heroAmount}`);
    console.log(`  Base expected: $${expectedBase.pensionMensual.toFixed(0)}`);
    console.log(`  M40 improves pension by using higher SBC from tope`);

    // Hero shows M40 pension, which must be >= base pension
    expect(result.heroAmount).toBeGreaterThanOrEqual(expectedBase.pensionMensual * 0.97);
    // M40 at 80% of tope ($2,262.80 SBC daily) significantly boosts the pension
    expect(result.heroAmount).toBeGreaterThan(10000);
  });

  test('base pension formula components are correct', () => {
    // Validate Art. 167 lookup and formula independently
    expect(expectedBase.elegible).toBe(true);
    expect(expectedBase.grupoSalarial).toBeGreaterThanOrEqual(1.01);
    expect(expectedBase.grupoSalarial).toBeLessThanOrEqual(1.25);
    expect(expectedBase.cuantiaBasica).toBeCloseTo(0.7711, 4);
    expect(expectedBase.incrementoAnual).toBeCloseTo(0.00814, 5);
    expect(expectedBase.nIncrementos).toBe(20);
    expect(expectedBase.factorEdad).toBe(1.0);
    expect(expectedBase.tipoPension).toBe('vejez');
    expect(expectedBase.aplicoMinimo).toBe(false);
    // Base pension ~$9,339
    expect(expectedBase.pensionMensual).toBeGreaterThan(9000);
    expect(expectedBase.pensionMensual).toBeLessThan(10000);
  });

  test('minimum guarantee NOT applied (pension > 1 SM)', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    expect(result.heroAmount).toBeGreaterThan(SM_DIARIO_2025 * DIAS_POR_MES);
  });

  test('pension displays with replacement rate', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    // M40 pension / salary * 100 should be a reasonable replacement rate
    expect(result.replacementRate).toBeGreaterThan(50);
    expect(result.replacementRate).toBeLessThan(250);
  });
});

// ============================================================================
// PROFILE B: LEY 73 CESANTIA (1 year to retirement at age 62)
// ============================================================================
// Born 1964-06-01 -> age ~61 -> 1 year to 62
// Base: semanas=1852, grupo=2.357, bracket [2.26,2.50], factor=0.85
// With M40: SBC boosted -> higher grupo -> hero shows M40 amount
// ============================================================================

test.describe('Profile B: Ley 73 Cesantia', () => {
  const profile: TestProfile = {
    fechaNacimiento: '1964-06-01',
    genero: 'M',
    edadRetiro: 62,
    fechaInicioCotizacion: '1990-01-01',
    salarioMensual: 20000,
    semanasCotizadas: 1800,
  };

  const semanasAlRetiro = profile.semanasCotizadas + 1 * SEMANAS_POR_ANO;
  const expectedBase = calculateLey73Pension(
    profile.salarioMensual,
    semanasAlRetiro,
    profile.edadRetiro,
  );

  test('hero pension (with M40) is above base calculation', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    console.log(`Profile B - Hero (M40): $${result.heroAmount}`);
    console.log(`  Base expected: $${expectedBase.pensionMensual.toFixed(0)}`);

    // M40 pension must be >= base pension
    expect(result.heroAmount).toBeGreaterThanOrEqual(expectedBase.pensionMensual * 0.97);
    expect(result.heroAmount).toBeGreaterThan(10000);
  });

  test('base pension uses cesantia factor 0.85 for age 62', () => {
    expect(expectedBase.factorEdad).toBe(0.85);
    expect(expectedBase.tipoPension).toBe('cesantia');
    expect(expectedBase.grupoSalarial).toBeGreaterThanOrEqual(2.26);
    expect(expectedBase.grupoSalarial).toBeLessThanOrEqual(2.50);
  });

  test('n_incrementos = 26 (1352 excess weeks / 52)', () => {
    expect(expectedBase.nIncrementos).toBe(26);
  });

  test('base pension ~$14K (before M40 boost)', () => {
    // Base: cuantia=0.3368, 26 increments, porcentaje~0.8225, factor=0.85
    expect(expectedBase.pensionMensual).toBeGreaterThan(12000);
    expect(expectedBase.pensionMensual).toBeLessThan(16000);
  });
});
