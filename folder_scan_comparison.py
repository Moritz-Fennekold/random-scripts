import csv
from datetime import date

old_file = "folder_scan_yyyy-MM-dd.csv"
new_file = f"folder_scan_{date.today()}.csv"
output_file = f"changes_{date.today()}.csv"

# Funktion zum Einlesen der CSV-Datei
def read_scan_file(path):
    data = {}
    with open(path, mode="r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f, delimiter=";")
        for row in reader:
            pfad = row["Pfad"]
            try:
                # Kommas in Zahlen (deutsches Format) in Punkte wandeln
                dateien = int(row["Dateien"])
                ordner = int(row["Ordner"])
                gesamt_mb = float(row["Gesamt_MB"].replace(",", "."))
            except ValueError:
                continue  # Fehlerhafte Zeilen überspringen
            data[pfad] = {"Dateien": dateien, "Ordner": ordner, "Gesamt_MB": gesamt_mb}
    return data

# Einlesen der beiden CSVs (alt und neu)
old_data = read_scan_file(old_file)
new_data = read_scan_file(new_file)

# Array zum Abspeichern der Unterschiede
changes = []
# Pfade, die in beiden Dateien vorkommen
common_paths = set(old_data.keys()) & set(new_data.keys())
# Nur in neuer Datei vorhanden
new_paths = set(new_data.keys()) - set(old_data.keys())
# Nur in alter Datei vorhanden
removed_paths = set(old_data.keys()) - set(new_data.keys())

# Gemeinsame Pfade auf Änderungen prüfen
for pfad in sorted(common_paths):
    old = old_data[pfad]
    new = new_data[pfad]

    diff_files = new["Dateien"] - old["Dateien"]
    diff_folders = new["Ordner"] - old["Ordner"]
    diff_mb = round(new["Gesamt_MB"] - old["Gesamt_MB"], 2)

    if diff_files != 0 or diff_folders != 0 or diff_mb != 0:
        changes.append({
            "Pfad": pfad,
            "Δ_Dateien": diff_files,
            "Δ_Ordner": diff_folders,
            "Δ_MB": diff_mb,
            "Status": "Geändert"
        })

# Neue Pfade hinzufügen
for pfad in sorted(new_paths):
    d = new_data[pfad]
    changes.append({
        "Pfad": pfad,
        "Δ_Dateien": "+",
        "Δ_Ordner": "+",
        "Δ_MB": "+",
        "Status": "Neu"
    })

# Entfernte Pfade hinzufügen
for pfad in sorted(removed_paths):
    d = old_data[pfad]
    changes.append({
        "Pfad": pfad,
        "Δ_Dateien": "-",
        "Δ_Ordner": "-",
        "Δ_MB": "-",
        "Status": "Entfernt"
    })

# Ergebnis verarbeiten und in CSV schreiben
if changes:
    with open(output_file, mode="w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=changes[0].keys(), delimiter=";")
        writer.writeheader()
        writer.writerows(changes)
    print(f"Unterschiede gefunden und gespeichert in: {output_file}")
else:
    print("Keine Unterschiede gefunden.")
