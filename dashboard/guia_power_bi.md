# Guía paso a paso: construir el tablero en Power BI Desktop

Requisito previo: el job de PDI ya se ejecutó y la conciliación dio `CONCILIACION OK` (ver `etl/guia_ejecucion_pdi.md`).
Esta guía arma el `.pbix` paso a paso. Los detalles de cada visual están en `dashboard/especificacion_tablero.md`, las medidas en `dashboard/medidas.dax` y las cifras de control en `dashboard/consultas_tablero.sql`.

> **Aviso:** el diseño y las medidas no se han probado en Power BI (aquí no se puede abrir). Si una medida da un valor distinto al de su consulta SQL, avisen cuál y se corrige.

---

## 0. Qué necesitan

- Power BI Desktop (descarga gratuita de Microsoft), versión reciente.
- La base `observatorio_bi` cargada y PostgreSQL encendido.
- Un usuario de PostgreSQL con permiso de lectura sobre el esquema `dw` (puede ser `postgres`).
- Si Power BI pide «Npgsql» al conectar, instalen el proveedor Npgsql (versión 4.0.x o la que indique el mensaje) y reinicien Power BI.

## 1. Conectar con el data warehouse (rúbrica T1)

1. *Inicio → Obtener datos → Más… → Base de datos → **Base de datos PostgreSQL** → Conectar*.
2. Servidor: `localhost:5432` (o `localhost`). Base de datos: `observatorio_bi`. Modo: **Importar**. Aceptar.
3. Credenciales, pestaña *Base de datos*: usuario y contraseña. (La contraseña no queda en el archivo para quien lo abra.)
4. En el *Navegador*, expandan `dw` y marquen las **8 tablas**: `dim_tiempo`, `dim_localidad`, `dim_tipo_alojamiento`, `dim_tipo_hurto`, `dim_caracteristica_hurto`, `fact_dinamica_empresarial`, `fact_alojamiento`, `fact_hurtos`. No marquen nada del esquema `stg`. Clic en **Cargar**.
5. **No importen** los CSV/GeoJSON/GPKG de las fuentes: la rúbrica exige que el tablero use las tablas `dim_*` y `fact_*`.

Comprobación: en la vista *Datos* (icono de tabla) revisen los conteos: `fact_hurtos` 176.776 filas, `fact_alojamiento` 839, `fact_dinamica_empresarial` 60, `dim_tiempo` 6.209.

## 2. Revisar el modelo

1. Vista *Modelo* (icono de diagrama). Power BI suele crear solo las relaciones por nombre de columna. Deben existir exactamente estas (muchos a uno `*:1`, dirección de filtro **única**, activas):

| Desde (hecho) | Hasta (dimensión) |
|---|---|
| `fact_dinamica_empresarial[sk_localidad]` | `dim_localidad[sk_localidad]` |
| `fact_dinamica_empresarial[sk_tiempo]` | `dim_tiempo[sk_tiempo]` |
| `fact_alojamiento[sk_localidad]` | `dim_localidad[sk_localidad]` |
| `fact_alojamiento[sk_tiempo]` | `dim_tiempo[sk_tiempo]` |
| `fact_alojamiento[sk_tipo_alojamiento]` | `dim_tipo_alojamiento[sk_tipo_alojamiento]` |
| `fact_hurtos[sk_tiempo]` | `dim_tiempo[sk_tiempo]` |
| `fact_hurtos[sk_localidad]` | `dim_localidad[sk_localidad]` |
| `fact_hurtos[sk_tipo_hurto]` | `dim_tipo_hurto[sk_tipo_hurto]` |
| `fact_hurtos[sk_caracteristica]` | `dim_caracteristica_hurto[sk_caracteristica]` |

2. Si falta alguna: arrastren la columna del hecho sobre la de la dimensión. Si hay relaciones entre hechos o bidireccionales, bórrenlas.
3. `dim_tiempo`: clic derecho → *Marcar como tabla de fechas* → columna `fecha`.
4. `dim_tiempo[mes]`: seleccionar la columna → *Herramientas de columna → Ordenar por columna* → `numero_mes`.
5. Nueva columna en `dim_tiempo` (*Herramientas de tabla → Nueva columna*):
   `MesKey = dim_tiempo[anio] * 100 + dim_tiempo[numero_mes]`
6. Ocultar (clic derecho → *Ocultar en la vista de informe*) las columnas `sk_*` de todas las tablas y las columnas numéricas de los hechos que se usan solo mediante medidas.

## 3. Crear las medidas

1. *Inicio → Especificar datos* → una tabla de una columna con cualquier valor, nombrada `_Medidas` → *Cargar*.
2. Con `_Medidas` seleccionada: *Nueva medida*, una por cada bloque de `dashboard/medidas.dax` (16 medidas). Pegar el texto **desde el nombre de la medida** (sin las líneas que empiezan con `//`).
3. Formatos (*Herramientas de medida*): `…%` con 1 decimal en las variaciones y `Participación alojamientos %`; números enteros con separador de miles en los demás; `Promedio mensual hurtos` con 1 decimal; índices con 1 decimal.

### 3.1 Verificar las medidas antes de graficar
Cree una página temporal con una tarjeta por medida (sin filtros) y compare con los valores de `consultas_tablero.sql` (ejecutarlo en pgAdmin/psql):

| Medida (sin filtros) | Debe dar | Consulta |
|---|---|---|
| Empresas vigentes | 378.759 | Q01 (corte jul-2025) |
| Empresas corte anterior | 450.376 | Q01 |
| Variación empresas % | −15,9 % | Q01 |
| Establecimientos vigentes | 221.444 | Q02 |
| Establecimientos corte anterior | 257.751 | Q02 |
| Variación establecimientos % | −14,1 % | Q02 |
| Alojamientos | 839 | Q03 |
| Alojamientos promedio por localidad | 49,4 | Q03 |
| Localidades sin alojamientos | 3 | Q10 |
| Hurtos registros | 176.776 | Q05 |
| Promedio mensual hurtos | 888,3 | Q04 |
| Promedio mensual hurtos histórico | 888,3 | Q04 |
| Índice hurtos (2023=100) con `anio` = 2024 | 146,4 | Q16 |

Si alguno no coincide, **no sigan**: revisen relaciones y la fórmula. Después borren la página temporal.

## 4. Construir las 5 páginas

Siempre: *Formato → Título* con el texto de la especificación; ejes con título y unidad; sin 3D; un color de acento más gris. Las notas de cobertura van en el **subtítulo** del visual.

### Página 1 · «Panorama de Bogotá»
1. Insertar **KPI** ×3: (1.1) Indicador `Empresas vigentes`, Objetivo `Empresas corte anterior`; (1.2) `Establecimientos vigentes` / `Establecimientos corte anterior`; (1.3) `Promedio mensual hurtos` / `Promedio mensual hurtos histórico`. Ejes de tendencia: dejar vacíos.
2. **Tarjeta** (1.4): `Alojamientos`.
3. **Columnas agrupadas** (1.5): Eje `dim_tiempo[fecha]`; Valores `Empresas vigentes`. Panel *Filtros* → en el visual → `Empresas vigentes` → «no está en blanco». Formato del eje X: texto/«mmm-aaaa».
4. **Gráfico de líneas** (1.6): Eje `dim_tiempo[anio]`; Valores `Hurtos registros`.
5. **Segmentadores**: `dim_tiempo[anio]` (lista) y `dim_localidad[nombre_localidad]` (lista desplegable).

### Página 2 · «Actividad empresarial por localidad»
1. **Barras agrupadas horizontales** (2.1): Eje `dim_localidad[nombre_localidad]`, Valores `Empresas vigentes`; ordenar por valor descendente.
2. **Columnas agrupadas** (2.2): Eje `nombre_localidad`; Leyenda `dim_tiempo[fecha]`; Valores `Empresas vigentes`; filtro visual *N superior* = 10 por `Empresas vigentes`.
3. **Tabla** (2.3): `nombre_localidad`, `Empresas vigentes`, `Variación empresas %`, `Establecimientos vigentes`, `Variación establecimientos %`; barras de datos en las dos variaciones (*Formato condicional*).
4. Segmentadores: sincronizados con la página 1 (ver 5).

### Página 3 · «Alojamiento turístico por localidad»
1. **Barras horizontales** (3.1): Eje `nombre_localidad`, Valores `Alojamientos`; panel *Análisis* → *Línea de promedio* → Activar (etiqueta «Promedio por localidad»).
2. **Barras horizontales** (3.2): Eje `dim_tipo_alojamiento[cod_subcategoria]`, Valores `Alojamientos`.
3. **Tarjetas** (3.3 y 3.4): `Localidades sin alojamientos` y `Participación alojamientos %`.
4. Segmentadores: Localidad y Año (sincronizados) y `dim_tipo_alojamiento[cod_subcategoria]`.

### Página 4 · «Hurtos por modalidades»
1. **Líneas** (4.1): Eje `dim_tiempo[fecha]` con jerarquía en *Mes* (bajar un nivel); Valores `Hurtos registros`.
2. **Columnas apiladas** (4.2): Eje `dim_tiempo[anio]`; Leyenda `dim_tipo_hurto[descripcion_tipo]`; Valores `Hurtos registros`.
3. **Barras horizontales** (4.3): Eje `dim_caracteristica_hurto[arma_medio]`; Valores `Hurtos registros`.
4. **Barras agrupadas** (4.4): Eje `dim_caracteristica_hurto[grupo_etario]`; Leyenda `genero`; Valores `Hurtos registros`.
5. **Barras horizontales** (4.5): Eje `nombre_localidad`; Valores `Hurtos registros`; título con la advertencia de dato simulado.
6. Segmentadores: Año, Localidad (sincronizados) y `dim_tipo_hurto[descripcion_tipo]`.

### Página 5 · «Comparación descriptiva»
1. **Líneas** (5.1): Eje `dim_tiempo[anio]` con filtro visual `anio` entre 2023 y 2025; Valores `Índice empresas (2023=100)` y `Índice hurtos (2023=100)`.
2. **Tabla** (5.2): `nombre_localidad`, `Empresas vigentes`, `Alojamientos`, `Hurtos registros`; barras de datos.
3. Segmentadores: Año y Localidad (sincronizados).

## 5. Sincronizar segmentadores (rúbrica T7)

1. *Vista → Sincronizar segmentadores*.
2. Seleccionar el segmentador de **Año** → marcar las 5 páginas en *Sincronizar* y *Visible* → repetir con **Localidad**.
3. Cada segmentador debe afectar a todos los visuales de su página. Verificar con *Formato → Editar interacciones* que ninguno quede desactivado.
4. Prueba: elegir Localidad = CHAPINERO y revisar que cambien los visuales de las 5 páginas (con alojamientos = 160).

## 6. Revisar contra la rúbrica antes de guardar

| Indicador | Qué comprobar |
|---|---|
| T1 | Todas las tablas vienen de PostgreSQL (`dim_*`, `fact_*`); ninguna de archivos |
| T2 | Cada pregunta P0–P4 tiene su visual (ver `borrador_seccion4.md`, tabla 4.2) |
| T3 | Las cifras escritas en 4.2 son las del tablero |
| T4 | Hay ≥ 3 indicadores con fórmula documentada (tabla 4.1) |
| T5 | Cada indicador se ve frente a una referencia (KPI con objetivo; línea de promedio en 3.1) |
| T6 | Cada tipo de gráfico está justificado en 4.2 |
| T7 | Filtros de Año (tiempo) y Localidad que actúan en todos los visuales de cada página |
| T8 | Todos los visuales tienen título, ejes con unidad; sin 3D ni decoraciones |

## 7. Guardar y capturar

1. *Archivo → Guardar como* → `dashboard\Tablero_Observatorio_BI.pbix` dentro del repositorio.
2. Una captura **legible** por página (Windows: `Win + Shift + S`, o *Archivo → Exportar → PDF* y recortar). Nombres: `pagina1_panorama.png`, `pagina2_empresas.png`, `pagina3_alojamiento.png`, `pagina4_hurtos.png`, `pagina5_comparacion.png` en `dashboard\`.
3. Inserten las mismas capturas en la sección 4.3 del informe.
4. Completen 4.1, 4.2 y 4.4 con `borrador_seccion4.md`, **sustituyendo cada cifra por la que muestra su tablero** si difiere.
5. El `.pbix` guarda una copia de los datos. Si pesa mucho para GitHub (> 50 MB), avisen: se revisa qué hacer.

## 8. Si algo falla

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| No conecta a PostgreSQL | Servicio apagado, puerto distinto o falta Npgsql | Revisar servicio y puerto; instalar Npgsql |
| «Empresas vigentes» muestra la suma de los 3 cortes (1.229.212) | Se usó `SUM` simple en vez de la medida | Usar la medida de `medidas.dax` |
| KPI en blanco | Falta la relación hecho→`dim_tiempo` o la medida de referencia | Revisar relaciones y que el objetivo sea la medida correcta |
| Todo se ve igual al elegir una localidad | Relación inactiva o con `dim_localidad` ausente | Revisar la vista Modelo |
| La página 3 queda en blanco al elegir un año | Alojamiento solo tiene corte 2026 | Es lo esperado; elegir 2026 o limpiar el filtro |
| Los meses salen en orden alfabético | Falta «Ordenar por columna» | Paso 2.4 |
| Una medida da error de sintaxis | Se pegó el comentario `//` o falta el nombre | Pegar desde el nombre de la medida |
| Hurtos por localidad idénticos | Es el efecto del reparto simulado | Es lo esperado; ya está advertido en el título |
