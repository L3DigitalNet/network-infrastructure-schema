---
schema_version: '1.1'
id: 'index-j2b6yz-repository-conventions'
title: 'Repository Conventions'
description: 'Repository conventions for network-infrastructure-schema, covering frontmatter values, source layout, and tooling.'
doc_type: 'index'
status: 'active'
created: '2026-06-08'
updated: '2026-07-29'
tags:
  - 'conventions'
  - 'readme'
aliases: []
related: []
---

# Repository Conventions

## Purpose

This document outlines conventions used throughout this repository. They must not and do not conflict with any standards adopted from [project-standards](https://github.com/L3DigitalNet/project-standards).

## Table of Contents

- [Repository Conventions](#repository-conventions)
  - [Purpose](#purpose)
  - [Table of Contents](#table-of-contents)
  - [Frontmatter Values and Format](#frontmatter-values-and-format)
    - [`id`](#id)
  - [Plans and Specs](#plans-and-specs)
  - [Frontmatter Scope Expansion](#frontmatter-scope-expansion)
    - [Prerequisites](#prerequisites)
    - [Widening Order](#widening-order)
    - [Out of Scope](#out-of-scope)
  - [Source Layout](#source-layout)
  - [Tooling](#tooling)

## Frontmatter Values and Format

The [Markdown Frontmatter 1.6 SSOT](https://github.com/L3DigitalNet/project-standards/tree/v5.11.0/standards/markdown-frontmatter/versions/1.6)
is selected through the repository's Catalog 5 control plane.

### `id`

The document id shall consist of the document type followed by a random 6 character length base36 number followed by the document title stripped of date, numerical, or other prefixes.

`[doc_type]-[random base36-6]-[title]`

For example: `research-79ybcr-codex-cli-headless-exec-inter-agent`

## Plans and Specs

All plans and spec file names should be prefixed with the date in `YYYY-MM-DD` format followed by the spec name in lower kebab case.

For example: `2024-06-08-codex-cli-headless-exec-inter-agent.md`

## Frontmatter Scope Expansion

Frontmatter coverage is currently scoped by `.standards/config.toml` to
`docs/research/**/*.md`. Widening to additional directories is intentional but
gated — expand only when the following criteria are met:

### Prerequisites

1. **Existing scope is stable.** CI is green on `validate-frontmatter`, no known lint violations or formatting drift in the current scope.
2. **The target directory has a defined `doc_type`.** Every file in the target must map to a controlled `doc_type` value supported by the schema. If a new type is needed, open a PR to `project-standards` first.
3. **A migration plan exists for existing files.** All files currently in the target directory must be audited and conforming frontmatter added before the path is added to `.project-standards.yml`. Do not widen the gate and then fix violations — the gate must be green from day one of the new scope.
4. **Vendored or generated files are explicitly excluded.** Any files in the target directory that are not first-party authored must be listed under `exclude` in `.project-standards.yml` before widening.

### Widening Order

The research corpus is already governed. Further expansion is not on a fixed
schedule; each step requires the prerequisites above:

1. `docs/conventions/`
2. `docs/superpowers/`

**Do not:**

- Add a path to `.project-standards.yml` before all files in that path are conforming.
- Widen scope as part of a larger unrelated PR — scope expansions are their own commit so CI delta is readable.
- Widen scope to a directory that contains generated files without first adding those files to the `exclude` list.

### Out of Scope

Directories and files that tend to see high churn or are not of interest to the community should not be tracked.

1. Any dot folder (e.g. `.github/`) - repo backend operations

## Source Layout

This repository is **not an installable Python package**. Python lives in `python/` as hand-authored scripts run directly via uv. The `_build/` directory contains development-only helpers; it is not a shipped interface.

```text
python/
└── infra_models.py     # Pydantic v2 models + graph layer + CLI
_build/
└── *.py                # schema authoring helpers (development only)
```

## Tooling

- **Project Standards is reconciled through Catalog 5.** The control plane records
  release 5.11.0 and exact `markdown-frontmatter@1.6`; use
  `project-standards reconcile --check --json` to verify managed state.
- **Managed research metadata is validated locally.** Run
  `project-standards validate` and `format-frontmatter --check` from the repository
  root.
- **Validation toolchain runs via uv.** Use `uv run <command>` for all Python execution; do not activate `.venv` manually.
- **Dependencies are exact-pinned** (`pydantic`, `jsonschema`, `PyYAML`, `yamllint`). Bump intentionally and re-run all validation stages before committing a version change.
- **YAML linting → yamllint** (`.yamllint.yml`). All hand-authored YAML in `examples/` must pass before changes are considered complete.
- **OPA policies → conftest** (`policies/conftest/`). Run conftest checks as part of the CI pipeline stages defined in `ci/pipeline.md`.
- No `src/` layout, no `py.typed`, no installable wheel — downstream repos consume generated artifacts, not a pip import.
