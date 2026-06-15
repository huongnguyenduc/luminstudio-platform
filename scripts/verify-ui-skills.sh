#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ui_skills=(
  brandkit
  design-taste-frontend
  full-output-enforcement
  gpt-taste
  high-end-visual-design
  image-to-code
  imagegen-frontend-mobile
  imagegen-frontend-web
  industrial-brutalist-ui
  minimalist-ui
  redesign-existing-projects
  stitch-design-taste
)

for skill in "${ui_skills[@]}"; do
  test -f ".agents/skills/${skill}/SKILL.md"
  grep -q "\"${skill}\"" skills-lock.json
  grep -q "${skill}" docs/UI_SKILLS.md
done

test -f .agent/skills/flutter-expert/SKILL.md
test -f .agent/skills/mobile-developer/SKILL.md

grep -q 'docs/UI_SKILLS.md' AGENTS.md
grep -q 'web-ui-design' docs/UI_SKILLS.md
grep -q 'mobile-ui-design' docs/UI_SKILLS.md
grep -q 'mobile-ui-implementation' docs/UI_SKILLS.md
grep -q 'Image-generation output is design reference' AGENTS.md

bash scripts/register-ui-skills.sh >/dev/null

for capability in \
  web-ui-design \
  mobile-ui-design \
  mobile-ui-implementation \
  ui-redesign \
  web-ui-concept \
  web-image-to-code \
  brand-design \
  design-system-generation \
  output-completeness; do
  providers="$(scripts/bin/harness-cli query tools \
    --capability "$capability" --status present)"
  if ! grep -q 'skill' <<<"$providers"; then
    echo "No present skill provider for capability: $capability" >&2
    exit 1
  fi
done

git diff --check

echo "UI skill routing verification passed"
