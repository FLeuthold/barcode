# --- 1. KOMPAKTE CODE 39 DATENSTRUKTUREN ---
# Ein einziges Array mit 44 Integern. Index = Zeichenposition.
# Der Wert ist das 9-Elemente-Muster (Basis 4, wobei 1 und 3 verwendet werden).

# Dieses Array MUSS 44 Elemente enthalten (0-9, A-Z, Symbole, *)
$Code39_CompactCodes = @(
    18775, 43207, 18951, 43447, 19175, 43655, 19399, 19143, 43623, 19367,  # 0-9
    43047, 18919, 43415, 18743, 43239, 18983, 18727, 43271, 19015, 18759,  # A-J
    43015, 18887, 43247, 18711, 43287, 19047, 18695, 43223, 18983, 18679,  # K-T
    43527, 19159, 43687, 18855, 43383, 19087, 19479, 43903, 19287, 43879,  # U-Z, -, ., (Space), $, /, +, %
    18999, 43543, 19111,                                                   # Symbole (fortgesetzt)
    19183                                                                 # Index 43: '*' Start/Stop
)

# --- 2. HILFSFUNKTIONEN ---

## Berechnet den Index (Position im Array) für das gegebene Zeichen (Code 39 Zeichensatz).
function Get-Code39Index {
    param([char]$Char)
    
    $UpperChar = [char]::ToUpper($Char)
    $Ascii = [int]$UpperChar

    switch ($Ascii) {
        # Ziffern 0-9 (ASCII 48-57) -> Index 0-9
        { $_ -ge 48 -and $_ -le 57 } { return $_ - 48 } 
        
        # Buchstaben A-Z (ASCII 65-90) -> Index 10-35
        { $_ -ge 65 -and $_ -le 90 } { return $_ - 55 } # 65 - 55 = 10 ('A')
        
        # Symbole und Start/Stop-Zeichen
        45 { return 36 }  # '-' (Index 36)
        46 { return 37 }  # '.' (Index 37)
        32 { return 38 }  # ' ' (Index 38)
        36 { return 39 }  # '$' (Index 39)
        47 { return 40 }  # '/' (Index 40)
        43 { return 41 }  # '+' (Index 41)
        37 { return 42 }  # '%' (Index 42)
        42 { return 43 }  # '*' (Index 43)
        
        default { throw "Ungültiges Code 39 Zeichen: $Char" }
    }
}

## Dekomprimiert den Basis-4-Integer zurück in das 9-Elemente-Breiten-Array.
function Get-Code39Pattern {
    param(
        [Parameter(Mandatory=$true)]
        [int]$CompactCode
    )
    
    $PatternArray = [System.Collections.ArrayList]::new()
    $CompactValue = $CompactCode
    $Divisor = [System.Math]::Pow(4, 8) # 4^8 = 65536

    # Konvertierung von Base 10 -> Base 4
    for ($i = 0; $i -lt 9; $i++) {
        $Width = [System.Math]::Floor($CompactValue / $Divisor)
        $PatternArray.Add([int]$Width)
        $CompactValue -= ($Width * $Divisor)
        $Divisor /= 4
    }
    
    return $PatternArray -as [int[]]
}

# --- 3. HAUPTFUNKTION ZUR ARRAY-GENERIERUNG ---

function Convert-Code39ToArrayCompressed {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Data
    )

    $Data = $Data.ToUpper()
    $FullData = "*" + $Data + "*"
    
    $FinalBarArray = [System.Collections.ArrayList]::new()

    foreach ($Char in $FullData.ToCharArray()) {
        try {
            # 1. Zeichen -> Index (reine Berechnung)
            $Index = Get-Code39Index -Char $Char
            
            # 2. Index -> Kompakter Code (reines Array-Lookup)
            $CompactCode = $Code39_CompactCodes[$Index]
            
            # 3. Kompakter Code -> 9-Elemente Muster (reine Berechnung)
            $Pattern = Get-Code39Pattern -CompactCode $CompactCode
            
            # Füge das Muster hinzu
            $FinalBarArray.AddRange($Pattern)
            
            # Füge die Inter-Character-Space (Lücke) hinzu, außer nach dem letzten Zeichen
            if ($Char -ne $FullData[-1]) {
                 $FinalBarArray.Add(1) 
            }
        } catch {
            Write-Error $_
            return $null
        }
    }

    return $FinalBarArray -as [int[]]
}



$TestData = "Code 39"

# Array generieren
$BarcodeArray = Convert-Code39ToArrayCompressed -Data $TestData

if ($BarcodeArray) {
    Write-Host "Eingabe: $TestData"
    Write-Host "Codiert: *CODE 39*"
    Write-Host "Gesamte Elemente: $($BarcodeArray.Count)" # 8 Zeichen * 10 Elemente - 1 Lücke = 79 Elemente
    Write-Host "`nResultierendes Array (Breiten der Striche und Lücken):"
    
    # Ausgabe der ersten 20 Elemente zur Demonstration der Struktur
    Write-Output ($BarcodeArray | Select-Object -First 20 | Out-String).Trim()
    
    # Beispiel-Überprüfung des Anfangs (* C O)
    # *: [1, 3, 1, 1, 3, 1, 3, 1, 1]
    # Lücke: [1]
    # C: [3, 1, 3, 1, 3, 1, 1, 1, 1]
    # Lücke: [1]
    # O: [3, 1, 1, 1, 3, 1, 3, 1, 1]
}
