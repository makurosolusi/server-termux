// The apps PM2 runs on this phone. Add site('<name>') for a site you wrote yourself.
// Sites created by Panel Termux are in apps.json and loaded automatically by the panelApps block below.
// Source: PLAN/03 §7.2, same as files/sites/ecosystem.config.js in the server-termux repo.
const SITES = "/data/data/com.termux/files/home/sites";
const PREFIX = "/data/data/com.termux/files/usr";

// The glibc Bun binary runs through grun; the binary reads the .env in the site folder at start.
// biome-ignore lint/correctness/noUnusedVariables: used once the owner uncomments site('<name>') below.
const site = (name) => ({
  name,
  cwd: `${SITES}/${name}`,
  script: `${PREFIX}/bin/grun`,
  args: "./app",
  interpreter: "none",
  exp_backoff_restart_delay: 1000,
});

// Panel Termux: sites created by the panel are listed in apps.json (managed by the panel, do not edit by hand).
// Safe when apps.json is missing, empty or broken; entries whose binary does not exist yet are skipped,
// because one missing script makes pm2-runtime stop every app.
const panelApps = (() => {
  try {
    const fs = require("fs");
    const path = require("path");
    const list = require("./apps.json");
    return Array.isArray(list)
      ? list.filter(
          (a) => a && typeof a.name === "string" && fs.existsSync(path.resolve(a.cwd || __dirname, a.script || "")),
        )
      : [];
  } catch (e) {
    console.error(`[ecosystem] apps.json skipped: ${e.message}`);
    return [];
  }
})();

// pm2-runtime exits when the ecosystem has no app at start, even with --no-auto-exit.
// This keeper (sleep, ~1 MB) keeps it alive on a phone with no sites yet. Do not delete it.
const guard = {
  name: "pm2-guard",
  script: `${PREFIX}/bin/sleep`,
  args: "infinity",
  interpreter: "none",
  autorestart: true,
};

module.exports = {
  apps: [
    guard,
    // site('blog'),
    ...panelApps,
  ],
};
