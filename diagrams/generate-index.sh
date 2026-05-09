#!/bin/bash
# generate-index.sh — rebuild diagrams/index.html from file dates (newest first)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$DIR")"
OUT="$DIR/index.html"

# Gather files: all .html except index.html and this script
entries=()
for f in "$DIR"/*.html; do
    base="$(basename "$f")"
    [[ "$base" == "index.html" ]] && continue
    [[ "$base" == "generate-index.sh" ]] && continue

    # Get last commit date for this file
    date=$(git -C "$REPO" log -1 --format="%ai" -- "$f" 2>/dev/null || echo "1970-01-01 00:00:00 +0000")
    # Get title from <title> tag
    title=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' "$f" | head -1)
    [[ -z "$title" ]] && title="${base%.html}"  # fallback to filename

    entries+=("$date|$base|$title")
done

# Sort by date descending (newest first)
IFS=$'\n' sorted=($(sort -r <<<"${entries[*]}"))
unset IFS

# Build HTML
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
        .list .name { font-weight: 500; color: var(--accent); }
        .list .date { font-size: 0.8rem; color: var(--muted); white-space: nowrap; }
    </style>
</head>
<body>
    <div class="wrap">
        <nav><a href="../index.html">← Back to Home</a></nav>
        <h1>System Diagrams</h1>
        <p class="subtitle">Newest first</p>
        <ul class="list">
HTML

for entry in "${sorted[@]}"; do
    IFS='|' read -r date base title <<< "$entry"
    # Format date nicely
    display_date=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$date" "+%d %b %Y" 2>/dev/null || echo "$date")
    cat >> "$OUT" << EOF
            <li><a href="$base"><span class="name">$title</span><span class="date">$display_date</span></a></li>
EOF
done

cat >> "$OUT" << 'HTML'
        </ul>
    </div>
</body>
</html>
HTML

echo "Generated $OUT with ${#sorted[@]} entries"
