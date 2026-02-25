---
description: Build distinctive, production-grade frontend interfaces — components, pages, or full applications. Activates the fw-fe-designer persona and FE-design skill. Never produces generic AI aesthetics.
---

# FE Design Workflow

> **Persona active:** `fw-fe-designer` — activates the **FE-design** skill (see `skills/FE-design/SKILL.md`)

This command builds production-grade frontend interfaces with a committed aesthetic direction. Unlike `/fw:design` (which produces a plan), **this command produces working, runnable code** as its primary output.

---

## Step 0: Parse Input & Clarify

Parse the user's input after `/fw:fe-design`:
- **Subject**: what to build (component, page, application, flow)
- **Context hints**: any tech stack, framework, brand direction, or audience cues mentioned

If no description is provided, ask:
> *"What are you building? Describe the component, page, or application — even a rough idea is fine. Any tech stack preferences (React, plain HTML, Vue)?"*

Ask **at most 3** focused follow-up questions if the brief is vague. Only ask what matters for design direction:
- "Who is the target user, and in what context will they see this?"
- "Any existing brand colours, fonts, or design tokens I should work with?"
- "Is there a specific aesthetic feel you have in mind — or should I surprise you?"

If the brief is already specific, skip straight to Step 1.

Print:
```
🎨 FE Design Brief: <description>
🧭 Tech stack: <detected or specified>
```

---

## Step 1: Commit to an Aesthetic Direction

> *Read the brief and commit to a specific, distinctive visual direction — before writing any code.*

**DO NOT** pick a safe, generic direction. Choose something with a clear point of view:

| Direction type | Examples |
|----------------|---------|
| Brutally minimal | Raw grid, monospace, pure black/white contrast |
| Editorial/magazine | Large display type, asymmetric layout, bold editorial colors |
| Luxury/refined | Elegant serif, muted palette, exquisite micro-detail |
| Retro-futuristic | CRT scanlines, terminal aesthetics, neon on dark |
| Organic/natural | Soft gradients, earthy palette, flowing shapes |
| Maximalist | Rich texture, layered transparencies, high-density layout |
| Playful/toy-like | Rounded corners, punchy colors, bouncy micro-animations |
| Brutalist/raw | Exposed grids, unstyled elements used provocatively |

State the direction explicitly:

```
🎨 Aesthetic Direction: <name — e.g. "Editorial brutalism with warm earth tones">
🖋  Typography: <display font / body font pair from Google Fonts or system>
🎨 Palette: <dominant: #hex + accent(s): #hex>
✨ Signature element: <one unforgettable detail — e.g. "diagonal section break", "grain overlay", "staggered card reveal">
```

**Non-negotiables** (from FE-design skill):
- NEVER use Arial, Inter, Roboto, or generic system fonts as the primary face
- NEVER use purple-gradient-on-white or other clichéd AI color schemes
- ALWAYS use CSS variables for all color and spacing tokens
- ALWAYS add at least one purposeful animation (page load, hover, or scroll-triggered)
- ALWAYS create depth — no flat solid-color backgrounds

If the user specified a design direction or brand, honour it while still injecting distinctiveness.

---

## Step 2: Build the Interface

> *Write production-grade, complete, runnable code. No placeholders. No `// TODO`.*

Implementation rules:
- Match the tech stack specified (or default to **vanilla HTML/CSS/JS** if not specified)
- For React: use functional components + hooks; use Motion library for animations where available
- For Vue: use Composition API
- For plain HTML: CSS custom properties, `@keyframes`, and native Web APIs only
- Inline styles only for dynamic values — all static styles in `<style>` or `.css`
- All fonts loaded via Google Fonts `@import` or `<link>` in the output
- Responsive by default — mobile-first unless told otherwise
- **Accessible**: semantic HTML, ARIA labels where needed, sufficient color contrast

**Code structure for delivery:**

For a single-file deliverable (components, simple pages):
```html
<!-- fe-design-output.html or ComponentName.tsx / .vue -->
<!-- Self-contained, runnable as-is -->
```

For multi-file deliverables (full pages with separate CSS/JS):
Provide each file as a clearly labelled code block.

---

## Step 3: Present Output

Structure the response as:

```
## 🎨 Design Direction
[aesthetic name · typography · palette · signature element]

## 💡 Rationale
[2-4 sentences: why these specific choices fit the brief and audience]

## 💻 Code
[Complete, working, runnable code — all files]

## 🚀 Usage
[How to run or embed this; any dependencies (e.g. npm packages, CDN links)]
```

---

## Step 4: Iterate or Hand Off

After presenting the output, ask:

```
✅ Here's your interface. What next?

  [refine]     — adjust colors, layout, typography, animations
  [variant]    — build an alternative with a different aesthetic direction
  [review]     — hand to fw-code-reviewer for quality + accessibility audit
  [implement]  — hand off to /fw:implement to integrate this into the codebase
  [done]       — looks good, I'm done
```

- **refine** → Ask what to change. Update the code and rationale, then repeat Step 4. Max 3 refinement rounds before suggesting a fresh `/fw:fe-design` run.
- **variant** → Pick a contrasting aesthetic direction from Step 1's table and rebuild. Show both side-by-side as labelled code blocks.
- **review** → Summarise the interface in one paragraph and instruct the user to run `/fw:review` with the output file.
- **implement** → Output: *"Take this code and run `/fw:implement <component name> — integrate the output of /fw:fe-design into the project`. Reference the code above as the source of truth."*
- **done** → Print session path and close.

---

## Session Storage

Save all outputs to the project's flywheel session directory for traceability:

```bash
PROJECT_NAME="${FLYWHEEL_PROJECT:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")")}"
SESSION_DIR="$HOME/.flywheel/projects/$PROJECT_NAME/fe-design/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

Save:
- `$SESSION_DIR/00-brief.md` — original brief, aesthetic direction, palette
- `$SESSION_DIR/01-output.*` — the delivered code file(s)
- `$SESSION_DIR/02-iterations.md` — any refinement rounds (if applicable)

---

## Error Handling

| Situation | Response |
|-----------|----------|
| No tech stack specified | Default to vanilla HTML/CSS/JS; mention the choice |
| Brief is too vague after clarification | Pick a direction and state: *"I'm committing to X — tell me to adjust if that's not the right feel"* |
| User requests a banned aesthetic (purple gradients etc.) | Note the conflict with the FE-design skill, offer two alternatives, let user choose |
| Requested framework not in Claude's knowledge | Fall back to vanilla HTML/CSS/JS and note the limitation |

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------| 
| `FLYWHEEL_PROJECT` | `<git repo name>` | Project name for session isolation |
| `FLYWHEEL_FE_DESIGN_DIR` | `~/.flywheel/projects/<project>/fe-design` | Where session files are saved |
