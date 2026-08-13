param(
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action = 'Install',
    [ValidateSet('All', 'Movement', 'ClientFindr', 'Ultrawide')]
    [string[]]$Mods = @('All'),
    [ValidateSet(1, 2, 4, 8, 16, 32)]
    [int]$ClientFindrResolutionDivisor = 4,
    [ValidateRange(640, 16384)]
    [int]$BorderlessWidth = 3440,
    [ValidateRange(480, 8640)]
    [int]$BorderlessHeight = 1440
)

$ErrorActionPreference = 'Stop'

function Read-Choice {
    param(
        [string]$Prompt,
        [string[]]$Allowed,
        [string]$Default
    )
    while ($true) {
        $suffix = if ($Default) { " [$Default]" } else { '' }
        $answer = (Read-Host "$Prompt$suffix").Trim()
        if (-not $answer -and $Default) { return $Default }
        if ($Allowed -contains $answer) { return $answer }
        Write-Host "Please enter one of: $($Allowed -join ', ')" -ForegroundColor Yellow
    }
}

function Read-IntegerChoice {
    param(
        [string]$Prompt,
        [int]$Default,
        [int[]]$Allowed,
        [int]$Minimum,
        [int]$Maximum
    )
    while ($true) {
        $answer = (Read-Host "$Prompt [$Default]").Trim()
        if (-not $answer) { return $Default }
        $number = 0
        if ([int]::TryParse($answer, [ref]$number)) {
            if ($Allowed -and $Allowed -contains $number) { return $number }
            if (-not $Allowed -and $number -ge $Minimum -and $number -le $Maximum) { return $number }
        }
        if ($Allowed) {
            Write-Host "Choose one of: $($Allowed -join ', ')" -ForegroundColor Yellow
        } else {
            Write-Host "Enter a number from $Minimum to $Maximum." -ForegroundColor Yellow
        }
    }
}

# With no arguments, provide an interactive front end. Supplying parameters keeps
# the script non-interactive for shortcuts and automation.
if ($PSBoundParameters.Count -eq 0) {
    Clear-Host
    Write-Host 'Embr Mod Manager' -ForegroundColor Cyan
    Write-Host '================'
    Write-Host '1. Install all mods'
    Write-Host '2. Choose mods to install'
    Write-Host '3. Uninstall all mods'
    Write-Host '4. Exit'
    $menuChoice = Read-Choice 'Select an option' @('1','2','3','4') '1'

    switch ($menuChoice) {
        '1' { $Mods = @('All') }
        '2' {
            Write-Host ''
            Write-Host '1. Smooth movement and camera'
            Write-Host '2. Higher-resolution Client Findr'
            Write-Host '3. Ultrawide Windowed Fullscreen option'
            Write-Host 'Enter one or more numbers separated by commas (example: 1,2).'
            while ($true) {
                $entries = (Read-Host 'Mods to install [1,2,3]').Trim()
                if (-not $entries) { $entries = '1,2,3' }
                $numbers = @($entries -split ',' | ForEach-Object { $_.Trim() } | Select-Object -Unique)
                if ($numbers.Count -gt 0 -and @($numbers | Where-Object { $_ -notin @('1','2','3') }).Count -eq 0) {
                    break
                }
                Write-Host 'Use only 1, 2, and 3, separated by commas.' -ForegroundColor Yellow
            }
            $map = @{ '1'='Movement'; '2'='ClientFindr'; '3'='Ultrawide' }
            $Mods = @($numbers | ForEach-Object { $map[$_] })
        }
        '3' { $Action = 'Uninstall' }
        '4' { Write-Host 'No changes made.'; exit 0 }
    }

    if ($Action -eq 'Install') {
        $resolvedMods = if ($Mods -contains 'All') { @('Movement','ClientFindr','Ultrawide') } else { $Mods }
        if ($resolvedMods -contains 'ClientFindr') {
            Write-Host ''
            Write-Host 'Client Findr divisor: lower values are sharper but use more GPU power.'
            $ClientFindrResolutionDivisor = Read-IntegerChoice `
                'Divisor (recommended: 4)' 4 @(1,2,4,8,16,32) 0 0
        }
        if ($resolvedMods -contains 'Ultrawide') {
            Write-Host ''
            $BorderlessWidth = Read-IntegerChoice 'Borderless width' 3440 @() 640 16384
            $BorderlessHeight = Read-IntegerChoice 'Borderless height' 1440 @() 480 8640
        }
        Write-Host ''
    }
}

if ($Action -eq 'Uninstall') {
    & (Join-Path $PSScriptRoot 'Uninstall.ps1')
    exit $LASTEXITCODE
}

$selected = if ($Mods -contains 'All') {
    @('Movement', 'ClientFindr', 'Ultrawide')
} else {
    @($Mods | Select-Object -Unique)
}

foreach ($mod in $selected) {
    switch ($mod) {
        'Movement' {
            & (Join-Path $PSScriptRoot 'PatchSmoothMovement.ps1')
            if ($LASTEXITCODE) { exit $LASTEXITCODE }
        }
        'ClientFindr' {
            & (Join-Path $PSScriptRoot 'PatchClientFindr.ps1') `
                -ResolutionDivisor $ClientFindrResolutionDivisor
            if ($LASTEXITCODE) { exit $LASTEXITCODE }
        }
        'Ultrawide' {
            & (Join-Path $PSScriptRoot 'PatchUltrawideBorderless.ps1') `
                -Width $BorderlessWidth -Height $BorderlessHeight
            if ($LASTEXITCODE) { exit $LASTEXITCODE }
        }
    }
}

Write-Host "Selected Embr mods installed: $($selected -join ', ')"
