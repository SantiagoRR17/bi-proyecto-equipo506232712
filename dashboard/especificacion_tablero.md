# Tablero (Power BI Desktop) — especificación para construirlo

Este documento define el modelo, las medidas, las 5 páginas, los visuales y los filtros. El `.pbix` y las capturas se generan en Power BI Desktop (aquí no se puede abrir), así que **ninguna cifra de este documento se ha visto aún en Power BI**: las cifras salen de `consultas_tablero.sql` ejecutado sobre un DW cargado con las reglas del ETL, y deben coincidir con lo que muestre el tablero.

Archivos: `medidas.dax` (medidas), `consultas_tablero.sql` (verificación Q01–Q17), `borrador_seccion4.md` (tablas 4.1, 4.2 y 4.4 del informe).

## 1. Conexión y modelo (indicador T1)

1. Power BI Desktop → Obtener datos → **Base de datos PostgreSQL** → servidor `localhost`, base `observatorio_bi`, modo **Importar** (usuario de solo lectura si lo tienen; la contraseña no se guarda en el repositorio).
2. Cargar las 8 tablas del esquema `dw`: `dim_tiempo`, `dim_localidad`, `dim_tipo_alojamiento`, `dim_tipo_hurto`, `dim_caracteristica_hurto`, `fact_dinamica_empresarial`, `fact_alojamiento`, `fact_hurtos`. **No** importar archivos de las fuentes (la rúbrica lo penaliza).
3. Relaciones (muchos a uno, dirección única, de hecho a dimensión). Verificar en la vista Modelo que Power BI las detectó:

| Hecho | Llave | Dimensión |
|---|---|---|
| fact_dinamica_empresarial | sk_localidad, sk_tiempo | dim_localidad, dim_tiempo |
| fact_alojamiento | sk_localidad, sk_tiempo, sk_tipo_alojamiento | dim_localidad, dim_tiempo, dim_tipo_alojamiento |
| fact_hurtos | sk_tiempo, sk_localidad, sk_tipo_hurto, sk_caracteristica | dim_tiempo, dim_localidad, dim_tipo_hurto, dim_caracteristica_hurto |

4. `dim_tiempo`: marcar como **tabla de fechas** (columna `fecha`); ordenar `mes` por `numero_mes`; agregar la columna calculada `MesKey` (ver `medidas.dax`). Ocultar las columnas `sk_*` y las de hechos que no se usen directamente.
5. Crear la tabla `_Medidas` y pegar las medidas de `medidas.dax`. Formato: porcentajes con 1 decimal, enteros con separador de miles.

## 2. Páginas y visuales

Convenciones: títulos que dicen qué muestra y la unidad; ejes con título y unidad; sin 3D, sin imágenes ni formas decorativas; un solo color de acento más gris. Las notas de cobertura van en el **subtítulo** de cada visual, no en cuadros de texto aparte.

### Página 1 · Panorama de Bogotá (P0)

| Visual | Tipo | Campos | Título (texto exacto sugerido) | Referencia / justificación |
|---|---|---|---|---|
| 1.1 | KPI | Indicador `[Empresas vigentes]`, objetivo `[Empresas corte anterior]` | «Empresas vigentes (último corte) frente al corte anterior» | I1. KPI porque la pregunta es «¿cuánto y cómo cambió?» con una sola cifra y su referencia |
| 1.2 | KPI | `[Establecimientos vigentes]`, objetivo `[Establecimientos corte anterior]` | «Establecimientos vigentes (último corte) frente al corte anterior» | I2. Subtítulo: «2023 no disponible en la fuente» |
| 1.3 | KPI | `[Promedio mensual hurtos]`, objetivo `[Promedio mensual hurtos histórico]` | «Promedio mensual de hurtos (registros/mes) frente al promedio histórico» | I4. Subtítulo: «2026 parcial: enero a julio» |
| 1.4 | Tarjeta | `[Alojamientos]` | «Alojamientos inscritos en el RNT (corte 22/10/2026)» | Un solo corte: no hay evolución |
| 1.5 | Columnas | Eje `dim_tiempo[fecha]` (formato mmm-aaaa, filtro visual `[Empresas vigentes]` no está en blanco), valores `[Empresas vigentes]`; etiquetas de datos | «Empresas vigentes por corte de medición (número de empresas)» | Columnas: tres cortes puntuales, no serie continua; las barras evitan sugerir continuidad |
| 1.6 | Líneas | Eje `dim_tiempo[anio]`, valores `[Hurtos registros]` | «Hurtos registrados por año (registros; 2026 parcial: ene–jul)» | Línea: serie anual continua de 2010 a 2026 |

Segmentadores: Año (`dim_tiempo[anio]`) y Localidad (`dim_localidad[nombre_localidad]`).

### Página 2 · Actividad empresarial por localidad (P1)

| Visual | Tipo | Campos | Título | Justificación |
|---|---|---|---|---|
| 2.1 | Barras horizontales (ordenadas) | Eje localidad, valor `[Empresas vigentes]` | «Empresas vigentes por localidad en el último corte (número de empresas)» | Compara magnitudes entre 20 categorías con nombres largos |
| 2.2 | Columnas agrupadas | Eje localidad (Top 10 por empresas), leyenda `dim_tiempo[fecha]`, valor `[Empresas vigentes]` | «Empresas vigentes por localidad y corte, 10 mayores (número de empresas)» | Muestra la evolución por corte dentro de cada localidad |
| 2.3 | Tabla | Localidad, `[Empresas vigentes]`, `[Variación empresas %]`, `[Establecimientos vigentes]`, `[Variación establecimientos %]`; barras de datos en variaciones | «Empresas y establecimientos por localidad y variación frente al corte anterior (%)» | Tabla: lectura de valores exactos y de las dos variaciones a la vez |

Segmentadores: Año y Localidad (sincronizados con la página 1).

### Página 3 · Alojamiento turístico por localidad (P2)

| Visual | Tipo | Campos | Título | Justificación |
|---|---|---|---|---|
| 3.1 | Barras horizontales + **línea de promedio** (panel Análisis → Línea de promedio) | Eje localidad, valor `[Alojamientos]` | «Alojamientos por localidad frente al promedio (número de establecimientos)» | I3. Referencia: promedio por localidad con alojamientos (≈49,4) |
| 3.2 | Barras horizontales | Eje `dim_tipo_alojamiento[cod_subcategoria]`, valor `[Alojamientos]` | «Alojamientos por código de subcategoría RNT (SUBCATRNT; sin nombres verificados)» | Categorías nominales sin orden; el código se muestra tal cual porque el diccionario no permite nombrarlas |
| 3.3 | Tarjeta | `[Localidades sin alojamientos]` | «Localidades sin ningún alojamiento registrado» | Cobertura de la fuente (Ciudad Bolívar, San Cristóbal, Sumapaz) |
| 3.4 | Tarjeta | `[Participación alojamientos %]` | «Participación de la selección en el total de alojamientos (%)» | Con una localidad seleccionada muestra su peso |

Segmentadores: Localidad, Subcategoría (`dim_tipo_alojamiento[cod_subcategoria]`) y Año sincronizado (la fuente tiene un solo corte, 2026: con otro año los visuales quedan en blanco; decirlo en el subtítulo).

### Página 4 · Hurtos por modalidades (P3)

| Visual | Tipo | Campos | Título | Justificación |
|---|---|---|---|---|
| 4.1 | Líneas | Eje `dim_tiempo[fecha]` (jerarquía a mes), valor `[Hurtos registros]` | «Hurtos registrados por mes (registros/mes)» | Evolución temporal continua |
| 4.2 | Columnas apiladas | Eje `dim_tiempo[anio]`, leyenda `dim_tipo_hurto[descripcion_tipo]`, valor `[Hurtos registros]` | «Hurtos por año y tipo de hurto (registros; residencias desde 2024)» | Apiladas: total anual y composición por tipo |
| 4.3 | Barras horizontales | Eje `dim_caracteristica_hurto[arma_medio]`, valor `[Hurtos registros]` | «Hurtos por arma o medio (registros)» | Compara categorías nominales |
| 4.4 | Barras agrupadas | Eje `dim_caracteristica_hurto[grupo_etario]`, leyenda `genero`, valor `[Hurtos registros]` | «Hurtos por grupo etario y género (registros; SIN DATO = vacío en la fuente)» | Muestra que la mayoría no tiene género; no se imputa |
| 4.5 | Barras horizontales | Eje localidad, valor `[Hurtos registros]` | «Hurtos por localidad (registros; localidad asignada por el equipo, dato simulado)» | La advertencia va en el título |

Segmentadores: Año, Localidad y Tipo de hurto (`dim_tipo_hurto[descripcion_tipo]`).

### Página 5 · Comparación descriptiva (P4)

| Visual | Tipo | Campos | Título | Justificación |
|---|---|---|---|---|
| 5.1 | Líneas (2 series) | Eje `dim_tiempo[anio]` (filtro visual 2023–2025), valores `[Índice empresas (2023=100)]` y `[Índice hurtos (2023=100)]` | «Empresas vigentes y hurtos, índice con base 2023 = 100 (sin implicar causalidad)» | Un índice pone en la misma escala magnitudes distintas (cortes puntuales vs. años) |
| 5.2 | Tabla con barras de datos | Localidad, `[Empresas vigentes]`, `[Alojamientos]`, `[Hurtos registros]` | «Empresas, alojamientos y hurtos por localidad (valores absolutos del periodo seleccionado)» | Comparación lado a lado, valores exactos |

Segmentadores: Año y Localidad.

## 3. Filtros (indicador T7)

| Segmentador | Campo | Páginas | Observación |
|---|---|---|---|
| Año | `dim_tiempo[anio]` | 1, 2, 3, 4, 5 (sincronizado) | En la página 3 solo 2026 devuelve datos |
| Localidad | `dim_localidad[nombre_localidad]` | 1, 2, 3, 4, 5 (sincronizado) | Incluye «SIN LOCALIDAD» (código 21 de F3) |
| Tipo de hurto | `dim_tipo_hurto[descripcion_tipo]` | 4 | |
| Subcategoría RNT | `dim_tipo_alojamiento[cod_subcategoria]` | 3 | |

Verificar que ningún visual tenga «Editar interacciones» desactivado frente a un segmentador de su página.

## 4. Advertencias que deben quedar visibles en el informe

- `LOCALIDAD` de hurtos es simulada (reparto parejo): las 20 localidades tienen 8.838–8.839 registros. No sacar conclusiones territoriales de la página 4 (visual 4.5) ni de la columna de hurtos de la 5.2.
- Los cortes de F3 no son una serie continua y no son equidistantes (sep-2023, mar-2024, jul-2025).
- «Sin localidad» (código 21 de F3) entra en los totales de empresas; en 2025 tiene 19.987 empresas.
- Establecimientos 2023 no existe en la fuente.
- 2026 es parcial (ene–jul). El salto de 2016 (4.372) a 2017 (16.730) no se interpreta como cambio real sin validar la cobertura de la fuente.
- Alojamientos: un solo corte; no hay evolución.

## 5. Entregables del tablero en el repositorio

`dashboard/` debe contener el `.pbix` y **una captura legible por página** (5). Las mismas capturas van en la sección 4.3 del informe. Nombre sugerido: `pagina1_panorama.png`, … `pagina5_comparacion.png`.
