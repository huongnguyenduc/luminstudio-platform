#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

registry="$(scripts/bin/harness-cli query tools --json)"

register_skill() {
  local name="$1"
  local command="$2"
  local description="$3"
  local capability="$4"
  local scan="$5"

  if grep -q "\"name\": \"${name}\"" <<<"$registry"; then
    scripts/bin/harness-cli tool remove --name "$name"
  fi

  scripts/bin/harness-cli tool register \
    --name "$name" \
    --kind skill \
    --capability "$capability" \
    --scan "$scan" \
    --command "$command" \
    --description "$description" \
    --responsibility "Tool access"
}

register_skill brandkit \
  skill:.codex/skills/brandkit \
  "Premium brand identity and brand-kit image direction" \
  brand-design \
  .codex/skills/brandkit/SKILL.md
register_skill design-taste-frontend \
  skill:.codex/skills/design-taste-frontend \
  "Anti-generic frontend direction for landing editorial and redesign work" \
  web-ui-design \
  .codex/skills/design-taste-frontend/SKILL.md
register_skill full-output-enforcement \
  skill:.codex/skills/full-output-enforcement \
  "Complete unabridged output discipline for multi-file UI deliverables" \
  output-completeness \
  .codex/skills/full-output-enforcement/SKILL.md
register_skill gpt-taste \
  skill:.codex/skills/gpt-taste \
  "Experimental motion-rich Awwwards-style frontend direction" \
  web-ui-design \
  .codex/skills/gpt-taste/SKILL.md
register_skill high-end-visual-design \
  skill:.codex/skills/high-end-visual-design \
  "Premium agency-style web visual and motion direction" \
  web-ui-design \
  .codex/skills/high-end-visual-design/SKILL.md
register_skill image-to-code \
  skill:.codex/skills/image-to-code \
  "Image-first web design reference generation and implementation guidance" \
  web-image-to-code \
  .codex/skills/image-to-code/SKILL.md
register_skill imagegen-frontend-mobile \
  skill:.codex/skills/imagegen-frontend-mobile \
  "Premium mobile screen and flow concept image direction" \
  mobile-ui-design \
  .codex/skills/imagegen-frontend-mobile/SKILL.md
register_skill imagegen-frontend-web \
  skill:.codex/skills/imagegen-frontend-web \
  "Section-specific web concept image direction" \
  web-ui-concept \
  .codex/skills/imagegen-frontend-web/SKILL.md
register_skill industrial-brutalist-ui \
  skill:.codex/skills/industrial-brutalist-ui \
  "Industrial brutalist and telemetry-heavy web interface direction" \
  web-ui-design \
  .codex/skills/industrial-brutalist-ui/SKILL.md
register_skill minimalist-ui \
  skill:.codex/skills/minimalist-ui \
  "Minimal editorial and utilitarian web interface direction" \
  web-ui-design \
  .codex/skills/minimalist-ui/SKILL.md
register_skill redesign-existing-projects \
  skill:.codex/skills/redesign-existing-projects \
  "Audit-first visual redesign guidance that preserves existing behavior" \
  ui-redesign \
  .codex/skills/redesign-existing-projects/SKILL.md
register_skill stitch-design-taste \
  skill:.codex/skills/stitch-design-taste \
  "Generate premium semantic DESIGN.md guidance for Google Stitch" \
  design-system-generation \
  .codex/skills/stitch-design-taste/SKILL.md
register_skill flutter-expert \
  skill:.codex/skills/flutter-expert \
  "Flutter UI architecture implementation testing and performance guidance" \
  mobile-ui-implementation \
  .codex/skills/flutter-expert/SKILL.md
register_skill mobile-developer \
  skill:.codex/skills/mobile-developer \
  "Cross-platform mobile and native integration implementation guidance" \
  mobile-ui-implementation \
  .codex/skills/mobile-developer/SKILL.md

scripts/bin/harness-cli tool check
