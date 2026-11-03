# ETL con Pentaho Data Integration (PDI)

Carga completa del data warehouse `observatorio_bi` (esquema `dw`, ver `dw/ddl/`).

## Contenido

| Archivo | Qué hace |
|---|---|
| `trabajos/j_carga_dw.kjb` | **Job principal.** Limpia el DW (conserva los miembros -1), ejecuta las 8 transformaciones en orden y calcula variación % y participación %. |
| `transformaciones/t_dim_tiempo.ktr` | Calendario diario 2010-2026 (`generate_series`). |
| `transformaciones/t_dim_localidad.ktr` | 20 localidades desde F4 (`geografia.json`). |
| `transformaciones/t_dim_tipo_alojamiento.ktr` | Subcategorías RNT desde F1 (`turismo.geojson`). |
| `transformaciones/t_dim_tipo_hurto.ktr` | Tipo de hurto → artículo + descripción (F2). |
| `transformaciones/t_dim_caracteristica_hurto.ktr` | Combinaciones arma/medio × género × grupo etario (F2). |
| `transformaciones/t_fact_dinamica_empresarial.ktr` | F3: suma de las capas de detalle `Empresas` y `Establecimientos` por localidad, cortes 2023-09, 2024-03 y 2025-07. |
| `transformaciones/t_fact_alojamiento.ktr` | F1: un registro por `REGNTURISM`. |
| `transformaciones/t_fact_hurtos.ktr` | F2: un registro por fila del CSV de Bogotá. |
| `equivalencias/equivalencia_localidad.csv` | Tabla clave normalizada (código o nombre sin tildes en mayúscula) → `cod_localidad`. Código 21 y «Sin localidad» → 99 (miembro -1). |
| `scripts/asignar_localidad.py` | **Paso 0 (Python).** Agrega la columna `LOCALIDAD` al CSV de la Policía: reparto equitativo y reproducible entre las 20 localidades solo en las 176.776 filas de Bogotá (ver abajo). |
| `reglas_calidad.md` | Correspondencia problema (tabla 2.2) ↔ paso PDI ↔ conteo esperado. |
| `kettle.properties.ejemplo` | Plantilla de variables (sin contraseña real). |

## Requisitos

- PDI (Spoon/Kitchen) 9.x o superior, Java 11 o 17.
- Base creada con `dw/ddl/00` a `02` (el job no crea tablas).
- Controlador JDBC de PostgreSQL (viene con PDI) y **`sqlite-jdbc-*.jar`** en `data-integration/lib/` (para leer los `.gpkg` de F3; GeoPackage es SQLite).
- Iniciar Spoon con `-Dfile.encoding=UTF-8` (tildes del CSV y de las equivalencias). En `spoon.bat`/`spoon.sh`: añadir a `PENTAHO_DI_JAVA_OPTIONS`.

## Configuración

1. Copiar `kettle.properties.ejemplo` a `~/.kettle/kettle.properties` y completar `DB_*`, `RAIZ_REPO`, `ARCHIVO_HURTOS`, `FECHA_CORTE_TURISMO`. Ese archivo **no se sube** al repositorio siguiendo las instrucciones de la entrega.
2. La copia versionada de F2 en `datos/raw/` contiene únicamente las filas de Bogotá, que son las que utiliza el ETL. Generar el CSV con localidad (una sola vez, desde la raíz del repo): `python etl/scripts/asignar_localidad.py`. Escribe `datos/procesado/Reporte_Hurto_Bogota_con_LOCALIDAD.csv` (no se versiona: >50 MB; agregar `datos/procesado/` a `.gitignore`). `ARCHIVO_HURTOS` debe apuntar a ese archivo. Orden esperado: `DEPARTAMENTO, MUNICIPIO, CODIGO DANE, ARMAS MEDIOS, FECHA HECHO, GENERO, GRUPO ETARIO, TIPO DE HURTO, CANTIDAD, LOCALIDAD`. PDI lee este CSV por posición.

## Ejecución

Spoon: abrir `trabajos/j_carga_dw.kjb` y ejecutar. Consola:

```
kitchen.bat /file:"%RAIZ_REPO%/etl/trabajos/j_carga_dw.kjb" /level:Basic
```

El job es re-ejecutable: empieza borrando hechos y dimensiones (excepto los -1).

## Orden y dependencias

`Limpiar DW → dim_tiempo → dim_localidad → dim_tipo_alojamiento → dim_tipo_hurto → dim_caracteristica_hurto → fact_dinamica → fact_alojamiento → fact_hurtos → UPDATE variación/participación → Éxito`. Las dimensiones van antes porque los hechos resuelven las llaves con *Database lookup* (si no hay coincidencia → -1).

## Reglas de calidad

Cada uno de los 15 problemas de la tabla 2.2 de la Entrega 1 tiene un paso con nombre `P01…P15`; los controles adicionales se llaman `C-…`. La correspondencia completa (paso, forma de medir, conteo esperado) está en **`reglas_calidad.md`**. Las reglas hechas en JavaScript escriben su conteo en el log al terminar (`paso | contador: n`); las que descartan filas envían las filas a un paso `Rechazados …` o `Descartados …` (el conteo aparece en *Step Metrics*).

## Cálculos posteriores (SQL en el job)

- `variacion_*_pct`: variación respecto al corte anterior de la misma localidad (`LAG`). Los cortes no son equidistantes (sep-2023, mar-2024, jul-2025): documentarlo en el informe.
- `P10` (duplicados): **no se marcan ni se eliminan** en el DW. `t_fact_hurtos` los *cuenta* en una rama paralela (`P10-F2 Duplicados potenciales (solo conteo; se conservan en el DW)`, esperado 144.063) y la rama principal carga las 176.776 filas. Declarar en el informe que `COUNT(*)` incluye repeticiones posibles de los mismos nueve campos.
- `participacion_pct`: % de alojamientos de la localidad sobre el total; el valor se repite en cada alojamiento de la localidad (en Power BI usar `MAX`/`AVERAGE` por localidad, **no** `SUM`).

## Supuestos y límites (leer antes de ejecutar)


1. **`LOCALIDAD` es un dato simulado**, como declara la Entrega 1 (asignada por el equipo con autorización del docente). El script reparte las 176.776 filas de Bogotá en partes iguales (8.839 a 16 localidades y 8.838 a 4; incluye Sumapaz), con semilla fija 506232712; las 476.608 filas de otros departamentos quedan vacías. Cualquier indicador de hurtos por localidad refleja ese reparto, no la realidad: decirlo en el informe y en el tablero. El ETL lee el CSV por posición (`LOCALIDAD` = columna 10).
2. F3 se carga desde las capas de detalle agregadas por localidad, porque en el resumen de 2025 `EmpresasVigentes` es anómalo (p. ej. Usaquén 3.791 vs 38.307 en detalle). El resumen sirve para conciliar.
3. `fact_alojamiento.sk_tiempo` usa `FECHA_CORTE_TURISMO` (por defecto 20261022).
4. **Coordenadas de F1:** no se cargan (decisión del equipo: del alojamiento solo se usa la localidad). El modelo coincide con el diagrama de la Entrega 1. La Entrega 1 mencionaba reproyectar F1 a EPSG:4326; en la Entrega 2 se declara que no aplica porque no se guardan puntos. `P02` documenta esa exclusión.
5. Las contraseñas no están en los archivos; usan `${DB_PASSWORD}`.
6. **Conciliación:** `dw/conciliacion/` compara lo esperado (calculado directo de los archivos con Python) contra lo cargado en el DW. Se probó con una carga que aplica las mismas reglas del ETL en Python, no con PDI; la prueba real es ejecutar el job y luego `02_conciliar.sql`.
