// Articulo 167 LSS - Cuantia basica e incremento anual
// Source: data/articulo_167_tabla.csv (22 salary groups)

interface Art167Row {
  grupoMin: number;
  grupoMax: number;
  cuantiaBasica: number;
  incrementoAnual: number;
}

export const ART_167_TABLE: Art167Row[] = [
  { grupoMin: 0.00, grupoMax: 1.00, cuantiaBasica: 0.8000, incrementoAnual: 0.00563 },
  { grupoMin: 1.01, grupoMax: 1.25, cuantiaBasica: 0.7711, incrementoAnual: 0.00814 },
  { grupoMin: 1.26, grupoMax: 1.50, cuantiaBasica: 0.5818, incrementoAnual: 0.01178 },
  { grupoMin: 1.51, grupoMax: 1.75, cuantiaBasica: 0.4923, incrementoAnual: 0.01430 },
  { grupoMin: 1.76, grupoMax: 2.00, cuantiaBasica: 0.4267, incrementoAnual: 0.01615 },
  { grupoMin: 2.01, grupoMax: 2.25, cuantiaBasica: 0.3765, incrementoAnual: 0.01756 },
  { grupoMin: 2.26, grupoMax: 2.50, cuantiaBasica: 0.3368, incrementoAnual: 0.01868 },
  { grupoMin: 2.51, grupoMax: 2.75, cuantiaBasica: 0.3048, incrementoAnual: 0.01958 },
  { grupoMin: 2.76, grupoMax: 3.00, cuantiaBasica: 0.2783, incrementoAnual: 0.02033 },
  { grupoMin: 3.01, grupoMax: 3.25, cuantiaBasica: 0.2560, incrementoAnual: 0.02096 },
  { grupoMin: 3.26, grupoMax: 3.50, cuantiaBasica: 0.2370, incrementoAnual: 0.02149 },
  { grupoMin: 3.51, grupoMax: 3.75, cuantiaBasica: 0.2207, incrementoAnual: 0.02195 },
  { grupoMin: 3.76, grupoMax: 4.00, cuantiaBasica: 0.2065, incrementoAnual: 0.02235 },
  { grupoMin: 4.01, grupoMax: 4.25, cuantiaBasica: 0.1939, incrementoAnual: 0.02271 },
  { grupoMin: 4.26, grupoMax: 4.50, cuantiaBasica: 0.1829, incrementoAnual: 0.02302 },
  { grupoMin: 4.51, grupoMax: 4.75, cuantiaBasica: 0.1730, incrementoAnual: 0.02330 },
  { grupoMin: 4.76, grupoMax: 5.00, cuantiaBasica: 0.1641, incrementoAnual: 0.02355 },
  { grupoMin: 5.01, grupoMax: 5.25, cuantiaBasica: 0.1561, incrementoAnual: 0.02377 },
  { grupoMin: 5.26, grupoMax: 5.50, cuantiaBasica: 0.1488, incrementoAnual: 0.02398 },
  { grupoMin: 5.51, grupoMax: 5.75, cuantiaBasica: 0.1422, incrementoAnual: 0.02416 },
  { grupoMin: 5.76, grupoMax: 6.00, cuantiaBasica: 0.1362, incrementoAnual: 0.02433 },
  { grupoMin: 6.01, grupoMax: 25.00, cuantiaBasica: 0.1300, incrementoAnual: 0.02450 },
];

/**
 * Lookup Art. 167 table by grupo salarial (SBC / SM)
 * Mirrors R/data_tables.R:lookup_articulo_167()
 */
export function lookupArticulo167(grupoSalarial: number): { cuantia: number; incremento: number } {
  const row = ART_167_TABLE.find(
    r => grupoSalarial >= r.grupoMin && grupoSalarial <= r.grupoMax
  );

  if (row) {
    return { cuantia: row.cuantiaBasica, incremento: row.incrementoAnual };
  }

  // Fallback: if above max, use last row; otherwise first row
  // (mirrors R code behavior)
  if (grupoSalarial > ART_167_TABLE[ART_167_TABLE.length - 1].grupoMax) {
    const last = ART_167_TABLE[ART_167_TABLE.length - 1];
    return { cuantia: last.cuantiaBasica, incremento: last.incrementoAnual };
  }
  const first = ART_167_TABLE[0];
  return { cuantia: first.cuantiaBasica, incremento: first.incrementoAnual };
}
