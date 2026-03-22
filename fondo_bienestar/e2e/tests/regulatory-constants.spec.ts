import { test, expect } from '@playwright/test';
import {
  DIAS_POR_MES,
  UMA_DIARIA_2025,
  UMA_MENSUAL_2025,
  SM_DIARIO_2025,
  PENSION_MINIMA_LEY97,
  TOPE_SBC_DIARIO,
  UMBRAL_FONDO_2025,
  FACTORES_CESANTIA,
  getSemanasMinLey97,
} from '../helpers/constants';
import { ART_167_TABLE, lookupArticulo167 } from '../helpers/art167-table';

// ============================================================================
// REGULATORY CONSTANTS VALIDATION
// ============================================================================
// Verify that the constants used in the hand calculator match the
// latest Mexican regulatory values (2025).
//
// Sources:
//   UMA: INEGI / DOF (published annually, January)
//   SM: CONASAMI (published annually, December)
//   Fondo: DOF 01/05/2024 + IMSS annual adjustment
//   Tope: LSS Art. 28 (25 UMA)
//   Art. 167: LSS (unchanged since 1995)
//   Factores cesantia: LSS Art. 171
// ============================================================================

test.describe('Regulatory Constants 2025', () => {
  test('UMA 2025 values (INEGI/DOF)', () => {
    // UMA diaria 2025: $113.14 (DOF 10/01/2025)
    expect(UMA_DIARIA_2025).toBe(113.14);
    // UMA mensual = UMA diaria * 30.4 (INEGI standard)
    expect(UMA_MENSUAL_2025).toBe(3439.46);
  });

  test('Salario Minimo 2025 (CONASAMI)', () => {
    // SM diario 2025: $278.80 (CONASAMI, effective 01/01/2025)
    expect(SM_DIARIO_2025).toBe(278.80);
  });

  test('DIAS_POR_MES actuarial standard', () => {
    // 365.25 / 12 = 30.4375 (actuarial standard, accounts for leap years)
    expect(DIAS_POR_MES).toBeCloseTo(365.25 / 12, 4);
    expect(DIAS_POR_MES).toBe(30.4375);
  });

  test('Pension Minima Garantizada Ley 97 = 2.5 UMA mensuales', () => {
    // DOF reform: minimum pension = 2.5 * UMA mensual
    const calculated = 2.5 * UMA_MENSUAL_2025;
    expect(PENSION_MINIMA_LEY97).toBeCloseTo(calculated, 2);
    expect(PENSION_MINIMA_LEY97).toBeCloseTo(8598.65, 2);
  });

  test('Tope SBC = 25 UMA diarias (LSS Art. 28)', () => {
    const calculated = 25 * UMA_DIARIA_2025;
    expect(TOPE_SBC_DIARIO).toBeCloseTo(calculated, 2);
    expect(TOPE_SBC_DIARIO).toBeCloseTo(2828.50, 2);
  });

  test('Fondo Bienestar threshold 2025', () => {
    // IMSS published: promedio SBC for Fondo eligibility
    expect(UMBRAL_FONDO_2025).toBe(17364);
  });
});

test.describe('Cesantia Age Factors (LSS Art. 171)', () => {
  test('factor progression 60->65', () => {
    // Art. 171: Cesantia factors decrease for earlier retirement
    expect(FACTORES_CESANTIA[60]).toBe(0.75);
    expect(FACTORES_CESANTIA[61]).toBe(0.80);
    expect(FACTORES_CESANTIA[62]).toBe(0.85);
    expect(FACTORES_CESANTIA[63]).toBe(0.90);
    expect(FACTORES_CESANTIA[64]).toBe(0.95);
    expect(FACTORES_CESANTIA[65]).toBe(1.00);
  });

  test('factors are monotonically increasing', () => {
    for (let age = 60; age < 65; age++) {
      expect(FACTORES_CESANTIA[age]).toBeLessThan(FACTORES_CESANTIA[age + 1]);
    }
  });

  test('5% increment per year', () => {
    for (let age = 60; age < 65; age++) {
      const diff = FACTORES_CESANTIA[age + 1] - FACTORES_CESANTIA[age];
      expect(diff).toBeCloseTo(0.05, 2);
    }
  });
});

test.describe('Transitional Minimum Weeks (DOF 16/12/2020)', () => {
  test('base 750 weeks in 2021', () => {
    expect(getSemanasMinLey97(2021)).toBe(750);
  });

  test('+25 per year schedule', () => {
    expect(getSemanasMinLey97(2022)).toBe(775);
    expect(getSemanasMinLey97(2023)).toBe(800);
    expect(getSemanasMinLey97(2024)).toBe(825);
    expect(getSemanasMinLey97(2025)).toBe(850);
    expect(getSemanasMinLey97(2026)).toBe(875);
    expect(getSemanasMinLey97(2027)).toBe(900);
    expect(getSemanasMinLey97(2028)).toBe(925);
    expect(getSemanasMinLey97(2029)).toBe(950);
    expect(getSemanasMinLey97(2030)).toBe(975);
  });

  test('cap at 1000 weeks in 2031+', () => {
    expect(getSemanasMinLey97(2031)).toBe(1000);
    expect(getSemanasMinLey97(2035)).toBe(1000);
    expect(getSemanasMinLey97(2050)).toBe(1000);
  });

  test('pre-2021: base 750', () => {
    expect(getSemanasMinLey97(2020)).toBe(750);
    expect(getSemanasMinLey97(2015)).toBe(750);
  });
});

test.describe('Art. 167 Table Structure', () => {
  test('22 salary groups covering 0 to 25 SM', () => {
    expect(ART_167_TABLE).toHaveLength(22);
    expect(ART_167_TABLE[0].grupoMin).toBe(0.00);
    expect(ART_167_TABLE[ART_167_TABLE.length - 1].grupoMax).toBe(25.00);
  });

  test('cuantia basica decreases as salary increases', () => {
    // Higher earners get lower replacement percentages (progressive)
    for (let i = 0; i < ART_167_TABLE.length - 1; i++) {
      expect(ART_167_TABLE[i].cuantiaBasica).toBeGreaterThanOrEqual(
        ART_167_TABLE[i + 1].cuantiaBasica
      );
    }
  });

  test('incremento anual increases as salary increases', () => {
    // Higher earners get larger annual increments (compensating for lower base)
    for (let i = 0; i < ART_167_TABLE.length - 1; i++) {
      expect(ART_167_TABLE[i].incrementoAnual).toBeLessThanOrEqual(
        ART_167_TABLE[i + 1].incrementoAnual
      );
    }
  });

  test('first bracket: 0-1.00 SM, 80% cuantia', () => {
    const { cuantia, incremento } = lookupArticulo167(0.5);
    expect(cuantia).toBe(0.80);
    expect(incremento).toBeCloseTo(0.00563, 5);
  });

  test('last bracket: 6.01-25.00 SM, 13% cuantia', () => {
    const { cuantia, incremento } = lookupArticulo167(10.0);
    expect(cuantia).toBe(0.13);
    expect(incremento).toBeCloseTo(0.02450, 5);
  });

  test('lookup for grupo 1.18 -> bracket [1.01, 1.25]', () => {
    const { cuantia, incremento } = lookupArticulo167(1.18);
    expect(cuantia).toBeCloseTo(0.7711, 4);
    expect(incremento).toBeCloseTo(0.00814, 5);
  });

  test('lookup for grupo 2.36 -> bracket [2.26, 2.50]', () => {
    const { cuantia, incremento } = lookupArticulo167(2.36);
    expect(cuantia).toBeCloseTo(0.3368, 4);
    expect(incremento).toBeCloseTo(0.01868, 5);
  });
});
