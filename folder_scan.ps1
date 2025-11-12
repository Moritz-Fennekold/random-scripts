param(
    [string[]]$Paths = @(
        '\\...\',             # Hier die Ordnerpfade angeben, welche gescanned werden sollen
        '\\...\...'
    ),
    [string]$TxtLog = '\\Pfad\zum\Logs-Ordner'        # Pfad für die .txt Datei
)

Add-Type -AssemblyName System.IO

# Datum für CSV im Dateinamen
$scanDate = Get-Date -Format "yyyy-MM-dd"
$CsvLog = "\\...\folder_scan_$scanDate.csv"           # Ofad für die .csv Datei

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

