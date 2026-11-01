-- =============================================================================
-- 02_filas_desconocido.sql
-- Miembro -1 «DESCONOCIDO» de cada dimensión (excepto dim_tiempo).
-- Ejecutar después de 01_crear_modelo_dw.sql.
--
-- Sirve para que ningún registro de hechos quede sin llave: cuando el
-- Database lookup de PDI no encuentra coincidencia, la fila de hechos apunta
-- a -1 (o se envía a rechazos), en lugar de perderse o guardar el código de
-- la fuente.
--
-- dim_tiempo no lleva miembro -1: todas las fechas de los hechos son válidas
-- (F2 no tiene fechas inválidas; los cortes de F1 y F3 son fechas fijas).
--
-- Las llaves subrogadas «normales» arrancan en 1 (IDENTITY), sin colisión.
-- =============================================================================

BEGIN;

-- Código 99 (no oficial). El código 21 «Sin Localidad» de F3 y cualquier
-- localidad sin coincidencia se asignan a este miembro, con regla en PDI.
INSERT INTO dw.dim_localidad (sk_localidad, cod_localidad, nombre_localidad, acto_administrativo, area)
VALUES (-1, '99', 'SIN LOCALIDAD', NULL, NULL);

INSERT INTO dw.dim_tipo_alojamiento (sk_tipo_alojamiento, cod_subcategoria, etiqueta)
VALUES (-1, 'N/D', 'DESCONOCIDO');

INSERT INTO dw.dim_tipo_hurto (sk_tipo_hurto, etiqueta_original, articulo, descripcion_tipo)
VALUES (-1, 'DESCONOCIDO', 'DESCONOCIDO', 'DESCONOCIDO');

INSERT INTO dw.dim_caracteristica_hurto (sk_caracteristica, arma_medio, genero, grupo_etario)
VALUES (-1, 'DESCONOCIDO', 'DESCONOCIDO', 'DESCONOCIDO');

COMMIT;
