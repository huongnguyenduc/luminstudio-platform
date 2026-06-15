# UI Skill Routing

The repository includes optional UI design skills under `.agents/skills/`.
Use them for user-visible web and mobile work, but keep product docs, stories,
architecture rules, and executable validation as the authoritative contract.

## Required Workflow

1. Read the relevant product doc and story before selecting a visual direction.
2. Query equipped providers for the task capability:

   ```bash
   scripts/bin/harness-cli query tools --capability web-ui-design --status present
   scripts/bin/harness-cli query tools --capability mobile-ui-design --status present
   ```

3. Select the smallest compatible skill set and read every selected `SKILL.md`
   completely before applying it.
4. Preserve existing framework, navigation, state, API, and accessibility
   contracts unless the story explicitly changes them.
5. Implement the UI in the repository. Generated images and design boards are
   references only.
6. Verify responsive layout, interaction states, keyboard/touch behavior,
   loading/empty/error states, and console/runtime output as applicable.

## Core Routing

| Need | Capability | Preferred skill | Notes |
| --- | --- | --- | --- |
| Web landing, editorial, portfolio, or marketing page | `web-ui-design` | `design-taste-frontend` | Not for dashboards, data tables, or multi-step product UI. |
| Existing web or app UI refinement | `ui-redesign` | `redesign-existing-projects` | Audit first; preserve functionality and the current stack. |
| Premium web art direction with strong motion | `web-ui-design` | `high-end-visual-design` | Use only when the brief supports cinematic motion and visual density. |
| Experimental Awwwards-style web experience | `web-ui-design` | `gpt-taste` | Explicit opt-in; do not use for routine admin workflows. |
| Minimal editorial/product direction | `web-ui-design` | `minimalist-ui` | Choose this instead of another style skill, not in addition to one. |
| Industrial or telemetry-heavy direction | `web-ui-design` | `industrial-brutalist-ui` | Use only when the product brief calls for this aesthetic. |
| Web section concept images | `web-ui-concept` | `imagegen-frontend-web` | Produces design references, not code or proof. |
| Mobile screen/flow concept images | `mobile-ui-design` | `imagegen-frontend-mobile` | Pair with existing Flutter skills for implementation. |
| Flutter UI implementation | `mobile-ui-implementation` | `flutter-expert` | Preserve BLoC/Cubit, widget, testing, and performance conventions. |
| Broader mobile/platform implementation | `mobile-ui-implementation` | `mobile-developer` | Use when native integration or cross-platform behavior is part of the story. |
| Image-first web implementation | `web-image-to-code` | `image-to-code` | Generate/analyze references, then implement and browser-verify. |
| Brand identity exploration | `brand-design` | `brandkit` | Requires an explicit branding task; do not invent a new brand during feature work. |
| Google Stitch design-system file | `design-system-generation` | `stitch-design-taste` | Use only when Stitch or a `DESIGN.md` deliverable is requested. |
| Exhaustive generated deliverables | `output-completeness` | `full-output-enforcement` | Output discipline only; it does not choose a visual direction. |

The two mobile implementation providers live under `.agent/skills/`; the new
visual-direction providers live under `.agents/skills/`. Always follow the
path reported by Harness rather than assuming the directories are equivalent.

## Selection Rules

- Use at most one primary visual-style skill for an implementation pass.
- A concept skill may be paired with one implementation skill when the story
  explicitly benefits from image-first exploration.
- `full-output-enforcement` may accompany another skill when a complete set of
  files or screens is required.
- Do not use `brandkit`, `gpt-taste`, industrial brutalism, or high-motion
  direction by default. Their use must follow the brief or a recorded design
  choice.
- When skills conflict, product constraints and accessibility win. Then prefer
  the more task-specific skill over the more general aesthetic skill.
- Do not copy reference brands, logos, proprietary layouts, or copyrighted
  assets. Extract principles and create project-specific work.

## Platform Requirements

### Web Admin

- Keep implementation inside `apps/web-admin` and behind the Go API boundary.
- Product administration is application UI, not a marketing site. Prefer
  usability, data clarity, and complete states over decorative motion.
- Browser verification should cover at least mobile and desktop widths when
  the story changes responsive behavior.

### Flutter Mobile

- Keep feature-oriented Clean Architecture and BLoC/Cubit ownership intact.
- Treat generated phone screens as visual references; rebuild them with Flutter
  widgets and existing application contracts.
- Verify touch targets, safe areas, text scaling, navigation/state retention,
  and representative Android/iOS viewport sizes required by the story.

## Harness Registration

The installed skills are registered as Harness tools by capability. Refresh
or restore the registrations after cloning or recreating `harness.db`:

```bash
bash scripts/register-ui-skills.sh
scripts/bin/harness-cli query tools --summary
```

A skill reported as `present` is equipped on disk. The active agent runtime
must still support reading and applying that skill during the current session.
