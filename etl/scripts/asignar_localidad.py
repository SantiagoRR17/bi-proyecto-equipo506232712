#!/usr/bin/env python3
"""Agrega la columna LOCALIDAD al CSV de hurtos de la Policía Nacional (F2).

Regla (Entrega 1, sección de fuentes/diccionario de F2): la columna no existe en la fuente original; el equipo
la asigna con autorización del docente SOLO a las filas de Bogotá (DEPARTAMENTO = BOGOTA, 176.776 filas) para
poder integrar el reporte con F4. Reparto equitativo entre las 20 localidades (cerca de 8.800 cada una,
incluida Sumapaz); las demás filas (476.608) quedan con LOCALIDAD vacía. Los nombres llevan tildes y
"La Candelaria", como en la Entrega 1; la tabla de equivalencia los relaciona con LocCodigo.

Es DETERMINISTA: misma entrada y misma semilla -> misma salida. El resultado es un dato SIMULADO y debe
declararse así en el informe. El archivo no modifica ninguna otra columna ni el orden de las filas.

Uso (desde la raíz del repositorio):
    python etl/scripts/asignar_localidad.py
    python etl/scripts/asignar_localidad.py ENTRADA.csv SALIDA.csv --semilla 506232712
"""
import argparse, csv, glob, os, random, sys
from collections import Counter

LOCALIDADES = ["Usaquén", "Chapinero", "Santa Fe", "San Cristóbal", "Usme", "Tunjuelito", "Bosa", "Kennedy",
               "Fontibón", "Engativá", "Suba", "Barrios Unidos", "Teusaquillo", "Los Mártires", "Antonio Nariño",
               "Puente Aranda", "La Candelaria", "Rafael Uribe Uribe", "Ciudad Bolívar", "Sumapaz"]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("entrada", nargs="?")
    ap.add_argument("salida", nargs="?", default="datos/procesado/Reporte_Hurto_por_Modalidades_con_LOCALIDAD.csv")
    ap.add_argument("--semilla", type=int, default=506232712, help="semilla fija (por defecto, código del equipo)")
    a = ap.parse_args()
    entrada = a.entrada or (glob.glob("datos/raw/Reporte_Hurto_por_Modalidades_*_2026*.csv") or [None])[0]
    if not entrada or not os.path.exists(entrada):
        sys.exit("No encuentro el CSV de entrada; indíquelo como primer argumento.")
    if os.path.abspath(entrada) == os.path.abspath(a.salida):
        sys.exit("La salida no puede ser el archivo original.")

    with open(entrada, newline="", encoding="utf-8-sig") as f:
        filas = list(csv.reader(f))
    cab, datos = filas[0], filas[1:]
    if "LOCALIDAD" in cab:
        sys.exit("El archivo ya tiene la columna LOCALIDAD.")
    i_dep = cab.index("DEPARTAMENTO")
    bogota = [i for i, r in enumerate(datos) if r and r[i_dep] == "BOGOTA"]

    # Reparto equitativo y reproducible: se baraja el orden de las filas de Bogotá con la semilla y se
    # asigna en rotación. Cada localidad recibe n//20 filas y 'n % 20' localidades reciben una más.
    rng = random.Random(a.semilla)
    orden = bogota[:]
    rng.shuffle(orden)
    asign = {fila: LOCALIDADES[k % len(LOCALIDADES)] for k, fila in enumerate(orden)}

    os.makedirs(os.path.dirname(os.path.abspath(a.salida)), exist_ok=True)
    with open(a.salida, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(cab + ["LOCALIDAD"])
        for i, r in enumerate(datos):
            w.writerow(r + [asign.get(i, "")])

    c = Counter(asign.values())
    print(f"Filas totales: {len(datos):,} | con localidad (Bogotá): {len(bogota):,} | sin localidad: {len(datos)-len(bogota):,}")
    for n in LOCALIDADES:
        print(f"  {n:20s} {c[n]:>6,}")
    print("Salida:", a.salida)


if __name__ == "__main__":
    main()
