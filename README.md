# ktk-init

KotakeTech project initializer. Generates project scaffolds from versioned templates stored in this repository, with an interactive terminal menu.

## Dependencies

| Tool | Install |
|---|---|
| `gum` | [github.com/charmbracelet/gum](https://github.com/charmbracelet/gum) |
| `jq` | `sudo apt install jq` / `brew install jq` |
| `git` | `sudo apt install git` / `brew install git` |

> **No sudo?** Download static binaries for `gum` and `jq` and place them in `~/.local/bin`.

## Installation

```bash
git clone git@github.com:ismaelkotake/kotaketech-initializer.git
cd kotaketech-initializer
bash cli/install.sh
```

The installer copies the script to `~/.local/bin/ktk-init` and creates `~/.config/ktk-init/config` pointing to the templates in the cloned repo.

Make sure `~/.local/bin` is in your PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

## Usage

```bash
ktk-init              # create a new project interactively
ktk-init list         # list available templates
ktk-init update       # update templates from remote repository
ktk-init version
ktk-init help
```

### Creation flow

```
1. Select language
2. Select framework
3. Enter project name
4. Confirm or change output directory
5. Fill in template variables (package, description, etc.)
6. Confirm git initialization
```

If the `claude` CLI or `ANTHROPIC_API_KEY` is available, an assisted review of the generated project is offered at the end.

## Configuration

The file `~/.config/ktk-init/config` defines the template source:

```bash
# Local templates (default after install)
TEMPLATES_SOURCE=local:/path/to/kotaketech-initializer/templates

# Templates via Git (for devs without the repo cloned)
TEMPLATES_SOURCE=git:https://github.com/ismaelkotake/kotaketech-initializer
```

In `git` mode, templates are cloned into `~/.cache/ktk-init/repo` and updated with `ktk-init update`.

## Available templates

| ID | Language | Framework | Description |
|---|---|---|---|
| `java-21-spring` | Java 21 | Spring Boot | Hexagonal Architecture + DDD, OpenAPI-first, Testcontainers, Virtual Threads |

### java-21-spring

Inherits from `com.kotaketech:kotake-parent` and includes `kotake-core` for auto-configurations. Follows Hexagonal Architecture with DDD:

```
src/main/java/<package>/
├── domain/
│   ├── model/          # JPA entities with auditing
│   └── port/out/       # repository interfaces (outbound ports)
├── application/
│   ├── port/in/        # use case interfaces (inbound ports)
│   └── service/        # use case implementations
├── presentation/       # REST controllers (inbound adapters)
├── infrastructure/
│   └── persistence/    # Spring Data + outbound port adapters
└── config/             # Spring configurations
```

The `swagger.yml` in `src/main/resources/` automatically activates OpenAPI code generation via `kotake-parent`.

## Adding a new template

1. Create the directory `templates/<id>/` with scaffold files using `{{VAR_NAME}}` as placeholders (in both file contents and file/directory names)
2. Create `templates/<id>/template.json` declaring extra variables beyond `PROJECT_NAME`:

```json
{
  "variables": [
    {
      "name": "PACKAGE_NAME",
      "prompt": "Base Java package",
      "default": "com.kotaketech.app"
    }
  ]
}
```

> `PACKAGE_NAME` automatically generates `PACKAGE_PATH` (dots replaced with `/`), used for the Java directory structure.

3. Add an entry to `templates/registry.json`:

```json
{
  "id": "my-template",
  "language": "Python",
  "version": "3.12",
  "framework": "FastAPI",
  "description": "..."
}
```

No changes to the CLI are needed — the menu is generated dynamically from `registry.json`.
