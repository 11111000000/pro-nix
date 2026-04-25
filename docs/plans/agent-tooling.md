# Политика инструментов для агентов (agent-tooling)

Назначение: описать матрицу инструментов и политику установки для исследований LLM и агентских утилит.

Требуемые записи для проверок (Proof):
- В system-packages.nix должна присутствовать ссылка на `llm-lab` (в виде команды/скрипта) или на набор пакетов: `jupyterlab`, `transformers`, `datasets`, `sentencepiece`, `tokenizers`.
- В документации (этот файл) должна быть упоминание про `goose`, `aider`, `opencode`, `llm-lab` как поддерживаемые инструменты.

Установка / примечания:
- `llm-lab` представлен в `system-packages.nix` как wrapper-скрипт `llmLabCmd` (см. system-packages.nix). Для CI докажем наличие записи `llm-lab` через rg в system-packages.nix.

Матрица инструментов (коротко):
- goose — легковесный транслятор/обёртка (см. docs/plans/install-matrix.md)
- aider — локальный ассистент (wrapper через pipx)
- opencode — runtime для автономных агентов
- llm-lab — reproducible JupyterLab для исследований и тестов

Proof (для теста 03-llm-tools.sh):
- В system-packages.nix: упоминание `llm-lab` или перечисление пакетов `jupyterlab|transformers|datasets|sentencepiece|tokenizers`.
- В этом файле: упоминание `goose|aider|opencode|llm-lab`.
