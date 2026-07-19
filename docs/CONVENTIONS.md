# kaichen_era_media — Doc Conventions

> Generic rules: see the `docs-manager` SKILL in the lingo_cosmos repo. This file lists kaichen_era_media-specific particulars.

## 1. Project shape

**Single-repo, single-component plugin** (skill §15 form A / SDK).

Repo root is the package; no sub-component directories. Docs live in `docs/`.

## 2. Doc taxonomy

Per skill §3 simplified plugin taxonomy:

```
README.md                ← entry point + usage snippet
docs/CONVENTIONS.md      ← this file
docs/PRD.Media.md        ← API contract: surface / inputs / outputs / strategies
docs/ARCH.Media.md       ← internal pipeline: WebP normalization, sha256 timing, picker integration
```

ADR / PM / OPS / TEST / GLOSSARY are **not** carved out. The plugin is narrow enough that decision rationale lives in ARCH (in-line "design notes"), and integration test strategies belong to consumers (lingo / kinjin).

## 3. Audit command

```bash
find docs -type f -name "*.md" ! -name "README.md" | sort
```

## 4. Consumers

| Consumer repo | Use |
|---|---|
| [`kaichen_era_sticker_sdk`](https://github.com/KaiChenEra/kaichen_era_sticker_sdk) | sticker_add_flow uses normalizeBytesToWebp + ImagePickerService |
| [`lingo_cosmos_app`](https://github.com/KaiChenEra/lingo_cosmos_app) | lingo's lifted_subject_display_page calls normalizeBytesToWebp directly for its custom save flow |
| [`kinjin_sticker_app`](https://github.com/KaiChenEra/kinjin_sticker_app) | host-side cover assets / icon caching |

Per skill §15.2.4, plugin docs stay host-agnostic. Don't enumerate "lingo does X / kinjin does Y" comparison tables; let each consumer document its own integration.

## 5. PR workflow

| Item | Value |
|---|---|
| Base branch | `main` |
| All changes via PR | ✅ no direct push to main |
| Squash merge + delete branch | ✅ |
| Commit co-author | `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` |
| PR ordering with consumer docs | This plugin's docs **must merge first**; only then can consumer host docs link the GitHub URLs (skill §15.2.5) |

## 6. Naming

`PRD.Media.md` / `ARCH.Media.md` — single feature scope so no `Module` prefix beyond the package name.

If the package later grows additional independent features (e.g. an audio normalizer that doesn't share code with WebP), introduce sub-features:
- `PRD.Media.Webp.md`
- `PRD.Media.Audio.md`

## 7. Change history

| Date | Change |
|---|---|
| 2026-04-28 | Initial CONVENTIONS + simplified plugin taxonomy bootstrapped |
