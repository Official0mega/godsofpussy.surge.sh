const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const JavaScriptObfuscator = require("javascript-obfuscator");
const WWW_DIR = path.join(process.cwd(), "www");
const SKIP_JS = new Set(["sw.js", "OneSignalSDKWorker.js"]);
const SKIP_BASE64_HTML = new Set(["verify.html"]);

function run(cmd, input = null) {
    try { return execSync(cmd, { input, shell: true, stdio: ["pipe", "pipe", "pipe"] }).toString(); } catch (e) { return ""; }
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

const allFiles = walkSync(WWW_DIR);
allFiles.forEach(file => {
    const ext = path.extname(file).toLowerCase();
    const base = path.basename(file);
    const raw = fs.readFileSync(file, "utf8");
    if (raw.trim().length === 0) return;

    if (ext === ".css") {
        let min = run("npx cleancss -O2", raw);
        if (min && min.trim()) fs.writeFileSync(file, min, "utf8");
    } else if (ext === ".js") {
        if (SKIP_JS.has(base)) return;
        let minResult = run(`npx terser --compress passes=2 --mangle --ecma 2020`, raw);
        let min = (minResult && minResult.trim()) ? minResult : raw;
        try {
            const obf = JavaScriptObfuscator.obfuscate(min, {
                compact: true, simplify: true, stringArray: true, stringArrayThreshold: 1,
                stringArrayEncoding: ["base64"], stringArrayRotate: true, stringArrayShuffle: true,
                disableConsoleOutput: true
            });
            fs.writeFileSync(file, `(function(){var script=document.createElement('script');script.type='text/javascript';script.text=${JSON.stringify(obf.getObfuscatedCode())};document.head.appendChild(script);})();`, "utf8");
        } catch (e) { fs.writeFileSync(file, min, "utf8"); }
    } else if (ext === ".html" || ext === ".htm") {
        if (SKIP_BASE64_HTML.has(base)) return;
        let flags = [
            "--collapse-whitespace", "--remove-comments", "--remove-redundant-attributes",
            "--remove-script-type-attributes", "--remove-style-link-type-attributes",
            "--remove-empty-attributes", "--use-short-doctype", "--minify-css", "true", "--minify-js", "true"
        ].join(" ");
        let min = run(`npx html-minifier-terser ${flags}`, raw);
        if (!min || !min.trim()) min = raw;
        try {
            const encoded = Buffer.from(min, "utf8").toString("base64");
            const protectedHtml = `<!DOCTYPE html><html><head><meta charset="UTF-8"><script>(function(){var _0x=["${encoded}"];document.open();document.write(decodeURIComponent(escape(atob(_0x[0]))));document.close();})();</script></head><body></body></html>`;
            fs.writeFileSync(file, protectedHtml, "utf8");
        } catch (e) { fs.writeFileSync(file, min, "utf8"); }
    }
});
