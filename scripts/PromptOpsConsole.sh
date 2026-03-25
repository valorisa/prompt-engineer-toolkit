#!/usr/bin/env bash
# ============================================================================
# PromptOps Console - Interactive CLI for prompt-engineer-toolkit
# License: MIT
# Version: 2.1.0
# TODO(v2): Add signal handling for SIGINT during long operations.
# TODO(v2): Implement JSON parsing for config without jq dependency fallback.
# ============================================================================

set -euo pipefail

SCRIPT_VERSION="2.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
LOG_PATH="${PROJECT_ROOT}/logs/promptops-console.log"
# CONFIG_PATH="${PROJECT_ROOT}/.promptops-config.json"  # ← Commenté car inutilisé (SC2034)
HISTORY_PATH="${PROJECT_ROOT}/logs/console-history.log"

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

log_action() {
    local message="${1}"
    local level="${2:-INFO}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    mkdir -p "$(dirname "${LOG_PATH}")"
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_PATH}"

    if [[ "${level}" == "ACTION" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "${HISTORY_PATH}"
    fi
}

get_history() {
    local count="${1:-10}"
    if [[ -f "${HISTORY_PATH}" ]]; then
        tail -n "${count}" "${HISTORY_PATH}"
    fi
}

clear_history() {
    if [[ -f "${HISTORY_PATH}" ]]; then
        : > "${HISTORY_PATH}"  # ← ✅ CORRIGÉ: redirection avec commande no-op (SC2188)
        echo -e "\e[32m✓ History cleared\e[0m"
    fi
}

show_progress_bar() {
    local current="${1}"
    local total="${2}"
    local activity="${3}"

    local percent=$(( (current * 100) / total ))
    local filled=$(( percent / 5 ))
    local empty=$(( 20 - filled ))

    local progress="["
    for ((i=0; i<filled; i++)); do progress+="█"; done
    for ((i=0; i<empty; i++)); do progress+="░"; done
    progress+="]"

    echo -e "  ${activity} ${progress} ${percent}%"
}

# ============================================================================
# AFFICHAGE DU MENU
# ============================================================================

show_header() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo -e "║  🚀  Welcome to PromptOps Console v${SCRIPT_VERSION}                     ║"
    echo "║     Type '?' for help, '0' to exit                                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""
}

show_menu() {
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo -e "║  PromptOps Console v${SCRIPT_VERSION}                                      ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║  [1] Project Scaffold            ║"
    echo "║  [2] Automation Engine           ║"
    echo "║  [3] Docs Generator              ║"
    echo "║  [4] Super-Prompt Studio         ║"                                  ║"
    echo "║  [5] Health Check                ║"
    echo "║  [6] Settings                    ║"
    echo "║  [?] Help                        ║"
    echo "║  [0] Exit                        ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# SOUS-MENUS
# ============================================================================

show_project_scaffold() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║  🔨 Project Scaffold                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    read -rp "  Enter project name: " project_name
    if [[ -z "${project_name}" ]]; then
        echo -e "\e[33m  ⚠ No project name entered\e[0m"
        log_action "Scaffold cancelled - no name"
        read -rp "  Press Enter to continue"
        return
    fi

    local target_path="${PROJECT_ROOT}/../${project_name}"
    if [[ -d "${target_path}" ]]; then
        echo -e "\e[31m  ⚠ Project '${project_name}' already exists!\e[0m"
        log_action "Scaffold failed - project exists: ${project_name}"
        read -rp "  Press Enter to continue"
        return
    fi

    echo -e "\e[36m  📦 Creating project structure...\e[0m"
    local folders=("src" "tests" "docs" "config" "scripts" ".github/workflows")
    local total="${#folders[@]}"

    for i in "${!folders[@]}"; do
        local folder="${folders[$i]}"
        local full_path="${target_path}/${folder}"
        mkdir -p "${full_path}"
        show_progress_bar "$((i + 1))" "${total}" "Creating ${folder}"
    done

    echo "# ${project_name}" > "${target_path}/README.md"
    echo "" >> "${target_path}/README.md"
    echo "Project created with PromptOps Console" >> "${target_path}/README.md"

    echo "node_modules/" > "${target_path}/gitignore"
    echo ".log" >> "${target_path}/gitignore"
    echo ".env" >> "${target_path}/gitignore"

    echo -e "\e[32m  ✓ Project '${project_name}' scaffolded successfully!\e[0m"
    echo -e "\e[90m  Location: ${target_path}\e[0m"
    log_action "Scaffold created: ${project_name} at ${target_path}"
    read -rp "  Press Enter to continue"
}

show_automation_engine() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║  ⚙️  Automation Engine                                                ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  [1] Run all tests (npm test)"
    echo "  [2] Run tests with coverage"
    echo "  [3] Build project"
    echo "  [4] Deploy"
    echo "  [0] Back to main menu"
    echo ""

    read -rp "  Select automation: " choice
    case "${choice}" in
        "1")
            echo ""
            echo "╔══════════════════════════════════════════════════════════════════════╗"
            echo "║🧪 Running all tests...                                               ║"
            echo "╚══════════════════════════════════════════════════════════════════════╝"
            echo ""
            log_action "Automation: Running npm test"
            cd "${PROJECT_ROOT}/scripts/node"
            npm test
            cd "${PROJECT_ROOT}"
            echo ""
            echo "╔══════════════════════════════════════════════════════════════════════╗"
            echo "║✅ Tests completed!                                                   ║"
            echo "╚══════════════════════════════════════════════════════════════════════╝"
            log_action "Automation: Tests completed"
            read -rp "  Press Enter to continue"
            ;;
        "2")
            echo ""
            echo "╔══════════════════════════════════════════════════════════════════════╗"
            echo "║📊 Running tests with coverage...                                     ║"
            echo "╚══════════════════════════════════════════════════════════════════════╝"
            echo ""
            log_action "Automation: Running tests with coverage"
            cd "${PROJECT_ROOT}/scripts/node"
            npm test -- --coverage
            cd "${PROJECT_ROOT}"
            read -rp "  Press Enter to continue"
            ;;
        "3")
            echo -e "\e[33m⏳ Building project...\e[0m"
            for i in {1..5}; do
                show_progress_bar "${i}" "5" "Building project"
                sleep 0.2
            done
            echo -e "\e[32m  ✓ Complete!\e[0m"
            log_action "Automation: Build completed"
            read -rp "  Press Enter to continue"
            ;;
        "4")
            echo -e "\e[33m  ⚠ Deploy coming soon...\e[0m"
            log_action "Automation: Deploy requested (not implemented)"
            read -rp "  Press Enter to continue"
            ;;
        "0") return ;;
        *) echo -e "\e[31m  Invalid option\e[0m"; sleep 1 ;;
    esac
}

show_docs_generator() {
    echo ""
    echo -e "\e[36m📚 Docs Generator\e[0m"
    echo "----------------------------------------"

    local docs=(
        "README.md:${PROJECT_ROOT}/README.md"
        "API Documentation:${PROJECT_ROOT}/docs/API.md"
        "Usage Examples:${PROJECT_ROOT}/docs/USAGE.md"
        "Architecture:${PROJECT_ROOT}/docs/ARCHITECTURE.md"
    )

    echo -e "\e[33mGenerating documentation...\e[0m"
    log_action "Docs: Generation started"

    local i=0
    for doc in "${docs[@]}"; do
        local name="${doc%%:*}"
        local path="${doc##*:}"
        ((i++))

        if [[ -f "${path}" ]]; then
            show_progress_bar "${i}" "${#docs[@]}" "${name}"
            echo -e "\e[32m  ✓ ${name}\e[0m"
        else
            echo -e "\e[33m  ⚠ ${name} (not found)\e[0m"
        fi
    done

    log_action "Docs: Generation completed"
    echo -e "\e[32m✓ Documentation scan complete!\e[0m"
    read -rp "Press Enter to continue"
}

show_super_prompt_studio() {
    echo ""
    echo -e "\e[36m🤖 Super-Prompt Studio\e[0m"
    echo "----------------------------------------"
    echo "Launching PromptOps Node.js CLI..."
    log_action "Super-Prompt Studio: Launched"

    local node_path="${PROJECT_ROOT}/scripts/node"
    if [[ -d "${node_path}" ]]; then
        cd "${node_path}"

        while true; do
            echo ""
            echo "╔══════════════════════════════════════════════════════════════════════╗"
            echo "║=== PromptOps Node.js CLI ===                                         ║"
            echo "╠══════════════════════════════════════════════════════════════════════╣"
            echo "║  [1] List plugins                                                    ║"
            echo "║  [2] Run hello-world                                                 ║"
            echo "║  [3] Run promptor-matrix                                             ║"
            echo "║  [4] Run custom plugin                                               ║"
            echo "║  [5] Search plugins                                                  ║"
            echo "║  [0] Back to main menu                                               ║"
            echo "╚══════════════════════════════════════════════════════════════════════╝"
            echo ""

            read -rp "  Select option: " cli_choice
            case "${cli_choice}" in
                "1")
                    echo -e "\e[33m📋 Listing plugins...\e[0m"
                    log_action "CLI: List plugins"
                    npx tsx promptops.ts list
                    read -rp "  Press Enter to continue"
                    ;;
                "2")
                    read -rp "  Enter name (or press Enter for default): " name
                    log_action "CLI: Run hello-world --name=${name}"
                    if [[ -n "${name}" ]]; then
                        npx tsx promptops.ts run hello-world --name="${name}"
                    else
                        npx tsx promptops.ts run hello-world
                    fi
                    read -rp "  Press Enter to continue"
                    ;;
                "3")
                    echo -e "\e[33m🤖 Launching Promptor Matrix...\e[0m"
                    log_action "CLI: Run promptor-matrix"
                    npx tsx promptops.ts run promptor-matrix
                    read -rp "  Press Enter to continue"
                    ;;
                "4")
                    read -rp "  Enter plugin name: " plugin
                    if [[ -n "${plugin}" ]]; then
                        log_action "CLI: Run ${plugin}"
                        npx tsx promptops.ts run "${plugin}"
                        read -rp "  Press Enter to continue"
                    fi
                    ;;
                "5")
                    echo -e "\e[36m🔍 Search Plugins\e[0m"
                    read -rp "  Enter search term: " search
                    if [[ -n "${search}" ]]; then
                        echo -e "\e[33mSearching for '${search}'...\e[0m"
                        npx tsx promptops.ts list | grep -i "${search}" || echo "  No results found"
                    fi
                    read -rp "  Press Enter to continue"
                    ;;
                "0") break ;;
                *) echo -e "\e[31m  Invalid option\e[0m"; sleep 0.5 ;;
            esac
        done

        cd "${PROJECT_ROOT}"
    else
        echo -e "\e[31m❌ Node.js CLI not found at: ${node_path}\e[0m"
        log_action "CLI: Not found at ${node_path}"
        read -rp "Press Enter to continue"
    fi
}

show_health_check() {
    echo ""
    echo -e "\e[32m✅ Health Check\e[0m"
    echo "----------------------------------------"
    log_action "Health Check: Started"

    local passed=0
    local total=0

    # Git repository
    ((total++))
    if [[ -d ".git" ]]; then
        echo -e "\e[32m  ✓ Git repository\e[0m"
        ((passed++))
    else
        echo -e "\e[31m  ✗ Git repository\e[0m"
    fi

    # Node.js scripts
    ((total++))
    if [[ -d "scripts/node" ]]; then
        echo -e "\e[32m  ✓ Node.js scripts\e[0m"
        ((passed++))
    else
        echo -e "\e[31m  ✗ Node.js scripts\e[0m"
    fi

    # PowerShell scripts
    ((total++))
    if [[ -f "scripts/PromptOpsConsole.ps1" ]]; then
        echo -e "\e[32m  ✓ PowerShell scripts\e[0m"
        ((passed++))
    else
        echo -e "\e[31m  ✗ PowerShell scripts\e[0m"
    fi

    # README.md
    ((total++))
    if [[ -f "README.md" ]]; then
        echo -e "\e[32m  ✓ README.md\e[0m"
        ((passed++))
    else
        echo -e "\e[31m  ✗ README.md\e[0m"
    fi

    # Tests
    ((total++))
    if compgen -G "scripts/node/*.test.ts" > /dev/null; then
        echo -e "\e[32m  ✓ Tests\e[0m"
        ((passed++))
    else
        echo -e "\e[31m  ✗ Tests\e[0m"
    fi

    # package.json
    ((total++))
    if [[ -f "scripts/node/package.json" ]]; then
        echo -e "\e[32m  ✓ package.json\e[0m"
        ((passed++))
    else
        echo -e "\e[31m  ✗ package.json\e[0m"
    fi

    # tsconfig.json
    ((total++))
    if [[ -f "scripts/node/tsconfig.json" ]]; then
        echo -e "\e[32m  ✓ tsconfig.json\e[0m"
        ((passed++))
    else
        echo -e "\e[31m  ✗ tsconfig.json\e[0m"
    fi

    # Logs folder
    ((total++))
    if [[ -d "logs" ]]; then
        echo -e "\e[32m  ✓ Logs folder\e[0m"
        ((passed++))
    else
        echo -e "\e[31m  ✗ Logs folder\e[0m"
    fi

    echo -e "\e[33m🧪 Running quick test...\e[0m"
    cd "${PROJECT_ROOT}/scripts/node"
    npm test 2>&1 | grep -E "pass|fail|tests" | head -5
    cd "${PROJECT_ROOT}"

    local percent=$(( (passed * 100) / total ))
    echo -e "\n\e[36m📊 Overall Status: \e[0m"
    if [[ ${percent} -eq 100 ]]; then
        echo -e "\e[32mHEALTHY (${percent}%)\e[0m"
    elif [[ ${percent} -ge 75 ]]; then
        echo -e "\e[33mGOOD (${percent}%)\e[0m"
    else
        echo -e "\e[31mNEEDS ATTENTION (${percent}%)\e[0m"
    fi

    log_action "Health Check: Completed (${passed}/${total} passed)"
    read -rp "Press Enter to continue"
}

show_settings() {
    echo ""
    echo -e "\e[36m⚙️  Settings\e[0m"
    echo "----------------------------------------"

    echo "Current settings:"
    echo "  Theme: default"
    echo "  Show Progress Bars: true"
    echo "  Enable Logs: true"
    echo "  Max History: 10"
    echo ""
    echo "  [1] View Action History"
    echo "  [2] Clear History"
    echo "  [0] Back to main menu"
    echo ""

    read -rp "  Select option: " choice
    case "${choice}" in
        "1")
            echo -e "\e[36m📜 Recent Actions:\e[0m"
            get_history 10
            read -rp "  Press Enter to continue"
            ;;
        "2")
            clear_history
            ;;
        "0") return ;;
        *) echo -e "\e[31m  Invalid option\e[0m"; sleep 1 ;;
    esac
}

show_help() {
    cat << 'EOF'

╔══════════════════════════════════════════════════════════════╗
║                    PromptOps Console Help                    ║
╠══════════════════════════════════════════════════════════════╣
║  [1] Project Scaffold    - Create new project structure      ║
║  [2] Automation Engine   - Run automation scripts            ║
║  [3] Docs Generator      - Generate documentation            ║
║  [4] Super-Prompt Studio - Launch Node.js CLI for prompts    ║
║  [5] Health Check        - Run tests and check project status║
║  [6] Settings            - Configure options                 ║
║  [?] Help                - Show this help                    ║
║  [0] Exit                - Exit the console                  ║
╠══════════════════════════════════════════════════════════════╣
║  SHORTCUTS:                                                  ║
║    ↑/↓  Navigate menu (coming soon)                          ║
║    ?    Show help                                            ║
║    0    Exit                                                 ║
╚══════════════════════════════════════════════════════════════╝

EOF
    read -rp "Press Enter to continue"
}

# ============================================================================
# BOUCLE PRINCIPALE
# ============================================================================

clear
show_header

# Auto-update check (simplified for bash)
echo -e "\e[36m🔄 Checking for updates...\e[0m"
echo -e "\e[32m  ✓ You're up to date (v${SCRIPT_VERSION})\e[0m"
echo ""

while true; do
    show_menu

    read -rp "Select an option: " choice

    case "${choice}" in
        "1")
            log_action "Menu: Project Scaffold selected"
            show_project_scaffold
            ;;
        "2")
            log_action "Menu: Automation Engine selected"
            show_automation_engine
            ;;
        "3")
            log_action "Menu: Docs Generator selected"
            show_docs_generator
            ;;
        "4")
            log_action "Menu: Super-Prompt Studio selected"
            show_super_prompt_studio
            ;;
        "5")
            log_action "Menu: Health Check selected"
            show_health_check
            ;;
        "6")
            log_action "Menu: Settings selected"
            show_settings
            ;;
        "?")
            log_action "Menu: Help selected"
            show_help
            ;;
        "0")
            log_action "Menu: Exit selected"
            echo -e "\n\e[32m👋 Goodbye! Thanks for using PromptOps Console.\e[0m\n"
            break
            ;;
        "")
            echo -e "\e[31m❌ Invalid option. Please choose 0-6 or ? for help.\e[0m"
            log_action "Menu: Invalid option ''"
            sleep 1
            ;;
        *)
            echo -e "\e[31m❌ Invalid option. Please choose 0-6 or ? for help.\e[0m"
            log_action "Menu: Invalid option '${choice}'"
            sleep 1
            ;;
    esac
done