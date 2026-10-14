# Feature Idea — Versioned Digital-Twin via QR Rescan

*Parked 2026-09-18. Not discussed anywhere before this — checked `Chapter 1-3 v5.md` and `Thesis - Plans, Notes, and Warnings.md`, neither mentions it. Not built into `prototype/`. This file exists so the idea doesn't get lost; revisit and decide before committing it to the thesis or the schema.*

## The idea

Right now, Digital-Twin Archiving (Section 1.9) is a **single upload at intake**: a student attaches one scan/photo when they submit, and that's the only digital copy that ever exists for that request. `requests.document_path` is one column, one file, forever.

The idea: let each office, when it clears its step on the physical form (i.e. adds a new wet-ink signature to the paper), **attach a freshly re-scanned/re-photographed copy** — triggered by scanning the document's QR code at that office. Each scan-and-upload would create a **new version** of the digital twin rather than overwriting or ignoring the original, so the digital record stays in sync with the paper as signatures accumulate across offices, instead of only reflecting the document's state at the moment of intake.

## Why this matters

As currently designed, the "digital twin" name slightly overstates what happens after intake: the paper document keeps changing (new signatures at each office) while the digital copy is frozen from the first upload. Anyone looking at the archived scan later sees the *original* unsigned/partially-signed form, not the fully-executed one — so it's really a backup snapshot, not a live twin. Versioned re-upload would close that gap and make the "twin" claim more literally true.

## Why it's not in the current build or thesis

- `Chapter 1-3 v5.md`'s own definition of Digital-Twin Archiving is explicit that it happens "at the point of intake" — one time, not per-hop.
- The only appearance of "version control" anywhere in the thesis is describing a *different* precedent system (Raralio et al. [4], Apayao DTAS) in the Section 2.8 comparison table — not something DocuRoute itself claims.
- The schema (`prototype/supabase/schema.sql`) has no versions table; `requests.document_path` is a single text column.
- The UI (`View attached form` in `index.html`) opens one signed URL to one file — there's no version list anywhere to view.

So this is a genuinely new feature, not something that was scoped and deferred.

## What building it would actually touch, if picked back up

**Chapter 1 (paper):**
- Section 1.3's feature list and Section 1.9's Digital-Twin Archiving definition would need rewriting to describe versioning, not single-capture.
- Possibly a new line in the gap-to-feature mapping if this is framed as addressing the "lack of unified access and version control" gap (currently addressed only by centralized *storage*, not versioning) — worth deciding whether this actually strengthens that gap's resolution or is a separate enhancement.

**Database (`prototype/supabase/schema.sql`):**
- A new `document_versions` table: `request_id`, `office` (which hop uploaded it), `uploaded_by`, `path`, `created_at`.
- RLS: only the office currently at that request's active hop (or the original student, for the initial version) should be able to insert a new version — same `staff_can_see_request()`-style scoping already used elsewhere, but additionally checked against "is this office the *current* hop," not just "does this office appear anywhere in the route."
- Decide: does `requests.document_path` stay as a convenience pointer to the *latest* version, or does everything move to querying `document_versions` directly?

**UI (`prototype/index.html`):**
- An upload control added to each staff action screen (Dean's Decision, Registrar Queue, Treasury Queue, Section Chief Review) for attaching a new scan when clearing a step — presumably tied to the existing QR scan flow so scanning IS the trigger, not a separate button.
- Replace the single "View attached form" button with a version history list (who uploaded, when, from which office).

## Does this need its own literature reference?

**Resolved 2026-09-18: no new reference needed.** Checked against the precedent already set in `Thesis - Plans, Notes, and Warnings.md` Part A.1 (RBAC, audit trail, UUID mechanics, routing table — all declared as this study's own design choices, no citation required).

- The *problem* this idea addresses is already cited: Gap #2 in Section 1.2 is literally "the lack of unified access and **version control**... [4]", and Section 2.8's table lists "version control" as a Key Functionality of Raralio et al. [4] (Apayao DTAS). So the motivation can lean on `[4]`, already in the reference list — no new source needed to justify why version control matters.
- The *mechanism* (a QR scan at each office triggering a new archived version) is an original system-design choice, same category as RBAC/audit trail/routing table. State it declaratively ("this study implements...") rather than attributing it to a source, since nothing in the current reference list studies this specific mechanism and nothing requires it to.

## Open questions to resolve before building this

1. Is the re-upload *mandatory* to clear a step, or optional? (Mandatory is more realistic to the "keep paper and digital in sync" goal, but adds friction if a phone camera isn't handy at every office.)
2. Does this apply to all 6 document types uniformly, or only ones where a physical wet-ink signature is actually the approval mechanism (vs. e.g. a pure digital sign-off)?
3. Should old versions stay visible/downloadable to the student, or only the latest?
4. Any ISO/IEC 25010 evaluation impact — e.g. does this become something Section 3.17's instrument should ask about (likely under Functional Suitability or Reliability)?
