<#
.SYNOPSIS
    Interactively steps through a list of directories from a text file using a native PowerShell nested prompt (with full Tab completion).
.PARAMETER ListFile
    Path to the text file containing directory paths.
.PARAMETER AutoList
    Automatically runs Get-ChildItem (dir) upon entering each directory.
#>

# The 'param' block defines the command-line arguments the script accepts.
# Because this block is at the top, PowerShell automatically generates help text and handles argument validation.
param(
    # 'Mandatory = $true' forces PowerShell to prompt the user if they forget to pass a file path.
    # 'Position = 0' allows passing the file directly (e.g., .\Walk-Dirs.ps1 list.txt) without typing '-ListFile'.
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ListFile,

    # A '[switch]' is a boolean flag that is $false by default and becomes $true only when included (e.g., -AutoList).
    [switch]$AutoList
)

# Verify the input file actually exists before doing any work.
# '-LiteralPath' treats special characters like '[' or ']' in file paths literally rather than as wildcards.
# '-PathType Leaf' ensures the path points to a file, not a folder.
if (-not (Test-Path -LiteralPath $ListFile -PathType Leaf)) {
    Write-Error "Input file not found: $ListFile"
    exit 1 # Exit with a non-zero status code to signal an error to the calling terminal/script.
}

# Read the text file and process it through a PowerShell pipeline ('|'), passing one line at a time to the next command.
# Wrapping the pipeline in '@(...)' guarantees the result is always an Array, even if only 0 or 1 matching lines are found.
$entries = @(
    Get-Content -LiteralPath $ListFile |
        # Remove leading and trailing spaces/tabs from each line.
        ForEach-Object { $_.Trim() } |
        # Filter the stream using a Regular Expression ('-match') to keep ONLY lines starting ('^') with:
        # a drive letter ('[a-zA-Z]'), a colon (':'), and a forward or backward slash ('[\\/]').
        # This automatically ignores headers, blank lines, and summary footers.
        Where-Object { $_ -match '^[a-zA-Z]:[\\/]' } |
        # Transform each valid text line into a structured object with two properties: 'Path' and 'Note'.
        ForEach-Object {
            # Check if the line has a bracketed '[Deep dive found: ...]' tag at the end.
            # Named capture groups '(?<Path>...)' and '(?<Note>...)' save the matched pieces into the built-in '$Matches' hashtable.
            if ($_ -match '^(?<Path>.+?)\s+(?<Note>\[Deep dive found:.*\])$') {
                # '[PSCustomObject]' creates a lightweight custom data object so we can keep the clean path separate from the display note.
                [PSCustomObject]@{
                    Path = $Matches['Path'].Trim()
                    Note = $Matches['Note'].Trim()
                }
            }
            else {
                # If there is no bracketed note, store the whole line as the Path and set Note to $null (empty).
                [PSCustomObject]@{
                    Path = $_
                    Note = $null
                }
            }
        }
)

# If no valid directory lines matched our filter, warn the user and stop gracefully.
if ($entries.Count -eq 0) {
    Write-Warning "No valid directory paths (starting with e.g. C:\) were found in '$ListFile'."
    exit 0
}

# Save the user's starting directory so we can restore it when the script finishes or is aborted.
$originalLocation = Get-Location
$total = $entries.Count
$index = 0

# '$script:quitAll' uses the 'script:' scope modifier so that functions defined inside this script
# can modify this variable and have the main loop see the updated value.
$script:quitAll = $false

# Define helper commands ('n' and 'q') that the user can type while inside the interactive subshell.
# The 'global:' scope modifier makes these functions visible inside the nested prompt session.
function global:n {
    # Exits the current nested subshell, returning control back to the 'foreach' loop to move to the next folder.
    $Host.ExitNestedPrompt()
}

function global:q {
    # Sets the quit flag to $true and exits the nested subshell so the 'foreach' loop knows to stop completely.
    $script:quitAll = $true
    $Host.ExitNestedPrompt()
}

# A 'try / finally' block guarantees that the cleanup code inside 'finally' ALWAYS runs—even if an error occurs
# or the user presses Ctrl+C.
try {
    foreach ($entry in $entries) {
        $index++
        $dir = $entry.Path

        # Check that the folder still exists on disk ('-PathType Container' checks specifically for a folder).
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
            Write-Warning "[$index/$total] Skipping missing directory: $dir"
            continue # Skip the rest of this loop iteration and jump straight to the next folder.
        }

        # Change the current working directory into the target folder.
        Set-Location -LiteralPath $dir

        # Print a colored header banner showing progress ([1/94]), the folder path, and any deep-dive note.
        # '`n' inserts a blank newline; '-NoNewline' keeps the cursor on the same line so the magenta note prints right next to the path.
        Write-Host "`n======================================================================" -ForegroundColor Cyan
        Write-Host "[$index/$total] $dir" -ForegroundColor Green -NoNewline
        if ($entry.Note) {
            # '$($entry.Note)' is a subexpression; it forces PowerShell to evaluate the object property inside double quotes.
            Write-Host "  $($entry.Note)" -ForegroundColor Magenta
        }
        else {
            Write-Host ""
        }
        Write-Host "Full Tab completion active | Type 'n' or 'exit' = Next | 'q' = Quit all" -ForegroundColor DarkGray
        Write-Host "======================================================================" -ForegroundColor Cyan

        # If the user passed the '-AutoList' switch, immediately list the files in the directory.
        if ($AutoList) {
            Get-ChildItem
        }

        # Pause the script and hand control over to a real interactive PowerShell prompt ('>>').
        # Unlike 'Read-Host', '$Host.EnterNestedPrompt()' preserves native Tab completion, command history, and syntax highlighting.
        # The script waits right here until the user types 'n', 'q', or 'exit'.
        $Host.EnterNestedPrompt()

        # Once the nested prompt exits, check if the user typed 'q' to abort the rest of the list.
        if ($script:quitAll) {
            Write-Host "`nStopped at folder $index of $total." -ForegroundColor Yellow
            break # Exit the 'foreach' loop immediately.
        }
    }
}
finally {
    # Clean up the temporary 'n' and 'q' global functions so they don't linger in the user's terminal session.
    # '-ErrorAction SilentlyContinue' prevents an error message if a function was already removed.
    Remove-Item Function:\global:n -ErrorAction SilentlyContinue
    Remove-Item Function:\global:q -ErrorAction SilentlyContinue

    # Return the terminal back to the exact folder where the user started.
    Set-Location -LiteralPath $originalLocation
}

Write-Host "Done." -ForegroundColor Cyan
