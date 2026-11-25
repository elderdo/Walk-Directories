# Walk-Dirs

Here is a PowerShell script (Walk-Dirs.ps1) that reads a list of dirs file, filters out any line that doesn't start with a drive path (like C:\), and drops you into an interactive PowerShell subshell for each folder one by one.
Inside each folder's subshell, you have full PowerShell access (dir, tree, cat, code ., Remove-Item, etc.) plus quick single-letter shortcuts to move to the next folder or quit the entire session.

PowerShell Script (Walk-Dirs.ps1)

```powershell
<#
.SYNOPSIS
    Interactively steps through a list of directories from a text file, opening a subshell in each.
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
        Write-Host "Commands: Type any PowerShell command | 'n' or 'exit' = Next | 'q' = Quit all" -ForegroundColor DarkGray
        Write-Host "======================================================================" -ForegroundColor Cyan

        if ($AutoList) {
            Get-ChildItem
        }

        # Enter an interactive subshell loop for this directory
        $quitAll = $false
        while ($true) {
            $currentPath = (Get-Location).Path
            Write-Host "[$index/$total] PS $currentPath> " -NoNewline -ForegroundColor Yellow
            $userInput = Read-Host

            if ([string]::IsNullOrWhiteSpace($userInput)) {
                continue
            }

            $trimmed = $userInput.Trim()

            # Check for navigation/exit shortcuts
            if ($trimmed -ieq 'n' -or $trimmed -ieq 'next' -or $trimmed -ieq 'exit') {
                break
            }
            if ($trimmed -ieq 'q' -or $trimmed -ieq 'quit') {
                $quitAll = $true
                break
            }

            # Execute whatever PowerShell command was typed
            try {
                Invoke-Expression $userInput
            }
            catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
        }

        if ($quitAll) {
            Write-Host "`nStopped at folder $index of $total." -ForegroundColor Yellow
            break
        }
    }
}
finally {
    # Always return to where you started when finished or aborted
    Set-Location -LiteralPath $originalLocation
}

Write-Host "Done." -ForegroundColor Cyan
```

How to Use It

1. Save your Python output to a file (or use your existing file):powershell
   python find_non_sln_folders.py "C:\Users\Douglas\Documents\C#" --depth 1 > folders.txt
   Use code with caution.
1. Run the script against that file:powershell
   .\Walk-Dirs.ps1 .\folders.txt
   Use code with caution.
   (Tip: Add -AutoList if you want it to automatically list the files as soon as it enters each folder: .\Walk-Dirs.ps1 .\folders.txt -AutoList)

Controls Inside the Subshell

• Any PowerShell command (dir, ls, cd subfolder, cat README.md, start ., code ., rm ...): Runs normally right inside that folder.
• n (or next / exit): Moves immediately to the next directory in your list.
• q (or quit): Exits the entire script immediately and returns you to your original directory.
• Smart Filtering: Automatically ignores header lines (Folders without .sln...), blank lines, and footer lines (Total folders found: 94) using the regex ^[a-zA-Z]:[\\/].
Would you like to add any extra shortcuts to the subshell, such as:
• A d shortcut to prompt and delete the current folder before moving to the next?
• A s shortcut to save/log the current folder's path to a separate "keep/review later" text file?
• A b shortcut to step back to the previous directory in the list?
