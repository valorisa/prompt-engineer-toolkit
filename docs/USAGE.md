# Usage Guide — PromptOps Console

> Detailed usage instructions for the interactive CLI, super-prompt templates, and containerized workflows.

---

## Table of Contents

1. [Interactive CLI](#interactive-cli)
2. [Super-Prompt Templates](#super-prompt-templates)
3. [Docker & DevContainer](#docker--devcontainer)
4. [Configuration](#configuration)
5. [Troubleshooting](#troubleshooting)

---

## Interactive CLI

### Launch

```powershell
# Windows (PowerShell 5.1 or 7+)
.\scripts\PromptOpsConsole.ps1

# macOS / Linux (Bash or Zsh)
./scripts/PromptOpsConsole.sh
```

### Flags

| Flag | Alias | Description |
|------|-------|-------------|
| `--help` | `-h` | Display usage information and exit |
| `--version` | `-v` | Display version and exit |
| `--whatif` | N/A | Simulate execution without making changes (PowerShell only) |
| `--dry-run` | N/A | Preview actions without execution (stub for v2) |

### Menu Navigation

```text
PromptOps Console v1.0.0
----------------------------------------
[1] Project Scaffold   - New repo setup
[2] Automation Engine  - CI/CD & scripts
[3] Docs Generator     - README, guides
[4] Super-Prompt Studio- Create/optimize
[5] Health Check       - Lint & validate
[6] Settings           - Config & prefs
[0] Exit
----------------------------------------
```

**Behavior**:

- Each option triggers a guided questionnaire (≥4 questions).
- Inputs are validated before proceeding.
- A summary is displayed before execution.
- Confirmation is required (`y/n`) before any destructive operation.

### Example: Project Scaffold Flow

```text
>>> Project Scaffold
Repository name? my-ai-agent
Visibility (public/private)? public
Include CI/CD scaffolding? (y/n) y
Runtimes to include: pwsh/node/python/all? all
Initialize git and create first commit? (y/n) y

Summary:
  Name: my-ai-agent
  Visibility: public
  CI/CD: y
  Runtimes: all
  Git Init: y

Confirm execution? (y/n) y
✓ Creating directories...
✓ Writing placeholder files...
✓ Initializing git repository...
✓ Scaffold completed.
```

> 💡 **Tip**: Use `--whatif` (PowerShell) to preview changes before committing.

---

## Super-Prompt Templates

### Location & Schema

Templates reside in `prompts/templates/` and follow the schema defined in `prompts/templates/schema.yml`.

### Available Templates

| File | Purpose | Target Models |
|------|---------|--------------|
| `reverse-engineering.yml` | Infer and optimize prompts from AI output | GPT, Claude, Gemini, Qwen |
| `repo-orchestration.yml` | Generate project scaffolds + CI/CD config | GPT, Claude, Qwen |
| `content-pipeline.yml` | Plan technical content with SEO optimization | GPT, Gemini, Qwen |

### Using a Template

1. Copy the template to your working directory:

   ```bash
   cp prompts/templates/reverse-engineering.yml ./my-prompt.yml
   ```

2. Fill in variables:

   ```yaml
   variables:
     target_model: "qwen"
     ai_output: "Your AI-generated text here..."
   ```

3. Submit to your LLM provider with the `system` and `user_template` sections.

### Model-Specific Guidance

| Model | Recommendation |
|-------|---------------|
| **GPT-4** | Leverage system message weight; use explicit markdown formatting. |
| **Claude 3** | Use XML tags for structure; exploit 100K+ context window. |
| **Gemini** | Enable structured output mode; use clear section headers. |
| **Qwen** | Use linear instructions; front-load critical rules; add bilingual markers (EN/ZH) if needed. |

> 📋 **Reference**: See `docs/SUPER-PROMPT-SPEC.md` for full schema documentation.

---

## Docker & DevContainer

### Build Locally

```bash
cd docker
docker build -t promptops-toolkit:latest .
```

### Run Interactively

```bash
# PowerShell entrypoint
docker run -it --rm -v ${PWD}:/app promptops-toolkit:latest pwsh

# Bash entrypoint
docker run -it --rm -v ${PWD}:/app promptops-toolkit:latest bash
```

### DevContainer (VS Code)

1. Open the project folder in VS Code.
2. When prompted, click "Reopen in Container".
3. The environment will install:
   - PowerShell 7.4
   - ShellCheck
   - markdownlint
   - Python 3.11 + Pester

> ⚙️ **Customization**: Edit `.devcontainer/devcontainer.json` to add extensions or modify the post-create script.

---

## Configuration

### User Preferences

Stored in `~/.promptops/config.json` (auto-created on first run):

```json
{
  "locale": "en",
  "telemetry": false,
  "default_runtime": "pwsh",
  "color_output": true
}
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `locale` | string | `"en"` | CLI output language (`en` or `fr`) |
| `telemetry` | boolean | `false` | Opt-in anonymous usage metrics (v2) |
| `default_runtime` | string | `"pwsh"` | Preferred shell for sub-commands |
| `color_output` | boolean | `true` | Enable ANSI colors if terminal supports |

### Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `PROMPTOPS_CONFIG_DIR` | Override config directory | `export PROMPTOPS_CONFIG_DIR=/custom/path` |
| `GITHUB_TOKEN` | Auth for GitHub API calls | `export GITHUB_TOKEN=ghp_***` |
| `OPENAI_API_KEY` | API key for OpenAI integration | `export OPENAI_API_KEY=sk-***` |

> 🔐 **Security**: Never commit `.env` files. Add them to `.gitignore`.

---

## Troubleshooting

### Common Issues

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| `Command not found: PromptOpsConsole.sh` | Script not executable | `chmod +x scripts/PromptOpsConsole.sh` |
| `PowerShell 5.1 required` | Running on PS 3.0 or earlier | Upgrade to WMF 5.1 or install PowerShell 7+ |
| `ShellCheck warnings` | Unsafe bash patterns | Review `scripts/PromptOpsConsole.sh` with `shellcheck -x` |
| `Docker build fails` | Missing build args or network | Ensure Docker daemon is running; check proxy settings |
| `CI/CD job fails on macOS` | PS 5.1 not available | Matrix excludes PS 5.1 on non-Windows; verify workflow YAML |

### Debug Mode

```powershell
# PowerShell: Enable verbose output
.\scripts\PromptOpsConsole.ps1 -Verbose

# Bash: Enable debug tracing
bash -x ./scripts/PromptOpsConsole.sh
```

### Logs

- CLI logs to stdout/stderr by default.
- For persistent logging (v2), configure `config.json` with `"log_file": "~/.promptops/promptops.log"`.

---

## TODO(v2)

- [ ] Implement `--dry-run` flag for Bash/Zsh CLI.
- [ ] Add interactive tutorial mode (`--tutorial`) for first-time users.
- [ ] Support locale switching at runtime via `--locale fr`.
- [ ] Integrate telemetry opt-in with anonymized metrics collection.

---
