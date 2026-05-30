# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`ktk-init` is a Bash CLI that generates project scaffolds from templates stored in this same repo. It uses `gum` for interactive menus and `jq` to parse the template registry.

## CLI commands

```bash
ktk-init                # interactive project creation
ktk-init list           # list available templates
ktk-init update         # pull latest templates from remote (git mode only)
ktk-init version
ktk-init help
```

## Installing / testing locally

```bash
bash cli/install.sh     # installs to ~/.local/bin and writes ~/.config/ktk-init/config
```

`install.sh` automatically sets `TEMPLATES_SOURCE=local:<repo>/templates` in the config, so no manual config is needed for local development.

Dependencies required: `gum` (charmbracelet), `jq`, `git`. Both can be installed as static binaries into `~/.local/bin` without sudo.

## Architecture

### Two moving parts

| Path | Role |
|---|---|
| `cli/ktk-init.sh` | The CLI — reads config, drives the interactive flow, applies templates |
| `templates/` | Template files — `registry.json` is the index; each subdirectory is one template |

### CLI execution flow (`ktk-init.sh`)

```
main → check_deps → load_config → get_templates
     → select_template (gum menus driven by registry.json)
     → collect_vars    (PROJECT_NAME + template.json variables)
     → apply_template  (copy → sed substitution → dir/file rename)
     → claude_enhance  (optional, only if claude CLI or ANTHROPIC_API_KEY is present)
```

### Template sources (`TEMPLATES_SOURCE` in `~/.config/ktk-init/config`)

- `local:/absolute/path/to/templates` — reads from filesystem directly
- `git:https://github.com/user/repo` — clones/pulls into `~/.cache/ktk-init/repo`, then reads from there

### Variable system

- `PROJECT_NAME` — always collected first by the CLI, before template variables
- `PACKAGE_NAME` — when declared in `template.json`, the CLI automatically derives `PACKAGE_PATH` (dots replaced with `/`) and adds it to the var file
- All other variables are declared in `templates/<id>/template.json` under the `variables` array
- Placeholders use `{{VAR_NAME}}` syntax in both file contents and file/directory names
- The `{{PACKAGE_PATH}}` placeholder in directory names is special: since its value contains `/`, the CLI creates the full nested directory hierarchy and moves contents there

### Adding a new template

1. Create `templates/<new-id>/` with the scaffold files using `{{VAR_NAME}}` placeholders
2. Create `templates/<new-id>/template.json` declaring extra variables (beyond `PROJECT_NAME`)
3. Add an entry to `templates/registry.json` — the CLI picks it up immediately, no code change needed

### `registry.json` entry shape

```json
{
  "id": "java-21-spring",
  "language": "Java",
  "version": "21",
  "framework": "Spring Boot",
  "description": "..."
}
```

### `template.json` variable shape

```json
{
  "variables": [
    { "name": "PACKAGE_NAME", "prompt": "Package base", "default": "com.kotaketech.app" }
  ]
}
```

## java-21-spring template

Inherits from `com.kotaketech:kotake-parent` (not `spring-boot-starter-parent`). The parent manages all dependency versions via `kotake-bom`. Child projects must **not** include `<version>` on managed dependencies.

Package structure follows Hexagonal Architecture + DDD:

```
<PACKAGE_NAME>/
├── domain/model/          # JPA entities — no Spring imports except JPA annotations
├── domain/port/out/       # outbound port interfaces (e.g. repository contracts)
├── application/port/in/   # inbound port interfaces (use case contracts)
├── application/service/   # use case implementations (@Service)
├── presentation/          # REST adapters (@RestController) — implement OpenAPI delegate when swagger.yml is present
└── infrastructure/persistence/  # Spring Data repos + outbound port adapters
```

The `swagger.yml` in `src/main/resources/` activates the `openapi-generate` Maven profile from `kotake-parent` automatically, generating delegate interfaces into `presentation/`. The `.openapi-generator-ignore` file excludes scaffold classes that would conflict with the application.

`kotake-core` is included as a dependency and auto-activates `@EnableJpaAuditing` when a `DataSource` is on the classpath.
