# DocuRoute Prototype

A click-through wireframe of the DocuRoute workflow (Chapter 3, Sections 3.8 & 3.10), restyled to match the `Design V2` Figma exports (cream background, serif headings, sidebar navigation, green/amber/red status system, route stepper, and now the `Login.png` auth screen). It's a static page (`index.html`) backed by **Supabase** (Postgres + Auth + Storage, free tier) instead of browser `localStorage` or the old local-only PowerShell server — so it's genuinely multi-user: any browser, on any machine, pointed at the same Supabase project sees the same shared data. The "AI classification" is still a randomized confidence score, not an actual model.

> The previous local-only backend (`server/server.ps1` + `server/db.json`) is kept in this folder for reference but is no longer used by `index.html`. It only ever worked for one machine at a time, which is exactly the limitation Supabase replaces.

> **Which `index.html` is which:** the file this README describes is `prototype/index.html` — the one wired to Supabase, with real login, RLS, and file uploads. There used to be a second, unrelated `index.html` at `prototype-v2/`, a static Figma-fidelity mockup (client-side only, `localStorage`, no backend, invented demo data) that was never connected to any of this. It's been renamed to `prototype-v2-archived-unused/` so it can't be confused with the live one, and it isn't referenced by anything below. Say the word if you'd like it deleted outright instead of just archived.

## One-time Supabase setup

1. Create a free project at [supabase.com](https://supabase.com) (no credit card required on the free tier).
2. **SQL Editor → New query** → paste the entire contents of `prototype/supabase/schema.sql` → Run. This creates the `profiles`/`requests`/`request_logs` tables, all Row Level Security policies, the `documents` storage bucket, and two helper functions (`next_request_id`, `reset_request_seq`).
3. **Authentication → Providers → Email** → turn **off** "Confirm email" (this prototype has no mail server wired up to click confirmation links; leaving it on means nobody can log in right after being created).
4. **Authentication → Users → Add user** → create the three demo accounts below (email + password only — profiles are created automatically by a database trigger).
5. Back in **SQL Editor**, run the three commented `update public.profiles ...` statements at the bottom of `schema.sql` (uncomment them first) to set each demo account's role, display name, student number, and program.
6. **Project Settings → API** → copy the **Project URL** and the **anon public key**.
7. Open `prototype/supabase-config.js` and paste them in:
   ```js
   const SUPABASE_URL = "https://xxxx.supabase.co";
   const SUPABASE_ANON_KEY = "eyJ...";
   ```
8. Open `prototype/index.html` in a browser (double-click / `file://` is fine) and log in. If the config is still showing placeholder values, the page shows a card explaining exactly what to fill in instead of failing silently.

## Logging in

Every viewer sees only their own role's pages — there's no portal switcher, just a login screen matching `Figma/Design V2/Login.png` (logo mark, **School Email Address**, **Password**):

| Role | Email | Password | Pages |
|---|---|---|---|
| Student | `apvsanpedro@mymail.mapua.edu.ph` | `aaron` | Active Requests, Notifications |
| Student | `mefvocal@mymail.mapua.edu.ph` | `mike` | Active Requests, Notifications |
| Registrar Clerk | `registrar@mymail.mapua.edu.ph` | `registrar` | Registrar Queue |
| Treasury Personnel | `treasury@mymail.mapua.edu.ph` | `treasury` | Treasury Queue |
| Section Chief | `prof@mymail.mapua.edu.ph` | `prof` | Section Chief Review |
| Dean | `dean@mymail.mapua.edu.ph` | `deanss` | Dean's Decision |
| Admin | `admin@mymail.mapua.edu.ph` | `admin` | System Overview, Account Management |

(Passwords are just what you chose in step 4 above — these are only suggestions to match the login card's hint text.) The Student account only ever sees its own requests, enforced at the database level by a Row Level Security policy (`student_id = auth.uid()`), not just hidden in the UI. Each Staff account is likewise scoped to exactly one office via its profile's `office` field — a Treasury account's query for a Section Adjustment request returns nothing, the same way a student's query for another student's request returns nothing. This replaces the earlier single shared "Staff" login that collapsed all offices into one account; see `supabase/migration-002-office-scoping.sql` if you're upgrading an existing project.

**Account Management (Admin)** can edit an existing account's role/office/name/student no./program — that's a plain, RLS-guarded table update and works today. It **cannot** create or delete a login from the browser: Supabase's admin user-management API requires the `service_role` secret key, which must never be shipped to client-side code (it bypasses every RLS policy in the project). For now, new logins are created in the Supabase dashboard (step 4 above); a small privileged backend to do this from the Admin page itself is the natural next step — see "About Render" below.

## What it demonstrates

- **Student** — submit a request by describing what's needed (no document-type dropdown — declaring your own type up front would defeat the point of the AI Processing Layer figuring it out), attach a photographed/scanned copy of the form (stored in Supabase Storage — this *is* Digital-Twin Archiving, Section 1.3), watch the simulated AI pipeline run, track status + scan the generated QR code, and see status changes on a separate Notifications page.
- **Registrar Clerk** — Registrar Queue: confirm-and-route anything the AI flagged "Unverified" (<70% confidence), then approve/decline/clear anything currently at the Registrar step (every route ends at Registrar). Registrar is also the only one who captures a walk-in's paper form (mobile "Photograph Physical Form"), and does so by picking **which office it should go to** (Dean's Office / Section Chief / Treasury) rather than naming a document type — the two are equivalent (each office is the first stop of exactly one route) but frame the decision the way Registrar actually makes it.
- **Treasury Personnel** — Treasury Queue: approve/decline/clear a Student Clearance request currently at the Treasury step (first stop on that route).
- **Section Chief** — Section Chief Review: consent to (or decline) a Section Adjustment request for their section before it proceeds to Registrar — a new office queue that didn't exist in the earlier single-Staff-role version.
- **Dean** — Dean's Decision: inspect paper, apply a digital signature, and approve/decline/clear anything currently at the Dean's Office step, advancing multi-office requests (e.g. Clearance: Treasury → Dean's Office → Registrar) automatically. Any request with an attached scan shows a **View attached form** button in its detail dialog (opens a short-lived signed URL against the private bucket).
- **Admin** — live stats (auto-routed vs. flagged, avg. confidence, completed), a read-only RBAC reference table, a demo-data reset button (re-seeds the four demo requests via the same Postgres functions as real submissions), and account editing (role/office/name/student no./program).

## Deploy to Vercel

Because the backend is now Supabase (a real hosted service, not `localhost`), `index.html` deploys as a genuinely working public page — no "run this on your own machine first" caveat like the old PowerShell server had.

**Using Option B — GitHub + Vercel dashboard** (chosen so the project can be `git clone`d on any machine — monitor PC and laptop both stay in sync, unlike copying files by hand):

1. **Install Git for Windows** if you haven't: [git-scm.com/download/win](https://git-scm.com/download/win) (defaults are fine).
2. Turn this `prototype` folder into its own git repo — **only this folder**, not the whole `DocuRoute` directory, since that also holds thesis drafts and the `Forms/` folder of real uploaded student documents that must never end up on GitHub:
   ```
   cd "C:\Users\09002214\Downloads\DocuRoute\prototype"
   git init
   git add .
   git commit -m "Initial commit: DocuRoute prototype (Supabase-backed)"
   ```
3. Create a new repo on [github.com/new](https://github.com/new) (private is fine — recommended, even though `supabase-config.js`'s anon key is safe by design under RLS, there's no reason to make it public). Don't initialize it with a README/`.gitignore` — you already have one.
4. Connect and push:
   ```
   git remote add origin https://github.com/<your-username>/<repo-name>.git
   git branch -M main
   git push -u origin main
   ```
5. On [vercel.com](https://vercel.com) → **Add New Project** → import that repo → Framework preset: **Other**, Build command: none, Output directory: `/` (root) → Deploy.
6. On your laptop, `git clone https://github.com/AaronRonnie/docuroute-prototype.git` to get the exact same project — no manual file transfer needed. From either machine, `git pull` before you start working and `git add . && git commit -m "..." && git push` when you're done, and Vercel redeploys automatically on every push to `main`.

**Option A — CLI (fastest, but doesn't give you a repo to clone):**
```
npm i -g vercel
cd "C:\Users\09002214\Downloads\DocuRoute\prototype"
vercel
```
Accept the defaults (no framework / "Other") — it's a static folder, Vercel needs no config for it. Follow the printed URL, and redeploy any time with `vercel --prod`.

`supabase-config.js` ships the anon key to the browser on purpose either way — that's how Supabase is meant to be used; every table it touches is still gated by the RLS policies in `schema.sql`.

## About Render (next step)

Two things in DocuRoute's design still need a real server process, not just Supabase's client SDK, because they require secrets or Python that can't live in the browser:

1. **Privileged admin actions** — creating or deleting a login (needs the Supabase `service_role` key, held server-side only).
2. **The actual AI Processing Layer** (Section 3.10) — image rectification (OpenCV) + OCR (Tesseract) + layout-aware classification, replacing today's `Math.random()` confidence score.

Render's free tier (a web service that sleeps after ~15 minutes idle, 750 free hours/month) is a solid fit for both: a small FastAPI service holding the service-role key for admin operations, and/or the Python AI microservice from Section 3.11's tools table, called from this page after a document lands in Supabase Storage. Supabase stays the database either way — Render would just run stateless code in front of it.

Install Coding Agent Plugin


Turn your coding agent into a Vercel expert. Simply copy and run this in your terminal to install the plugin. Available for Claude, Cursor and Codex.

npx plugins add vercel/vercel-plugin