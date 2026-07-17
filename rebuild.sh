#!/usr/bin/env bash
# Reconstruct index.html from its parts and verify the build.
# The filesystem resets between sessions; this rebuilds the single-file app
# from shell-head.html + app.jsx + shell-tail.html.
set -euo pipefail
cd "$(dirname "$0")"

echo "== static parse (node --check) =="
cp app.jsx /tmp/app-check.js && node --check /tmp/app-check.js && echo "  PASS"

echo "== runtime parse (new Function) =="
node -e 'new Function(require("fs").readFileSync("app.jsx","utf8"))' && echo "  PASS"

echo "== splice =="
cat shell-head.html app.jsx shell-tail.html > index.html
echo "  wrote index.html ($(wc -c < index.html) bytes)"

echo "== paren/brace/bracket balance (app.jsx) =="
node -e '
const s = require("fs").readFileSync("app.jsx","utf8");
let p=0,b=0,k=0;
for (const c of s){ if(c==="(")p++;if(c===")")p--;if(c==="{")b++;if(c==="}")b--;if(c==="[")k++;if(c==="]")k--; }
console.log("  parens:"+p+" braces:"+b+" brackets:"+k+" (target 0/0/0)");
'
