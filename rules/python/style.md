---
paths:
  - "**/*.py"
---

## Python Style Rules

- **PEP 8** compliance — use a formatter (black or ruff format)
- **Type hints** on all function signatures (params and return types)
- **f-strings** over `.format()` or `%` formatting
- **pathlib** over `os.path` for all path operations
- **Virtual env**: use `venv` or `uv` — never install globally
- **pytest** for testing — not `unittest`
- **Docstrings**: Google style, only on public APIs
- **ReportLab PDFs**: follow existing patterns in the project's `build_*.py` files
- **Imports**: stdlib, third-party, local — separated by blank lines
- **Constants**: UPPER_SNAKE_CASE at module level
- **No mutable default arguments** — use `None` and assign inside the function
