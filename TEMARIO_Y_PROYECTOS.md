# Seguridad Social - Temario UNAM Actuaria + Temas Actualizados

## Temario Tradicional (Curso Seguridad Social - Facultad de Ciencias UNAM)

### Unidad 1: Fundamentos de la Seguridad Social
- Concepto y principios de la seguridad social
- Diferencia entre seguridad social y seguro social
- Antecedentes historicos en Mexico y el mundo
- Marco juridico constitucional (Art. 123)

### Unidad 2: Sistema de Seguridad Social Mexicano
- Instituto Mexicano del Seguro Social (IMSS)
- Instituto de Seguridad y Servicios Sociales de los Trabajadores del Estado (ISSSTE)
- Otros sistemas: ISSFAM, PEMEX, CFE, sistemas estatales
- Cobertura y poblacion derechohabiente

### Unidad 3: Regimen de la Ley del Seguro Social
- Ramos de aseguramiento:
  - Riesgos de trabajo
  - Enfermedades y maternidad
  - Invalidez y vida
  - Retiro, cesantia en edad avanzada y vejez (RCV)
  - Guarderias y prestaciones sociales
- Regimen obligatorio vs voluntario
- Cuotas obrero-patronales y aportaciones del Estado

### Unidad 4: Sistemas de Pensiones
- Sistema de reparto (Ley 1973)
- Sistema de capitalizacion individual (Ley 1997)
- Comparativo entre ambos sistemas
- Modalidades de pension: renta vitalicia, retiro programado
- Pension minima garantizada

### Unidad 5: Sistema de Ahorro para el Retiro (SAR)
- CONSAR: funciones y regulacion
- AFOREs: estructura, funcionamiento, comisiones
- SIEFORES: politicas de inversion, regimen de inversion
- Cuenta individual: subcuentas, aportaciones voluntarias
- Semanas de cotizacion y requisitos de pension

### Unidad 6: Valuacion Actuarial de Sistemas de Seguridad Social
- Metodologia de valuacion actuarial
- Proyecciones demograficas
- Hipotesis actuariales (mortalidad, invalidez, rotacion)
- Calculo de reservas tecnicas
- Equilibrio financiero y sostenibilidad
- Prima media general y prima escalonada

### Unidad 7: ISSSTE y Otros Sistemas
- Ley del ISSSTE (1983 y reforma 2007)
- Regimen de reparto vs cuentas individuales
- Sistema de pension ISSSTE: articulo decimo transitorio
- Pensionissste

---

## Temas Actualizados (2020-2025) - Complementarios

### Reforma de Pensiones 2020 (IMSS)
- Aumento gradual de aportaciones patronales (de 5.15% a 13.87%)
- Reduccion de semanas cotizadas requeridas (1,250 a 1,000)
- Incremento de pension minima garantizada
- Reduccion de comisiones AFORE

### Fondo de Pensiones para el Bienestar (2024)
- Creacion y financiamiento del Fondo
- Beneficiarios: trabajadores con salario <= $16,777.68
- Objetivo: pension del 100% del ultimo salario
- Uso de cuentas inactivas mayores de 70/75 anos
- Evaluacion actuarial cada 8 anos

### Comisiones AFORE 2025
- Nueva tarifa maxima: 0.55% sobre saldo
- Impacto en rendimientos netos
- Comparativo internacional

### Temas Demograficos y Actuariales Criticos
- Envejecimiento poblacional acelerado
- Baja densidad de cotizacion (informalidad laboral)
- Sostenibilidad fiscal del sistema de pensiones
- Desigualdad pensionaria: brecha de genero
- Cobertura universal vs contributiva

---

## Fuentes de Datos Reales Disponibles

| Fuente | URL | Datos |
|--------|-----|-------|
| Datos Abiertos IMSS | http://datos.imss.gob.mx/ | Asegurados, patrones, salarios por estado/sector |
| CONSAR | https://www.consar.gob.mx | AFOREs, comisiones, rendimientos, traspasos |
| Datos Abiertos Mexico | https://datos.gob.mx | Pensiones IMSS/ISSSTE por entidad |
| INEGI | https://www.inegi.org.mx | ENOE, ENIGH, proyecciones poblacionales |
| Banxico | https://www.banxico.org.mx | Tasas de interes, inflacion historica |
| CONAPO | https://www.gob.mx/conapo | Tablas de mortalidad, proyecciones demograficas |

---

## Proyectos Recomendados (Portfolio)

### PROYECTO 1: Simulador de Pension IMSS Ley 97 vs Fondo Bienestar
**Nivel:** Intermedio-Avanzado
**Datos:** CONSAR, INEGI (salarios), Banxico (tasas)
**Tecnologia:** Python + Streamlit o R Shiny

**Descripcion:**
Calculadora interactiva que permita a un usuario ingresar:
- Edad actual, edad de retiro deseada
- Salario base de cotizacion
- Semanas cotizadas actuales
- Saldo actual en AFORE

Y obtenga:
- Proyeccion de saldo al retiro (con diferentes rendimientos)
- Comparativo: pension sin Fondo Bienestar vs con Fondo
- Visualizacion del deficit que cubre el Fondo
- Analisis de sensibilidad (que pasa si cambio AFORE, aporto voluntario, etc.)

**Por que es bueno:**
- Tema de alta relevancia actual (reforma 2024)
- Demuestra conocimiento de legislacion vigente
- Util para cualquier trabajador mexicano
- Combina calculo actuarial + programacion + UX

---

### PROYECTO 2: Dashboard de Sostenibilidad del Sistema de Pensiones Mexicano
**Nivel:** Avanzado
**Datos:** Informes de valuacion actuarial IMSS/ISSSTE, INEGI, CONAPO
**Tecnologia:** Python/R + Tableau/Power BI o Dash

**Descripcion:**
Visualizacion interactiva que muestre:
- Piramide poblacional dinamica (1990-2050)
- Ratio trabajadores activos / pensionados (historico y proyectado)
- Deficit actuarial proyectado bajo diferentes escenarios
- Comparativo con sistemas de otros paises (Chile, USA, Espana)
- Indicadores de alerta temprana

**Por que es bueno:**
- Demuestra comprension profunda de valuacion actuarial
- Tema de interes para policy makers
- Originalidad: pocos recursos publicos muestran esto de forma accesible
- Potencial de difusion academica/mediática

---

### PROYECTO 3: Analisis de Equidad de Genero en Pensiones Mexicanas
**Nivel:** Intermedio
**Datos:** ENIGH, ENOE, datos CONSAR
**Tecnologia:** Python/R para analisis + visualizacion

**Descripcion:**
Estudio cuantitativo que analice:
- Brecha salarial y su impacto en montos de pension
- Diferencias en densidad de cotizacion por genero
- Efecto de lagunas laborales (maternidad, cuidados)
- Simulacion: cuanto perderia una mujer "tipica" vs hombre "tipico"
- Propuestas de politica publica (creditos por cuidados, etc.)

**Por que es bueno:**
- Tema socialmente relevante y poco explorado en Mexico
- Combina analisis actuarial con perspectiva social
- Atractivo para becas, concursos, publicaciones
- Demuestra capacidad de investigacion original

---

### PROYECTO 4: Comparador Inteligente de AFOREs
**Nivel:** Intermedio
**Datos:** CONSAR (comisiones, rendimientos, traspasos)
**Tecnologia:** Python + Web scraping + Dashboard

**Descripcion:**
Herramienta que:
- Actualice automaticamente datos de CONSAR
- Calcule rendimiento neto real (descontando comisiones e inflacion)
- Proyecte saldo a diferentes plazos por AFORE
- Recomiende AFORE segun perfil (edad, tolerancia al riesgo)
- Muestre costo de oportunidad de estar en AFORE suboptima

**Por que es bueno:**
- Utilidad practica inmediata para millones de mexicanos
- Demuestra habilidades de automatizacion y datos
- Potencial de convertirse en producto/servicio real
- Diferenciador: enfoque en rendimiento NETO, no bruto

---

### PROYECTO 5: Modelo de Microsimulacion de Trayectorias Laborales
**Nivel:** Avanzado
**Datos:** ENOE, tablas de mortalidad CONAPO, CONSAR
**Tecnologia:** Python (SimPy o modelo propio)

**Descripcion:**
Simulacion Monte Carlo que:
- Genere 10,000+ trayectorias laborales sinteticas
- Modele transiciones: formal/informal, empleo/desempleo
- Incorpore heterogeneidad: genero, region, sector, educacion
- Proyecte distribucion de pensiones bajo diferentes reformas
- Estime cobertura efectiva del sistema

**Por que es bueno:**
- Metodologia de frontera en analisis de pensiones
- Demuestra capacidad tecnica avanzada
- Resultados publicables en revistas academicas
- Util para evaluar impacto de politicas

---

### PROYECTO 6: Visualizador de Riesgos de Trabajo por Sector/Region
**Nivel:** Basico-Intermedio
**Datos:** Datos abiertos IMSS (riesgos de trabajo)
**Tecnologia:** Python + Folium/Plotly

**Descripcion:**
Mapa interactivo y dashboard que muestre:
- Tasa de incidencia de riesgos de trabajo por estado
- Sectores economicos mas riesgosos
- Evolucion temporal
- Costo promedio por siniestro
- Relacion con prima de riesgo

**Por que es bueno:**
- Tema poco visualizado de forma accesible
- Util para empresas (calculo de primas)
- Util para trabajadores (conocer riesgos)
- Demuestra manejo de datos espaciales

---

## Matriz de Seleccion

| Proyecto | Dificultad | Datos Disponibles | Originalidad | Utilidad Practica | Impacto Portfolio |
|----------|------------|-------------------|--------------|-------------------|-------------------|
| 1. Simulador Pension | Media | Alta | Media | Muy Alta | Alto |
| 2. Dashboard Sostenibilidad | Alta | Media | Alta | Alta | Muy Alto |
| 3. Equidad de Genero | Media | Alta | Muy Alta | Alta | Muy Alto |
| 4. Comparador AFOREs | Media | Muy Alta | Media | Muy Alta | Alto |
| 5. Microsimulacion | Muy Alta | Alta | Muy Alta | Media | Muy Alto |
| 6. Riesgos de Trabajo | Baja | Muy Alta | Alta | Alta | Medio |

---

## Recomendacion Personal

Para un recien egresado que busca **demostrar competencia actuarial + impacto practico**, recomiendo comenzar con:

1. **Proyecto 1 (Simulador)** como proyecto principal - demuestra aplicacion directa
2. **Proyecto 3 (Equidad de Genero)** como proyecto de investigacion - demuestra pensamiento critico

Ambos son viables con datos publicos, tienen relevancia social, y no requieren acceso a datos privados.

---

## Referencias

- [CONSAR - Reforma de Pensiones](https://www.gob.mx/consar/articulos/reforma-a-la-ley-del-seguro-social-y-a-la-ley-del-sar)
- [Datos Abiertos IMSS](http://datos.imss.gob.mx/)
- [Ley del Seguro Social](https://www.diputados.gob.mx/LeyesBiblio/pdf/LISSSTE.pdf)
- [Fondo de Pensiones para el Bienestar](https://www.dof.gob.mx/nota_detalle.php?codigo=5725285&fecha=01/05/2024)
- [Analisis academico UNAM](https://www.scielo.org.mx/scielo.php?script=sci_arttext&pid=S1405-74252023000100029)
