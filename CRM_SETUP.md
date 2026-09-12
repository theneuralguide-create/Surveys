# Network — personal CRM setup

A private, installable phone app for tracking who you've spoken to, what they
need, and who to follow up with. Lives at `crm.html` on the same site as the
surveys but is not linked from anywhere, and is password-gated.

Data lives in a free **Neon** Postgres database. The page talks to one
Vercel serverless function, `api/crm.js`, which talks to Neon. Nothing else.

## 1. Create the database (once)

1. Create a free project at [neon.tech](https://neon.tech) (or let Claude do
   it through the Neon connector).
2. Neon console → **SQL Editor** → paste the whole of `crm-setup.sql` → **Run**.
   Safe to re-run.
3. Set your password. In the same editor run (with your own password):

   ```sql
   update crm.config
      set password_hash = crypt('your-long-random-password', gen_salt('bf'))
    where id = 1;
   ```

   **This password is the only thing between the open internet and your
   contacts' details.** Make it long and random (a password manager
   passphrase, 20+ characters), and do not reuse the survey admin password.
   It is stored bcrypt-hashed; nobody, including Neon, can read it back.

## 2. Give Vercel the connection string (once)

1. Neon console → your project → **Connect** → copy the connection string
   (it starts `postgresql://…` and ends `?sslmode=require`).
2. Vercel → your project → **Settings → Environment Variables** → add
   `DATABASE_URL` = that string, for Production (and Preview). Save.
3. Push to GitHub; Vercel deploys automatically and picks up `api/crm.js`.
   The app is then at `https://<your-site>/crm.html`. Nothing links to it.

The connection string is a secret: it never goes in the repo or the page.

## 3. Put it on your phone

**iPhone (Safari)**
1. Open `https://<your-site>/crm.html` in Safari — it has to be Safari, not Chrome.
2. Tap the **Share** button (square with an arrow).
3. Scroll and tap **Add to Home Screen**, then **Add**.
4. Open it from the home screen. It launches full-screen, with no browser
   bar, and stays signed in for 30 days.

**Android (Chrome)**
1. Open the URL in Chrome.
2. Menu (⋮) → **Add to Home screen** / **Install app**.

It works on your laptop at the same URL, sharing the same data.

## How it fits together

| File | What it is |
|---|---|
| `crm-setup.sql` | Database schema, security, and the functions the app calls |
| `api/crm.js` | The one serverless function: forwards `{ fn, args }` to those Postgres functions |
| `package.json` | Pulls in the Neon driver for `api/crm.js` |
| `crm.html` | The whole app |
| `crm.css` | Its styles (on top of `hub.css`) |
| `crm-sw.js` | Service worker: caches the app shell so it opens instantly and survives a bad signal |
| `manifest.webmanifest` | Tells the phone this is an installable app |
| `icons/crm-*.png` | Home-screen icons |

## Security model (why this is different from the surveys)

Survey responses are anonymous and deliberately public. The CRM holds real
people's names, numbers and private notes, so:

- The database is reachable only from `api/crm.js` running on Vercel, using
  the `DATABASE_URL` secret. There is no public key in the page at all.
- `api/crm.js` can only call the `crm_*` functions it lists; each one checks
  a session token first. `crm_login` hands out a token in exchange for the
  password; the phone stores only the token, never the password.
- Sessions expire after 30 days. Eight wrong passwords in 15 minutes locks
  logins for 15 minutes.
- To sign every device out at once, run `delete from crm.sessions;` in the
  Neon SQL editor. To change the password, re-run the `update crm.config …`
  statement above.

## Backups

Today screen → **⋯** → *Full backup (JSON)*, or CSV of people / conversations.
On the phone this opens the share sheet (save to Files, AirDrop, email it).

## Adding a field later

Add the column in `crm-setup.sql` (`alter table crm.contacts add column …`),
add it to the `insert`/`update` lists in `crm_save_contact` (or
`crm_save_interaction`), then add the input to the matching form in
`crm.html` and include it in `saveContact()` / `readLogForm()`. Bump
`CACHE_VERSION` in `crm-sw.js` so phones pick up the new page immediately.
