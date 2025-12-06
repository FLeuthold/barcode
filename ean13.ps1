# --- 1. KOMPAKTE EAN-13 DATENSTRUKTUREN ---

# L-Set: Codes für Ziffern 0-9 (Index = Ziffer)
$L_Codes = @(157, 181, 156, 405, 206, 351, 138, 251, 278, 176)

# G-Set: Codes für Ziffern 0-9 (Index = Ziffer)
$G_Codes = @(277, 301, 276, 176, 281, 171, 526, 351, 251, 426)

# Muster für die führende Ziffer (Index = Ziffer 0-9)
# Wert ist der komprimierte Integer der L/G-Sequenz (L=0, G=1)
$FirstDigitPatterns = @(0, 11, 13, 14, 19, 25, 28, 21, 22, 26)

# --- 2. HILFSFUNKTIONEN ---

## Berechnet die EAN-13 Prüfziffer
function Get-Ean13CheckDigit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Ean12
    )
    # [Logik der Prüfziffernberechnung, wie zuvor definiert]
    if ($Ean12.Length -ne 12) { throw "Input muss genau 12 Ziffern lang sein." }
    $Sum = 0
    for ($i = 0; $i -lt 12; $i++) {
        $Digit = [int]::Parse($Ean12[$i])
        if (($i + 1) % 2 -eq 0) { $Sum += $Digit * 3 } else { $Sum += $Digit * 1 }
    }
    $Remainder = $Sum % 10
    return (10 - ($Sum % 10)) % 10
}

## Dekomprimiert den Code und wendet die R-Set-Umkehrung an
function Get-EanBarArray {
    param(
        [Parameter(Mandatory=$true)]
        [int]$CompactCode,
        [switch]$IsRSet
    )
    $BarArray = [System.Collections.ArrayList]@()
    $CompactValue = $CompactCode
    $Divisor = 125 # 5^3

    # Base 10 -> Base 5 Konvertierung
    for ($i = 0; $i -lt 4; $i++) {
        $Width = [System.Math]::Floor($CompactValue / $Divisor)
        $BarArray.Add([int]$Width)
        $CompactValue -= ($Width * $Divisor)
        $Divisor /= 5
    }

    # R-Set Hack: Kehrt die Reihenfolge um
    if ($IsRSet) { $BarArray.Reverse() }

    return $BarArray -as [int[]]
}

# --- 3. HAUPTFUNKTION ZUR ARRAY-GENERIERUNG ---

function Convert-Ean13ToBarArray {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Ean13Code # Muss 13 Ziffern lang sein (inkl. Prüfziffer)
    )
    if ($Ean13Code.Length -ne 13) { throw "Input muss genau 13 Ziffern lang sein." }

    $BarArray = [System.Collections.ArrayList]@()
    $LeadingDigit = [int]::Parse($Ean13Code[0])
    $LeftDigits = $Ean13Code.Substring(1, 6).ToCharArray() 
    $RightDigits = $Ean13Code.Substring(7, 6).ToCharArray() 

    # --- 1. Start-Separator (101) ---
    $BarArray.AddRange(@(1, 1, 1))

    # --- 2. Linke Hälfte (Ziffern 2-7) ---
    $PatternInt = $FirstDigitPatterns[$LeadingDigit]
    
    # Binärdekodierung des Musters (G=1, L=0)
    for ($i = 0; $i -lt 6; $i++) {
        $DigitValue = [int]::Parse($LeftDigits[$i])
        
        # Holen des Bits an Position (5 - $i) für das Muster (0 bis 5)
        # Beispiel: i=0 (links), Bit ist 5. Stelle
        $IsGSet = ($PatternInt -shr (5 - $i)) -band 1 

        if ($IsGSet -eq 1) {
            # G-Set verwenden
            $CompactCode = $G_Codes[$DigitValue]
        } else {
            # L-Set verwenden
            $CompactCode = $L_Codes[$DigitValue]
        }
        $BarArray.AddRange((Get-EanBarArray -CompactCode $CompactCode))
    }

    # --- 3. Mittel-Separator (01010) ---
    $BarArray.AddRange(@(1, 1, 1, 1, 1))

    # --- 4. Rechte Hälfte (Ziffern 8-13, immer R-Set) ---
    foreach ($DigitChar in $RightDigits) {
        $DigitValue = [int]::Parse($DigitChar)
        # R-Set verwendet die kompakten L-Codes, aber mit Reversal-Flag
        $CompactCode = $L_Codes[$DigitValue]
        $BarArray.AddRange((Get-EanBarArray -CompactCode $CompactCode -IsRSet))
    }

    # --- 5. End-Separator (101) ---
    $BarArray.AddRange(@(1, 1, 1))
    
    return $BarArray -as [int[]]
}

# --- ANWENDUNG ---
$TestEan12 = "400638133393"
$CheckDigit = Get-Ean13CheckDigit -Ean12 $TestEan12
$Ean13Code = $TestEan12 + $CheckDigit

$FinalBarArray = Convert-Ean13ToBarArray -Ean13Code $Ean13Code

Write-Host "Vollständiger EAN-13 Code: $Ean13Code"
Write-Host "Generiertes Array (95 Elemente):"
$FinalBarArray | Select-Object -First 15 | Out-String # Zeigt die ersten 15 Breiten
