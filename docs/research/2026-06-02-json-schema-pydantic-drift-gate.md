---
schema_version: '1.1'
id: 'research-g3szvl-ci-drift-gate-json-schema-draft-2020-12-vs-pydantic-v2-semantic-equivalence'
title: 'CI Drift Gate: JSON Schema Draft 2020-12 vs Pydantic v2 Semantic Equivalence'
description: 'Research supporting the repository schema-to-Pydantic drift gate design.'
doc_type: 'research'
status: 'active'
created: '2026-06-02'
updated: '2026-06-03'
tags:
  - 'python'
  - 'research'
  - 'schema'
  - 'validation'
aliases: []
related: []
---

# CI Drift Gate: JSON Schema Draft 2020-12 vs Pydantic v2 Semantic Equivalence

Mode: research  ·  Topic: CI drift gate for JSON Schema Draft 2020-12 vs Pydantic v2 model equivalence  ·  Saved: docs/research/2026-06-02-json-schema-pydantic-drift-gate.md

## Summary

| Angle | Sources | Strongest finding |
|-------|---------|-------------------|
| Official Docs | 5 | `jsonschema` 4.x has full Draft 2020-12 support; Pydantic v2 GenerateJsonSchema is subclassable for output normalization |
| Best Practices | 4 | Industry strongly prefers single-sourcing; dual-author with behavioral gate is a recognized but rare pattern |
| Footguns | 6 | hypothesis-jsonschema has no Draft 2020-12 support and is effectively unmaintained since Feb 2024 |
| Existing Tools | 5 | stable_pydantic (Pydantic-only, schema snapshots), jsonschema-diff (structural diff), json-schema-diff (Draft-07 only) |
| Security | 3 | `format` is annotation-only by default in Draft 2020-12; both validators must explicitly opt in to assert it |
| Recent Changes | 4 | Pydantic v2.0 dropped built-in Hypothesis plugin; no replacement shipped as of 2026-06 |

**Queries:** 12  ·  **Results parsed:** ~120  ·  **Deep reads:** 6  ·  **Follow-up pass:** no

---

## Official Documentation

- Python `jsonschema` 4.x ships `Draft202012Validator` with full support for `$dynamicRef`, `$dynamicAnchor`, `prefixItems`, `unevaluatedProperties`, `unevaluatedItems`, and `if/then`. The validator set is enumerated in `jsonschema.validators` and confirmed in the readthedocs API reference. [official] (https://python-jsonschema.readthedocs.io/en/latest/api/jsonschema/validators/)

- `format` is annotation-only in Draft 2020-12 by spec design (vocabulary `format-annotation`). The `jsonschema` library respects this: format assertions are only triggered when a `format_checker` is passed explicitly to the validator, or when using `Draft202012Validator` with `format_checker=jsonschema.FormatChecker()`. This differs from pre-2019-09 behavior where implementations chose. [official] (https://python-jsonschema.readthedocs.io/en/latest/faq/)

- Pydantic v2 `GenerateJsonSchema` is a documented, stable subclassing point. The constructor accepts `by_alias: bool` and `ref_template: str`. Subclasses can override `generate()`, `field_title_should_be_set()`, `tagged_union_schema()`, and `emit_warning()`. The default schema dialect emitted is `https://json-schema.org/draft/2020-12/schema`. [official] (https://pydantic.dev/docs/validation/latest/concepts/json_schema/)

- `models_json_schema()` (plural) collects all models and their sub-model `$defs` into a single top-level document, avoiding per-model fragmentation. This is the correct entry point for generating a schema comparable to the canonical hand-authored one. [official] (https://docs.pydantic.dev/latest/api/json_schema/)

- Draft 2020-12 spec: `$recursiveRef`/`$recursiveAnchor` from 2019-09 are replaced by `$dynamicRef`/`$dynamicAnchor`; `items`-as-array is replaced by `prefixItems`; `format-assertion` vocabulary is separated from `format-annotation` and is NOT required in the default meta-schema. [official] (https://json-schema.org/draft/2020-12/release-notes)

---

## Best Practices

- The dominant industry pattern for Python projects is to **single-source from Pydantic and generate JSON Schema** — not dual-author. The Pydantic docs present `model_json_schema()` as sufficient for most interop (OpenAPI, frontend validation, documentation). This works well when the JSON Schema does not need to outlive or be shared beyond the Python codebase. [official] (https://pydantic.dev/docs/validation/latest/concepts/json_schema/)

- When a hand-authored JSON Schema is the portable, language-agnostic source of truth (the scenario in this repo), the accepted approach is: generate Pydantic models from the schema using a tool like `datamodel-code-generator`, then the schema remains authoritative and Pydantic is derived. The reverse (generate schema from Pydantic) is simpler but loses control over schema structure. [community] (https://towardsdatascience.com/how-to-make-the-most-of-pydantic-aa374d5c12d/)

- For the dual-author case (both files hand-maintained), a CI "drift gate" based on behavioral/differential testing is the closest accepted practice. No established open-source tool targets this exact problem. `stable_pydantic` is the nearest relative but targets Pydantic-to-Pydantic version compatibility, not schema-to-Pydantic equivalence. [community] (https://pypi.org/project/stable-pydantic/)

- Property-based differential testing of two validators against a shared corpus is a well-understood pattern for finding semantic divergence between implementations of the same spec (used in JSON Schema test suites). Applying it to find divergence between two different encodings of the same constraint set is a natural extension. [community] (https://openproceedings.org/2025/conf/edbt/paper-T3.pdf)

---

## Footguns and Gotchas

### Option A: Behavioral / Differential Testing

- **hypothesis-jsonschema has no Draft 2020-12 support and is effectively unmaintained.** The CHANGELOG explicitly states (v0.21.0, Oct 2021): "updated to jsonschema >= 4.0.0; though support for Draft 2019-09 and 2020-12 will take longer." The last release was 0.23.1 on Feb 28, 2024 — a patch bump, not a Draft 2020-12 feature addition. The README still states only "Drafts 04, 05, and 07 are fully tested and working." There has been no commit activity to address 2020-12 since. Using it to generate instances from your hand-authored 2020-12 schema will silently fall back to partial/incorrect generation — particularly for `prefixItems`, `unevaluatedProperties`, `$dynamicRef`, and `if/then`. — corroborated by [official PyPI release history](https://pypi.org/project/hypothesis-jsonschema/), [official CHANGELOG](https://github.com/python-jsonschema/hypothesis-jsonschema/blob/master/CHANGELOG.md)

- **Pydantic v2 dropped the built-in Hypothesis plugin.** Pydantic v2.0 removed the integrated Hypothesis plugin "temporarily" pending a mechanism based on `annotated-types`. As of June 2026, it has not returned. The open tracking issue is pydantic/pydantic#4682. Hypothesis `st.builds(MyModel)` still works for models with unconstrained fields, but constrained fields (using `Field(ge=..., pattern=..., etc.)`) will generate invalid values that raise `ValidationError`, requiring `assume(False)` workarounds that severely reduce corpus quality. — corroborated by [official Pydantic docs](https://pydantic.dev/docs/validation/latest/integrations/dev-tools/hypothesis/), [GitHub issue #4682](https://github.com/pydantic/pydantic/issues/4682)

- **`format` assertion default divergence between validators is a corroboration trap.** Under Draft 2020-12, `format` is annotation-only by default in `jsonschema`. Pydantic's validator uses its own type coercion for formats like `date-time` (it coerces to `datetime`, not string-matches). If your hand-authored schema uses `format: date-time` and you compare accept/reject decisions, a string like `"not-a-date"` will be accepted by `jsonschema` (format not asserted) but rejected by Pydantic. This is not a real divergence — it is a validator configuration mismatch. You must explicitly enable `format_checker` on `Draft202012Validator` to get parity. — corroborated by [official jsonschema FAQ](https://python-jsonschema.readthedocs.io/en/latest/faq/), [official JSON Schema 2020-12 spec](https://json-schema.org/draft/2020-12/release-notes)

- **Shrinking across `if/then` and discriminated unions produces misleading counterexamples.** When hypothesis shrinks a failing instance from a union-based schema, the shrunk example may cross kind boundaries (e.g., shrink away the discriminator field), producing a counterexample that fails for trivial structural reasons rather than the actual semantic delta. This makes CI output hard to read. [community] (https://stevana.github.io/the_sad_state_of_property-based_testing_libraries.html)

- **Asymmetric corpus coverage by direction.** Generating from the JSON Schema and validating with Pydantic catches: fields the JSON Schema permits that Pydantic rejects (JSON Schema is broader). Generating from Pydantic (`st.builds`) and validating with `Draft202012Validator` catches: fields Pydantic permits that JSON Schema rejects (Pydantic is broader). Neither direction alone is sufficient. The gap cases are: (a) cross-field constraints in Pydantic `@model_validator` not expressed in JSON Schema — missed by both; (b) `unevaluatedProperties: false` strictness in JSON Schema not caught by `st.builds` which generates exactly the declared fields. [community] (https://github.com/pydantic/pydantic/discussions/5979)

### Option B: Semantic-Structural Normalization

- **if/then-vs-discriminated-oneOf is not mechanically reconcilable without semantic knowledge of the discriminator field.** The if/then pattern (`if: {properties: {kind: {const: "foo"}}}, then: {$ref: "#/$defs/Foo"}`) and Pydantic's `oneOf` with a wrapper (`{oneOf: [...], discriminator: {propertyName: "kind"}}`) are semantically equivalent for valid instances but differ in what they accept as invalid — `if/then` silently passes instances where the condition doesn't match (no `else`), while `oneOf` requires exactly one branch to match. A normalizer must understand that your `if` blocks have exhaustive coverage and together implement a `oneOf`. This is undecidable in the general case. For your specific schema it is tractable but the hand-rolled code is brittle to any change in how kinds are added. — corroborated by [json-schema-org discussion #1082](https://github.com/json-schema-org/json-schema-spec/issues/1082), [endjin blog on discriminators](https://endjin.com/blog/json-schema-patterns-dotnet-polymorphism-with-discriminator-properties)

- **No existing tool semantically diffs two Draft 2020-12 schemas across different structural encodings.** `jsonschema-diff` (PyPI, v0.1.11, Mar 2026) does structural diff — it reports added/removed/changed paths in the JSON document, not semantic set equivalence. It will report hundreds of false differences between your two schemas because of the if/then vs oneOf and named-ref vs inline encodings. `json-schema-diff` (npm, Atlassian-origin) is Draft-07 only, unmaintained. `getsentry/json-schema-diff` (Rust) is explicitly "work in progress, draft-07 only." There is no Python-native tool that does semantic equivalence checking for Draft 2020-12. — corroborated by [PyPI jsonschema-diff](https://pypi.org/project/jsonschema-diff/), [github.com/getsentry/json-schema-diff](https://github.com/getsentry/json-schema-diff)

- **Pydantic `$defs` naming is deterministic but non-configurable for wrapper classes.** Pydantic emits wrapper classes for discriminated unions (e.g., a `KindFoo` wrapper containing `{oneOf: [...]}`) and names `$defs` entries by Python class name. The 44 vs 65 `$defs` count delta (only 29 overlapping) reflects: Pydantic creates one extra `$defs` entry per union wrapper, plus inlines primitive constraints as anonymous schemas rather than `$ref`ing them. You can use `ref_template` to change the `$ref` path prefix but cannot suppress the extra wrapper `$defs` entries without subclassing `GenerateJsonSchema` and overriding `tagged_union_schema()`. [official] (https://docs.pydantic.dev/latest/api/json_schema/)

- **`GenerateJsonSchema` subclassing for normalization is powerful but fragile across Pydantic minor versions.** The internal method names (`tagged_union_schema`, `get_schema_from_definitions`, `json_to_defs_refs`) are not versioned as stable public API despite being documented. Pydantic's own changelog records `generate_definitions` signature changes between minor releases. [community] (https://pypi.org/project/pydantic/2.0.2/)

---

## Existing Tools

| Tool | Maintenance | Link | Fit for this use case |
|------|-------------|------|-----------------------|
| hypothesis-jsonschema | Low — last release Feb 2024, no Draft 2020-12 support | https://pypi.org/project/hypothesis-jsonschema/ | Partially — usable for Draft-07-compatible portions only; will miss 2020-12-specific keywords |
| polyfactory (ModelFactory) | Active — litestar-org maintained, Pydantic v2 supported | https://pypi.org/project/polyfactory/ | Good for Pydantic-side corpus generation; no JSON Schema generation |
| jsonschema-diff | Active — v0.1.11 released Mar 2026 | https://pypi.org/project/jsonschema-diff/ | Structural diff only; will produce noisy output across different encodings of the same intent |
| stable_pydantic | Early — v0.1.0 only, Reddit announcement 2025 | https://pypi.org/project/stable-pydantic/ | Pydantic-to-Pydantic schema version compatibility, not cross-format equivalence |
| json-schema-diff (npm/Atlassian) | Unmaintained — Draft-07 only | https://www.npmjs.com/package/json-schema-diff | Not suitable — wrong draft, wrong language |
| getsentry/json-schema-diff (Rust) | WIP — Draft-07 partial | https://github.com/getsentry/json-schema-diff | Not suitable |

---

## Security and Compatibility

- **`format` assertion opt-in is the single largest correctness-vs-security footgun in this setup.** If `format: ipv4`, `format: date-time`, or `format: uri` appears in the hand-authored schema, `Draft202012Validator` will not enforce it by default. Pydantic, by contrast, type-coerces to `IPv4Address`, `datetime`, etc. and rejects malformed values. This means the `jsonschema` validator will accept values the Pydantic model rejects — a systematic false-negative in the drift gate — unless you explicitly construct `Draft202012Validator(..., format_checker=jsonschema.FormatChecker())`. [official] (https://python-jsonschema.readthedocs.io/en/latest/faq/)

- **Accepting untrusted schemas as input.** The `jsonschema` docs explicitly warn: "Accepting untrusted schemas as input, especially combined with untrusted data to validate, can lead to vulnerabilities even when restricting to official JSON Schema dialects." This applies if the drift gate ever runs against externally-supplied schemas. For CI over a controlled repo this is not a concern. [official] (https://python-jsonschema.readthedocs.io/_/downloads/en/stable/pdf/)

- **Pydantic `$schema` dialect URI.** `GenerateJsonSchema` emits `$schema: https://json-schema.org/draft/2020-12/schema` by default when `generate()` is overridden to include `self.schema_dialect`. This is correct. Without the override, the emitted schema has no `$schema` key and `Draft202012Validator` must be chosen manually. [official] (https://github.com/pydantic/pydantic/blob/main/docs/concepts/json_schema.md)

---

## Recent Changes

- **Pydantic v2.0 (June 2023) dropped the built-in Hypothesis plugin.** The plugin provided `st.from_type()` inference for constrained Pydantic types. Its removal means there is no maintained, automatic path from a Pydantic v2 model to a Hypothesis strategy that respects all field constraints. Issue #4682 tracks re-introduction via `annotated-types` protocol; no ETA as of June 2026. [official] (https://pydantic.dev/docs/validation/latest/integrations/dev-tools/hypothesis/)

- **hypothesis-jsonschema 0.23.1 (Feb 2024) is the last release.** No releases in 2025 or 2026. The project acknowledged Draft 2019-09 / 2020-12 support is pending since Oct 2021. The repo has 423 commits total, no recent activity. Treat this as effectively unmaintained for 2020-12 use. [official] (https://pypi.org/project/hypothesis-jsonschema/)

- **jsonschema-diff v0.1.11 released Mar 2026** — actively developed Python library for structural JSON Schema diff, but only reports path-level changes, not semantic equivalence across different schema encodings. [community] (https://pypi.org/project/jsonschema-diff/)

- **JSON Schema spec moving toward stability post-2020-12.** The JSON Schema team has announced the forthcoming release will be versioned by year (2023, 2024, 2025 drafts) with backward compatibility guarantees. Draft 2020-12 will be the supported baseline for the stable series. All tooling written against 2020-12 should remain valid. [official] (https://json-schema.org/blog/posts/future-of-json-schema)

---

## Recommendation

### Neither Option A nor Option B in isolation is reliable. A specific hybrid is the pragmatic choice.

**Recommended approach: Curated corpus gate (Option A, fixed corpus only) + lightweight structural normalization check (Option B, scoped to kind names and required fields).**

#### Why not pure Option A

The hypothesis-jsonschema blocker is hard: the library does not support Draft 2020-12, is unmaintained, and the gap covers exactly the keywords this schema uses (`if/then`, `unevaluatedProperties`). You could write a custom Hypothesis strategy that generates from a manually-resolved version of the schema, but that is essentially re-implementing hypothesis-jsonschema for 2020-12 — a significant build cost with ongoing maintenance.

The Pydantic-side generation (using `st.builds` or `polyfactory`) suffers from the opposite problem: constrained fields produce many `ValidationError` discards unless you carefully hand-write strategies per model. The `assume(False)` workaround degrades corpus quality silently.

**However**: generating from Pydantic and validating against `Draft202012Validator` (direction 2) is tractable with `polyfactory` for the known-valid corpus, and is worth including. It catches the case where Pydantic accepts something the JSON Schema rejects.

#### Why not pure Option B

The if/then vs discriminated-oneOf reconciliation is not automatable without a semantic DSL that understands your kind-discrimination pattern specifically. Writing and maintaining that normalizer is more expensive than the hybrid approach and is fragile across schema evolution.

#### The hybrid: what to build

1. **Curated valid corpus** (`examples/kinds/*.yaml` + `examples/manifests/*.yaml`): run all files through both `Draft202012Validator` (with `format_checker` enabled) and Pydantic `__init__`/`model_validate`. Assert both accept. This is already half of what you have (Stage 2 validates against JSON Schema, Stage 3 validates against Pydantic). Adding a single CI step that runs both validators on the same files closes the gap for the positive corpus.

2. **Curated invalid corpus** (`examples/invalid/` directory, to be created): a small set (~20-30) of hand-crafted documents that are definitively invalid per the intent of the schema (wrong kind value, missing required field, extra properties on a closed kind, IP outside prefix, etc.). Assert both validators reject them. This is the most effective way to catch silent acceptance divergence without relying on generation.

3. **polyfactory positive generation** (optional, high ROI): use `ModelFactory` for each `*Spec` Pydantic class to generate 50-100 random valid instances per kind, feed through `Draft202012Validator` with `format_checker`. This catches Pydantic-accepts-but-JSON-Schema-rejects cases. Straightforward to implement, no hypothesis-jsonschema dependency.

4. **Kind-name and required-field structural check** (scoped Option B): write a small Python script that asserts: (a) every kind name in the JSON Schema `if/then` discriminator blocks has a corresponding `$defs` entry in the Pydantic-emitted schema; (b) every `required` field list for each kind matches between the two schemas (after $ref resolution). This is a 50-line script, not a full normalizer, and is stable across schema evolution.

#### Cost and false-confidence trade-offs

| Approach | Maintenance cost | False-negative risk | False-positive risk |
|----------|-----------------|--------------------|--------------------|
| Curated corpus both validators | Low | High (only tests enumerated cases) | Very low |
| Curated invalid corpus | Low | Medium | Very low |
| polyfactory + Draft202012Validator | Low-medium | Medium (misses JSON-Schema-side generation) | Low |
| hypothesis-jsonschema full PBT | High (blocked on 2020-12 support) | Low | Medium (format semantics drift) |
| Full Option B normalizer | High (brittle) | Low-medium | High (false equiv on if/then vs oneOf) |
| **Hybrid (1+2+3+4)** | **Medium** | **Low-medium** | **Low** |

The primary **false-confidence risk** of the hybrid is that neither `polyfactory` nor the curated corpus will generate instances that stress cross-field graph constraints (IP-in-prefix, referential integrity) that Pydantic's `@model_validator` checks but the JSON Schema does not express. This is a known limitation that should be documented as an Open Question rather than treated as a blocker — the drift gate exists to catch structural schema drift, not to verify that graph checks are equivalent (they are not: the schema intentionally delegates those to Pydantic).

---

## Open Questions

| # | Question | Why unresolved |
|---|----------|----------------|
| 1 | Is anyone actively working on Draft 2020-12 support in hypothesis-jsonschema? | GitHub shows no recent activity; issue tracker not crawled in this pass |
| 2 | Can `hypothesis.strategies.from_type()` be made to work for Pydantic v2 constrained types via the `annotated-types` `GroupedMetadata` protocol without the dropped plugin? | Issue #4682 is open; no community solution found in this search |
| 3 | What is the exact semantic difference, if any, between your `if/then` kind-discrimination (with no `else`) and Pydantic's `oneOf` for instances that fail all discriminators? | If both validators accept them (because `if` without `else` passes silently and `oneOf` with all-failing branches rejects), this is a real divergence for the negative corpus. Requires hands-on testing with your actual schemas. |
| 4 | Does `unevaluatedProperties: false` in the canonical JSON Schema have an equivalent enforcement path in Pydantic v2? | Pydantic uses `model_config = ConfigDict(extra='forbid')` but this may not apply to all levels of nested kinds. Not confirmed in this research pass. |
| 5 | Does polyfactory correctly generate values for all 19 kind-specific `*Spec` classes including union fields and `SecretRef`? | Polyfactory handles Pydantic v2 well in the general case but `Literal` discriminators and `Union` with `SecretRef` forward refs may need factory customization — see follow-up section below |

---

## Handoff

Persisted at `docs/research/2026-06-02-json-schema-pydantic-drift-gate.md`. Downstream commands that may consume it:

- `/qdev:quality-review` — review a related artifact with this research as ground truth
- `superpowers:brainstorming` — feed Open Questions (especially #3 and #4) into a design conversation about the hybrid gate architecture
- `feature-dev:feature-dev` — start implementation of the hybrid gate (curated corpus + polyfactory + kind-name structural check)

---

---

## Follow-up: C3 Viability — polyfactory for Regex-Constrained Pydantic v2 Generation

*Appended 2026-06-02. Targeted investigation of one design decision: whether `polyfactory.factories.pydantic_factory.ModelFactory` is viable for generating valid instances of the `*Spec` Pydantic models to feed into `Draft202012Validator` (component C3 of the drift gate). All five questions answered from source-code inspection, Context7 docs, and targeted searches.*

---

### Q1 — Constraint-honoring: does polyfactory SATISFY arbitrary `pattern` regexes?

**Yes, polyfactory generates strings that genuinely satisfy arbitrary `pattern` regexes. It does not ignore them or fall back to a generic string.**

The mechanism: polyfactory ships a self-contained `RegexFactory` in `polyfactory/value_generators/regex.py`. This class parses the regex using Python's own `re._parser` / `sre_parse` module (no external dependency on `rstr`, `exrex`, or `sre_yield`) and walks the resulting parse tree node-by-node, randomly selecting characters that satisfy each node type (`literal`, `in` (character class), `range`, `any`, `branch`, `repeat`, etc.). The result is a string that structurally satisfies the regex by construction, not by rejection-sampling.

For `Annotated[str, StringConstraints(pattern=r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")]` (MAC address), `Annotated[str, StringConstraints(pattern=r"^[a-z0-9-]+$")]` (slug), or similar: polyfactory will call `_generate_pattern(random, pattern)` which invokes `RegexFactory(random)(pattern)` and returns a structurally matching string. [official source] (https://github.com/litestar-org/polyfactory/blob/main/polyfactory/value_generators/regex.py)

**Known footgun — `max_length` truncation can break a generated regex match.** When a field has both `pattern` and `max_length`, polyfactory generates a regex-matching string and then truncates it to `max_length`. If the regex anchors the end of string (`$` or `\Z`) or requires a fixed total length (e.g. a MAC address is always exactly 17 chars), truncation can produce a string that no longer matches the pattern. This was a reported bug in 2022 (polyfactory issue #124) and the fix was to repeat-concatenate the pattern output until `min_length` is reached — but the truncation to `max_length` is still a hard cut. **Consequence for your schema:** if any `*Spec` field has both a fixed-length regex pattern AND a `max_length` constraint shorter than the minimum match length, build will silently produce a non-matching string. The resulting instance will fail Pydantic's own `model_validate` — surfacing as a `ValidationError` on `build()` (see Q2 below). [community] (https://github.com/litestar-org/polyfactory/issues/124)

**Known secondary footgun — regex engine dialect mismatch in the emitted JSON Schema.** Pydantic 2.11+ `StringConstraints` accepts compiled `re.Pattern` objects as the `pattern` argument, but JSON Schema `pattern` must be an ECMAScript regex string. Constructs like `\A`, `\Z`, `{,3}`, and Python-specific flags are invalid in ECMAScript. If your Pydantic model uses Python-only regex syntax, polyfactory will generate correctly for Pydantic, but the JSON Schema validator will reject the generated instance for a different reason (the pattern string in the schema is illegal under ECMA regex). This is a separate concern from polyfactory itself but is load-bearing for the C3 test. [community] (https://github.com/pydantic/pydantic/issues/12249)

**Numeric bounds (`ge`, `le`, `Field(ge=0, le=65535)`):** fully honored. polyfactory generates integers in `[ge, le]` by passing those bounds directly to `random.randint`. Confirmed by Context7 docs and source. `float` bounds likewise. [official] (https://context7.com/litestar-org/polyfactory/llms.txt)

**`Literal[...]` enums:** fully honored. polyfactory calls `random.choice(get_args(Literal[...]))` for Literal-typed fields. Confirmed by `DataclassFactory.coverage()` behavior which yields one instance per Literal value. [official] (https://context7.com/litestar-org/polyfactory/llms.txt)

---

### Q2 — Validation on build: does `ModelFactory.build()` run Pydantic validation?

**Yes, by default `build()` runs full Pydantic validation.** Internally, `ModelFactory.build()` calls `model_validate(data)` (Pydantic v2 path), which triggers all field validators and `@model_validator` methods. A constraint-violating generated value (e.g., from the `max_length` truncation bug described above) will raise `ValidationError` at `build()` time — the failure surfaces immediately as a build error, not as silent bad data.

The bypass path is the explicit opt-in `factory_use_construct=True` passed to `build()`:

```python
raw = MySpecFactory.build(factory_use_construct=True)
```

This calls `model_construct()` instead of `model_validate()`, skipping all validators. **Do not use this for the C3 drift gate** — instances produced this way may violate the model's own constraints and would cause spurious JSON Schema rejections for non-drift reasons.

Changelog note: polyfactory v2.16.1 fixed a bug where `factory_use_construct` was not propagated to nested factory calls; prior versions could bypass validation on top-level but still validate nested models. Pin to v2.16.1+ if using nested `*Spec` models. [official] (https://polyfactory.litestar.dev/latest/changelog.html)

---

### Q3 — Structural support for discriminated unions, plain Union, forward refs, Annotated, nested models

| Feature | Support | Notes |
|---------|---------|-------|
| `Annotated[T, Field(ge=, le=)]` numeric bounds | Full | Passed directly to random generator |
| `Annotated[str, StringConstraints(pattern=...)]` | Full with caveat | Regex is generated correctly; `max_length` truncation can break anchored patterns |
| `Literal["foo", "bar"]` fields | Full | `random.choice(get_args(...))` |
| Plain `Union[X, Y]` | Full (v2.14.1+) | v2.14.1 specifically fixed "Handle unions properly" (#491) |
| Discriminated unions `Field(discriminator='kind')` | Full | `ModelFactory` calls `model_validate` which resolves the discriminator; the factory picks one branch randomly |
| Forward references / string annotations | Full via `__forward_references__` | Must declare `__forward_references__ = {"MyRef": ConcreteType}` in the factory class; `ModelFactory` auto-calls `model.model_rebuild()` in `_init_model` |
| Deeply nested `BaseModel` fields | Full | Factory recursively generates sub-models |
| `__use_examples__ = True` | Full (Pydantic v2 only) | Picks from `Field(examples=[...])` — useful for `apiVersion`, `kind` literal fields |

**Discriminated union detail:** polyfactory picks one branch of the union at random for each build call. To test all branches, use `ModelFactory.coverage()` which yields one instance per union branch. For the C3 gate this means you should call `coverage()` rather than `build()` to ensure every kind variant is represented. [official] (https://context7.com/litestar-org/polyfactory/llms.txt)

**Forward ref detail for `SecretRef`:** if `SecretRef` is a forward-referenced type or defined in a separate module, add it to the factory's `__forward_references__` dict. If `SecretRef` is a string annotation, polyfactory's `ModelFactory._init_model()` already calls `model.model_rebuild()` which resolves most cases automatically. If `SecretRef` uses a `RootModel` or `NewType`, an explicit `provide_factory` override may be needed. [official] (https://github.com/litestar-org/polyfactory/blob/main/docs/usage/configuration.rst)

---

### Q4 — Determinism: seeding API for reproducible CI runs

Two equivalent mechanisms, pick one:

**Option A — class-level seed (preferred for CI, seeds at class definition):**

```python
from polyfactory.factories.pydantic_factory import ModelFactory
from faker import Faker

class MySpecFactory(ModelFactory[MySpec]):
    __random_seed__ = 42
    __faker__ = Faker()          # Faker is also seeded via __random_seed__
```

**Option B — runtime seed (useful when seed must vary per run or come from env):**

```python
ModelFactory.seed_random(42)    # seeds both Random and Faker globally
```

Both `random.Random` methods and `Faker` are seeded by `__random_seed__`. As of v2.7.1, constrained strings with a seed are deterministic. **The seed must be set before the first `build()` call.** Using `__random_seed__` at class definition is safer for CI because it is not order-dependent. [official] (https://github.com/litestar-org/polyfactory/blob/main/docs/usage/configuration.rst)

---

### Q5 — Alternative if regex/pattern handling is poor

polyfactory's regex handling is *not* poor — it genuinely satisfies patterns. However, the `max_length` truncation footgun is real. If your `*Spec` fields have anchored-pattern + max_length combinations, the safest mitigation is to **provide the regex-constrained fields as explicit factory overrides** rather than relying on automatic generation:

```python
import random as _random

class DeviceSpecFactory(ModelFactory[DeviceSpec]):
    __random_seed__ = 42
    # Override regex-constrained fields with hand-curated generators
    mac_address = lambda: _random.choice([
        "aa:bb:cc:dd:ee:ff", "00:11:22:33:44:55", "de:ad:be:ef:00:01"
    ])
    slug = lambda: _random.choice(["my-device", "core-switch-01", "edge-router"])
```

If you want programmatic regex generation with no truncation risk, `hypothesis.strategies.from_regex(pattern, fullmatch=True)` is the most robust option — it uses a constraint-solving approach (via `hypothesis`'s own regex strategy) that respects anchors and produces valid full matches without truncation. This requires `hypothesis` as a dev dependency but not the Pydantic plugin or `hypothesis-jsonschema`. It is the recommended fallback if polyfactory's `RegexFactory` misbehaves on a specific pattern. [official] (https://hypothesis.readthedocs.io/en/latest/data.html)

---

### C3 Verdict

**NEEDS-CUSTOM-PROVIDERS** — but only a targeted, low-cost form of it.

polyfactory will handle numeric bounds, Literal fields, Union branches, forward refs, and nested models cleanly out of the box. The specific issue is anchored `pattern` regexes combined with `max_length`: polyfactory generates correct regex matches but truncates them, which breaks anchored patterns (MAC addresses, duration strings, apiVersion patterns, slug patterns with `^...$`). This is not a reason to abandon C3 — it is a reason to override exactly those fields.

**Practical implementation:**

1. For fields with `pattern` + no `max_length` (or `max_length` >= the pattern's minimum match length): polyfactory works without override.
2. For fields with anchored `pattern` (uses `^`/`$`/`\A`/`\Z`) + `max_length`: provide a factory override with a curated list of 3-5 valid values, or use `Field(examples=[...])` + `__use_examples__ = True`.
3. For fields with Python-only regex syntax (`\A`, `\Z`, `{,3}`, named groups): also check that the pattern as emitted in the JSON Schema is valid ECMAScript before testing against `Draft202012Validator`.

The audit scope is bounded: check each `*Spec` class for the pattern+max_length combination. For a 19-kind schema with mostly simple patterns (MAC, slug, CIDR-like strings, apiVersion), the number of fields needing override is likely 3-8 total across all kinds — not a per-kind burden.
