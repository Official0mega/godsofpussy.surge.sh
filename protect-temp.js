const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const JavaScriptObfuscator = require("javascript-obfuscator");

const WWW_DIR = path.join(process.cwd(), "www");
const SKIP_JS = new Set(["sw.js", "OneSignalSDKWorker.js"]);
const SKIP_BASE64_HTML = new Set(["verify.html"]); // pages that must remain readable

function run(cmd, input = null) {
    try {
        return execSync(cmd, { input, shell: true, stdio: ["pipe", "pipe", "pipe"] }).toString();
    } catch (e) { return ""; }
}

const walkSync = (dir, filelist = []) => {
    if (!fs.existsSync(dir)) return filelist;
    fs.readdirSync(dir).forEach(file => {
        const dirFile = path.join(dir, file);
        if (fs.statSync(dirFile).isDirectory()) filelist = walkSync(dirFile, filelist);
        else filelist.push(dirFile);
    });
    return filelist;
};

const stats = { css: 0, js: 0, html: 0, skipped: 0, failed: 0 };
const failures = [];

function log(icon, color, relPath, msg) {
    const reset = "\x1b[0m";
    console.log(`  ${icon} ${color}${relPath}${reset} ${msg || ""}`);
}

const allFiles = walkSync(WWW_DIR);
const total = allFiles.length;
console.log(`\n  Scanning ${total} files in www/ ...\n`);

allFiles.forEach(file => {
    const ext = path.extname(file).toLowerCase();
    const base = path.basename(file);
    const relPath = path.relative(WWW_DIR, file);
    const raw = fs.readFileSync(file, "utf8");

    if (raw.trim().length === 0) { stats.skipped++; return; }

    // ---------- CSS ----------
    if (ext === ".css") {
        const before = raw.length;
        let min = run("npx cleancss -O2", raw);
        if (min && min.trim()) {
            fs.writeFileSync(file, min, "utf8");
            const pct = before ? Math.round((1 - min.length / before) * 100) : 0;
            log("✔", "\x1b[32m", relPath, `(${before} → ${min.length}B, -${pct}%)`);
            stats.css++;
        } else {
            log("!", "\x1b[33m", relPath, "(css minify produced empty — kept original)");
            stats.skipped++;
        }
        return;
    }

    // ---------- JS (minify + obfuscate) ----------
    if (ext === ".js") {
        if (SKIP_JS.has(base)) {
            log("–", "\x1b[33m", relPath, "(excluded by SKIP_JS)");
            stats.skipped++;
            return;
        }
        const before = raw.length;
        let minResult = run(`npx terser --compress passes=2 --mangle --ecma 2020`, raw);
        let min = (minResult && minResult.trim()) ? minResult : raw;
        try {
            const obf = JavaScriptObfuscator.obfuscate(min, {
                compact: true, simplify: true, stringArray: true, stringArrayThreshold: 1,
                stringArrayEncoding: ["base64"], stringArrayRotate: true, stringArrayShuffle: true,
                disableConsoleOutput: true
            });
            const wrapped = `(function(){var script=document.createElement('script');script.type='text/javascript';script.text=${JSON.stringify(obf.getObfuscatedCode())};document.head.appendChild(script);})();`;
            fs.writeFileSync(file, wrapped, "utf8");
            log("✔", "\x1b[32m", relPath, `(${before} → ${wrapped.length}B, obfuscated)`);
            stats.js++;
        } catch (e) {
            fs.writeFileSync(file, min, "utf8");
            log("!", "\x1b[33m", relPath, `(obfuscation failed, minified only: ${e.message})`);
            failures.push(relPath);
            stats.failed++;
        }
        return;
    }

    // ---------- HTML / HTM (minify + base64-protect) ----------
    if (ext === ".html" || ext === ".htm") {
        if (SKIP_BASE64_HTML.has(base)) {
            log("–", "\x1b[33m", relPath, "(excluded by SKIP_BASE64_HTML)");
            stats.skipped++;
            return;
        }
        const before = raw.length;
        const flags = [
            "--collapse-whitespace", "--remove-comments", "--remove-redundant-attributes",
            "--remove-script-type-attributes", "--remove-style-link-type-attributes",
            "--remove-empty-attributes", "--use-short-doctype", "--minify-css", "true", "--minify-js", "true"
        ].join(" ");
        let min = run(`npx html-minifier-terser ${flags}`, raw);
        if (!min || !min.trim()) min = raw;
        try {
            const encoded = Buffer.from(min, "utf8").toString("base64");
            const protectedHtml =
`<!DOCTYPE html><html><head><meta charset="UTF-8"><script>(function(){var _0x=["${encoded}"];document.open();document.write(decodeURIComponent(escape(atob(_0x[0]))));document.close();})();</script></head><body></body></html>`;
            fs.writeFileSync(file, protectedHtml, "utf8");
            const pct = before ? Math.round((1 - min.length / before) * 100) : 0;
            log("✔", "\x1b[32m", relPath, `(${before} → ${protectedHtml.length}B, min -${pct}%, base64 protected)`);
            stats.html++;
        } catch (e) {
            fs.writeFileSync(file, min, "utf8");
            log("!", "\x1b[33m", relPath, `(base64 wrap failed, minified only: ${e.message})`);
            failures.push(relPath);
            stats.failed++;
        }
        return;
    }
});

console.log("\n  ─────────────────────────────────────────────────────────");
console.log(`  📊 Protection Summary`);
console.log(`     CSS minified       : ${stats.css}`);
console.log(`     JS obfuscated      : ${stats.js}`);
console.log(`     HTML base64-wrapped: ${stats.html}`);
console.log(`     Skipped            : ${stats.skipped}`);
console.log(`     Failed             : ${stats.failed}`);
if (failures.length) {
    console.log(`\n  ⚠️  Files that fell back to minified-only:`);
    failures.forEach(f => console.log(`     - ${f}`));
}
console.log("  ─────────────────────────────────────────────────────────\n");
