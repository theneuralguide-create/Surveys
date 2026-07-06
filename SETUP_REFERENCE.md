# Survey Hub — Complete Setup Reference

**Date:** July 6, 2026  
**Status:** Live on Vercel + Supabase backend configured

---

## Quick Links

- **Live site:** https://surveys-tau-beryl.vercel.app/
- **Admin dashboard:** https://surveys-tau-beryl.vercel.app/admin.html
- **Survey directory:** https://surveys-tau-beryl.vercel.app/surveys.html
- **Local launcher:** Double-click `Start Survey Hub.command` in `Desktop/Surveys`
- **GitHub repo:** https://github.com/theneuralguide-create/Surveys
- **Supabase project:** supabase.com (Project ID: `zaftmandamqwxrxsibyk`)

---

## What You Have

A three-tier survey platform:

1. **Frontend** (HTML/CSS/JS, static)
   - Intro page (`index.html`)
   - Survey directory (`surveys.html`)
   - Admin dashboard (`admin.html`)
   - Individual surveys in `surveys/` folder
   - Shared styling (`hub.css`)

2. **Backend** (Supabase)
   - Tables: `surveys` (directory), `responses` (answers), `admin_config` (password)
   - Row-level security (RLS) enabled
   - Admin password: `your-strong-password` (you set this in Supabase)

3. **Deployment** (Vercel + GitHub)
   - Auto-deploys on every GitHub push
   - Free tier, permanent uptime
   - Lives at `https://surveys-tau-beryl.vercel.app/`

---

## Configuration

### Supabase Details

**File:** `config.js` in your Desktop/Surveys folder

```javascript
window.SURVEY_HUB_CONFIG = {
  url: 'https://zaftmandamqwxrxsibyk.supabase.co',
  anonKey: 'sb_publishable_mauZK5A_2i7sqxl5aB8xtQ_-XhIHJs7'
};
```

**Admin password:** Set in Supabase SQL Editor (run once during setup):
```sql
update admin_config set password = 'your-strong-password' where id = 1;
```

### GitHub Repo Structure

```
surveys/
├── index.html              (landing page)
├── surveys.html            (directory)
├── admin.html              (dashboard, no login needed in local mode)
├── hub.css                 (shared styles)
├── config.js               (Supabase credentials)
├── supabase-setup.sql      (database schema — already run)
├── Start Survey Hub.command (local launcher)
├── README.md               (setup instructions)
├── SETUP_REFERENCE.md      (this file)
└── surveys/
    └── decision-making-survey.html (your first survey)
```

---

## How It Works

### Landing Page (`index.html`)
- Hero section introducing the project
- Three feature cards
- CTA button linking to `/surveys.html`
- No backend needed

### Survey Directory (`surveys.html`)
- Reads list of live surveys from either:
  - **Local mode:** `localStorage` key `hub-surveys` (if no Supabase)
  - **Supabase mode:** `surveys` table where `status='live'`
- Displays cards for each survey
- Clicking a card links to the survey's HTML file

### Admin Dashboard (`admin.html`)
- **Local mode:** No login, reads/writes everything to this browser's localStorage
  - Responses: `response-*` keys
  - Survey list: `hub-surveys` key
- **Supabase mode:** Requires admin password (from `admin_config` table)
- Two tabs:
  - **Results:** View all responses, filter by survey, download CSV
  - **Manage surveys:** Add/edit/delete surveys from the directory

### Individual Survey (`surveys/decision-making-survey.html`)
- Two A/B variants (base vs. AI framing) — random 50/50 split
- Saves draft progress in local storage
- On completion:
  - Submits to Supabase (if configured)
  - Falls back to localStorage (if not)
  - Shows personalized results page with comparison to other respondents

---

## Common Tasks

### Edit the Landing Page

1. Open `index.html` on your computer in a text editor
2. Find the section you want to change (look for `<h1>`, `<p>`, etc.)
3. Make your edits
4. Save the file
5. **Upload to GitHub:**
   - Go to https://github.com/theneuralguide-create/Surveys
   - Click on `index.html`
   - Click the pencil icon (Edit)
   - Paste your changes
   - Click **Commit changes**
6. Vercel auto-deploys in ~1 minute

### Edit the Survey Directory

Same process as above, but edit `surveys.html`.

### Edit Survey Questions/Text

Edit `surveys/decision-making-survey.html` — look for the `CONTENT` object around line 256. The two variants are:
- `base` — non-AI framing ("Would you press the button?")
- `ai` — AI framing ("Would you deploy it?")

### Add a New Survey

1. Create your survey HTML file (can copy `surveys/decision-making-survey.html` as a template)
2. Change the `SURVEY_SLUG` near the top to a new slug (e.g., `risk-survey`)
3. Update the `CONTENT` object with your questions
4. Upload the HTML file to the `surveys/` folder on GitHub
5. Go to Admin dashboard → **Manage surveys** → **Add a survey**
   - Title: your survey name
   - Slug: `risk-survey` (must match the HTML file)
   - URL: `surveys/risk-survey.html`
   - Status: `live`
   - Est. minutes: e.g., `5-8`
6. Click **Add survey** — it appears on the directory immediately

### Download All Responses

1. Go to Admin dashboard → **Results** tab
2. Filter by survey (or keep "All")
3. Click **Download CSV (current view)**
4. You get a spreadsheet with all answers

### Delete a Response

1. Admin → Results
2. Find the row you want to delete
3. Click the **✕** button on the right
4. Confirm deletion

---

## Running Locally

**Command:** Double-click `Start Survey Hub.command`

This:
- Starts a local server on `http://localhost:8765/`
- Opens your browser automatically
- Works **only on your computer** (others can't access it)
- Responses saved to your browser's localStorage
- No Supabase needed (local mode)

To stop: Close the terminal window that appears.

---

## Deployment to Vercel

Already done! Your repo at https://github.com/theneuralguide-create/Surveys is connected to Vercel.

**How it works:**
1. You edit files on GitHub (via web editor or upload)
2. You push/commit the changes
3. Vercel auto-detects the change
4. Vercel redeploys in ~1 minute
5. Your live site updates at https://surveys-tau-beryl.vercel.app/

**No manual steps needed** — just edit and commit.

---

## Troubleshooting

### "Backend not configured" message in Admin

This means `config.js` is empty or invalid. Two options:
1. **Use local mode:** Just use the admin dashboard as-is (it works without backend)
2. **Connect Supabase:** Fill in the two lines in `config.js` with your Supabase URL and anon key

### Survey responses not showing up

1. Check that you ran `supabase-setup.sql` in Supabase (SQL Editor)
2. Check that `config.js` has the correct Supabase credentials
3. Try refreshing the admin dashboard (click **Refresh** button)
4. If still stuck, check Supabase dashboard → Data → `responses` table to see if data is there

### Can't edit files on GitHub

- Make sure you're logged into GitHub
- Make sure you have permission (you created the repo, so you do)
- Try clicking the pencil icon again
- Or use the "Upload files" button instead

### Live site shows 404 or old content

- Vercel cache can take 1-2 minutes to clear
- Try a hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
- Check that the files actually uploaded to GitHub (go to github.com/yourrepo and verify)

---

## Important Files to Know

| File | Purpose | Editable? |
|------|---------|-----------|
| `index.html` | Landing page | ✅ Yes |
| `surveys.html` | Directory | ✅ Yes (mostly) |
| `admin.html` | Dashboard | ⚠️ Advanced only |
| `hub.css` | All styling | ✅ Yes |
| `config.js` | Supabase credentials | ✅ Yes (2 lines only) |
| `surveys/*.html` | Individual surveys | ✅ Yes |
| `supabase-setup.sql` | Database schema | ❌ Don't edit (already run) |

---

## What's in the Supabase Database

### `surveys` table
Stores the directory of surveys.

```
id (uuid, auto)
slug (text, unique) — e.g., 'decision-making'
title (text) — e.g., 'Decision-Making Under Uncertainty'
description (text)
url (text) — e.g., 'surveys/decision-making-survey.html'
status (text) — 'live', 'draft', or 'closed'
est_minutes (text) — e.g., '5-8'
sort_order (int)
created_at (timestamp, auto)
```

### `responses` table
Stores every submitted response.

```
id (uuid, auto)
survey_slug (text) — which survey
variant (text) — e.g., 'ai' or 'base'
answers (jsonb) — all the answers as a JSON object
submitted_at (timestamp, auto)
```

### `admin_config` table
Stores the admin password (protected by RLS).

```
id (int, always 1)
password (text) — the admin password you set
```

---

## Share This Link

Share this with respondents:
```
https://surveys-tau-beryl.vercel.app/surveys.html
```

Or link to a specific survey:
```
https://surveys-tau-beryl.vercel.app/surveys/decision-making-survey.html
```

---

## Future Tasks

- [ ] Set a custom domain (costs ~$12/year for domain, Vercel handles the rest)
- [ ] Create more surveys by copying the template
- [ ] Monitor responses in the admin dashboard
- [ ] Export data as needed
- [ ] Adjust survey copy/questions based on feedback

---

**Last updated:** 2026-07-06  
**Maintained by:** Claude
