# Survey Hub Project — Conversation Summary

**Date:** July 6, 2026  
**User:** Zac (Lovatzac50@gmail.com)  
**Project:** Centralised research survey platform

---

## What Was Built

A complete survey platform with:
- **Public landing page** introducing the research project
- **Survey directory** showing all available surveys
- **Admin dashboard** for managing surveys and viewing responses
- **Backend database** (Supabase) for collecting responses from multiple respondents
- **Live deployment** on Vercel (auto-deploys on GitHub changes)
- **Local mode** for testing on your own computer without internet

---

## The Journey

### Part 1: Initial Request
User wanted a centralised website to:
- Host all surveys they create over time
- Provide access to response data via an admin dashboard
- Maintain a clean aesthetic matching their existing survey

### Part 2: Architecture Decision
Asked user how to handle data collection. User chose:
- **Backend:** Supabase (free, hosted database)
- **Admin security:** Password gate (simple, sufficient)
- Later changed to: **Local-first mode** for immediate testing, with Supabase as optional backend

### Part 3: Built the Hub Site
Created:
- `index.html` — intro/landing page ("How Do We Think and Decide?")
- `surveys.html` — public survey directory (reads from database or local storage)
- `admin.html` — dashboard for results + survey management (no login in local mode)
- `hub.css` — shared design system (matches the survey's blue palette, fonts, panel style)
- `config.js` — placeholder for Supabase credentials
- `supabase-setup.sql` — one-time database schema setup
- `Start Survey Hub.command` — double-clickable launcher for local testing

Integrated the existing decision-making survey by:
- Adding Supabase backend hooks (hubSubmit, hubLoadResponses)
- Styling a "back to hub" link
- Tagging responses with their survey slug
- Adding responsive fixes for short viewports (Mac laptops)
- Rewriting two survey questions for clarity

### Part 4: Responsive Design Fix
User reported the landing page didn't fit well on Mac (wide, short viewport). Added media queries at three breakpoints (max-height: 900px, 740px, 560px) to compress the hero proportionally on short screens while leaving phone layouts untouched.

### Part 5: Question Rewording
Updated two key survey questions in both AI and non-AI variants:
- "At what probability..." → "If the 10% was changeable to whatever you'd like, at what probability..."
- "What is the highest..." → "Since you're okay with 10%, what is the highest..."
Added context to make the follow-up questions feel more natural.

### Part 6: Supabase Setup
1. User created free Supabase account
2. Created new project (`zaftmandamqwxrxsibyk` in eu-west-1)
3. Ran SQL setup script (created tables: surveys, responses, admin_config + RLS)
4. Set admin password
5. Retrieved Project URL and anon API key
6. Filled in `config.js`

### Part 7: Vercel Deployment
1. Created GitHub account (theneuralguide-create)
2. Created GitHub repo `surveys`
3. Uploaded all files from Desktop/Surveys to GitHub
4. Connected Vercel to GitHub
5. Deployed to Vercel (auto-deploys on every GitHub push)
6. **Live site:** https://surveys-tau-beryl.vercel.app/

### Part 8: GitHub CLI Setup (In Progress)
Started installing GitHub CLI via Homebrew so Claude can directly push changes without manual uploads. User is at password entry step.

---

## Current Status

| Component | Status | Details |
|-----------|--------|---------|
| Landing page | ✅ Live | https://surveys-tau-beryl.vercel.app/ |
| Survey directory | ✅ Live | https://surveys-tau-beryl.vercel.app/surveys.html |
| Admin dashboard | ✅ Live | https://surveys-tau-beryl.vercel.app/admin.html (no login needed) |
| Decision-making survey | ✅ Live | https://surveys-tau-beryl.vercel.app/surveys/decision-making-survey.html |
| Supabase backend | ✅ Configured | Tables created, credentials in config.js |
| Local testing | ✅ Ready | Double-click `Start Survey Hub.command` |
| GitHub integration | ✅ Done | gh CLI authenticated; Desktop/Surveys is a git repo, Claude pushes directly |

---

## File Structure

```
Desktop/Surveys/
├── index.html                         (landing page)
├── surveys.html                       (survey directory)
├── admin.html                         (admin dashboard)
├── hub.css                            (shared styles)
├── config.js                          (Supabase URL + anon key)
├── supabase-setup.sql                 (database schema — already run)
├── Start Survey Hub.command           (local launcher)
├── README.md                          (setup instructions)
├── SETUP_REFERENCE.md                 (technical reference)
├── CONVERSATION_SUMMARY.md            (this file)
└── surveys/
    └── decision-making-survey.html    (your first survey)
```

---

## Key Configuration

### Supabase
- **Project ID:** zaftmandamqwxrxsibyk
- **Region:** eu-west-1
- **URL:** https://zaftmandamqwxrxsibyk.supabase.co
- **Anon key:** sb_publishable_mauZK5A_2i7sqxl5aB8xtQ_-XhIHJs7
- **Admin password:** (user set during setup)

### GitHub
- **Repo:** https://github.com/theneuralguide-create/Surveys
- **User:** theneuralguide-create

### Vercel
- **Live URL:** https://surveys-tau-beryl.vercel.app/
- **Auto-deploys:** on every GitHub push (1-2 min lag)

---

## How It Works

1. **User visits the site** → lands on intro page
2. **Clicks "Explore surveys"** → sees survey directory (reads from Supabase or localStorage)
3. **Takes a survey** → answers saved to Supabase + shown results comparison
4. **Admin views results** → goes to /admin.html, sees all responses in a table, can filter, download CSV
5. **Admin adds new survey** → fills form in dashboard, survey appears in directory immediately
6. **Any changes made** → pushed to GitHub, Vercel auto-deploys in ~1 minute

---

## What's Left to Do

### Immediate (if GitHub CLI completes)
- [ ] Finish GitHub CLI setup (`gh auth login`)
- [ ] Test that Claude can push changes directly

### If survey URL is still 404
- [ ] Check that `surveys/` folder was uploaded to GitHub
- [ ] Re-upload the `surveys/` folder if missing

### Optional / Future
- [ ] Add more surveys (copy decision-making-survey.html as template)
- [ ] Customize survey questions/content
- [ ] Monitor response data in admin dashboard
- [ ] Export responses as CSV
- [ ] Set up custom domain (costs ~$12/year)
- [ ] A/B test different survey variants

---

## How to Use This in a New Chat

1. Copy the full contents of this file
2. Go to a new Claude chat
3. Paste it at the top
4. Also paste `SETUP_REFERENCE.md` for technical details
5. Ask Claude to help with whatever you need (edit pages, add surveys, etc.)

Claude will have full context and can either:
- Walk you through manual steps
- Direct-push changes via GitHub CLI (once setup completes)

---

## Important Notes

- **Local mode works without Supabase** — responses saved to browser's localStorage
- **Vercel auto-deploys** — no manual deployment needed after GitHub push
- **Admin dashboard has no login in local mode** — use password only if you connect Supabase
- **Responses are anonymous** — no emails, names, or tracking
- **Survey variants (base vs. AI)** — randomly assigned 50/50, collected separately for comparison

---

## Quick Links Summary

| Thing | Link |
|-------|------|
| Live site | https://surveys-tau-beryl.vercel.app/ |
| Admin dashboard | https://surveys-tau-beryl.vercel.app/admin.html |
| Survey directory | https://surveys-tau-beryl.vercel.app/surveys.html |
| Decision-making survey | https://surveys-tau-beryl.vercel.app/surveys/decision-making-survey.html |
| GitHub repo | https://github.com/theneuralguide-create/Surveys |
| Supabase project | https://app.supabase.com (Project ID: zaftmandamqwxrxsibyk) |
| Share this with respondents | https://surveys-tau-beryl.vercel.app/surveys.html |

---

**Status:** Ready for use. Fully operational — Claude pushes changes directly via git from Desktop/Surveys.
