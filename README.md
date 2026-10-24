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

*Por definir en proceso de entrega 2.*
