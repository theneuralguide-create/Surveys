// Personal CRM — the only server-side code.
//
// The app POSTs { fn, args } here; this calls the matching Postgres function
// (defined in crm-setup.sql) and returns its result. Every function checks
// the session token itself, so this file is deliberately dumb: it maps names
// to parameter lists and forwards. The database is reachable only via
// DATABASE_URL, a secret that lives in Vercel, never in the page.
const { neon } = require('@neondatabase/serverless');

// fn -> [[argName, pgType], ...]  Anything not listed here cannot be called.
const FUNCTIONS = {
  crm_login:              [['pw', 'text']],
  crm_logout:             [['tok', 'text']],
  crm_dashboard:          [['tok', 'text']],
  crm_list_contacts:      [['tok', 'text'], ['q', 'text'], ['tag', 'text']],
  crm_get_contact:        [['tok', 'text'], ['p_id', 'uuid']],
  crm_save_contact:       [['tok', 'text'], ['payload', 'jsonb']],
  crm_delete_contact:     [['tok', 'text'], ['p_id', 'uuid']],
  crm_save_interaction:   [['tok', 'text'], ['payload', 'jsonb']],
  crm_complete_step:      [['tok', 'text'], ['p_id', 'uuid'], ['p_done', 'boolean']],
  crm_delete_interaction: [['tok', 'text'], ['p_id', 'uuid']],
  crm_export:             [['tok', 'text']]
};

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') return res.status(405).json({ message: 'POST only' });
  if (!process.env.DATABASE_URL) return res.status(500).json({ message: 'DATABASE_URL is not set on the server' });

  const body = typeof req.body === 'string' ? safeJson(req.body) : (req.body || {});
  const spec = FUNCTIONS[body.fn];
  if (!spec) return res.status(404).json({ message: 'unknown function' });
  const args = body.args || {};

  const placeholders = spec.map(([name, type], i) => `${name} => $${i + 1}::${type}`).join(', ');
  const values = spec.map(([name, type]) => {
    const v = args[name];
    if (v === undefined || v === '') return null;
    return type === 'jsonb' ? JSON.stringify(v) : v;
  });

  try {
    const sql = neon(process.env.DATABASE_URL);
    const rows = await sql.query(`select public.${body.fn}(${placeholders}) as result`, values);
    return res.status(200).json(rows[0] ? rows[0].result : null);
  } catch (e) {
    // Postgres "raise exception" messages come through here (e.g. 'not signed in').
    return res.status(400).json({ message: String(e.message || e).replace(/^error: /i, '') });
  }
};

function safeJson(s) { try { return JSON.parse(s); } catch (e) { return {}; } }
