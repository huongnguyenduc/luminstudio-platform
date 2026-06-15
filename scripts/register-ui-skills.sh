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
    return
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
  skill:.agents/skills/brandkit \
  "Premium brand identity and brand-kit image direction" \
  brand-design \
  .agents/skills/brandkit/SKILL.md
register_skill design-taste-frontend \
  skill:.agents/skills/design-taste-frontend \
  "Anti-generic frontend direction for landing editorial and redesign work" \
  web-ui-design \
  .agents/skills/design-taste-frontend/SKILL.md
register_skill full-output-enforcement \
  skill:.agents/skills/full-output-enforcement \
  "Complete unabridged output discipline for multi-file UI deliverables" \
  output-completeness \
  .agents/skills/full-output-enforcement/SKILL.md
register_skill gpt-taste \
  skill:.agents/skills/gpt-taste \
  "Experimental motion-rich Awwwards-style frontend direction" \
  web-ui-design \
  .agents/skills/gpt-taste/SKILL.md
register_skill high-end-visual-design \
  skill:.agents/skills/high-end-visual-design \
  "Premium agency-style web visual and motion direction" \
  web-ui-design \
  .agents/skills/high-end-visual-design/SKILL.md
register_skill image-to-code \
  skill:.agents/skills/image-to-code \
  "Image-first web design reference generation and implementation guidance" \
  web-image-to-code \
  .agents/skills/image-to-code/SKILL.md
register_skill imagegen-frontend-mobile \
  skill:.agents/skills/imagegen-frontend-mobile \
  "Premium mobile screen and flow concept image direction" \
  mobile-ui-design \
  .agents/skills/imagegen-frontend-mobile/SKILL.md
register_skill imagegen-frontend-web \
  skill:.agents/skills/imagegen-frontend-web \
  "Section-specific web concept image direction" \
  web-ui-concept \
  .agents/skills/imagegen-frontend-web/SKILL.md
register_skill industrial-brutalist-ui \
  skill:.agents/skills/industrial-brutalist-ui \
  "Industrial brutalist and telemetry-heavy web interface direction" \
  web-ui-design \
  .agents/skills/industrial-brutalist-ui/SKILL.md
register_skill minimalist-ui \
  skill:.agents/skills/minimalist-ui \
  "Minimal editorial and utilitarian web interface direction" \
  web-ui-design \
  .agents/skills/minimalist-ui/SKILL.md
register_skill redesign-existing-projects \
  skill:.agents/skills/redesign-existing-projects \
  "Audit-first visual redesign guidance that preserves existing behavior" \
  ui-redesign \
  .agents/skills/redesign-existing-projects/SKILL.md
register_skill stitch-design-taste \
  skill:.agents/skills/stitch-design-taste \
  "Generate premium semantic DESIGN.md guidance for Google Stitch" \
  design-system-generation \
  .agents/skills/stitch-design-taste/SKILL.md
register_skill flutter-expert \
  skill:.agent/skills/flutter-expert \
  "Flutter UI architecture implementation testing and performance guidance" \
  mobile-ui-implementation \
  .agent/skills/flutter-expert/SKILL.md
register_skill mobile-developer \
  skill:.agent/skills/mobile-developer \
  "Cross-platform mobile and native integration implementation guidance" \
  mobile-ui-implementation \
  .agent/skills/mobile-developer/SKILL.md

scripts/bin/harness-cli tool check
