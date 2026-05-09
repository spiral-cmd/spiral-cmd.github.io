#!/bin/bash
# generate-index.sh — rebuild diagrams/index.html from file numbers (highest first)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$DIR")"
OUT="$DIR/index.html"

entries=()
for f in "$DIR"/*.html; do
    base="$(basename "$f")"
    [[ "$base" == "index.html" ]] && continue
    [[ "$base" == "generate-index.sh" ]] && continue

    # Extract 4-digit prefix if it exists
    num=""
    if [[ "$base" =~ ^([0-9]{4})- ]]; then
        num="${BASH_REMATCH[1]}"
    fi

    # Get title from <title> tag
    title=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' "$f" | head -1)
    [[ -z "$title" ]] && title="${base%.html}"

    # Sort key: numbered files by number desc, unnumbered at bottom
    sortkey="${num:-0000}"
    entries+=("$sortkey|$num|$base|$title")
done

# Sort by number descending, then filename for ties
IFS=$'\n' sorted=($(sort -t'|' -k1,1rn -k3 <<<"${entries[*]}"))
unset IFS

cat > "$OUT" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Diagrams — spiralarc</title>
    <style>
        :root { --bg: #78C2CE; --text: #222; --muted: #666; --line: #6FB3BE; --accent: #01696f; --max: 960px; }
        body { font-family: "Inter", sans-serif; background: var(--bg); color: var(--text); margin: 0; padding: 2rem; display: flex; flex-direction: column; align-items: center; }
        .wrap { width: min(100% - 2rem, var(--max)); }
        h1 { font-size: 2rem; margin-bottom: 0.5rem; text-align: center; }
        .subtitle { text-align: center; color: var(--muted); margin-bottom: 2rem; font-size: 0.9rem; }
        nav { margin-bottom: 2rem; text-align: center; }
        nav a { color: var(--text); text-decoration: none; font-weight: 500; border-bottom: 2px solid var(--accent); }
        .list { list-style: none; padding: 0; margin: 0; }
        .list li { background: white; margin-bottom: 0.75rem; border-radius: .5rem; border: 1px solid var(--line); transition: transform 0.15s ease; }
        .list li:hover { transform: translateX(4px); }
        .list a { display: flex; justify-content: space-between; align-items: center; padding: 1rem 1.25rem; text-decoration: none; color: inherit; }
        .list .num { color: var(--muted); font-size: 0.8rem; font-weight: 600; margin-right: 0.75rem; min-width: 3em; }
        .list .name { font-weight: 500; color: var(--accent); flex: 1; }
    </style>
</head>
<body>
    <div class="wrap">
        <nav><a href="../index.html">← Back to Home</a></nav>
        <h1>System Diagrams</h1>
        <ul class="list">
HTML

for entry in "${sorted[@]}"; do
    IFS='|' read -r sortkey num base title <<< "$entry"
    if [[ -n "$num" ]]; then
        cat >> "$OUT" << EOF
            <li><a href="$base"><span class="num">$num</span><span class="name">$title</span></a></li>
EOF
    else
        cat >> "$OUT" << EOF
            <li><a href="$base"><span class="name">$title</span></a></li>
EOF
    fi
done

cat >> "$OUT" << 'HTML'
        </ul>
    </div>
</body>
</html>
HTML

echo "Generated $OUT with ${#sorted[@]} entries"