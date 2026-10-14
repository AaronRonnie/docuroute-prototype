# DocuRoute Figma Redesign — Implementation Plan

As of 2026-10-14. Source design: [DocuRoute · UI/UX Redesign — Light Theme](https://www.figma.com/design/TzMJnEP0azyRWIwGKEnkGc/DocuRoute-%C2%B7-UI-UX-Redesign-%E2%80%94-Light-Theme?node-id=7-2), page "01 — Priority UX screens" (node 7:2).

Almost every Figma frame can be built with plain HTML/CSS/JS. Only a few features need database or backend work, and five design choices break the prompt's rules and should be fixed before coding.

## Frames in the Figma file (node IDs for Figma MCP)

| Frame | Node |
| --- | --- |
| Student · Active requests (desktop) | 9:10 |
| Student · Requests / mobile | 9:57 |
| Student · New request (desktop) | 9:91 |
| Student · New request / mobile | 9:125 |
| Student · AI result (desktop) | 9:148 |
| Student · AI unsure / mobile | 9:177 |
| Student · Request detail (desktop) | 9:200 |
| Student · Request detail / mobile | 9:240 |
| Staff · My queue / mobile | 10:10 |
| Staff · AI walk-in capture / mobile | 10:42 |
| Staff · QR scan / mobile | 10:67 |
| Registrar · Manual confirmation / desktop | 10:87 |
| Registrar · Confirm suggested type / mobile | 10:136 |
| Dean · Decision queue / desktop | 10:159 |

**Missing:** Login, Notifications feed, Admin, Treasury and Section Chief desktop queues, empty/offline/error states, dark theme, Dean signature screen (only a "PLANNED" note). Design these while building, following the same tokens.

## Can build now (front-end only)

- **Sidebar and mobile bottom tab bar.** Drop the "Mobile Version" badge; mobile follows the phone's light/dark setting (remove the forced-dark rules).
- **Student request cards and route stepper.** Built from existing `route[]` and `hop`.
- **New request form.** Read-only profile fields, photo box with preview, optional details. No type dropdown for students.
- **AI result screen (#2).** From `/classify`'s `type` and `confidence` plus the route table.
- **"AI unsure" screen.** Replace "% Conflict" (`statusPill`, ~line 1175) with a calm label like "Registrar will confirm".
- **Request detail redesign.** Next step first, then form preview, info, collapsed audit trail.
- **Staff mobile queue (#1).** Same query as desktop queue, shown as cards.
- **Registrar master-detail (#3).** List left; photo, AI guess, "Confirm & route" right. "Change type" = `<select>` of 6 types.
- **QR scan screen.** Restyle.
- **Search, sort by age, filters on queues.** Client-side.
- **Replace `alert()` with toasts** (~lines 1573, 1601, 1713, 1741).

## Needs backend or schema changes

| Feature | Why |
| --- | --- |
| Saved contact number (#4) | Add `contact_no` to `profiles`; today it only lives per request. |
| Walk-in: photo first, AI suggests type (#5) | Staff capture must call `/classify`; it skips it today. |
| Student lookup by student number | Staff can read `profiles`, but walk-ins often have no account — need a "not found, type it in" fallback. |
| Decline reason shown cleanly | Saved only as text in the audit log (`declineRequest`, ~line 1893). Parse it or add `decline_reason`. |
| Dean signature, version history, station check-in (#13, #17, #18) | Planned. Version history needs `document_versions` (see feature note). |

## Conflicts to fix before coding

1. **Dean queue list shows full student name and term.** Privacy rule: show ID + form type in lists, name in detail.
2. **Student desktop "Current route" box** isn't tied to one request. Put the stepper inside each card.
3. **"Routed" pill uses the same soft green as "good".** Add icons; settle student vs staff status words (#12) first.
4. **"Ω DocuRoute" text logo is hidden**, a "DR monogram placeholder" is used. Decide the final logo.
5. **Walk-in frame drops type-specific fields.** Decide if Registrar still fills them after confirming type.

## Build order

1. Design tokens and layout shell (colors, fonts, sidebar, bottom tab bar, system theme).
2. Status words, pills and toasts.
3. Student flow: New request → AI result / AI unsure → Active requests → Detail.
4. Registrar master-detail with one-tap confirm (only ~11% of photos reach 70%).
5. Staff mobile queue and scan.
6. Dean, Treasury, Section Chief queues on one shared template.
7. Schema work: saved contact number, walk-in → `/classify`, decline reason.
8. Missing and planned screens: Login, Notifications, Admin, then signature, versions, station QR.
