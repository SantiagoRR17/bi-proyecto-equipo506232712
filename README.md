# Observatorio Distrital de Actividad Económica, Turismo y Seguridad

## Integrantes

- Julian David Avila Cortes
- Santiago Rocha Ramirez

## Contexto del proyecto

Este proyecto plantea el caso hipotético de un **Observatorio Distrital de Actividad Económica, Turismo y Seguridad**, una organización orientada al análisis de información territorial de Bogotá D.C. y al apoyo de la toma de decisiones relacionadas con la actividad empresarial, el turismo y la seguridad ciudadana.

Para efectos del caso, se considera una organización de tamaño mediano, con una sede central y equipos encargados de la planeación, el análisis y el seguimiento de indicadores. El principal decisor es la dirección del observatorio, con el apoyo de profesionales de las áreas de análisis y planeación.

Actualmente, la organización dispone de diferentes fuentes de información pública que son administradas de manera independiente y presentan diferencias en estructura, formato, nivel de detalle y periodicidad. Las fuentes consideradas son:

- **F1. Establecimientos de alojamiento turístico de Bogotá:** representa geográficamente los establecimientos de hospedaje.
- **F2. Reporte de hurto por modalidades de la Policía Nacional:** archivo CSV con registros de hurtos que incluye la fecha del hecho, el tipo de hurto, el arma o medio reportado, el género, el grupo etario y la cantidad, entre otros campos.
- **F3. Dinámica empresarial de Bogotá D.C.:** contiene información sobre empresas y establecimientos vigentes por localidad y corte de medición.
- **F4. Localidad de Bogotá D.C.:** se utiliza como referencia geográfica para integrar las demás fuentes.

## Problema de negocio

La información no se encuentra integrada en un modelo común que permita realizar análisis consistentes. Las fuentes presentan tres tipos de grano:

- La dinámica empresarial se distribuye en archivos de diferentes años y maneja indicadores por localidad y corte de medición. Los cortes disponibles corresponden a septiembre de 2023, marzo de 2024 y julio de 2025, por lo que no constituyen una serie continua.
- Los establecimientos de alojamiento turístico se representan como entidades individuales con información geográfica.
- Los hurtos se registran como eventos de la fuente policial, con fecha, modalidad y características del hecho.

Adicionalmente, las fuentes difieren en la representación de los códigos y nombres de localidad, por ejemplo, `"3"` frente a `"03"`, así como en los formatos de fecha y en los sistemas de referencia espacial. Estas diferencias deben tratarse durante la integración. La columna de localidad de los hurtos permite relacionar esta fuente con las demás por territorio.

Como consecuencia, el decisor no cuenta actualmente con una visión integrada que le permita:

- Comparar la actividad empresarial por localidad.
- Analizar la concentración de establecimientos de alojamiento turístico.
- Estudiar la evolución de los hurtos por fecha y modalidad en los periodos disponibles.
- Identificar concentraciones y comparar periodos utilizando criterios homogéneos.

## Solución propuesta

Se propone implementar una arquitectura de **Business Intelligence** que permita:

1. Extraer la información de las fuentes públicas.
2. Integrar y transformar los datos.
3. Normalizar los identificadores territoriales y temporales.
4. Almacenar la información en un modelo dimensional.
5. Consultar y visualizar los datos mediante herramientas de análisis y generación de reportes.

Esta solución busca generar indicadores y reportes que faciliten la toma de decisiones de la dirección del observatorio y de los equipos de análisis y planeación.

## Arquitectura y herramientas

De acuerdo con el diagrama de arquitectura del proyecto, se utilizarán las siguientes herramientas:

- **Python:** apoyo en la extracción, limpieza, transformación y preparación de los datos.
- **Pentaho:** desarrollo y ejecución de los procesos ETL, integración de las fuentes y carga de la información.
- **PostgreSQL:** almacenamiento de los datos integrados y del modelo dimensional para su posterior consulta.

## Alcance

El propósito del proyecto es proporcionar una visión descriptiva e integrada de la información disponible sobre actividad económica, turismo y seguridad en Bogotá D.C.

La comparación entre las fuentes permitirá identificar distribuciones, concentraciones y cambios en los periodos disponibles. Sin embargo, el proyecto **no pretende establecer relaciones causales** entre la actividad económica, el turismo y la seguridad, ni explicar las causas de la seguridad ciudadana. Los resultados deben interpretarse exclusivamente como análisis descriptivos de las fuentes integradas.

## Cómo reproducir el proyecto

Los siguientes pasos reproducen la construcción del DW y la carga ETL con los
archivos que se encuentran en este repositorio. Deben ejecutarse desde la raíz
del proyecto.

### 1. Requisitos

- PostgreSQL 16.
- Python 3.
- Pentaho Data Integration (PDI) 9.x o superior, con Java 11 o 17.
- El controlador JDBC de PostgreSQL incluido en PDI y
  `sqlite-jdbc-*.jar` en `data-integration/lib/`, necesario para leer los
  GeoPackage de la dinámica empresarial.
- Ejecutar Spoon con `-Dfile.encoding=UTF-8`.

Las fuentes descargadas y sus instrucciones de origen están en
[`datos/descarga.md`](datos/descarga.md). Las copias utilizadas por el
proyecto están en `datos/raw/`. La copia de la fuente policial está reducida a
las filas de Bogotá, que son las únicas que utiliza el ETL.

### 2. Crear el modelo dimensional

1. Conectarse a PostgreSQL usando la base `postgres` y ejecutar
   [`dw/ddl/00_crear_base_datos.sql`](dw/ddl/00_crear_base_datos.sql) una sola
   vez. El script crea la base `observatorio_bi`.
2. Conectarse a `observatorio_bi` y ejecutar, en este orden:
   [`dw/ddl/01_crear_modelo_dw.sql`](dw/ddl/01_crear_modelo_dw.sql),
   [`dw/ddl/02_filas_desconocido.sql`](dw/ddl/02_filas_desconocido.sql) y
   [`dw/ddl/03_verificar_modelo.sql`](dw/ddl/03_verificar_modelo.sql).

El primer script del modelo recrea los esquemas `dw` y `stg`; por tanto,
reemplaza cualquier carga anterior. Las dimensiones, excepto tiempo, incluyen
el miembro `-1` para registros sin coincidencia en los *lookups* del ETL.

### 3. Preparar el archivo de hurtos

La fuente policial no contiene localidad. Para integrarla con F4 se genera un
CSV adicional con una localidad asignada únicamente a las filas de Bogotá:

```powershell
python etl\scripts\asignar_localidad.py
```

El resultado es
`datos/procesado/Reporte_Hurto_por_Modalidades_con_LOCALIDAD.csv`. La
asignación es reproducible (semilla `506232712`), reparte las 176.776 filas de
Bogotá entre las 20 localidades y deja vacías las filas de otros
departamentos. Es un dato simulado y cualquier análisis de hurtos por
localidad debe interpretarse con esa limitación.

### 4. Configurar y ejecutar PDI

Crear `~/.kettle/kettle.properties` y definir las variables que usan el job y
las transformaciones:

```properties
DB_HOST=localhost
DB_PORT=5432
DB_NAME=observatorio_bi
DB_USER=<usuario_de_postgresql>
DB_PASSWORD=<contraseña_de_postgresql>
RAIZ_REPO=G:\bi-proyecto-equipo506232712
ARCHIVO_HURTOS=G:\bi-proyecto-equipo506232712\datos\procesado\Reporte_Hurto_por_Modalidades_con_LOCALIDAD.csv
FECHA_CORTE_TURISMO=20261022
```

En Windows, adaptar `RAIZ_REPO` y `ARCHIVO_HURTOS` a la ubicación local del
repositorio. El archivo de propiedades no debe subirse al repositorio.

En Spoon, abrir y ejecutar
[`etl/trabajos/j_carga_dw.kjb`](etl/trabajos/j_carga_dw.kjb).

El job es re-ejecutable: limpia hechos y dimensiones conservando los miembros
`-1`, carga las dimensiones, carga los tres hechos y calcula las variaciones y
la participación. El orden de las transformaciones y las reglas de calidad
está documentado en [`etl/README.MD`](etl/README.MD) y
[`etl/reglas_calidad.md`](etl/reglas_calidad.md). Antes de la primera
ejecución, verificar el job en Spoon (F11), tal como indica la documentación
del ETL.

### 5. Conciliar la carga

Después de ejecutar PDI, generar los valores esperados directamente desde las
fuentes y comparar ambos caminos:

```powershell
python dw\conciliacion\generar_valores_fuente.py
psql -d observatorio_bi -f dw\conciliacion\00_tabla_conteos_pdi.sql
psql -d observatorio_bi -f dw\conciliacion\01_valores_fuente.sql
psql -d observatorio_bi -f dw\conciliacion\02_conciliar.sql
```

`00_tabla_conteos_pdi.sql` se ejecuta una sola vez. Si se desea comparar los
conteos de *Step Metrics* y del log de PDI, registrar esos valores en
`stg.conciliacion_pdi` antes de ejecutar `02_conciliar.sql`. La conciliación
debe mostrar `CONCILIACION OK`; su procedimiento está detallado en
[`dw/conciliacion/README.md`](dw/conciliacion/README.md).

Como comprobación adicional, ejecutar
[`dw/ddl/03_verificar_modelo.sql`](dw/ddl/03_verificar_modelo.sql) y revisar
la estructura, las llaves foráneas y los conteos de las ocho tablas del
esquema `dw`. Los conteos de referencia documentados son 6.209 filas en
`dim_tiempo`, 839 en `fact_alojamiento`, 60 en
`fact_dinamica_empresarial` y 176.776 en `fact_hurtos`.

### 6. Abrir el tablero

Con la conciliación aprobada, abrir
[`dashboard/dashboard.pbix`](dashboard/dashboard.pbix) en Power BI Desktop y
conectar mediante PostgreSQL a `observatorio_bi`. Cargar únicamente las ocho
tablas del esquema `dw`, no los archivos de las fuentes. La configuración de
relaciones, medidas, páginas y verificaciones está en
[`dashboard/guia_power_bi.md`](dashboard/guia_power_bi.md).
