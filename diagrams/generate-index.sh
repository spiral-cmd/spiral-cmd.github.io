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

    # Get tags from <meta name="tags" content="..."> tag
    tags=$(sed -n 's/.*<meta name="tags" content="\(.*\)">.*/\1/p' "$f" | head -1)

    # Sort key: numbered files by number desc, unnumbered at bottom
    sortkey="${num:-0000}"
    entries+=("$sortkey|$num|$base|$title|$tags")
done

# Sort by number descending, then filename for ties
IFS=$'\n' sorted=($(sort -t'|' -k1,1rn -k3 <<<"${entries[*]}"))
unset IFS

# Build the TAGS map (tag -> count) from all data-tags values
# Using a temporary file for portability instead of associative array
tag_counts_file=$(mktemp)
for entry in "${sorted[@]}"; do
    IFS='|' read -r sortkey num base title tags <<< "$entry"
    [[ -z "$tags" ]] && continue
    IFS=',' read -ra tarr <<< "$tags"
    for t in "${tarr[@]}"; do
        t="${t// /}"
        [[ -z "$t" ]] && continue
        echo "$t" >> "$tag_counts_file"
    done
done

taglist_raw=$(sort "$tag_counts_file" | uniq -c | sort -rn | awk '{print $2 ":" $1}' | paste -sd, -)
rm "$tag_counts_file"

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

        /* Filter UI */
        .filter-wrap { margin-bottom: 1.25rem; text-align: center; position: relative; }
        .filter-box { display: inline-flex; align-items: center; gap: 0.5rem; background: white; border: 1px solid var(--line); border-radius: 0.5rem; padding: 0.4rem 0.6rem; flex-wrap: wrap; max-width: 100%; }
        .filter-box input { border: none; outline: none; font-size: 1rem; padding: 0.3rem; min-width: 180px; flex: 1; }
        .chip { display: inline-flex; align-items: center; gap: 0.35rem; background: var(--accent); color: white; border-radius: 999px; padding: 0.2rem 0.6rem; font-size: 0.8rem; }
        .chip button { background: none; border: none; color: white; cursor: pointer; font-size: 0.9rem; line-height: 1; padding: 0; }
        .dropdown { position: absolute; left: 50%; transform: translateX(-50%); top: 100%; margin-top: 0.25rem; background: white; border: 1px solid var(--line); border-radius: 0.5rem; box-shadow: 0 4px 12px rgba(0,0,0,0.12); width: 260px; z-index: 10; text-align: left; max-height: 260px; overflow-y: auto; display: none; }
        .dropdown .opt { padding: 0.5rem 0.75rem; cursor: pointer; display: flex; justify-content: space-between; align-items: center; font-size: 0.9rem; }
        .dropdown .opt:hover, .dropdown .opt.active { background: #eef6f7; }
        .dropdown .opt .cnt { color: var(--muted); font-size: 0.75rem; }
        .legend { margin-bottom: 1.25rem; text-align: center; }
        .legend .pill { display: inline-block; background: white; border: 1px solid var(--line); border-radius: 999px; padding: 0.25rem 0.7rem; margin: 0.15rem; font-size: 0.8rem; cursor: pointer; color: var(--accent); }
        .legend .pill:hover { background: #eef6f7; }
        .legend .pill.on { background: var(--accent); color: white; }
        .count { text-align: center; color: var(--muted); font-size: 0.85rem; margin-bottom: 1rem; }
        .empty { text-align: center; color: var(--muted); padding: 2rem; font-size: 0.95rem; }

        .list { list-style: none; padding: 0; margin: 0; }
        .list li { background: white; margin-bottom: 0.75rem; border-radius: .5rem; border: 1px solid var(--line); transition: transform 0.15s ease; }
        .list li:hover { transform: translateX(4px); }
        .list a { display: flex; justify-content: space-between; align-items: center; padding: 1rem 1.25rem; text-decoration: none; color: inherit; }
        .list .num { color: var(--muted); font-size: 0.8rem; font-weight: 600; margin-right: 0.75rem; min-width: 3em; }
        .list .name { font-weight: 500; color: var(--accent); flex: 1; }
        .list .tags { font-size: 0.75rem; color: var(--muted); margin-left: 1rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 150px; }
    </style>
</head>
<body>
    <div class="wrap">
        <nav><a href="../index.html">← Back to Home</a></nav>
        <h1>System Diagrams</h1>

        <div class="legend" id="legend"></div>

        <div class="filter-wrap">
            <div class="filter-box" id="filterBox">
                <span id="chips"></span>
                <input type="text" id="tagFilter" placeholder="Filter by tag…" autocomplete="off">
            </div>
            <div class="dropdown" id="dropdown"></div>
        </div>

        <div class="count" id="count"></div>
        <ul class="list" id="diagramList">
HTML

for entry in "${sorted[@]}"; do
    IFS='|' read -r sortkey num base title tags <<< "$entry"
    if [[ -n "$num" ]]; then
        cat >> "$OUT" << EOF
            <li data-tags="$tags"><a href="$base"><span class="num">$num</span><span class="name">$title</span><span class="tags">$tags</span></a></li>
EOF
    else
        cat >> "$OUT" << EOF
            <li data-tags="$tags"><a href="$base"><span class="name">$title</span><span class="tags">$tags</span></a></li>
EOF
    fi
done

cat >> "$OUT" << 'HTML'
        </ul>
    </div>
    <script>
        // Known tags: tag -> count (generated)
        const TAGS = { __TAGMAP__ };
        const items = Array.from(document.querySelectorAll('#diagramList li'));
        const input = document.getElementById('tagFilter');
        const dropdown = document.getElementById('dropdown');
        const chipsEl = document.getElementById('chips');
        const countEl = document.getElementById('count');
        const legendEl = document.getElementById('legend');
        let selected = [];      // active tag filters (AND)
        let activeIdx = -1;     // dropdown highlight

        // Build legend pills
        Object.entries(TAGS).forEach(([tag, cnt]) => {
            const p = document.createElement('span');
            p.className = 'pill';
            p.textContent = tag + ' (' + cnt + ')';
            p.dataset.tag = tag;
            p.addEventListener('click', () => toggleTag(tag));
            legendEl.appendChild(p);
        });

        function matches(item) {
            if (selected.length === 0) return true;
            const tags = (item.getAttribute('data-tags') || '').split(',').map(s => s.trim());
            return selected.every(t => tags.includes(t));
        }

        function render() {
            let shown = 0;
            items.forEach(item => {
                const ok = matches(item);
                item.style.display = ok ? '' : 'none';
                if (ok) shown++;
            });
            countEl.textContent = selected.length
                ? 'Showing ' + shown + ' of ' + items.length + ' diagrams'
                : items.length + ' diagrams';
            // legend pill state
            document.querySelectorAll('.legend .pill').forEach(p => {
                p.classList.toggle('on', selected.includes(p.dataset.tag));
            });
            // empty state
            let empty = document.getElementById('emptyMsg');
            if (shown === 0) {
                if (!empty) {
                    empty = document.createElement('div');
                    empty.id = 'emptyMsg';
                    empty.className = 'empty';
                    empty.textContent = 'No diagrams match — try a different tag.';
                    countEl.after(empty);
                }
            } else if (empty) {
                empty.remove();
            }
        }

        function renderChips() {
            chipsEl.innerHTML = '';
            selected.forEach(tag => {
                const c = document.createElement('span');
                c.className = 'chip';
                c.textContent = tag;
                const x = document.createElement('button');
                x.textContent = '✕';
                x.addEventListener('click', () => toggleTag(tag));
                c.appendChild(x);
                chipsEl.appendChild(c);
            });
        }

        function toggleTag(tag) {
            const i = selected.indexOf(tag);
            if (i >= 0) selected.splice(i, 1);
            else selected.push(tag);
            renderChips();
            render();
            input.value = '';
            hideDropdown();
            input.focus();
        }

        function showDropdown(list) {
            dropdown.innerHTML = '';
            activeIdx = -1;
            if (!list.length) { hideDropdown(); return; }
            list.forEach((tag, i) => {
                const d = document.createElement('div');
                d.className = 'opt';
                d.dataset.tag = tag;
                d.innerHTML = '<span>' + tag + '</span><span class="cnt">(' + TAGS[tag] + ')</span>';
                d.addEventListener('mousedown', (e) => { e.preventDefault(); toggleTag(tag); });
                dropdown.appendChild(d);
            });
            dropdown.style.display = 'block';
        }

        function hideDropdown() { dropdown.style.display = 'none'; }

        function suggest(q) {
            q = q.toLowerCase().trim();
            if (!q) { hideDropdown(); return; }
            const list = Object.keys(TAGS)
                .filter(t => !selected.includes(t))
                .filter(t => t.toLowerCase().startsWith(q) || t.toLowerCase().includes(q))
                .sort((a, b) => TAGS[b] - TAGS[a]);
            showDropdown(list);
        }

        input.addEventListener('input', () => suggest(input.value));
        input.addEventListener('focus', () => suggest(input.value));
        input.addEventListener('blur', () => setTimeout(hideDropdown, 150));
        input.addEventListener('keydown', (e) => {
            const opts = dropdown.querySelectorAll('.opt');
            if (e.key === 'ArrowDown' && opts.length) {
                e.preventDefault();
                activeIdx = (activeIdx + 1) % opts.length;
                highlight(opts);
            } else if (e.key === 'ArrowUp' && opts.length) {
                e.preventDefault();
                activeIdx = (activeIdx - 1 + opts.length) % opts.length;
                highlight(opts);
            } else if (e.key === 'Enter' && activeIdx >= 0 && opts[activeIdx]) {
                e.preventDefault();
                toggleTag(opts[activeIdx].dataset.tag);
            } else if (e.key === 'Escape') {
                hideDropdown();
            }
        });

        function highlight(opts) {
            opts.forEach((o, i) => o.classList.toggle('active', i === activeIdx));
        }

        render();
    </script>
</body>
</html>
HTML

# Substitute the TAGS map into the generated file
python3 - "$OUT" "$taglist_raw" <<'PY'
import sys, re
out, taglist = sys.argv[1], sys.argv[2]
with open(out) as f: html = f.read()
# taglist is "tag:count,tag:count,..."
pairs = [p.split(':') for p in taglist.split(',') if p]
obj = '{ ' + ', '.join(f'"{k}": {v}' for k, v in pairs) + ' }'
html = html.replace('{ __TAGMAP__ }', obj)
with open(out, 'w') as f: f.write(html)
PY

echo "Generated $OUT with ${#sorted[@]} entries"
