# DocuRoute prototype — notes for Claude Code

## Current task: UI redesign from Figma
- Figma file: https://www.figma.com/design/TzMJnEP0azyRWIwGKEnkGc/ — page "01 — Priority UX screens" (node 7:2). Frame node IDs are in `docs/redesign-plan.md`.
- Figma MCP is capped at 20 calls/month on the Starter plan — don't spend calls on it. Build from the user's screenshots of the frames (approved 2026-10-14), matching the tokens already in `index.html`.
- Read first: `docs/redesign-plan.md`, then `docs/figma-ui-redesign-prompt.txt`.
- Follow the build order in the plan. Do one step at a time and stop for review.

## Build status (updated 2026-10-14)
- **Done:** step 1 (tokens, forest sidebar, mobile top bar + bottom tab bar, system light/dark), step 2 (status vocabulary + icon pills, toasts, confirm/decline dialogs replacing alert/confirm/prompt), logo in `assets/`.
- **Step 3 done (awaiting review):** student Active requests, full-page Request detail, full-page New request (photo dropzone + preview, contact remembered per device), AI result / AI unsure / not-recognized screens — desktop + mobile. Not committed yet.
- **Next: step 4** — Registrar master-detail with one-tap confirm (screenshot "Registrar · Manual confirmation / desktop" + "Confirm suggested type / mobile"). Known gap to fix there: an unverified student request has `route=[]` and no saved type, so `confirmAndRoute` needs a type picker that sets `type` + `route`. The AI's suggestion is only in the audit log text ("classified as X …").
- Logo decision: use the R + DOCUROUTE logo in `assets/` (not the Ω or the Figma "DR monogram").
- Visual checks: no login available headlessly; use a stub-Supabase harness (fake `sb` + seeded `session`/`state`, rendered with headless Edge). Headless Edge floors at ~500px wide, so check mobile at 560px.

## Rules
- If `README.md` / `prototype.md` conflict with the redesign prompt, trust the prompt (e.g. rectification and real photos now exist).
- Edit `index.html` only (plus `supabase/` migrations when the plan says schema work). Plain HTML/CSS/vanilla JS — no frameworks, no build step.
- Keep the 6 document types, 6 roles, route table and the 70% confidence gate exactly as they are.
- Students never pick the document type.
- Schema changes go in a new numbered `supabase/migration-00N-*.sql`, never by editing `schema.sql` alone.
- Never add real student data or form photos to this repo — it is pushed to GitHub.

## Reference
- `docs/reference/serve.py`, `classify.py` — the `/classify` response shape (`type`, `confidence`, `similarities`, `textPreview`; `type` is null for "other").
- `docs/Feature Idea - Versioned Digital-Twin via QR Rescan.md` — planned #18.
- `docs/station-qr-sheet-A4.png` — station QR codes for planned #17 (`DOCUROUTE:STATION:<OFFICE>`).
- `docs/current-ui/` — screenshots of the current UI.
