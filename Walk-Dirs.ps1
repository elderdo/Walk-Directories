<#
.SYNOPSIS
    Interactively steps through a list of directories from a text file using a native PowerShell nested prompt (with full Tab completion).
.PARAMETER ListFile
    Path to the text file containing directory paths.
.PARAMETER AutoList
    Automatically runs Get-ChildItem (dir) upon entering each directory.
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ListFile,

    [switch]$AutoList
)

if (-not (Test-Path -LiteralPath $ListFile -PathType Leaf)) {
    Write-Error "Input file not found: $ListFile"
    exit 1
}

# Read lines, trim whitespace, and keep ONLY lines starting with a drive letter, colon, and slash (e.g., C:\)
$directories = Get-Content -LiteralPath $ListFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -match '^[a-zA-Z]:[\\/]' }

if ($directories.Count -eq 0) {
    Write-Warning "No valid directory paths (starting with e.g. C:\) were found in '$ListFile'."
    exit 0
}

$originalLocation = Get-Location
$total = $directories.Count
$index = 0
$script:quitAll = $false

# Define helper functions available inside the nested subshell
function global:n {
    $Host.ExitNestedPrompt()
}

function global:q {
    $script:quitAll = $true
    $Host.ExitNestedPrompt()
}

try {
    foreach ($dir in $directories) {
        $index++

        if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
            Write-Warning "[$index/$total] Skipping missing directory: $dir"
            continue
        }

        Set-Location -LiteralPath $dir

        Write-Host "`n======================================================================" -ForegroundColor Cyan
        Write-Host "[$index/$total] $dir" -ForegroundColor Green
        Write-Host "Full Tab completion active | Type 'n' or 'exit' = Next | 'q' = Quit all" -ForegroundColor DarkGray
        Write-Host "======================================================================" -ForegroundColor Cyan

        if ($AutoList) {
            Get-ChildItem
        }

        # Enter a real PowerShell nested prompt (preserves PSReadLine Tab completion & history)
        $Host.EnterNestedPrompt()

        if ($script:quitAll) {
            Write-Host "`nStopped at folder $index of $total." -ForegroundColor Yellow
            break
        }
    }
}
finally {
    # Clean up the temporary navigation functions and return to original directory
    Remove-Item Function:\global:n -ErrorAction SilentlyContinue
    Remove-Item Function:\global:q -ErrorAction SilentlyContinue
    Set-Location -LiteralPath $originalLocation
}

Write-Host "Done." -ForegroundColor Cyan
