# DocuRoute Prototype — Warnings, Tutorials & Notes

*Running reference for working on `prototype/`. Setup steps live in `README.md`; this file is the "things that will bite you" and "how do I actually do X" companion. Update it as new gotchas turn up instead of losing track of them.*

---

## ⚠️ Warnings — things that will bite you if you don't know them

1. **Deleting and recreating a Supabase Auth user wipes their profile.** Changing a password should always be done via Supabase Dashboard → Authentication → Users → *reset/update password* on the existing user — never delete-then-recreate with the same email. Deleting cascades and removing the row, and a fresh signup re-fires the `handle_new_user()` trigger, which creates a brand-new blank profile (name defaults back to the raw email, student_no/program go empty). This already happened once to both student demo accounts and had to be manually re-fixed.
2. **Live QR camera scanning needs HTTPS.** `getUserMedia` (used by the mobile "Scan QR Label" tool) is blocked by browsers on a plain `file://` page. It only works once deployed to the Vercel HTTPS URL, opened on a real phone. Locally, the scan screen falls back to a manual tracking-ID text field — that's expected, not broken.
3. **Admin can't create or delete logins from the browser, on purpose.** Supabase's admin user-management API needs the `service_role` secret key, which must never ship to client-side code (it bypasses every RLS policy in the project). "+ Add Account" / "Delete" in Account Management intentionally show an explanatory alert instead of pretending to work. New logins are created via Supabase Dashboard → Authentication → Users for now; this becomes possible from the app itself once the Render admin service (see below) exists.
4. **Headless-browser screenshot testing has a hidden floor around ~500px width.** Verified directly: identical minimal HTML rendered perfectly at 550px and looked "cut off on the right" at 390px — using Edge's `--headless=new --screenshot` flag, not a real bug. If a layout looks broken in an automated screenshot under ~500px, retest at 550px+ (or on an actual phone) before concluding it's a real CSS bug.
5. **The git repo is scoped to `prototype/` only — never `git init` at the `DocuRoute` root.** That root also holds thesis drafts and `Forms/` (real uploaded student documents with personal information) that must never end up on GitHub.
6. **There were two `index.html` files; only one is real.** `prototype/index.html` is the live, Supabase-wired app. `prototype-v2-archived-unused/index.html` was a static Figma-fidelity mockup (client-side only, invented demo data) that was never connected to any backend — it's kept only for visual reference, not in git, not deployed. Always edit `prototype/index.html`.
7. **The AI classification is entirely fake right now.** Every confidence score is `Math.random()`. There is no real OCR, no real layout model, and no real image rectification (the "Rectifying image…" pipeline stage is a text label with a timer, not actual pixel processing). The 70%-confidence *gate logic* itself is real and correctly tested — it's just fed a random number instead of a trained model's output. Don't describe this pipeline as "AI" to anyone evaluating functional suitability without this caveat.
8. **Free-tier Supabase projects pause after ~1 week of no API activity.** If the app suddenly can't reach the backend after a break, check the Supabase dashboard for a paused project first before assuming something broke.
9. **Staff/Admin demo passwords are shorter than the public signup policy allows.** `staff`/`admin` (5 chars each) work because they were set via the Dashboard's admin-privileged flow, which bypasses the public password-length minimum. A real self-service signup on the login page would reject anything under 6 characters — don't be surprised if a *new* short password rejected there works fine when set from the Dashboard instead.
10. **`git` isn't on PATH in every shell.** It installed to `C:\Users\09002214\AppData\Local\Programs\Git\bin\git.exe` — a shell opened before install won't see it as a bare `git` command. Open a new terminal, or use the full path.
11. **A staff account with no `office` set sees "No Office Assigned," not an error.** Since RLS now scopes every staff query by `profiles.office`, a staff row created without one (e.g. via "+ Add Account"'s Dashboard-then-edit-here flow) can log in fine but sees nothing — that's `unassignedOfficeView()` working as intended, not a bug. Fix it in Account Management by setting the Office field, or directly via `update public.profiles set office='Registrar' where email='...'` in SQL Editor.
12. **Office scoping is enforced at the RLS level, not just the queue filter.** A Treasury account's `select` on `requests` genuinely returns zero rows for a Prerequisite Waiver or Section Adjustment — Treasury never appears in either route. If a queue looks emptier than expected while testing, check you're logged in as the right office before assuming something's broken.
13. **Multiple open tabs need Realtime enabled to see each other's changes.** `index.html` subscribes to Postgres changes on `requests`/`request_logs` (`subscribeRealtime()`) so every open tab/account updates within a second of another one's action, instead of needing a manual reload. This only works once both tables are added to Supabase's `supabase_realtime` publication — run `supabase/migration-004-realtime.sql` once on an existing project (fresh installs already get this from `schema.sql`). There's also a self-healing sweep (`recoverStuckSubmissions()`) for a request that gets permanently stuck showing "Currently at: AI Processing Layer" — that happens if a tab is closed/reloaded mid-classification, since nothing else would ever finish it. Only a student's own account or Admin can trigger this (RLS hides an unclassified request, `route=[]`, from every staff office anyway), and it only fires after ~8 seconds so it never fights the real pipeline animation.

## 📘 Tutorials — how to actually do things

### Get the project running from scratch
1. Follow `README.md`'s "One-time Supabase setup" (create project → run `supabase/schema.sql` → disable email confirmation → create the 4 demo users → run their profile `UPDATE`s → paste URL/anon key into `supabase-config.js`).
2. Open `prototype/index.html` directly in a browser (double-click, `file://` is fine) and log in with a demo account from the table below.

### Make a change and ship it (GitHub + Vercel)
```
cd "C:\Users\09002214\Downloads\DocuRoute\prototype"
git pull
# ...edit files...
git add .
git commit -m "describe the change"
git push
```
If the repo is already imported into Vercel, that's it — Vercel redeploys automatically within a minute or two of the push. No separate action needed on vercel.com.

### Test the mobile view on a desktop browser
Just shrink the browser window below 680px wide — the app switches to the dark, badge-marked mobile layout automatically (no toggle, no separate URL). For genuine phone-camera features (QR scanning), you need either a real phone hitting the deployed HTTPS URL, or Chrome/Edge DevTools' device-toolbar + a fake camera flag — a plain narrow desktop window can't grant camera access convincingly.

### Check what a role actually sees, quickly
Log out and back in as a different demo account (table below) rather than trying to simulate roles — RLS means the data returned genuinely differs per login, it isn't just a UI filter.

### Reset the demo data
Log in as Admin → System Overview → "↺ Reset demo database". This wipes and reseeds the four demo requests via the same Postgres functions real submissions use (`next_request_id`, `reset_request_seq`); it does not touch accounts.

## 📝 Notes to keep in mind

**Demo accounts (current, verified working):**

| Role | Email | Password |
|---|---|---|
| Student | `apvsanpedro@mymail.mapua.edu.ph` | `aaron` |
| Student | `mefvocal@mymail.mapua.edu.ph` | `mike` |
| Registrar Clerk | `registrar@mymail.mapua.edu.ph` | `registrar` |
| Treasury Personnel | `treasury@mymail.mapua.edu.ph` | `treasury` |
| Section Chief | `prof@mymail.mapua.edu.ph` | `profff` |
| Dean | `dean@mymail.mapua.edu.ph` | `deanss` |
| Admin | `admin@mymail.mapua.edu.ph` | `admin` |

The old single `staff@mymail.mapua.edu.ph` account was renamed to `registrar@...` in place (edited in the Supabase Dashboard, never deleted-and-recreated — see warning #1) when the single shared "Staff" role was split into four office-scoped accounts.

**Thesis feature status (Section 1.3's 6 core features — not 8; the "8" elsewhere is ISO/IEC 25010's evaluation characteristics, a separate list):**

| Feature | Status |
|---|---|
| Dynamic QR Traceability | Mostly real — QR generation + live camera QR scanning work; no live push alert to students yet |
| Digital-twin archiving | Real — Supabase Storage upload/RLS/signed URLs, load-tested |
| Role-based workflow automation | Real — Auth + RLS + routing table + confirm/advance/decline, most thoroughly tested |
| Layout-aware AI classification | Simulated only — `Math.random()`, no OCR/model |
| Document image rectification | Simulated only — cosmetic label, no image processing |
| Confidence-based human review (70% gate) | Real logic, fed a fake confidence number |

**What's deferred to a future Render-hosted backend** (the two things Supabase's client SDK structurally cannot do from a browser):
1. Privileged admin actions (create/delete a login) — needs the `service_role` key held server-side.
2. The real AI Processing Layer (OpenCV rectification + Tesseract OCR + a trained classifier) — real Python, can't run client-side.

**Key file locations:**
- App: `prototype/index.html`
- DB schema + RLS policies (fresh-install reference): `prototype/supabase/schema.sql`
- Migration for an already-existing project: `prototype/supabase/migration-002-office-scoping.sql`
- Supabase credentials: `prototype/supabase-config.js`
- Legacy (unused) local backend: `prototype/server/` — kept for reference only
