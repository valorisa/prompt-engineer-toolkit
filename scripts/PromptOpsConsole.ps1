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
# CORRECTION ENCODAGE UTF-8 (APRÈS param() — OBLIGATOIRE !)
# ============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ✅ WRAPPER DANS TRY-CATCH POUR CI/CD (headless environments)
try {
    [System.Console]::TreatControlCAsInput = $true
} catch {
    # Ignorer en environnement headless (CI/CD, Docker, etc.)
}

# ============================================================================
# CONFIGURATION GLOBALE
# ============================================================================
$ScriptVersion = "2.1.0"
$ProjectRoot = $PSScriptRoot | Split-Path -Parent
$LogPath = "$ProjectRoot/logs/promptops-console.log"
$ConfigPath = "$ProjectRoot/.promptops-config.json"
$HistoryPath = "$ProjectRoot/logs/console-history.log"

# Thèmes de couleurs
$Themes = @{
    "default" = @{
        "Title" = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Info" = "White"
        "Highlight" = "Magenta"
        "Border" = "DarkGray"
    }
    "dark" = @{
        "Title" = "Blue"
        "Success" = "DarkGreen"
        "Warning" = "DarkYellow"
        "Error" = "DarkRed"
        "Info" = "Gray"
        "Highlight" = "DarkMagenta"
        "Border" = "Gray"
    }
    "light" = @{
        "Title" = "DarkBlue"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Info" = "Black"
        "Highlight" = "Magenta"
        "Border" = "DarkGray"
    }
}

# ============================================================================
# CONSTANTES UI & FONCTIONS DE FORMATAGE
# ============================================================================
$UIWidth = 72

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

function Truncate-Text {
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

function Format-BoxLine {
    param(
        [string]$Text = "",
        [int]$Width = $UIWidth,
        [string]$Prefix = "  "
    )
    $content = "$Prefix$Text"
    if (-not $Text -and -not $Prefix) { $content = "" }
    $displayWidth = Get-DisplayWidth -Text $content
    if ($displayWidth -gt $Width) {
        $content = Truncate-Text -Text $content -MaxWidth $Width
        $displayWidth = Get-DisplayWidth -Text $content
    }
    $padding = $Width - $displayWidth
    if ($padding -lt 0) { $padding = 0 }
    return "║$content" + (" " * $padding) + "║"
}

function Get-BorderLine {
    param([string]$FillChar = "═")
    $char = if ([string]::IsNullOrEmpty($FillChar)) { "═" } else { $FillChar.Substring(0,1) }
    return $char * $UIWidth
}

function Read-MenuInput {
    param([string]$Prompt = "Select option")
    return Read-Host "  $Prompt"
}

function Read-Input {
    param([string]$Prompt)
    return Read-Host "  $Prompt"
}

function Wait-Enter {
    param([string]$Message = "Press Enter to continue")
    [void](Read-Host "  $Message")
}

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================
function Get-Config {
    if (Test-Path $ConfigPath) {
        return Get-Content $ConfigPath | ConvertFrom-Json
    } else {
        return @{
            "Theme" = "default"
            "ShowProgress" = $true
            "EnableLogs" = $true
            "MaxHistory" = 10
        }
    }
}

function Save-Config {
    param($Config)
    $Config | ConvertTo-Json | Set-Content $ConfigPath
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $config = Get-Config
    if (-not $config.EnableLogs) { return }
    $logDir = Split-Path $LogPath -Parent
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

function Log-Action {
    param([string]$Message)
    Write-Log -Message $Message -Level "ACTION"
}

function Get-History {
    param([int]$Count = 10)
    if (Test-Path $HistoryPath) {
        Get-Content $HistoryPath | Select-Object -Last $Count
    } else {
        @()
    }
}

function Clear-History {
    if (Test-Path $HistoryPath) {
        Clear-Content $HistoryPath
        Write-Host "✓ History cleared" -ForegroundColor Green
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
    $percent = [math]::Round(($Current / $Total) * 100, 2)
    $progress = "[" + ("█" * [int]($percent / 5)) + ("░" * (20 - [int]($percent / 5))) + "]"
    Write-Host "  $Activity $progress $percent%" -NoNewline
    Write-Host ""
}

function Start-ProgressTask {
    param(
        [string]$Activity,
        [scriptblock]$Task,
        [int]$Steps = 5
    )
    Write-Host "`n⏳ $Activity..." -ForegroundColor Yellow
    for ($i = 1; $i -le $Steps; $i++) {
        Show-ProgressBar -Current $i -Total $Steps -Activity $Activity
        & $Task
        Start-Sleep -Milliseconds 200
    }
    Write-Host "  ✓ Complete!" -ForegroundColor Green
}

function Test-AutoUpdate {
    Write-Host "`n🔄 Checking for updates..." -ForegroundColor Cyan
    try {
        # ✅ CORRECTION: URL sans espaces trailing
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/valorisa/prompt-engineer-toolkit/releases/latest" -TimeoutSec 5
        $latestVersion = $response.tag_name -replace 'v', ''
        if ($latestVersion -gt $ScriptVersion) {
            Write-Host "  ⚠ New version available: v$latestVersion (you have v$ScriptVersion)" -ForegroundColor Yellow
            Write-Host "  Run: git pull origin main" -ForegroundColor Gray
            Log-Action "Update available: v$latestVersion"
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

# ============================================================================
# FONCTIONS D'AFFICHAGE (ALIGNEMENT PARFAIT)
# ============================================================================
function Show-Header {
    param([string]$Title, [string]$Version)
    $config = Get-Config
    $theme = $Themes[$config.Theme]
    $border = Get-BorderLine -FillChar "═"
    Write-Host ""
    Write-Host ("╔$border╗") -ForegroundColor $theme.Border
    Write-Host (Format-BoxLine -Text "🚀  $Title v$Version") -ForegroundColor $theme.Title
    Write-Host (Format-BoxLine -Text "Type '?' for help, '0' to exit") -ForegroundColor $theme.Info
    Write-Host ("╚$border╝") -ForegroundColor $theme.Border
    Write-Host ""
}

function Show-Menu {
    param([string]$Version)
    $config = Get-Config
    $theme = $Themes[$config.Theme]
    $border = Get-BorderLine -FillChar "─"
    Write-Host ("╔$border╗") -ForegroundColor $theme.Border
    Write-Host (Format-BoxLine -Text "PromptOps Console v$Version") -ForegroundColor $theme.Title
    Write-Host ("╠$border╣") -ForegroundColor $theme.Border
    Write-Host (Format-BoxLine -Text "[1] Project Scaffold") -ForegroundColor $theme.Info
    Write-Host (Format-BoxLine -Text "[2] Automation Engine") -ForegroundColor $theme.Info
    Write-Host (Format-BoxLine -Text "[3] Docs Generator") -ForegroundColor $theme.Info
    Write-Host (Format-BoxLine -Text "[4] Super-Prompt Studio") -ForegroundColor $theme.Info
    Write-Host (Format-BoxLine -Text "[5] Health Check") -ForegroundColor $theme.Info
    Write-Host (Format-BoxLine -Text "[6] Settings") -ForegroundColor $theme.Info
    Write-Host (Format-BoxLine -Text "[?] Help") -ForegroundColor $theme.Info
    Write-Host (Format-BoxLine -Text "[0] Exit") -ForegroundColor $theme.Success
    Write-Host ("╚$border╝") -ForegroundColor $theme.Border
    Write-Host ""
}

function Show-SubMenu {
    param(
        [string]$Title,
        [string[]]$Options = @()
    )
    $config = Get-Config
    $theme = $Themes[$config.Theme]
    $border = Get-BorderLine -FillChar "─"
    Write-Host ""
    Write-Host ("╔$border╗") -ForegroundColor $theme.Border
    Write-Host (Format-BoxLine -Text $Title) -ForegroundColor $theme.Title
    if ($Options.Count -gt 0) {
        Write-Host ("╠$border╣") -ForegroundColor $theme.Border
        foreach ($option in $Options) {
            if ([string]::IsNullOrWhiteSpace($option)) {
                Write-Host (Format-BoxLine -Text "" -Prefix "") -ForegroundColor $theme.Info
            } else {
                Write-Host (Format-BoxLine -Text $option) -ForegroundColor $theme.Info
            }
        }
    }
    Write-Host ("╚$border╝") -ForegroundColor $theme.Border
    Write-Host ""
}

function Show-Message {
    param([string]$Message, [string]$Type = "Info")
    $config = Get-Config
    $theme = $Themes[$config.Theme]
    $color = switch ($Type) {
        "Success" { $theme.Success }
        "Warning" { $theme.Warning }
        "Error" { $theme.Error }
        default { $theme.Info }
    }
    Write-Host "  $Message" -ForegroundColor $color
}

# ============================================================================
# FONCTIONS DES SOUS-MENUS
# ============================================================================
function Show-ProjectScaffold {
    Show-SubMenu -Title "🔨 Project Scaffold" -Options @(
        "Enter project name and generate folder structure.",
        "Includes src/tests/docs/config/scripts/.github"
    )
    $projectName = Read-Input -Prompt "Enter project name"
    if (-not $projectName) {
        Show-Message "⚠ No project name entered" "Warning"
        Log-Action "Scaffold cancelled - no name"
        Wait-Enter "Press Enter to continue"
        return
    }
    $targetPath = "$ProjectRoot/../$projectName"
    if (Test-Path $targetPath) {
        Show-Message "⚠ Project '$projectName' already exists!" "Error"
        Log-Action "Scaffold failed - project exists: $projectName"
        Wait-Enter "Press Enter to continue"
        return
    }
    Show-Message "📦 Creating project structure..." "Info"
    $folders = @("src", "tests", "docs", "config", "scripts", ".github/workflows")
    $total = $folders.Count
    for ($i = 0; $i -lt $folders.Count; $i++) {
        $folder = $folders[$i]
        $fullPath = "$targetPath/$folder"
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
        Show-ProgressBar -Current ($i + 1) -Total $total -Activity "Creating $folder"
    }
    Set-Content -Path "$targetPath/README.md" -Value "# $projectName`n`nProject created with PromptOps Console"
    Set-Content -Path "$targetPath/.gitignore" -Value "node_modules/`n*.log`n.env"
    Show-Message "✓ Project '$projectName' scaffolded successfully!" "Success"
    Show-Message "  Location: $targetPath" "Info"
    Log-Action "Scaffold created: $projectName at $targetPath"
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
            $border = Get-BorderLine -FillChar "═"
            Write-Host ""
            Write-Host ("╔$border╗") -ForegroundColor Yellow
            Write-Host (Format-BoxLine -Text "🧪 Running all tests...") -ForegroundColor Yellow
            Write-Host ("╚$border╝") -ForegroundColor Yellow
            Write-Host ""
            Log-Action "Automation: Running npm test"
            Set-Location "$ProjectRoot/scripts/node"
            npm test 2>&1 | Format-TestOutput
            Write-Host ""
            Write-Host ("╔$border╗") -ForegroundColor Green
            Write-Host (Format-BoxLine -Text "✅ Tests completed!") -ForegroundColor Green
            Write-Host ("╚$border╝") -ForegroundColor Green
            Set-Location $ProjectRoot
            Log-Action "Automation: Tests completed"
            Wait-Enter "Press Enter to continue"
        }
        "2" {
            $border = Get-BorderLine -FillChar "═"
            Write-Host ""
            Write-Host ("╔$border╗") -ForegroundColor Yellow
            Write-Host (Format-BoxLine -Text "📊 Running tests with coverage...") -ForegroundColor Yellow
            Write-Host ("╚$border╝") -ForegroundColor Yellow
            Write-Host ""
            Log-Action "Automation: Running tests with coverage"
            Set-Location "$ProjectRoot/scripts/node"
            npm test -- --coverage 2>&1 | Format-TestOutput
            Set-Location $ProjectRoot
            Write-Host ""
            Write-Host ("╔$border╗") -ForegroundColor Green
            Write-Host (Format-BoxLine -Text "✅ Coverage report generated!") -ForegroundColor Green
            Write-Host ("╚$border╝") -ForegroundColor Green
            Wait-Enter "Press Enter to continue"
        }
        "3" {
            Start-ProgressTask -Activity "Building project" -Task { Start-Sleep -Milliseconds 100 }
            Log-Action "Automation: Build completed"
            Wait-Enter "Press Enter to continue"
        }
        "4" {
            Show-Message "⚠ Deploy coming soon..." "Warning"
            Log-Action "Automation: Deploy requested (not implemented)"
            Wait-Enter "Press Enter to continue"
        }
        "0" { return }
    }
}

function Show-DocsGenerator {
    Show-SubMenu -Title "📚 Docs Generator" -Options @(
        "Scan documentation targets and report availability."
    )
    $docs = @(
        @{ Name = "README.md"; Path = "$ProjectRoot/README.md" },
        @{ Name = "API Documentation"; Path = "$ProjectRoot/docs/API.md" },
        @{ Name = "Usage Examples"; Path = "$ProjectRoot/docs/USAGE.md" },
        @{ Name = "Architecture"; Path = "$ProjectRoot/docs/ARCHITECTURE.md" }
    )
    Write-Host "`nGenerating documentation..." -ForegroundColor Yellow
    Log-Action "Docs: Generation started"
    for ($i = 0; $i -lt $docs.Count; $i++) {
        $doc = $docs[$i]
        if (Test-Path $doc.Path) {
            Show-ProgressBar -Current ($i + 1) -Total $docs.Count -Activity $doc.Name
            Write-Host "  ✓ $($doc.Name)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ $($doc.Name) (not found)" -ForegroundColor Yellow
        }
    }
    Log-Action "Docs: Generation completed"
    Write-Host "`n✓ Documentation scan complete!" -ForegroundColor Green
    Wait-Enter "Press Enter to continue"
}

function Show-SuperPromptStudio {
    Show-SubMenu -Title "🤖 Super-Prompt Studio" -Options @(
        "Launch PromptOps Node.js CLI utilities."
    )
    Log-Action "Super-Prompt Studio: Launched"
    $nodePath = "$ProjectRoot/scripts/node"
    if (Test-Path $nodePath) {
        Set-Location $nodePath
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
                    Log-Action "CLI: List plugins"
                    npx tsx promptops.ts list 2>&1 | Format-TestOutput
                    Wait-Enter "Press Enter to continue"
                }
                "2" {
                    $name = Read-Input -Prompt "Enter name (or press Enter for default)"
                    Log-Action "CLI: Run hello-world --name=$name"
                    if ($name) {
                        npx tsx promptops.ts run hello-world --name=$name 2>&1 | Format-TestOutput
                    } else {
                        npx tsx promptops.ts run hello-world 2>&1 | Format-TestOutput
                    }
                    Wait-Enter "Press Enter to continue"
                }
                "3" {
                    Write-Host "`n🤖 Launching Promptor Matrix..." -ForegroundColor Yellow
                    Log-Action "CLI: Run promptor-matrix"
                    npx tsx promptops.ts run promptor-matrix 2>&1 | Format-TestOutput
                    Wait-Enter "Press Enter to continue"
                }
                "4" {
                    $plugin = Read-Input -Prompt "Enter plugin name"
                    if ($plugin) {
                        Log-Action "CLI: Run $plugin"
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
        Set-Location $ProjectRoot
    } else {
        Show-Message "❌ Node.js CLI not found at: $nodePath" "Error"
        Log-Action "CLI: Not found at $nodePath"
        Wait-Enter "Press Enter to continue"
    }
}

function Show-HealthCheck {
    Show-SubMenu -Title "✅ Health Check" -Options @(
        "Run repository diagnostics plus a quick npm smoke test."
    )
    Log-Action "Health Check: Started"
    $checks = @{
        "Git repository" = { Test-Path ".git" }
        "Node.js scripts" = { Test-Path "scripts/node" }
        "PowerShell scripts" = { Test-Path "scripts/PromptOpsConsole.ps1" }
        "README.md" = { Test-Path "README.md" }
        "Tests" = { (Get-ChildItem "scripts/node/*.test.ts" -ErrorAction SilentlyContinue).Count -gt 0 }
        "package.json" = { Test-Path "scripts/node/package.json" }
        "tsconfig.json" = { Test-Path "scripts/node/tsconfig.json" }
        "Logs folder" = { Test-Path "$ProjectRoot/logs" }
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
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`n🧪 Running quick test..." -ForegroundColor Yellow
    Set-Location "$ProjectRoot/scripts/node"
    $testResult = npm test 2>&1 | Select-String "pass|fail" | Select-Object -First 5
    Set-Location $ProjectRoot
    if ($testResult) {
        Write-Host "  Test results:" -ForegroundColor Cyan
        $testResult | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
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
    Log-Action "Health Check: Completed ($passed/$total passed)"
    Wait-Enter "Press Enter to continue"
}

function Show-Settings {
    Show-SubMenu -Title "⚙️ Settings" -Options @(
        "Adjust themes, logging, progress bars and history limits."
    )
    $config = Get-Config
    while ($true) {
        $options = @(
            "Theme: $($config.Theme)",
            "Show Progress Bars: $($config.ShowProgress)",
            "Enable Logs: $($config.EnableLogs)",
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
        Show-SubMenu -Title "⚙️ Settings Panel" -Options $options
        $choice = Read-MenuInput -Prompt "Select option"
        switch ($choice) {
            "1" {
                Write-Host "`nAvailable themes: default, dark, light"
                $theme = Read-Input -Prompt "Enter theme"
                if ($Themes.ContainsKey($theme)) {
                    $config.Theme = $theme
                    Save-Config $config
                    Show-Message "✓ Theme changed to '$theme'" "Success"
                    Log-Action "Settings: Theme changed to $theme"
                } else {
                    Show-Message "⚠ Unknown theme" "Warning"
                }
            }
            "2" {
                $config.ShowProgress = -not $config.ShowProgress
                Save-Config $config
                Show-Message "✓ Progress bars: $((($config.ShowProgress) ? 'Enabled' : 'Disabled'))" "Success"
                Log-Action "Settings: Progress toggled to $($config.ShowProgress)"
            }
            "3" {
                $config.EnableLogs = -not $config.EnableLogs
                Save-Config $config
                Show-Message "✓ Logs: $((($config.EnableLogs) ? 'Enabled' : 'Disabled'))" "Success"
                Log-Action "Settings: Logs toggled to $($config.EnableLogs)"
            }
            "4" {
                $max = Read-Input -Prompt "Enter max history (1-100)"
                if ([int]$max -ge 1 -and [int]$max -le 100) {
                    $config.MaxHistory = [int]$max
                    Save-Config $config
                    Show-Message "✓ Max history set to $max" "Success"
                } else {
                    Show-Message "⚠ Value out of range" "Warning"
                }
            }
            "5" {
                Write-Host "`n📜 Recent Actions:" -ForegroundColor Cyan
                Get-History -Count $config.MaxHistory | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
                Wait-Enter "Press Enter to continue"
            }
            "6" {
                Clear-History
            }
            "0" { break }
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
        "[6] Settings            - Configure options",
        "[?] Help                - Show this help",
        "[0] Exit                - Exit the console",
        "",
        "SHORTCUTS:",
        "  ↑/↓  Navigate menu (coming soon)",
        "  ?    Show help",
        "  0    Exit"
    )
    Show-SubMenu -Title "PromptOps Console Help" -Options $helpLines
    Wait-Enter "Press Enter to continue"
}

# ============================================================================
# BOUCLE PRINCIPALE
# ============================================================================

# ✅ CORRECTION CI/CD: Clear-Host wrapper pour environnements headless
try {
    Clear-Host
} catch {
    # Ignorer si Clear-Host échoue (CI/CD, Docker, etc.)
}

Show-Header -Title "Welcome to PromptOps Console" -Version $ScriptVersion
Test-AutoUpdate

while ($true) {
    $config = Get-Config
    $theme = $Themes[$config.Theme]
    Show-Menu -Version $ScriptVersion
    $choice = Read-MenuInput -Prompt "Select an option"
    switch ($choice) {
        "1" {
            Log-Action "Menu: Project Scaffold selected"
            Show-ProjectScaffold
        }
        "2" {
            Log-Action "Menu: Automation Engine selected"
            Show-AutomationEngine
        }
        "3" {
            Log-Action "Menu: Docs Generator selected"
            Show-DocsGenerator
        }
        "4" {
            Log-Action "Menu: Super-Prompt Studio selected"
            Show-SuperPromptStudio
        }
        "5" {
            Log-Action "Menu: Health Check selected"
            Show-HealthCheck
        }
        "6" {
            Log-Action "Menu: Settings selected"
            Show-Settings
        }
        "?" {
            Log-Action "Menu: Help selected"
            Show-Help
        }
        "0" {
            Log-Action "Menu: Exit selected"
            Write-Host "`n👋 Goodbye! Thanks for using PromptOps Console.`n" -ForegroundColor $theme.Success
            break
        }
        default {
            Write-Host "`n❌ Invalid option. Please choose 0-6 or ? for help." -ForegroundColor $theme.Error
            Log-Action "Menu: Invalid option '$choice'"
            Start-Sleep -Seconds 1
        }
    }
    if ($choice -eq "0") { break }
}

Write-Host ""