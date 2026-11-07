#!/bin/bash

# ==============================================================================
# 🚀 SET ENVIRONMENT VARIABLES FIRST (CRITICAL FOR JAVA & ANDROID)
# ==============================================================================
export EXE4J_JAVA_HOME="D:/Installed_Windows_Program/java/jdk-21.0.12"
export JAVA_HOME="D:/Installed_Windows_Program/java/jdk-21.0.12"
export PATH="$JAVA_HOME/bin:$PATH"

export ANDROID_HOME="/d/Android_Studio/Android_Studio_Backup_28_11_2024/Main_Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$PATH"

# ==============================================================================
# 🚀 GODSOFPUSSY — WEB-FIRST + OPTIONAL MOBILE PIPELINE
# ==============================================================================
APP_PACKAGE="com.codeversehub.godsofpussy"
APP_NAME="GodsOfPussy"
SURGE_DOMAIN="godsofpussy.surge.sh"

# Directories to copy into www/
SITE_DIRS=("includes" "es" "fi" "tour" "chat" "salas-tematicas")
# SITE_DIRS+=("backup")

# Terminal Colors
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_MAGENTA='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[1;37m'
COLOR_BOLD='\033[1m'

TOTAL_STEPS=6
CURRENT_STEP=0
BUILD_START_TIME=$(date +%s)

MOBILE_PROJECT_READY=false
MOBILE_DEVICE_READY=false
SKIP_MOBILE=true

log_info()      { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"; }
log_success()   { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"; }
log_warning()   { echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"; }
log_error()     { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"; }

print_divider()      { echo -e "${COLOR_MAGENTA}========================================================================${COLOR_RESET}"; }
print_thin_divider() { echo -e "${COLOR_MAGENTA}------------------------------------------------------------------------${COLOR_RESET}"; }

print_step_header() {
    CURRENT_STEP=$1
    echo ""
    print_divider
    echo -e "${COLOR_CYAN}${COLOR_BOLD} [PHASE $1/$2] : $3 ${COLOR_RESET}"
    print_divider
}

print_banner() {
    echo -e "${COLOR_CYAN}"
    echo "   _____ _    _ ______ _____   ____  _____  "
    echo "  / ____| |  | |  ____|  __ \ / __ \|  __ \ "
    echo " | |  __| |__| | |__  | |  | | |  | | |__) |"
    echo " | | |_ |  __  |  __| | |  | | |  | |  ___/ "
    echo " | |__| | |  | | |____| |__| | |__| | |     "
    echo "  \_____|_|  |_|______|_____/ \____/|_|     "
    echo -e "${COLOR_RESET}"
    echo -e "${COLOR_WHITE}          GodsofPussy Pipeline — Web-First Edition${COLOR_RESET}"
    echo ""
}

print_elapsed_time() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - BUILD_START_TIME))
    log_info "Total build time: $((elapsed / 60))m $((elapsed % 60))s"
}

check_command_exists() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required tool '$1' is not installed or not in PATH."
        return 1
    fi
    return 0
}

prepare_directory() {
    if [ "$2" == "clean" ] && [ -d "$1" ]; then rm -rf "$1"; fi
    if [ ! -d "$1" ]; then mkdir -p "$1"; fi
}

check_node_dependencies() {
    log_info "Verifying Node.js dependencies..."
    local pkgs=("javascript-obfuscator" "clean-css-cli" "html-minifier-terser" "terser" "surge")
    local missing=()
    for pkg in "${pkgs[@]}"; do
        if [ ! -d "node_modules/$pkg" ]; then missing+=("$pkg"); fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_info "Installing missing dependencies: ${missing[*]}"
        if [ ! -f "package.json" ]; then
            log_warning "package.json not found — creating a minimal one (build only)."
            echo '{"name":"godsofpussy","version":"1.0.0","private":true}' > package.json
        fi
        npm install --save-dev "${missing[@]}"
    else
        log_success "All Node.js dependencies are present."
    fi
}

detect_mobile_project() {
    MOBILE_PROJECT_READY=false
    if [ ! -d "android" ]; then
        log_warning "No 'android/' directory — mobile build will be skipped."
        return
    fi
    if [ ! -f "capacitor.config.json" ] && [ ! -f "capacitor.config.ts" ]; then
        log_warning "No Capacitor config — mobile build will be skipped."
        return
    fi
    if [ ! -d "$ANDROID_HOME" ]; then
        log_warning "Android SDK not found — mobile build will be skipped."
        return
    fi
    MOBILE_PROJECT_READY=true
    log_success "Android project detected and SDK found."
}

detect_mobile_device() {
    MOBILE_DEVICE_READY=false
    if ! command -v adb &> /dev/null; then
        log_warning "adb not found — no connected Android device."
        return
    fi
    local count
    count=$(adb devices 2>/dev/null | grep -v "List of devices" | grep -c "device$")
    if [ "$count" -gt 0 ]; then
        MOBILE_DEVICE_READY=true
        log_success "Detected $count connected Android device(s)."
    else
        log_warning "No Android device connected via ADB."
    fi
}

# ==============================================================================
print_banner
print_step_header 1 $TOTAL_STEPS "Environment Validation"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

required_tools=("node" "npm" "npx")
for tool in "${required_tools[@]}"; do check_command_exists "$tool" || exit 1; done

if [ ! -f "index.htm" ] && [ ! -f "index.html" ]; then
    log_error "Missing site entry point: expected index.htm or index.html"
    exit 1
fi
log_success "Site entry point found."

detect_mobile_project
if [ "$MOBILE_PROJECT_READY" = true ]; then
    detect_mobile_device
    if [ "$MOBILE_DEVICE_READY" = true ]; then
        SKIP_MOBILE=false
        log_success "Mobile build will run."
    else
        log_warning "Mobile project exists but no device connected — mobile deploy will be skipped."
        SKIP_MOBILE=true
    fi
else
    log_warning "No mobile project yet — mobile deploy will be skipped (web only)."
    SKIP_MOBILE=true
fi

check_node_dependencies
print_elapsed_time

# ==============================================================================
print_step_header 2 $TOTAL_STEPS "Web Asset Gathering"

prepare_directory "www" "clean"
log_success "Created clean 'www/' staging directory."

for file in *.htm *.html *.css *.js *.json *.xml *.txt *.webmanifest; do
    if [ -f "$file" ] \
        && [[ "$file" != "package.json" ]] \
        && [[ "$file" != "package-lock.json" ]] \
        && [[ "$file" != "capacitor.config.json" ]] \
        && [[ "$file" != *".sh"* ]]; then
        cp "$file" www/ 2>/dev/null
    fi
done

for file in *.png *.svg *.ico *.jpg *.jpeg *.gif *.webp *.woff *.woff2 *.ttf *.eot; do
    [ -f "$file" ] && cp "$file" www/ 2>/dev/null
done

for dir in "${SITE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        cp -r "$dir" www/ 2>/dev/null
        log_success "Copied directory: $dir"
    else
        log_warning "Directory '$dir' not found — skipped."
    fi
done

log_success "Web assets gathered."
print_elapsed_time

# ==============================================================================
print_step_header 3 $TOTAL_STEPS "Advanced Code Protection (Minify + Obfuscate)"

cat << 'EOF' > protect-temp.js
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
EOF

node protect-temp.js
rm protect-temp.js
print_elapsed_time

# ==============================================================================
print_step_header 4 $TOTAL_STEPS "Deploying Web App to Surge"
npx surge ./www ${SURGE_DOMAIN} || log_warning "Surge deployment failed."
print_elapsed_time

# ==============================================================================
print_step_header 5 $TOTAL_STEPS "Mobile App (Optional)"

if [ "$SKIP_MOBILE" = true ]; then
    print_divider
    log_warning "Skipping mobile build."
    log_info    "Reason: no mobile project and/or no connected Android device."
    log_info    "This is expected — mobile app is planned for a later date."
    log_info    "Web deploy is complete and unaffected."
    print_divider
else
    log_info "Syncing Capacitor native assets..."
    rm -rf android/app/src/main/assets/public
    mkdir -p android/app/src/main/assets/public
    node node_modules/@capacitor/cli/bin/capacitor copy android
    node node_modules/@capacitor/cli/bin/capacitor sync android
    print_elapsed_time

    cd android || exit 1
    ./gradlew --stop > /dev/null 2>&1 || true
    taskkill //F //IM java.exe  2>/dev/null || true
    taskkill //F //IM javaw.exe 2>/dev/null || true
    cd ..
    rm -rf node_modules/@capacitor/android/capacitor/build
    rm -rf node_modules/@capacitor/*/android/build
    rm -rf android/app/build
    rm -rf android/build
    rm -rf android/.gradle
    print_elapsed_time

    BUILD_GRADLE="android/app/build.gradle"
    if [ -f "$BUILD_GRADLE" ]; then
        CURRENT_CODE=$(awk '/versionCode / {print $2}' "$BUILD_GRADLE" | tr -d '\r')
        CURRENT_NAME=$(awk '/versionName / {print $2}' "$BUILD_GRADLE" | tr -d '"' | tr -d '\r')
        if [[ "$CURRENT_CODE" =~ ^[0-9]+$ ]] && [[ -n "$CURRENT_NAME" ]]; then
            NEW_CODE=$((CURRENT_CODE + 1))
            IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_NAME"
            MAJOR=${VERSION_PARTS[0]}
            MINOR=${VERSION_PARTS[1]:-0}
            PATCH=${VERSION_PARTS[2]:-0}
            PATCH=$((PATCH + 1))
            NEW_NAME="${MAJOR}.${MINOR}.${PATCH}"
            awk -v new_code="$NEW_CODE" -v new_name="$NEW_NAME" '
                /versionCode / { sub(/versionCode [0-9]+/, "versionCode " new_code) }
                /versionName / { sub(/versionName "[^"]+"/, "versionName \"" new_name "\"") }
                { print }
            ' "$BUILD_GRADLE" > "${BUILD_GRADLE}.tmp" && mv "${BUILD_GRADLE}.tmp" "$BUILD_GRADLE"
            log_success "Version bumped to Code $NEW_CODE | Name $NEW_NAME"
        fi
    fi
    print_elapsed_time

    cd android || exit 1
    log_info "🔨 Building Debug APK..."
    ./gradlew assembleDebug --no-daemon || exit 1
    log_info "🔨 Building Release Bundle (AAB)..."
    ./gradlew bundleRelease --no-daemon || exit 1
    log_info "🔨 Building Release APK..."
    ./gradlew assembleRelease --no-daemon || exit 1
    print_elapsed_time

    if command -v adb &> /dev/null; then
        DEVICE_COUNT=$(adb devices | grep -v "List of devices" | grep -c "device$")
        if [ "$DEVICE_COUNT" -gt 0 ]; then
            DEBUG_APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
            if [ -f "$DEBUG_APK_PATH" ]; then
                adb uninstall ${APP_PACKAGE} > /dev/null 2>&1 || true
                adb install -r "$DEBUG_APK_PATH"
                if [ $? -eq 0 ]; then
                    adb shell monkey -p ${APP_PACKAGE} -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
                    log_success "App is now running on your device."
                else
                    log_error "ADB installation failed."
                fi
            fi
        fi
    fi
    print_elapsed_time
fi

# ==============================================================================
print_step_header 6 $TOTAL_STEPS "Build Pipeline Complete"

cd "$SCRIPT_DIR" 2>/dev/null || true

echo -e "${COLOR_GREEN}${COLOR_BOLD}🎉 GODSOFPUSSY PIPELINE FINISHED!${COLOR_RESET}"
echo ""
echo -e "${COLOR_CYAN}🌐 WEB VERSION:${COLOR_RESET}"
print_thin_divider
echo "   https://${SURGE_DOMAIN}"
print_thin_divider

if [ "$SKIP_MOBILE" = false ]; then
    AAB_PATH="android/app/build/outputs/bundle/release/app-release.aab"
    REL_APK_PATH="android/app/build/outputs/apk/release/app-release.apk"
    DBG_APK_PATH="android/app/build/outputs/apk/debug/app-debug.apk"
    echo -e "${COLOR_CYAN}📦 GENERATED MOBILE ARTIFACTS:${COLOR_RESET}"
    [ -f "$AAB_PATH" ]     && echo -e "${COLOR_GREEN}✅ AAB (Play Store):${COLOR_RESET}\n   $AAB_PATH"
    [ -f "$REL_APK_PATH" ] && echo -e "${COLOR_GREEN}✅ APK (Release):${COLOR_RESET}\n   $REL_APK_PATH"
    [ -f "$DBG_APK_PATH" ] && echo -e "${COLOR_GREEN}✅ APK (Debug):${COLOR_RESET}\n   $DBG_APK_PATH"
    print_thin_divider
else
    echo -e "${COLOR_YELLOW}⚠️  Mobile build skipped — web deploy only.${COLOR_RESET}"
    print_thin_divider
fi

print_elapsed_time
exit 0