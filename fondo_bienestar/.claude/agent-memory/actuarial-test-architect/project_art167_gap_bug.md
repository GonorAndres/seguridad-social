---
name: Art 167 and Reform Bracket Gap Bug
description: CSV-encoded bracket boundaries have gaps (1.00 vs 1.01) causing workers at exact boundaries to get wrong rates
type: project
---

Art. 167 table and DOF 2020 reform rate table both have gaps between consecutive brackets in the CSV encoding (e.g., row 1 ends at 1.00 SM, row 2 starts at 1.01 SM). A grupo_salarial of 1.005 falls in neither bracket.

- Art. 167: lookup_articulo_167 defaults to first row (cuantia=0.80), giving a slightly HIGHER pension than intended.
- Reform rates: find_reforma_bracket_idx defaults to LAST row (4.01+ UMA, highest bracket), giving significantly HIGHER contribution rates than intended for workers near low-salary boundaries.

**Why:** The LSS Art. 167 uses "hasta" (up to) language, suggesting contiguous brackets. The gap is a CSV encoding artifact.

**How to apply:** When modifying Art. 167 or reform rate logic, consider fixing bracket boundaries to be contiguous. Tests in test_actuarial_edge_cases.R document current behavior at gap values (EC-A and EC-F sections).
