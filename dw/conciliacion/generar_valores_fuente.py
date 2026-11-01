#!/usr/bin/env python3
"""Calcula DIRECTAMENTE de los archivos fuente (sin PDI) los valores esperados de la carga y los escribe en
dw/conciliacion/01_valores_fuente.sql. Así la conciliación compara dos caminos independientes: archivos -> Python
y archivos -> PDI -> DW. Aplica las mismas reglas del ETL (ver etl/README.md y etl/reglas_calidad.md).

Uso (desde la raíz del repositorio, con el CSV de hurtos que ya tiene LOCALIDAD):
    python dw/conciliacion/generar_valores_fuente.py [--hurtos RUTA_CSV_CON_LOCALIDAD] [--turismo-sk 20261022]
"""
import argparse, csv, collections, json, math, os, re, sqlite3, datetime

ap = argparse.ArgumentParser()
ap.add_argument("--raw", default="datos/raw")
ap.add_argument("--hurtos", default="datos/procesado/Reporte_Hurto_Bogota_con_LOCALIDAD.csv")
ap.add_argument("--equiv", default="etl/equivalencias/equivalencia_localidad.csv")
ap.add_argument("--turismo-sk", type=int, default=20261022)
ap.add_argument("--salida", default="dw/conciliacion/01_valores_fuente.sql")
a = ap.parse_args()

# ---- mismas funciones de limpieza que el JavaScript del ETL
def cl(x): return re.sub(r"\s+", " ", "" if x is None else str(x)).strip()
def norm(x):
    s = cl(x).upper()
    for k, v in (("ÁÀÂÄ", "A"), ("ÉÈÊË", "E"), ("ÍÌÎÏ", "I"), ("ÓÒÔÖ", "O"), ("ÚÙÛÜ", "U"), ("Ñ", "N")):
        for ch in k: s = s.replace(ch, v)
    return s
def clave_loc(x):
    s = cl(x)
    if re.fullmatch(r"[0-9]+(\.0+)?", s): return ("00" + re.sub(r"\.0+$", "", s))[-2:]
    return norm(s)
EQ = {r["clave"]: r["cod_loc_eq"] for r in csv.DictReader(open(a.equiv, encoding="utf-8"))}
def cod_loc(x): return EQ.get(clave_loc(x), "99")

V = []  # (fuente, concepto, clave, valor)
def add(f, c, k, v): V.append((f, c, str(k), "NULL" if v is None else v))

# ---- F4
g = json.load(open(f"{a.raw}/geografia.json", encoding="utf-8"))["features"]
add("F4", "info_leidas", "", len(g)); add("F4", "cmp_dim_localidad", "", len({clave_loc(x["attributes"]["LocCodigo"]) for x in g}))

# ---- F1
f1 = [x["properties"] for x in json.load(open(f"{a.raw}/turismo.geojson", encoding="utf-8"))["features"]]
regs = collections.Counter(); desc_nulo = desc_noNum = desc_dup = 0; ok = []
for p in f1:
    r = cl(p.get("REGNTURISM")).replace(".0", "") if p.get("REGNTURISM") is not None else ""
    if r == "": desc_nulo += 1; continue
    if not re.fullmatch(r"[0-9]+", r): desc_noNum += 1; continue
    if r in regs: desc_dup += 1; continue
    regs[r] += 1; ok.append(p)
add("F1", "info_leidas", "", len(f1)); add("F1", "info_descartadas_rnt_nulo", "", desc_nulo)
add("F1", "info_descartadas_rnt_no_numerico", "", desc_noNum); add("F1", "info_descartadas_rnt_duplicado", "", desc_dup)
add("F1", "info_localidad_sin_cero_izquierda", "", sum(bool(re.fullmatch(r"[0-9]", cl(p.get("LOCALIDAD")))) for p in f1))
add("F1", "cmp_filas_total", "", len(ok))
for k, v in sorted(collections.Counter(cod_loc(p.get("LOCALIDAD")) for p in ok).items()): add("F1", "cmp_filas_localidad", k, v)
for k, v in sorted(collections.Counter(cl(p.get("SUBCATRNT")).replace(".0", "") for p in ok).items()): add("F1", "cmp_filas_subcategoria", k, v)
def rep(x, y):
    lon = x / 20037508.34 * 180; lat = math.degrees(2 * math.atan(math.exp(y / 6378137)) - math.pi / 2); return lat, lon
add("F1", "cmp_filas_con_localidad_valida", "", sum(1 for p in ok if cod_loc(p.get("LOCALIDAD")) != "99"))
add("DIM", "cmp_dim_tipo_alojamiento", "", len({cl(p.get("SUBCATRNT")).replace(".0", "") for p in ok}))

# ---- F2
if not os.path.exists(a.hurtos): raise SystemExit(f"No existe {a.hurtos}; genere primero etl/scripts/asignar_localidad.py")
rows = list(csv.reader(open(a.hurtos, encoding="utf-8-sig", newline="")))
h, d = rows[0], rows[1:]
assert h[-1] == "LOCALIDAD" and len(h) == 10, "El CSV debe terminar en la columna LOCALIDAD"
bog = [(i + 1, r) for i, r in enumerate(d) if r[0] == "BOGOTA"]
inval = 0; buenas = []
for n, r in bog:
    m = re.fullmatch(r"(\d{1,2})/(\d{1,2})/(\d{4})", cl(r[4])); okf = False
    if m:
        dd, mm, yy = map(int, m.groups())
        try: datetime.date(yy, mm, dd); okf = 2010 <= yy <= 2026
        except ValueError: pass
    q = cl(r[8]); okc = bool(re.fullmatch(r"[0-9]+", q)) and int(q) > 0
    if okf and okc and cl(r[7]) != "": buenas.append((n, r, yy, int(q)))
    else: inval += 1
add("F2", "info_leidas", "", len(d)); add("F2", "info_descartadas_fuera_bogota", "", len(d) - len(bog))
add("F2", "info_descartadas_fecha_cantidad_tipo_invalido", "", inval)
add("F2", "cmp_filas_total", "", len(buenas)); add("F2", "cmp_suma_cantidad", "", sum(b[3] for b in buenas))
for k, v in sorted(collections.Counter(str(b[2]) for b in buenas).items()): add("F2", "cmp_filas_anio", k, v)
for k, v in sorted(collections.Counter(cod_loc(b[1][9]) for b in buenas).items()): add("F2", "cmp_filas_localidad", k, v)
add("F2", "cmp_filas_genero_sin_dato", "", sum(norm(b[1][5]) == "" for b in buenas))
add("F2", "cmp_filas_grupo_sin_dato", "", sum(norm(b[1][6]) == "" for b in buenas))
key = collections.Counter(); dup = 0
for n, r, y, q in buenas:
    k = tuple(r[:9])
    if key[k]: dup += 1
    key[k] += 1
add("F2", "info_duplicados_potenciales_no_marcados", "", dup)  # solo informativo: se detectan en PDI (P10) pero no se guardan
add("DIM", "cmp_dim_tipo_hurto", "", len({cl(b[1][7]) for b in buenas}))
add("DIM", "cmp_dim_caracteristica_hurto", "", len({(norm(b[1][3]) or "SIN DATO", norm(b[1][5]) or "SIN DATO", norm(b[1][6]) or "SIN DATO") for b in buenas}))

# ---- F3 (detalle agregado por localidad y corte)
tot = 0
for y in (2023, 2024, 2025):
    c = sqlite3.connect(f"{a.raw}/dinamicaempresarial{y}.gpkg")
    emp = c.execute("select count(*) from Empresas").fetchone()[0]; est = c.execute("select count(*) from Establecimientos").fetchone()[0]
    res = c.execute("select count(*) from DinamicaEmpresarial").fetchone()[0]
    sk = c.execute("select max(Periodo*10000+Mes*100+1) from Empresas").fetchone()[0]
    q = ("SELECT e.loc, e.emp, s.est FROM (SELECT LOCNOMBRE loc, SUM(empresasvigentes) emp FROM Empresas GROUP BY LOCNOMBRE) e "
         "LEFT JOIN (SELECT LOCNOMBRE loc, SUM(Establecimientosvigentes) est FROM Establecimientos GROUP BY LOCNOMBRE) s ON s.loc=e.loc")
    g3 = [r for r in c.execute(q) if r[1] is not None]
    add("F3", "info_leidas_detalle_empresas", sk, emp); add("F3", "info_leidas_detalle_establecimientos", sk, est)
    add("F3", "info_leidas_resumen", sk, res)
    add("F3", "info_resumen_empresas_vigentes_NO_CARGADO", sk, c.execute("select sum(EmpresasVigentes) from DinamicaEmpresarial").fetchone()[0])
    add("F3", "cmp_filas_corte", sk, len(g3))
    add("F3", "cmp_empresas_corte", sk, sum(r[1] for r in g3))
    ests = [r[2] for r in g3 if r[2] is not None]
    add("F3", "cmp_establecimientos_corte", sk, sum(ests) if ests else None)
    add("F3", "cmp_establecimientos_nulos_corte", sk, sum(r[2] is None for r in g3))
    tot += len(g3)
add("F3", "cmp_filas_total", "", tot)
add("DIM", "cmp_dim_tiempo", "", (datetime.date(2026, 12, 31) - datetime.date(2010, 1, 1)).days + 1)

def sqlv(x): return x if x == "NULL" else str(x)
def lit(s): return "'" + str(s).replace("'", "''") + "'"
out = ["-- GENERADO por generar_valores_fuente.py el %s. No editar a mano." % datetime.date.today(),
       "-- Valores esperados calculados directamente de los archivos fuente en datos/raw y del CSV con LOCALIDAD.",
       "CREATE SCHEMA IF NOT EXISTS stg;",
       "DROP TABLE IF EXISTS stg.conciliacion_fuente;",
       "CREATE TABLE stg.conciliacion_fuente (fuente VARCHAR(10) NOT NULL, concepto VARCHAR(80) NOT NULL, clave VARCHAR(20) NOT NULL DEFAULT '', valor NUMERIC);",
       "INSERT INTO stg.conciliacion_fuente (fuente, concepto, clave, valor) VALUES"]
out.append(",\n".join(f"  ({lit(f)}, {lit(c)}, {lit(k)}, {sqlv(v)})" for f, c, k, v in V) + ";")
open(a.salida, "w", encoding="utf-8").write("\n".join(out) + "\n")
print(len(V), "valores escritos en", a.salida)
