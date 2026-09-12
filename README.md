# Research Surveys — Survey Hub

A centralised website for all your surveys: a public intro page, a survey
directory, and a password-gated admin dashboard where you can register new
surveys and see every response collected across all of them.

## What's here

| File | Purpose |
|---|---|
| `index.html` | Intro page — introduces the project and links to the surveys |
| `surveys.html` | Public survey directory (loads the list from the backend) |
| `admin.html` | Admin dashboard — manage surveys, browse/export all responses |
| `surveys/decision-making-survey.html` | Your first survey, wired to the backend |
| `config.js` | Where your Supabase URL + anon key go |
| `supabase-setup.sql` | One-time database setup script |
| `hub.css` | Shared styles for the hub pages |

Everything is plain HTML/CSS/JS — no build step.

## Running it on your own computer (no setup)

Double-click **`Start Survey Hub.command`**. It opens the site in your
browser at `http://localhost:8765/` — keep the little terminal window open
in the background while you use it.

In this "local mode" everything works on your machine: take surveys, add or
edit surveys in the admin dashboard (no password needed — it's your own
computer), and see every response you've submitted in this browser, with CSV
export. The only limitation: responses from *other people's* devices can't
reach you until you connect the backend below. Nothing needs undoing later —
fill in `config.js` whenever you're ready and the site switches over
automatically.

## Optional: shared backend (~5 minutes, for collecting others' responses)

1. **Create a Supabase project** — free at [supabase.com](https://supabase.com)
   (sign in, "New project", any name/region, wait ~1 min for it to provision).
2. **Run the setup script** — in your project, open **SQL Editor**, paste the
   entire contents of `supabase-setup.sql`, and click **Run**.
3. **Set your admin password** — in the same SQL Editor, run
   (replacing with a password of your choosing):
   ```sql
   update admin_config set password = 'your-strong-password' where id = 1;
   ```
4. **Connect the site** — go to **Project Settings → API**, copy the
   **Project URL** and the **anon / public key**, and paste both into
   `config.js`.

That's it. Responses from any device now flow into your database, and
`admin.html` shows them all.

## Putting it online

The site is static, so any static host works. Two easy options:

- **Netlify Drop** — go to [app.netlify.com/drop](https://app.netlify.com/drop)
  and drag this whole folder onto the page. Done — you get a public URL.
- **GitHub Pages** — push this folder to a GitHub repo, then enable Pages in
  the repo settings.

Share `https://your-site/…/surveys.html` (or a direct survey link) with
respondents.

## Adding a new survey later

1. Create the survey as an HTML file and drop it into the `surveys/` folder
   (redeploy/re-upload the site so the file is live).
2. Open `admin.html` → **Manage surveys** → fill in the *Add a survey* form
   (title, a short slug like `my-new-survey`, the URL
   `surveys/my-new-survey.html`) → **Add survey**. It appears on the public
   directory immediately.
3. To make the new survey *save* responses to the backend, give it the same
   small submit snippet used in `surveys/decision-making-survey.html` — look
   for the `Hub backend` block (`SURVEY_SLUG`, `hubSubmit`, `hubLoadResponses`)
   and use the new survey's slug. (Or just ask Claude to wire it up.)

A survey set to **draft** or **closed** in the admin panel disappears from
the public directory but keeps its data.

## Notes on privacy & security

- Responses are anonymous — no names, emails, or IPs are stored.
- The Supabase **anon key** in `config.js` is public by design (it's how
  browsers talk to the database); row-level security limits what it can do.
- As set up, raw anonymous responses are **publicly readable** — this powers
  the live "how you compare" section at the end of each survey. If you'd
  rather lock the raw data down, delete the `public read responses` policy
  in Supabase (the survey then compares against its built-in reference
  sample instead, and you still see everything via the admin dashboard).
- The admin password gates all management actions and is checked
  server-side; it is never stored in the site's code.
- The old in-survey admin view still exists at
  `surveys/decision-making-survey.html#admin` (code `results2026`) and now
  shows pooled backend data too.

## Network — personal CRM (private, phone-installable)

`crm.html` is a second, unlisted app on the same site: a personal CRM for
tracking who you've spoken to, their contact details and work area, every
conversation (takeaways, their call to action, the problem you might solve),
and a follow-up queue that surfaces who's overdue and who's going cold.

It is password-gated and not linked from any page. Its data lives in a free
Neon Postgres database that only `api/crm.js` (a Vercel serverless function)
can reach — no public key anywhere. Setup, the security model, and how to
install it on a phone are in **[CRM_SETUP.md](CRM_SETUP.md)**.

| File | Purpose |
|---|---|
| `crm.html`, `crm.css` | The app |
| `crm-setup.sql` | Database schema + password-checked functions (run once in Neon) |
| `api/crm.js`, `package.json` | The serverless function and its one dependency |
| `crm-sw.js`, `manifest.webmanifest`, `icons/` | What makes it installable on a phone |
