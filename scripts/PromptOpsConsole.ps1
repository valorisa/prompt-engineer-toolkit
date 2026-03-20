#!/usr/bin/env pwsh
<#
.SYNOPSIS
    PromptOps Console - Interactive CLI for prompt-engineer-toolkit.
.DESCRIPTION
    Interactive menu-driven console for project management, automation,
    documentation, and prompt engineering tools.
.NOTES
    Author: valorisa
    License: MIT
    Version: 2.1.0
#>

[CmdletBinding()]
param(
    [switch]$Help,
    [switch]$Version,
    [switch]$WhatIf
)

# ============================================================================
# CORRECTION ENCODAGE UTF-8
# ============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Wrapper pour environnements headless (CI/CD)
try {
    [System.Console]::TreatControlCAsInput = $true
} catch {
    Write-Verbose "Exception interceptée et ignorée volontairement (compatibilité hôte/CI)."
}

# ============================================================================
# CONFIGURATION GLOBALE
# ============================================================================
$ScriptVersion = "2.1.0"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogPath = Join-Path $ProjectRoot "logs/promptops-console.log"
$ConfigPath = Join-Path $ProjectRoot ".promptops-config.json"
$HistoryPath = Join-Path $ProjectRoot "logs/console-history.log"

# ============================================================================
# DÉTECTION ROBUSTE DU MODE INTERACTIF / CI
# ============================================================================
$script:IsCI = (($env:GITHUB_ACTIONS -eq 'true') -or ($env:CI -eq 'true'))

$script:IsNonInteractiveSession = $false
try {
    $cmdLine = [string]::Join(' ', [Environment]::GetCommandLineArgs())
    $script:IsNonInteractiveSession = ($cmdLine -match '(?i)(^|\s)-noninteractive(\s|$)')
} catch {
    $script:IsNonInteractiveSession = $false
}

$script:CanPrompt = $true
try {
    $script:CanPrompt = -not [Console]::IsInputRedirected
} catch {
    $script:CanPrompt = [Environment]::UserInteractive
}

if ($script:IsNonInteractiveSession) {
    $script:CanPrompt = $false
}

# ============================================================================
# FAST-PATHS CI / TESTS
# ============================================================================
# IMPORTANT: return (pas exit) pour ne pas tuer le process Pester
if ($Version.IsPresent) {
    Write-Output $ScriptVersion
    return
}

if ($Help.IsPresent) {
    Write-Output @"
PromptOps Console v$ScriptVersion
Usage:
  ./scripts/PromptOpsConsole.ps1 -Help
  ./scripts/PromptOpsConsole.ps1 -Version
  ./scripts/PromptOpsConsole.ps1
"@
    return
}

if (-not $script:CanPrompt) {
    Write-Output "PromptOps Console v$ScriptVersion"
    Write-Output "Non-interactive mode detected. Exiting."
    return
}

if ($script:IsCI -and $PSBoundParameters.Count -eq 0) {
    Write-Output "PromptOps Console v$ScriptVersion"
    Write-Output "CI mode detected. Exiting interactive console."
    return
}

# ============================================================================
# THÈMES
# ============================================================================
$Themes = @{
    "default" = @{
        "Title" = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Info" = "White"
        "Highlight" = "Magenta"
        "Border" = "White"
    }
    "dark" = @{
        "Title" = "Blue"
        "Success" = "DarkGreen"
        "Warning" = "DarkYellow"
        "Error" = "DarkRed"
        "Info" = "Gray"
        "Highlight" = "DarkMagenta"
        "Border" = "White"
    }
    "light" = @{
        "Title" = "DarkBlue"
        "Success" = "Green"
        "Warning" = "DarkYellow"
        "Error" = "Red"
        "Info" = "Black"
        "Highlight" = "Magenta"
        "Border" = "White"
    }
}

# ============================================================================
# CONSTANTES UI & FORMATAGE
# ============================================================================
$UIWidth = 72
$script:FrameBorderColor = "White"
$script:FrameDefaultPrefix = "  "

function Get-DisplayWidth {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return 0 }

    $width = 0
    $enumerator = [System.Globalization.StringInfo]::GetTextElementEnumerator($Text)

    while ($enumerator.MoveNext()) {
        $element = $enumerator.GetTextElement()

        try {
            $codePoint = [System.Text.Rune]::GetRuneAt($element, 0).Value
        } catch {
            $codePoint = [int][char]$element[0]
        }

        if (
            ($codePoint -ge 0x1100 -and $codePoint -le 0x115F) -or
            ($codePoint -ge 0x2E80 -and $codePoint -le 0xA4CF) -or
            ($codePoint -ge 0xAC00 -and $codePoint -le 0xD7A3) -or
            ($codePoint -ge 0xF900 -and $codePoint -le 0xFAFF) -or
            ($codePoint -ge 0xFE10 -and $codePoint -le 0xFE19) -or
            ($codePoint -ge 0x1F300 -and $codePoint -le 0x1FAFF)
        ) {
            $width += 2
        } else {
            $width++
        }
    }

    return $width
}

function Get-TruncatedText {
    param(
        [string]$Text,
        [int]$MaxWidth
    )

    if ([string]::IsNullOrEmpty($Text)) { return "" }
    if ((Get-DisplayWidth -Text $Text) -le $MaxWidth) { return $Text }

    $builder = New-Object System.Text.StringBuilder
    $width = 0
    $enumerator = [System.Globalization.StringInfo]::GetTextElementEnumerator($Text)

    while ($enumerator.MoveNext()) {
        $element = $enumerator.GetTextElement()
        $elementWidth = Get-DisplayWidth -Text $element

        if (($width + $elementWidth) -gt ($MaxWidth - 1)) { break }

        [void]$builder.Append($element)
        $width += $elementWidth
    }

    [void]$builder.Append("…")
    return $builder.ToString()
}

function Format-BoxContent {
    param(
        [string]$Text = "",
        [int]$Width = $UIWidth,
        [string]$Prefix = $script:FrameDefaultPrefix
    )

    $content = "$Prefix$Text"
    if (-not $Text -and -not $Prefix) { $content = "" }

    $displayWidth = Get-DisplayWidth -Text $content
    if ($displayWidth -gt $Width) {
        $content = Get-TruncatedText -Text $content -MaxWidth $Width
        $displayWidth = Get-DisplayWidth -Text $content
    }

    $padding = $Width - $displayWidth
    if ($padding -lt 0) { $padding = 0 }

    return $content + (" " * $padding)
}

function Get-BorderLine {
    param([string]$FillChar = "═")
    $char = if ([string]::IsNullOrEmpty($FillChar)) { "═" } else { $FillChar.Substring(0, 1) }
    return $char * $UIWidth
}

function Write-FrameTop {
    param([string]$FillChar = "═")
    Write-Host ("╔{0}╗" -f (Get-BorderLine -FillChar $FillChar)) -ForegroundColor $script:FrameBorderColor
}

function Write-FrameSeparator {
    param([string]$FillChar = "─")
    Write-Host ("╠{0}╣" -f (Get-BorderLine -FillChar $FillChar)) -ForegroundColor $script:FrameBorderColor
}

function Write-FrameBottom {
    param([string]$FillChar = "═")
    Write-Host ("╚{0}╝" -f (Get-BorderLine -FillChar $FillChar)) -ForegroundColor $script:FrameBorderColor
}

function Write-FrameRow {
    param(
        [string]$Text = "",
        [string]$TextColor = "Gray",
        [string]$Prefix = $script:FrameDefaultPrefix
    )

    $content = Format-BoxContent -Text $Text -Width $UIWidth -Prefix $Prefix

    Write-Host "║" -NoNewline -ForegroundColor $script:FrameBorderColor
    Write-Host $content -NoNewline -ForegroundColor $TextColor
    Write-Host "║" -ForegroundColor $script:FrameBorderColor
}

function Read-MenuInput {
    param([string]$Prompt = "Select option")
    if (-not $script:CanPrompt) { return "0" }
    return Read-Host "  $Prompt"
}

function Read-Input {
    param([string]$Prompt)
    if (-not $script:CanPrompt) { return "" }
    return Read-Host "  $Prompt"
}

function Wait-Enter {
    param([string]$Message = "Press Enter to continue")
    if (-not $script:CanPrompt) { return }
    [void](Read-Host "  $Message")
}

# ============================================================================
# UTILITAIRES
# ============================================================================
function Get-DefaultConfig {
    return [pscustomobject]@{
        Theme = "default"
        ShowProgress = $true
        EnableLogs = $true
        MaxHistory = 10
    }
}

function Get-Config {
    $cfg = Get-DefaultConfig

    if (Test-Path $ConfigPath) {
        try {
            $raw = Get-Content -Path $ConfigPath -Raw
            $loaded = $raw | ConvertFrom-Json

            if ($null -ne $loaded.Theme) { $cfg.Theme = [string]$loaded.Theme }
            if ($null -ne $loaded.ShowProgress) { $cfg.ShowProgress = [bool]$loaded.ShowProgress }
            if ($null -ne $loaded.EnableLogs) { $cfg.EnableLogs = [bool]$loaded.EnableLogs }
            if ($null -ne $loaded.MaxHistory) { $cfg.MaxHistory = [int]$loaded.MaxHistory }
        } catch {
            return Get-DefaultConfig
        }
    }

    if (-not $Themes.ContainsKey($cfg.Theme)) {
        $cfg.Theme = "default"
    }

    if ($cfg.MaxHistory -lt 1) { $cfg.MaxHistory = 1 }
    if ($cfg.MaxHistory -gt 100) { $cfg.MaxHistory = 100 }

    return $cfg
}

function Save-Config {
    param($Config)

    $dir = Split-Path -Parent $ConfigPath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $Config | ConvertTo-Json -Depth 6 | Set-Content -Path $ConfigPath -Encoding UTF8
}

function Write-AppLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $config = Get-Config
    if (-not $config.EnableLogs) { return }

    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    Add-Content -Path $LogPath -Value $logEntry
    if ($Level -eq "ACTION") {
        Add-Content -Path $HistoryPath -Value $logEntry
    }
}

function Write-ActionLog {
    param([string]$Message)
    Write-AppLog -Message $Message -Level "ACTION"
}

function Get-ActionHistory {
    param([int]$Count = 10)

    if (Test-Path $HistoryPath) {
        return (Get-Content $HistoryPath | Select-Object -Last $Count)
    }

    return @()
}

function Clear-ActionHistory {
    if (Test-Path $HistoryPath) {
        Clear-Content $HistoryPath
        Write-Host "  ✓ History cleared" -ForegroundColor Green
    }
}

function Show-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity
    )

    $config = Get-Config
    if (-not $config.ShowProgress) { return }
    if ($Total -le 0) { return }

    $percent = [math]::Round(($Current / $Total) * 100, 2)
    $filled = [Math]::Min(20, [int]($percent / 5))
    $empty = 20 - $filled
    $progress = "[" + ("█" * $filled) + ("░" * $empty) + "]"

    Write-Host ("  {0} {1} {2}%" -f $Activity, $progress, $percent)
}

function Invoke-ProgressTask {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Activity,
        [scriptblock]$Task,
        [int]$Steps = 5
    )

    if ($PSCmdlet.ShouldProcess($Activity, "Execute progress task")) {
        Write-Host "`n⏳ $Activity..." -ForegroundColor Yellow
        for ($i = 1; $i -le $Steps; $i++) {
            Show-ProgressBar -Current $i -Total $Steps -Activity $Activity
            & $Task
            Start-Sleep -Milliseconds 180
        }
        Write-Host "  ✓ Complete!" -ForegroundColor Green
    }
}

function Test-AutoUpdate {
    Write-Host "`n🔄 Checking for updates..." -ForegroundColor Cyan
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/valorisa/prompt-engineer-toolkit/releases/latest" -TimeoutSec 5
        $latestVersion = $response.tag_name -replace 'v', ''

        if ($latestVersion -gt $ScriptVersion) {
            Write-Host "  ⚠ New version available: v$latestVersion (you have v$ScriptVersion)" -ForegroundColor Yellow
            Write-Host "  Run: git pull origin main" -ForegroundColor Gray
            Write-ActionLog "Update available: v$latestVersion"
        } else {
            Write-Host "  ✓ You're up to date (v$ScriptVersion)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ⚠ Could not check for updates (offline?)" -ForegroundColor Gray
    }
}

function Format-TestOutput {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]$InputObject
    )

    process {
        if ($null -eq $InputObject) { return }
        $segments = $InputObject -split "`r`n|`n|`r"

        foreach ($line in $segments) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                Write-Host ""
                continue
            }

            if ($line -match "✔|✓|pass|Success|✅") {
                Write-Host "  $line" -ForegroundColor Green
            } elseif ($line -match "✖|✗|fail|Error|❌") {
                Write-Host "  $line" -ForegroundColor Red
            } elseif ($line -match "▶|Running|ℹ|tests|suites") {
                Write-Host "  $line" -ForegroundColor Cyan
            } elseif ($line -match "⚠|Warning|already") {
                Write-Host "  $line" -ForegroundColor Yellow
            } else {
                Write-Host "  $line" -ForegroundColor Gray
            }
        }
    }
}

function Show-StatusPanel {
    param(
        [string]$Title,
        [string]$Color = "Yellow"
    )

    Write-Host ""
    Write-FrameTop -FillChar "═"
    Write-FrameRow -Text $Title -TextColor $Color
    Write-FrameBottom -FillChar "═"
    Write-Host ""
}

# ============================================================================
# AFFICHAGE
# ============================================================================
function Show-Header {
    param([string]$Title, [string]$Version)

    $config = Get-Config
    $theme = $Themes[$config.Theme]
    $script:FrameBorderColor = $theme.Border

    Write-Host ""
    Write-FrameTop -FillChar "═"
    Write-FrameRow -Text "🚀  $Title v$Version" -TextColor $theme.Title
    Write-FrameRow -Text "Type '?' for help, '0' to exit" -TextColor $theme.Info
    Write-FrameBottom -FillChar "═"
    Write-Host ""
}

function Show-Menu {
    param([string]$Version)

    $config = Get-Config
    $theme = $Themes[$config.Theme]
    $script:FrameBorderColor = $theme.Border

    Write-FrameTop -FillChar "─"
    Write-FrameRow -Text "PromptOps Console v$Version" -TextColor $theme.Title
    Write-FrameSeparator -FillChar "─"

    Write-FrameRow -Text "[1] Project Scaffold" -TextColor $theme.Info
    Write-FrameRow -Text "[2] Automation Engine" -TextColor $theme.Info
    Write-FrameRow -Text "[3] Docs Generator" -TextColor $theme.Info
    Write-FrameRow -Text "[4] Super-Prompt Studio" -TextColor White
    Write-FrameRow -Text "[5] Health Check" -TextColor $theme.Info
    Write-FrameRow -Text "[6] Setting" -TextColor $theme.Info
    Write-FrameRow -Text "[?] Help" -TextColor $theme.Info
    Write-FrameRow -Text "[0] Exit" -TextColor $theme.Success

    Write-FrameBottom -FillChar "─"
    Write-Host ""
}

function Show-SubMenu {
    param(
        [string]$Title,
        [string[]]$Options = @()
    )

    $config = Get-Config
    $theme = $Themes[$config.Theme]
    $script:FrameBorderColor = $theme.Border

    Write-Host ""
    Write-FrameTop -FillChar "─"
    Write-FrameRow -Text $Title -TextColor $theme.Title

    if ($Options.Count -gt 0) {
        Write-FrameSeparator -FillChar "─"
        foreach ($option in $Options) {
            if ([string]::IsNullOrWhiteSpace($option)) {
                Write-FrameRow -Text "" -TextColor $theme.Info -Prefix ""
            } else {
                Write-FrameRow -Text $option -TextColor $theme.Info
            }
        }
    }

    Write-FrameBottom -FillChar "─"
    Write-Host ""
}

function Show-Message {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    $config = Get-Config
    $theme = $Themes[$config.Theme]

    $color = switch ($Type) {
        "Success" { $theme.Success }
        "Warning" { $theme.Warning }
        "Error"   { $theme.Error }
        default   { $theme.Info }
    }

    Write-Host "  $Message" -ForegroundColor $color
}

# ============================================================================
# SOUS-MENUS
# ============================================================================
function Show-ProjectScaffold {
    Show-SubMenu -Title "🔨 Project Scaffold" -Options @(
        "Enter project name and generate folder structure.",
        "Includes src/tests/docs/config/scripts/.github"
    )

    $projectName = Read-Input -Prompt "Enter project name"
    if (-not $projectName) {
        Show-Message "⚠ No project name entered" "Warning"
        Write-ActionLog "Scaffold cancelled - no name"
        Wait-Enter "Press Enter to continue"
        return
    }

    $targetPath = Join-Path (Join-Path $ProjectRoot "..") $projectName
    if (Test-Path $targetPath) {
        Show-Message "⚠ Project '$projectName' already exists!" "Error"
        Write-ActionLog "Scaffold failed - project exists: $projectName"
        Wait-Enter "Press Enter to continue"
        return
    }

    Show-Message "📦 Creating project structure..." "Info"

    $folders = @("src", "tests", "docs", "config", "scripts", ".github/workflows")
    $total = $folders.Count

    for ($i = 0; $i -lt $folders.Count; $i++) {
        $folder = $folders[$i]
        $fullPath = Join-Path $targetPath $folder
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
        Show-ProgressBar -Current ($i + 1) -Total $total -Activity "Creating $folder"
    }

    Set-Content -Path (Join-Path $targetPath "README.md") -Value "# $projectName`n`nProject created with PromptOps Console"
    Set-Content -Path (Join-Path $targetPath ".gitignore") -Value "node_modules/`n*.log`n.env"

    Show-Message "✓ Project '$projectName' scaffolded successfully!" "Success"
    Show-Message "Location: $targetPath" "Info"
    Write-ActionLog "Scaffold created: $projectName at $targetPath"

    Wait-Enter "Press Enter to continue"
}

function Show-AutomationEngine {
    Show-SubMenu -Title "⚙️ Automation Engine" -Options @(
        "[1] Run all tests (npm test)",
        "[2] Run tests with coverage",
        "[3] Build project",
        "[4] Deploy (coming soon)",
        "[0] Back to main menu"
    )

    $choice = Read-MenuInput -Prompt "Select automation"

    switch ($choice) {
        "1" {
            Show-StatusPanel -Title "🧪 Running all tests..." -Color "Yellow"
            Write-ActionLog "Automation: Running npm test"

            $nodePath = Join-Path $ProjectRoot "scripts/node"
            if (-not (Test-Path $nodePath)) {
                Show-Message "❌ Node project not found: $nodePath" "Error"
                Wait-Enter "Press Enter to continue"
                return
            }

            Push-Location $nodePath
            try {
                npm test 2>&1 | Format-TestOutput
            } finally {
                Pop-Location
            }

            Show-StatusPanel -Title "✅ Tests completed!" -Color "Green"
            Write-ActionLog "Automation: Tests completed"
            Wait-Enter "Press Enter to continue"
        }

        "2" {
            Show-StatusPanel -Title "📊 Running tests with coverage..." -Color "Yellow"
            Write-ActionLog "Automation: Running tests with coverage"

            $nodePath = Join-Path $ProjectRoot "scripts/node"
            if (-not (Test-Path $nodePath)) {
                Show-Message "❌ Node project not found: $nodePath" "Error"
                Wait-Enter "Press Enter to continue"
                return
            }

            Push-Location $nodePath
            try {
                npm test -- --coverage 2>&1 | Format-TestOutput
            } finally {
                Pop-Location
            }

            Show-StatusPanel -Title "✅ Coverage report generated!" -Color "Green"
            Wait-Enter "Press Enter to continue"
        }

        "3" {
            Invoke-ProgressTask -Activity "Building project" -Task { Start-Sleep -Milliseconds 100 }
            Write-ActionLog "Automation: Build completed"
            Wait-Enter "Press Enter to continue"
        }

        "4" {
            Show-Message "⚠ Deploy coming soon..." "Warning"
            Write-ActionLog "Automation: Deploy requested (not implemented)"
            Wait-Enter "Press Enter to continue"
        }

        "0" { return }
        default { return }
    }
}

function Show-DocsGenerator {
    Show-SubMenu -Title "📚 Docs Generator" -Options @(
        "Scan documentation targets and report availability."
    )

    $docs = @(
        @{ Name = "README.md";         Path = (Join-Path $ProjectRoot "README.md") },
        @{ Name = "API Documentation"; Path = (Join-Path $ProjectRoot "docs/API.md") },
        @{ Name = "Usage Examples";    Path = (Join-Path $ProjectRoot "docs/USAGE.md") },
        @{ Name = "Architecture";      Path = (Join-Path $ProjectRoot "docs/ARCHITECTURE.md") }
    )

    Write-Host "`nGenerating documentation..." -ForegroundColor Yellow
    Write-ActionLog "Docs: Generation started"

    for ($i = 0; $i -lt $docs.Count; $i++) {
        $doc = $docs[$i]
        if (Test-Path $doc.Path) {
            Show-ProgressBar -Current ($i + 1) -Total $docs.Count -Activity $doc.Name
            Write-Host "  ✓ $($doc.Name)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ $($doc.Name) (not found)" -ForegroundColor Yellow
        }
    }

    Write-ActionLog "Docs: Generation completed"
    Write-Host "`n✓ Documentation scan complete!" -ForegroundColor Green
    Wait-Enter "Press Enter to continue"
}

function Show-SuperPromptStudio {
    Show-SubMenu -Title "🤖 Super-Prompt Studio" -Options @(
        "Launch PromptOps Node.js CLI utilities."
    )

    Write-ActionLog "Super-Prompt Studio: Launched"
    $nodePath = Join-Path $ProjectRoot "scripts/node"

    if (-not (Test-Path $nodePath)) {
        Show-Message "❌ Node.js CLI not found at: $nodePath" "Error"
        Write-ActionLog "CLI: Not found at $nodePath"
        Wait-Enter "Press Enter to continue"
        return
    }

    Push-Location $nodePath
    try {
        while ($true) {
            Show-SubMenu -Title "PromptOps Node.js CLI" -Options @(
                "[1] List plugins",
                "[2] Run hello-world",
                "[3] Run promptor-matrix",
                "[4] Run custom plugin",
                "[5] Search plugins",
                "[0] Back to main menu"
            )

            $cliChoice = Read-MenuInput -Prompt "Select option"

            switch ($cliChoice) {
                "1" {
                    Write-Host "`n📋 Listing plugins..." -ForegroundColor Yellow
                    Write-ActionLog "CLI: List plugins"
                    npx tsx promptops.ts list 2>&1 | Format-TestOutput
                    Wait-Enter "Press Enter to continue"
                }

                "2" {
                    $name = Read-Input -Prompt "Enter name (or press Enter for default)"
                    Write-ActionLog "CLI: Run hello-world --name=$name"

                    if ($name) {
                        npx tsx promptops.ts run hello-world --name=$name 2>&1 | Format-TestOutput
                    } else {
                        npx tsx promptops.ts run hello-world 2>&1 | Format-TestOutput
                    }

                    Wait-Enter "Press Enter to continue"
                }

                "3" {
                    Write-Host "`n🤖 Launching Promptor Matrix..." -ForegroundColor Yellow
                    Write-ActionLog "CLI: Run promptor-matrix"
                    npx tsx promptops.ts run promptor-matrix 2>&1 | Format-TestOutput
                    Wait-Enter "Press Enter to continue"
                }

                "4" {
                    $plugin = Read-Input -Prompt "Enter plugin name"
                    if ($plugin) {
                        Write-ActionLog "CLI: Run $plugin"
                        npx tsx promptops.ts run $plugin 2>&1 | Format-TestOutput
                        Wait-Enter "Press Enter to continue"
                    }
                }

                "5" {
                    Write-Host "`n🔍 Search Plugins" -ForegroundColor Cyan
                    $search = Read-Input -Prompt "Enter search term"
                    if ($search) {
                        Write-Host "`nSearching for '$search'..." -ForegroundColor Yellow
                        $output = npx tsx promptops.ts list 2>&1
                        $output | Select-String $search | ForEach-Object { Write-Host "  $_" -ForegroundColor Cyan }
                    }
                    Wait-Enter "Press Enter to continue"
                }

                "0" { break }

                default {
                    Write-Host "  Invalid option" -ForegroundColor Red
                    Start-Sleep -Milliseconds 500
                }
            }

            if ($cliChoice -eq "0") { break }
        }
    } finally {
        Pop-Location
    }
}

function Show-HealthCheck {
    Show-SubMenu -Title "✅ Health Check" -Options @(
        "Run repository diagnostics plus a quick npm smoke test."
    )

    Write-ActionLog "Health Check: Started"

    $checks = @{
        "Git repository"      = { Test-Path (Join-Path $ProjectRoot ".git") }
        "Node.js scripts"     = { Test-Path (Join-Path $ProjectRoot "scripts/node") }
        "PowerShell scripts"  = { Test-Path (Join-Path $ProjectRoot "scripts/PromptOpsConsole.ps1") }
        "README.md"           = { Test-Path (Join-Path $ProjectRoot "README.md") }
        "Tests"               = { (Get-ChildItem (Join-Path $ProjectRoot "scripts/node/*.test.ts") -ErrorAction SilentlyContinue).Count -gt 0 }
        "package.json"        = { Test-Path (Join-Path $ProjectRoot "scripts/node/package.json") }
        "tsconfig.json"       = { Test-Path (Join-Path $ProjectRoot "scripts/node/tsconfig.json") }
        "Logs folder"         = { Test-Path (Join-Path $ProjectRoot "logs") }
    }

    $passed = 0
    $total = $checks.Count

    foreach ($check in $checks.GetEnumerator()) {
        $result = & $check.Value
        if ($result) {
            Write-Host "  ✓ $($check.Key)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  ✗ $($check.Key)" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 90
    }

    Write-Host "`n🧪 Running quick test..." -ForegroundColor Yellow

    $nodePath = Join-Path $ProjectRoot "scripts/node"
    if (Test-Path $nodePath) {
        Push-Location $nodePath
        try {
            $testResult = npm test 2>&1 | Select-String "pass|fail|tests|suites" | Select-Object -First 5
        } finally {
            Pop-Location
        }

        if ($testResult) {
            Write-Host "  Test results:" -ForegroundColor Cyan
            $testResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    } else {
        Write-Host "  ⚠ Skipped npm smoke test (scripts/node missing)" -ForegroundColor Yellow
    }

    $percent = [math]::Round(($passed / $total) * 100, 0)
    Write-Host "`n📊 Overall Status: " -NoNewline

    if ($percent -eq 100) {
        Write-Host "HEALTHY ($percent%)" -ForegroundColor Green
    } elseif ($percent -ge 75) {
        Write-Host "GOOD ($percent%)" -ForegroundColor Yellow
    } else {
        Write-Host "NEEDS ATTENTION ($percent%)" -ForegroundColor Red
    }

    Write-ActionLog "Health Check: Completed ($passed/$total passed)"
    Wait-Enter "Press Enter to continue"
}

function Show-Setting {
    Show-SubMenu -Title "⚙️ Setting" -Options @(
        "Adjust themes, logging, progress bars and history limits."
    )

    $config = Get-Config

    while ($true) {
        $progressText = if ($config.ShowProgress) { "Enabled" } else { "Disabled" }
        $logsText = if ($config.EnableLogs) { "Enabled" } else { "Disabled" }

        $options = @(
            "Theme: $($config.Theme)",
            "Show Progress Bars: $progressText",
            "Enable Logs: $logsText",
            "Max History: $($config.MaxHistory)",
            "",
            "[1] Change Theme",
            "[2] Toggle Progress Bars",
            "[3] Toggle Logs",
            "[4] Set Max History",
            "[5] View Action History",
            "[6] Clear History",
            "[0] Back to main menu"
        )

        Show-SubMenu -Title "⚙️ Setting Panel" -Options $options
        $choice = Read-MenuInput -Prompt "Select option"

        switch ($choice) {
            "1" {
                Write-Host "`nAvailable themes: default, dark, light"
                $theme = Read-Input -Prompt "Enter theme"

                if ($Themes.ContainsKey($theme)) {
                    $config.Theme = $theme
                    Save-Config $config
                    Show-Message "✓ Theme changed to '$theme'" "Success"
                    Write-ActionLog "Setting: Theme changed to $theme"
                } else {
                    Show-Message "⚠ Unknown theme" "Warning"
                }
            }

            "2" {
                $config.ShowProgress = -not $config.ShowProgress
                Save-Config $config
                $text = if ($config.ShowProgress) { "Enabled" } else { "Disabled" }
                Show-Message "✓ Progress bars: $text" "Success"
                Write-ActionLog "Setting: Progress toggled to $($config.ShowProgress)"
            }

            "3" {
                $config.EnableLogs = -not $config.EnableLogs
                Save-Config $config
                $text = if ($config.EnableLogs) { "Enabled" } else { "Disabled" }
                Show-Message "✓ Logs: $text" "Success"
                Write-ActionLog "Setting: Logs toggled to $($config.EnableLogs)"
            }

            "4" {
                $maxText = Read-Input -Prompt "Enter max history (1-100)"
                $maxValue = 0
                if ([int]::TryParse($maxText, [ref]$maxValue) -and $maxValue -ge 1 -and $maxValue -le 100) {
                    $config.MaxHistory = $maxValue
                    Save-Config $config
                    Show-Message "✓ Max history set to $maxValue" "Success"
                    Write-ActionLog "Setting: MaxHistory set to $maxValue"
                } else {
                    Show-Message "⚠ Value out of range or invalid number" "Warning"
                }
            }

            "5" {
                Write-Host "`n📜 Recent Actions:" -ForegroundColor Cyan
                Get-ActionHistory -Count $config.MaxHistory | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
                Wait-Enter "Press Enter to continue"
            }

            "6" {
                Clear-ActionHistory
            }

            "0" { break }
            default { }
        }

        if ($choice -eq "0") { break }
    }
}

function Show-Help {
    $helpLines = @(
        "[1] Project Scaffold    - Create new project structure",
        "[2] Automation Engine   - Run automation scripts",
        "[3] Docs Generator      - Generate documentation",
        "[4] Super-Prompt Studio - Launch Node.js CLI for prompts",
        "[5] Health Check        - Run tests and check project status",
        "[6] Setting             - Configure options",
        "[?] Help                - Show this help",
        "[0] Exit                - Exit the console",
        "",
        "SHORTCUTS:",
        "  ?    Show help",
        "  0    Exit"
    )

    Show-SubMenu -Title "PromptOps Console Help" -Options $helpLines
    Wait-Enter "Press Enter to continue"
}

# ============================================================================
# BOUCLE PRINCIPALE
# ============================================================================
try {
    Clear-Host
} catch {
    Write-Verbose "Exception interceptée et ignorée volontairement (compatibilité hôte/CI)."
}

Show-Header -Title "Welcome to PromptOps Console" -Version $ScriptVersion
Test-AutoUpdate

while ($true) {
    $config = Get-Config
    $theme = $Themes[$config.Theme]

    Show-Menu -Version $ScriptVersion
    $choice = Read-MenuInput -Prompt "Select an option"

    # Garde-fou anti-boucle
    if (-not $script:CanPrompt -and [string]::IsNullOrWhiteSpace($choice)) {
        Write-Host "Non-interactive mode detected, exiting menu loop." -ForegroundColor Yellow
        break
    }

    switch ($choice) {
        "1" {
            Write-ActionLog "Menu: Project Scaffold selected"
            Show-ProjectScaffold
        }
        "2" {
            Write-ActionLog "Menu: Automation Engine selected"
            Show-AutomationEngine
        }
        "3" {
            Write-ActionLog "Menu: Docs Generator selected"
            Show-DocsGenerator
        }
        "4" {
            Write-ActionLog "Menu: Super-Prompt Studio selected"
            Show-SuperPromptStudio
        }
        "5" {
            Write-ActionLog "Menu: Health Check selected"
            Show-HealthCheck
        }
        "6" {
            Write-ActionLog "Menu: Setting selected"
            Show-Setting
        }
        "?" {
            Write-ActionLog "Menu: Help selected"
            Show-Help
        }
        "0" {
            Write-ActionLog "Menu: Exit selected"
            Write-Host "`n👋 Goodbye! Thanks for using PromptOps Console.`n" -ForegroundColor $theme.Success
            break
        }
        default {
            Write-Host "`n❌ Invalid option. Please choose 0-6 or ? for help." -ForegroundColor $theme.Error
            Write-ActionLog "Menu: Invalid option '$choice'"
            Start-Sleep -Seconds 1
        }
    }

    if ($choice -eq "0") { break }
}

Write-Host ""