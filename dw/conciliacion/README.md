# Conciliación de filas y cantidades (fuente ↔ almacén de datos)

Orden de ejecución (conectado a `observatorio_bi`, después de correr el job de PDI):

1. `python dw/conciliacion/generar_valores_fuente.py` — calcula lo esperado directo de `datos/raw` y del CSV con LOCALIDAD y genera `01_valores_fuente.sql`.
2. `psql -d observatorio_bi -f dw/conciliacion/00_tabla_conteos_pdi.sql` (una vez)
3. `psql -d observatorio_bi -f dw/conciliacion/01_valores_fuente.sql`
4. `psql -d observatorio_bi -f dw/conciliacion/02_conciliar.sql`

Resultados: (1) leídos = cargados + descartados para F1 y F2; F3 muestra el cambio de grano; (2) 87 comparaciones de filas y cantidades (OK / DIFERENCIA); (3) resumen; (4) conteos de PDI frente a lo esperado, si los registran en `stg.conciliacion_pdi`; (5) controles de integridad (miembros -1, localidades sin datos).

Para la sección 4, tras ejecutar el job copien los valores de *Step Metrics* con el mismo nombre de concepto que `stg.conciliacion_fuente` (ver ejemplo en `00_tabla_conteos_pdi.sql`). Para el Anexo A del informe, pegar los resultados de las secciones 1–3.
