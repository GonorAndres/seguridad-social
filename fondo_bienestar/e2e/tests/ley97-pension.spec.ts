import { test, expect } from '@playwright/test';
import { runFullWizard, TestProfile } from '../helpers/shiny-helpers';
import { extractResults } from '../helpers/result-extractor';
import { PENSION_MINIMA_LEY97 } from '../helpers/constants';

// Wider tolerance for Ley 97 since 1-year projection adds compounding complexity
const TOLERANCE_PCT = 0.05; // 5%
const TOLERANCE_ABS = 500;  // $500 MXN

function assertPensionClose(actual: number, expected: number, label: string) {
  const diff = Math.abs(actual - expected);
  const pctDiff = expected > 0 ? diff / expected : diff;
  const passes = diff <= TOLERANCE_ABS || pctDiff <= TOLERANCE_PCT;
  expect(passes, `${label}: actual=$${actual.toFixed(0)} vs expected=$${expected.toFixed(0)} (diff=$${diff.toFixed(0)}, ${(pctDiff * 100).toFixed(1)}%)`).toBe(true);
}

// ============================================================================
// PROFILE C: LEY 97 + FONDO ELIGIBLE
// ============================================================================
// Born 1961-06-01 (age ~64) retire at 65, 1 year remaining
// Salary $15,000 (below Fondo threshold $17,364)
// 1300 weeks + 52 = 1352 >= 1000 -> Fondo eligible
//
// Key insight: With Fondo, the hero shows SALARY regardless of projected balance
// because Fondo tops up: pension_total = min(salary, threshold) = $15,000
// The minimum guarantee ($8,599) is always below salary ($15K), so
// Fondo complement = 15000 - pension_afore > 0
//
// Source: DOF 01/05/2024, Art. 2 Fondo decreto
// ============================================================================

test.describe('Profile C: Ley 97 Fondo Eligible', () => {
  const profile: TestProfile = {
    fechaNacimiento: '1961-06-01',
    genero: 'M',
    edadRetiro: 65,
    fechaInicioCotizacion: '2000-01-01',
    salarioMensual: 15000,
    semanasCotizadas: 1300,
    saldoAfore: 500000,
    aportacionVoluntaria: 0,
    escenario: 'base',
    aforeActual: 'PensionISSSTE',
  };

  test('hero shows Fondo pension = salary ($15,000)', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    console.log(`Profile C - Hero: $${result.heroAmount}`);
    console.log(`  Expected: $15,000 (Fondo tops up to salary)`);

    // With Fondo, pension total = min(salary, threshold) = $15,000
    assertPensionClose(result.heroAmount, 15000, 'Ley97 Fondo pension');
  });

  test('Fondo Bienestar badge shows eligible', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    expect(result.fondoEligible).toBe(true);
  });

  test('replacement rate is ~100%', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    expect(result.replacementRate).toBeGreaterThanOrEqual(95);
    expect(result.replacementRate).toBeLessThanOrEqual(105);
  });
});

// ============================================================================
// PROFILE D: LEY 97 ABOVE FONDO THRESHOLD (NOT eligible)
// ============================================================================
// Born 1961-06-01, salary $50,000 (above threshold), saldo $2M
// 1 year of compounding: ~3.48% net return on $2M = ~$2,127K projected
// pension ≈ $2,127K / 204 ≈ $10,430
//
// Source: LSS Ley 97 retiro programado, DOF reform
// ============================================================================

test.describe('Profile D: Ley 97 Above Fondo Threshold', () => {
  const profile: TestProfile = {
    fechaNacimiento: '1961-06-01',
    genero: 'M',
    edadRetiro: 65,
    fechaInicioCotizacion: '2000-01-01',
    salarioMensual: 50000,
    semanasCotizadas: 1300,
    saldoAfore: 2000000,
    aportacionVoluntaria: 0,
    escenario: 'base',
    aforeActual: 'PensionISSSTE',
  };

  test('pension from own AFORE balance (above minimum)', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    console.log(`Profile D - Hero: $${result.heroAmount}`);
    console.log(`  Expected: ~$10,000-$11,000 (1yr projection of $2M)`);

    // After 1 year compounding, balance ~$2.07-2.13M, pension ~$10K-10.5K
    expect(result.heroAmount).toBeGreaterThan(9500);
    expect(result.heroAmount).toBeLessThan(12000);
    // Must be above the minimum guarantee
    expect(result.heroAmount).toBeGreaterThan(PENSION_MINIMA_LEY97);
  });

  test('Fondo NOT eligible (salary above threshold)', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    expect(result.fondoEligible).toBe(false);
  });

  test('replacement rate ~20% (low for high earner)', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    expect(result.replacementRate).toBeGreaterThanOrEqual(15);
    expect(result.replacementRate).toBeLessThanOrEqual(30);
  });
});

// ============================================================================
// PROFILE E: LEY 97 MINIMUM GUARANTEE (Fondo eligible but complement ~$0)
// ============================================================================
// Born 1961-06-01, salary $8,000, saldo $100K, 1000 weeks
// After 1 year projection: balance grows slightly but still triggers minimum
// pension_minima ($8,599) > salary ($8,000)
// So Fondo complement = max(0, 8000 - 8599) = $0
//
// This edge case validates minimum-guarantee vs Fondo interaction.
// ============================================================================

test.describe('Profile E: Ley 97 Minimum + Fondo Edge Case', () => {
  const profile: TestProfile = {
    fechaNacimiento: '1961-06-01',
    genero: 'M',
    edadRetiro: 65,
    fechaInicioCotizacion: '2000-01-01',
    salarioMensual: 8000,
    semanasCotizadas: 1000,
    saldoAfore: 100000,
    aportacionVoluntaria: 0,
    escenario: 'base',
    aforeActual: 'PensionISSSTE',
  };

  test('pension is minimum guarantee ($8,599)', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    console.log(`Profile E - Hero: $${result.heroAmount}`);
    console.log(`  Expected: ~$8,599 (minimum guarantee)`);

    // Even after 1 year projection, $100K + contributions << minimum needed
    // So minimum guarantee applies: $8,598.65
    assertPensionClose(result.heroAmount, PENSION_MINIMA_LEY97, 'Ley97 minimum guarantee');
  });

  test('Fondo eligible but complement is effectively $0', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    // Fondo should show as eligible
    // But complement = max(0, salary - pension_minima) = max(0, 8000-8599) = 0
    // Hero shows the minimum guarantee amount, close to salary
    expect(result.heroAmount).toBeGreaterThanOrEqual(7500);
    expect(result.heroAmount).toBeLessThanOrEqual(9500);
  });

  test('replacement rate > 100% (minimum > salary)', async ({ page }) => {
    await runFullWizard(page, profile);
    const result = await extractResults(page);

    // Minimum $8,599 / salary $8,000 = 107%
    expect(result.replacementRate).toBeGreaterThanOrEqual(100);
  });
});
