<#
.SYNOPSIS
    Scannt beliebige Verzeichnisse rekursiv und ermittelt die Anzahl von Dateien, Ordnern, Gesamtgröße sowie aufgetretene Fehler. 
    Ergebnisse werden als .txt und .csv gespeichert.

.DESCRIPTION
    Das Skript dient zur Analyse vom Speicherverbrauch in Fileserver-Strukturen.
    Es ermittelt rekursiv die Größe und Struktur des Hauptordners und aller Unterordner der ersten Ebene.
    Die Ergebnisse werden dann als CSV (für weitere Auswertung bspw. via folder_scan_comparison.py) und als lesbare TXT-Logdatei gespeichert, wobei die TXT-Logdatei bei jeder Ausführung überschrieben wird.
    Fehler beim Zugriff auf Dateien oder Ordner werden mitgezählt.

.AUTHOR
    Moritz

.VERSION
    1.0 I guess - 14.11.2025 Initial Version

.PARAMETER
    Paths:     Liste der Ordnerpfade, die gescannt werden sollen (da ich das Skript für Fileserver-Strukturen benutze, gebe ich die Pfade in UNC-Format an).
    TxtLog:    Pfad zur TXT-Logdatei, in welche fortlaufend geschrieben wird.

.OUTPUT
    CSV-Datei mit Scanergebnissen (z.B. folder_scan_2025-11-14.csv)
    TXT-Log mit allen Terminal-Ausgaben

.NOTES
    Zum Ausführen benutze ich VSCode mit der PowerShell Extension (v2025.4.0), oder direkt per PowerShell (Version 7.5.4 in Win11 25H2).
    Fehler beim Dateizugriff werden lediglich gezählt, nicht einzeln protokolliert.
    Die CSV-Datei wird automatisch mit Tagesdatum versehen.
#>
param(
    [string[]]$Paths = @(
        '\\...\',
        '\\...\...'
    ),
    [string]$TxtLog = '\\...\folder_scan_today.txt'
)

Add-Type -AssemblyName System.IO

# Datum für CSV im Dateinamen
$scanDate = Get-Date -Format "yyyy-MM-dd"
$CsvLog = "\\...\folder_scan_$scanDate.csv"

# Liste für CSV-Ergebnisse
$csvResults = New-Object System.Collections.Generic.List[PSObject]

# Funktionen
function Measure-Folder {
    param([string]$FolderPath)

    $totalBytes = 0L
    $fileCount = 0
    $dirCount = 0
    $errors = 0

    $stack = New-Object System.Collections.Stack
    $stack.Push($FolderPath)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        try {
            foreach ($f in [System.IO.Directory]::EnumerateFiles($current)) {
                try {
                    $fi = [System.IO.FileInfo]::new($f)
                    $totalBytes += $fi.Length
                    $fileCount++
                } catch { $errors++ }
            }

            foreach ($d in [System.IO.Directory]::EnumerateDirectories($current)) {
                $dirCount++
                $stack.Push($d)
            }
        } catch { $errors++ }
    }

    return [PSCustomObject]@{
        Pfad      = $FolderPath
        Dateien   = $fileCount
        Ordner    = $dirCount
        Gesamt_MB = [math]::Round($totalBytes / 1MB, 2)
        Fehler    = $errors
    }
}

function Write-Result {
    param($result)

    $output = @"
Pfad:        $($result.Pfad)
Dateien:     $($result.Dateien)
Ordner:      $($result.Ordner)
Gesamtgröße: $($result.Gesamt_MB) MB
Fehler:      $($result.Fehler)
"@ + "`r`n"

    Write-Host $output # Optional (damit man den Fortschritt sieht)
    $output | Out-File -FilePath $TxtLog -Append -Encoding UTF8
    $csvResults.Add($result)
}

# TXT Log starten
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"Scan gestartet am $timestamp" | Out-File -FilePath $TxtLog -Encoding UTF8

# Hauptschleife für alle Pfade
foreach ($Path in $Paths) {
    if (-not (Test-Path $Path)) {
        Write-Warning "Pfad nicht gefunden: $Path"
        continue
    }

    Write-Host "Scanne Hauptordner: $Path"
    "Scanne Hauptordner: $Path" | Out-File -FilePath $TxtLog -Append -Encoding UTF8

    # Hauptordner
    $resultRoot = Measure-Folder -FolderPath $Path
    Write-Result $resultRoot

    # Unterordner 1. Ebene
    $subfolders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
    foreach ($sub in $subfolders) {
        Write-Host "`nScanne Unterordner: $($sub.FullName)"
        "Scanne Unterordner: $($sub.FullName)" | Out-File -FilePath $TxtLog -Append -Encoding UTF8
        $resultSub = Measure-Folder -FolderPath $sub.FullName
        Write-Result $resultSub
    }
}

# CSV speichern
$csvResults | Export-Csv -Path $CsvLog -Delimiter ";" -Encoding UTF8 -NoTypeInformation

# Abschlussmeldung
"`nScan beendet am $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") " | Out-File -FilePath $TxtLog -Append -Encoding UTF8
Write-Host "`nFertig! Ergebnisse wurden gespeichert in:`nTXT: $TxtLog`nCSV: $CsvLog"
