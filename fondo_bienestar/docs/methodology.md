# Metodologia del Simulador de Pension IMSS

## Version 1.0 - Enero 2025

---

## 1. Introduccion

Este documento describe la metodologia utilizada por el Simulador de Pension IMSS + Fondo Bienestar para estimar pensiones bajo los diferentes regimenes del sistema mexicano de seguridad social.

**Proposito:** Proporcionar estimaciones educativas que ayuden a los trabajadores mexicanos a entender y planificar su retiro.

**Alcance:** El simulador cubre:
- Ley 73 (trabajadores que comenzaron a cotizar antes del 1 de julio de 1997)
- Ley 97 (trabajadores que comenzaron a cotizar despues del 1 de julio de 1997)
- Fondo de Pensiones para el Bienestar (2024)

---

## 2. Regimen Ley 73

### 2.1 Descripcion General

La Ley del Seguro Social de 1973 establece un sistema de pension definida donde el monto de la pension depende de:
- Salario Base de Cotizacion promedio
- Semanas cotizadas
- Edad al momento del retiro

### 2.2 Formulas

#### Pension Base

```
Pension_Base = SBC_Promedio × Porcentaje_Art167
```

Donde:
- `SBC_Promedio` = Salario promedio de las ultimas 250 semanas cotizadas
- `Porcentaje_Art167` = Porcentaje segun tabla del Articulo 167 de la LSS 1973

#### Factor de Cesantia

Para retiros anticipados (antes de 65 anos):

| Edad | Factor |
|------|--------|
| 60   | 75%    |
| 61   | 80%    |
| 62   | 85%    |
| 63   | 90%    |
| 64   | 95%    |
| 65+  | 100%   |

#### Pension Final

```
Pension_Final = Pension_Base × Factor_Cesantia
```

### 2.3 Requisitos de Elegibilidad

- Minimo 500 semanas cotizadas
- Edad minima: 60 anos (cesantia) o 65 anos (vejez)
- Haber cotizado antes del 1 de julio de 1997

### 2.4 Tabla del Articulo 167

La tabla establece porcentajes basados en semanas cotizadas y grupos salariales. Los porcentajes van desde aproximadamente 13% (500 semanas, salario alto) hasta 80%+ (2,500+ semanas, salario bajo).

---

## 3. Regimen Ley 97 (AFORE)

### 3.1 Descripcion General

La Ley del Seguro Social de 1997 establece un sistema de cuentas individuales administradas por AFOREs. La pension depende del saldo acumulado al momento del retiro.

### 3.2 Formulas

#### Proyeccion del Saldo

```
Saldo_Final = Saldo_Actual × (1 + r)^n + Σ(Aportaciones_Anuales × (1 + r)^(n-i))
```

Donde:
- `r` = Rendimiento real anual (3-5% segun escenario)
- `n` = Anos hasta el retiro
- `Aportaciones_Anuales` = Aportaciones obligatorias + voluntarias

#### Aportaciones Obligatorias (2025)

| Concepto | Porcentaje del SBC |
|----------|-------------------|
| Patron (RCV) | 5.15% |
| Patron (Cesantia) | 3.15% |
| Trabajador | 1.125% |
| Gobierno | 0.225% |
| **Total** | **9.65%** |

*Nota: Las aportaciones patronales aumentaran gradualmente hasta 2030 segun la reforma de 2020.*

#### Pension Mensual (Retiro Programado)

```
Pension_Mensual = Saldo_Final / (Esperanza_Vida_Meses)
```

La esperanza de vida se toma de tablas actuariales simplificadas basadas en datos de CONAPO.

### 3.3 Requisitos de Elegibilidad

- Minimo 1,000 semanas cotizadas (reducido de 1,250 en la reforma 2020)
- Edad minima: 60 anos (cesantia) o 65 anos (vejez)

### 3.4 Escenarios de Rendimiento

| Escenario | Rendimiento Real | Uso |
|-----------|-----------------|-----|
| Conservador | 3% | Estimacion pesimista |
| Base | 4% | Estimacion central |
| Optimista | 5% | Estimacion optimista |

*Basado en rendimientos historicos de AFOREs (IRN), que han promediado 4-5% real en los ultimos 10 anos.*

---

## 4. Fondo de Pensiones para el Bienestar

### 4.1 Descripcion General

Creado en 2024, este fondo complementa las pensiones de trabajadores con salarios bajos y medios, garantizando hasta el 100% del ultimo salario.

### 4.2 Requisitos de Elegibilidad

1. Edad minima: 65 anos
2. Salario promedio <= Umbral ($17,364/mes en 2025)
3. Pension AFORE < 100% del salario
4. Regimen Ley 97

### 4.3 Calculo del Complemento

```
Complemento = min(Salario - Pension_AFORE, Pension_Garantizada_Maxima)
```

### 4.4 Limitaciones del Modelo

**IMPORTANTE:** El Fondo de Pensiones para el Bienestar es un programa nuevo (2024) con las siguientes incertidumbres:

- Sostenibilidad fiscal a largo plazo no demostrada
- Posibles cambios en requisitos o montos
- Dependencia de decisiones politicas futuras

Por esta razon, el simulador presenta el Fondo como un escenario posible, no como una garantia.

---

## 5. Datos y Fuentes

### 5.1 Constantes 2025

| Parametro | Valor | Fuente |
|-----------|-------|--------|
| UMA Diaria | $113.14 | INEGI / DOF |
| UMA Mensual | $3,439.46 | Calculado |
| Salario Minimo | $278.80/dia | CONASAMI |
| Umbral Fondo Bienestar | $17,364/mes | DOF / IMSS |
| Tope SBC | 25 UMA | LSS |

### 5.2 Fuentes de Datos

1. **Tabla Articulo 167:** Ley del Seguro Social 1973 (texto vigente)
2. **UMA:** Instituto Nacional de Estadistica y Geografia (INEGI)
3. **Salario Minimo:** Comision Nacional de los Salarios Minimos (CONASAMI)
4. **Comisiones AFORE:** Comision Nacional del Sistema de Ahorro para el Retiro (CONSAR)
5. **Mortalidad:** Consejo Nacional de Poblacion (CONAPO), simplificada

---

## 6. Supuestos del Modelo

### 6.1 Supuestos Generales

1. **Continuidad laboral:** Se asume empleo continuo hasta el retiro (densidad de cotizacion 100%)
2. **Salario constante:** El salario se mantiene constante en terminos reales
3. **Inflacion:** No se modela inflacion explicita; todos los valores son reales
4. **Rendimientos:** Se usan rendimientos reales constantes segun escenario

### 6.2 Simplificaciones

1. No se incluyen beneficios adicionales (asignaciones familiares, ayuda asistencial)
2. No se modela la opcion de renta vitalicia (solo retiro programado)
3. La esperanza de vida se basa en tablas simplificadas
4. No se consideran interrupciones laborales futuras

---

## 7. Limitaciones y Disclaimers

### 7.1 Naturaleza Educativa

Este simulador es una **herramienta educativa**. Los resultados son estimaciones basadas en supuestos que pueden no reflejar la realidad individual de cada usuario.

### 7.2 Factores No Modelados

- Cambios futuros en leyes y politicas
- Variabilidad en rendimientos de AFORE
- Interrupciones laborales
- Cambios en esperanza de vida
- Inflacion variable

### 7.3 Recomendaciones

1. Consultar siempre fuentes oficiales (IMSS, CONSAR, AFORE)
2. Revisar el estado de cuenta personal de AFORE
3. Verificar semanas cotizadas en IMSS Digital
4. Considerar asesoria profesional para decisiones importantes

---

## 8. Actualizaciones

| Version | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | Enero 2025 | Version inicial |

---

## 9. Referencias

1. Ley del Seguro Social (1973)
2. Ley del Seguro Social (1997, reformada 2020)
3. Decreto del Fondo de Pensiones para el Bienestar (2024)
4. CONSAR - Indicadores de AFOREs
5. INEGI - Unidad de Medida y Actualizacion
6. CONAPO - Proyecciones de poblacion

---

*Documento actualizado: Enero 2025*
*Simulador de Pension IMSS + Fondo Bienestar v1.0*
