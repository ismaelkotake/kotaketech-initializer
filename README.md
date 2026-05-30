# ktk-init

Inicializador de projetos KotakeTech. Gera scaffolds a partir de templates versionados neste repositório, com menu interativo no terminal.

## Dependências

| Ferramenta | Instalação |
|---|---|
| `gum` | [github.com/charmbracelet/gum](https://github.com/charmbracelet/gum) |
| `jq` | `sudo apt install jq` / `brew install jq` |
| `git` | `sudo apt install git` / `brew install git` |

> **Sem sudo?** Baixe os binários estáticos de `gum` e `jq` e coloque em `~/.local/bin`.

## Instalação

```bash
git clone git@github.com:ismaelkotake/kotaketech-initializer.git
cd kotaketech-initializer
bash cli/install.sh
```

O installer copia o script para `~/.local/bin/ktk-init` e cria `~/.config/ktk-init/config` apontando para os templates do repo clonado.

Certifique-se que `~/.local/bin` está no seu PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

## Uso

```bash
ktk-init              # cria um novo projeto interativamente
ktk-init list         # lista templates disponíveis
ktk-init update       # atualiza templates do repositório remoto
ktk-init version
ktk-init help
```

### Fluxo de criação

```
1. Escolha a linguagem
2. Escolha o framework
3. Informe o nome do projeto
4. Confirme ou altere o diretório de saída
5. Preencha as variáveis do template (package, descrição, etc.)
6. Confirme a inicialização do git
```

Se `claude` CLI ou `ANTHROPIC_API_KEY` estiver disponível, ao final é oferecida uma revisão assistida do projeto gerado.

## Configuração

O arquivo `~/.config/ktk-init/config` define a origem dos templates:

```bash
# Templates locais (padrão após install)
TEMPLATES_SOURCE=local:/caminho/para/kotaketech-initializer/templates

# Templates via Git (para devs sem o repo clonado)
TEMPLATES_SOURCE=git:https://github.com/ismaelkotake/kotaketech-initializer
```

No modo `git`, os templates são clonados em `~/.cache/ktk-init/repo` e atualizados com `ktk-init update`.

## Templates disponíveis

| ID | Linguagem | Framework | Descrição |
|---|---|---|---|
| `java-21-spring` | Java 21 | Spring Boot | Hexagonal Architecture + DDD, OpenAPI-first, Testcontainers, Virtual Threads |

### java-21-spring

Herda de `com.kotaketech:kotake-parent` e inclui `kotake-core` para auto-configurações. Segue Hexagonal Architecture com DDD:

```
src/main/java/<package>/
├── domain/
│   ├── model/          # entidades JPA com auditing
│   └── port/out/       # interfaces de repositório (outbound ports)
├── application/
│   ├── port/in/        # interfaces de caso de uso (inbound ports)
│   └── service/        # implementações dos casos de uso
├── presentation/       # controllers REST (inbound adapters)
├── infrastructure/
│   └── persistence/    # Spring Data + adapters dos outbound ports
└── config/             # configurações Spring
```

O `swagger.yml` em `src/main/resources/` ativa automaticamente a geração de código OpenAPI via `kotake-parent`.

## Adicionando um novo template

1. Crie o diretório `templates/<id>/` com os arquivos do scaffold usando `{{VAR_NAME}}` como placeholder (em conteúdo e nomes de arquivos/diretórios)
2. Crie `templates/<id>/template.json` declarando as variáveis extras além de `PROJECT_NAME`:

```json
{
  "variables": [
    {
      "name": "PACKAGE_NAME",
      "prompt": "Package base Java",
      "default": "com.kotaketech.app"
    }
  ]
}
```

> `PACKAGE_NAME` gera automaticamente `PACKAGE_PATH` (pontos substituídos por `/`), útil para estrutura de diretórios Java.

3. Adicione uma entrada em `templates/registry.json`:

```json
{
  "id": "meu-template",
  "language": "Python",
  "version": "3.12",
  "framework": "FastAPI",
  "description": "..."
}
```

Nenhuma alteração no CLI é necessária — o menu é gerado dinamicamente a partir do `registry.json`.
