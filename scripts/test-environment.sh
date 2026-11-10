#!/bin/bash
# Destructive-path regression checks run only inside an isolated fixture.
set -euo pipefail
PROJECT_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/growing-room-environment.XXXXXX")"
trap 'rm -rf -- "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/project/scripts" "$FIXTURE/project/src" "$FIXTURE/project/public/assets" "$FIXTURE/outside"
cp "$PROJECT_ROOT/dev" "$FIXTURE/project/dev"
cp "$PROJECT_ROOT/scripts/environment.sh" "$FIXTURE/project/scripts/environment.sh"
cd "$FIXTURE/project"
printf 'source\n' > src/keep.ts
printf 'asset\n' > public/assets/keep.txt
printf 'lock\n' > package-lock.json
printf 'private configuration\n' > .env.local
printf 'outside\n' > "$FIXTURE/outside/keep.txt"

populate() {
  mkdir -p .dev/cache .dev/runtime node_modules dist
  for target in .dev/cache .dev/runtime node_modules dist; do
    printf 'generated\n' > "$target/example"
  done
}

populate
./dev clean deps >/dev/null
test ! -e node_modules
test -f .dev/cache/example && test -f .dev/runtime/example && test -f dist/example
./dev clean build >/dev/null
test ! -e dist && test -f .dev/cache/example
./dev clean cache >/dev/null
test ! -e .dev/cache && test -f .dev/runtime/example
./dev clean runtime >/dev/null
test ! -e .dev/runtime

populate
./dev clean all >/dev/null
for target in .dev/cache .dev/runtime node_modules dist; do test ! -e "$target"; done
test "$(cat src/keep.ts)" = source
test "$(cat public/assets/keep.txt)" = asset
test "$(cat package-lock.json)" = lock
test "$(cat .env.local)" = 'private configuration'

ln -s "$FIXTURE/outside" .dev/cache
if ./dev clean cache >"$FIXTURE/result" 2>&1; then
  printf 'FAIL: symbolic-link target was accepted\n' >&2; exit 1
fi
test -f "$FIXTURE/outside/keep.txt"
rm .dev/cache

mkdir -p .dev/run/server.lock
printf '%s\n' "$$" > .dev/run/server.lock/owner.pid
if ./dev clean all >"$FIXTURE/result" 2>&1; then
  printf 'FAIL: active service was ignored\n' >&2; exit 1
fi
case "$(cat "$FIXTURE/result")" in
  *'开发服务仍在运行'*) ;;
  *) cat "$FIXTURE/result" >&2; exit 1 ;;
esac
if ./dev setup >"$FIXTURE/result" 2>&1; then
  printf 'FAIL: setup allowed replacement during an active service\n' >&2; exit 1
fi
case "$(cat "$FIXTURE/result")" in
  *'开发服务仍在运行'*) ;;
  *) cat "$FIXTURE/result" >&2; exit 1 ;;
esac
rm -rf .dev/run/server.lock
if ./dev clean ../outside >"$FIXTURE/result" 2>&1; then
  printf 'FAIL: arbitrary cleanup target was accepted\n' >&2; exit 1
fi
test -f "$FIXTURE/outside/keep.txt"
printf 'PASS: selective cleanup, source/config preservation, path boundaries, active-service guards\n'
