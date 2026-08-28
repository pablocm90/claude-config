#!/usr/bin/env bash
# Behaviour tests for the review reference map: given a changed file, which
# files reference it. The answer must not depend on the project keeping its
# code in app/, lib/ or src/.
set -uo pipefail

LIB="$(cd "$(dirname "$0")/.." && pwd)/lib/refs.sh"
fails=0
[ -f "$LIB" ] || { echo "FAIL: $LIB does not exist"; exit 1; }
# shellcheck source=/dev/null
. "$LIB"

assert_eq() {
  [ "$2" = "$3" ] || { echo "FAIL: $1"; echo "  expected: [$3]"; echo "  got:      [$2]"; fails=$((fails + 1)); }
}
deps() { dependents_for "$1" "$2" | sort | tr '\n' ' ' | sed 's/ $//'; }

repo=$(mktemp -d)

# --- Ruby: an engine keeps models outside app/ and lib/ --------------------
mkdir -p "$repo/engines/billing/app/models" "$repo/app/services"
cat > "$repo/engines/billing/app/models/late_invoice.rb" <<'RB'
class LateInvoice < ApplicationRecord; end
RB
cat > "$repo/app/services/dunning.rb" <<'RB'
class Dunning
  def call = LateInvoice.overdue
end
RB
cat > "$repo/app/services/unrelated.rb" <<'RB'
class Unrelated; end
RB
assert_eq "a ruby file outside app/ is still found" \
  "$(deps "$repo" engines/billing/app/models/late_invoice.rb)" "app/services/dunning.rb"

# --- TypeScript: a monorepo keeps packages above src/ ---------------------
mkdir -p "$repo/packages/web/src/components"
echo 'export const Chart = () => null' > "$repo/packages/web/src/components/chart.tsx"
echo "import { Chart } from '../components/chart'" > "$repo/packages/web/src/dashboard.tsx"
assert_eq "a tsx file under packages/ is still found" \
  "$(deps "$repo" packages/web/src/components/chart.tsx)" "packages/web/src/dashboard.tsx"

# --- JavaScript is the same language for this purpose ---------------------
mkdir -p "$repo/scripts"
echo 'module.exports = {}' > "$repo/scripts/report.js"
echo "const r = require('./report')" > "$repo/scripts/run.js"
assert_eq "a js file resolves like a ts one" \
  "$(deps "$repo" scripts/report.js)" "scripts/run.js"

# --- Python was invisible entirely ----------------------------------------
mkdir -p "$repo/svc"
echo 'def handle(): pass' > "$repo/svc/handlers.py"
echo 'from svc.handlers import handle' > "$repo/svc/main.py"
echo 'x = 1  # handlers mentioned only in a comment' > "$repo/svc/noise.py"
mkdir -p "$repo/app/views"
assert_eq "a python module is found through its import line" \
  "$(deps "$repo" svc/handlers.py)" "svc/main.py"

# --- A repo's own worktrees are not part of its source --------------------
mkdir -p "$repo/.claude/worktrees/other-task/app/services"
cp "$repo/app/services/dunning.rb" "$repo/.claude/worktrees/other-task/app/services/dunning.rb"
assert_eq "a sibling worktree is not searched" \
  "$(deps "$repo" engines/billing/app/models/late_invoice.rb)" "app/services/dunning.rb"

mkdir -p "$repo/node_modules/pkg" "$repo/vendor/bundle"
echo 'LateInvoice' > "$repo/vendor/bundle/cached.rb"
echo "import { Chart } from '../components/chart'" > "$repo/node_modules/pkg/index.tsx"
assert_eq "vendored trees are not searched (ruby)" \
  "$(deps "$repo" engines/billing/app/models/late_invoice.rb)" "app/services/dunning.rb"
assert_eq "vendored trees are not searched (ts)" \
  "$(deps "$repo" packages/web/src/components/chart.tsx)" "packages/web/src/dashboard.tsx"

# A longer constant that merely starts with this one is a different class.
echo "class LateInvoiceSerializer; end" > "$repo/app/services/late_invoice_serializer.rb"

# A view is a caller too.
echo "<%= LateInvoice.count %>" > "$repo/app/views/report.html.erb"
assert_eq "a template counts as a reference" \
  "$(deps "$repo" engines/billing/app/models/late_invoice.rb)" "app/services/dunning.rb app/views/report.html.erb"

# nothing imports a package marker by name
# A package marker names no module — every `import pkg` would match its stem.
touch "$repo/svc/__init__.py"
assert_eq "a package marker has no dependents" "$(deps "$repo" svc/__init__.py)" ""

# --- A language with no filename-based heuristic says nothing -------------
echo 'package main' > "$repo/main.go"
assert_eq "an unsupported language returns nothing rather than noise" \
  "$(deps "$repo" main.go)" ""

# --- Forward imports ------------------------------------------------------
fwd() { imports_for "$1" "$2" | sort | tr '\n' ' ' | sed 's/ $//'; }
assert_eq "a tsx file lists its local imports" \
  "$(fwd "$repo" packages/web/src/dashboard.tsx)" "../components/chart"
assert_eq "a python file lists its local imports" \
  "$(fwd "$repo" svc/main.py)" "svc.handlers"

rm -rf "$repo"
[ "$fails" -eq 0 ] && echo "refs: all assertions passed"
exit "$fails"
