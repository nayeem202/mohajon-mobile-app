#!/usr/bin/env bash
set -uo pipefail

qa_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(dirname -- "$qa_dir")"
project_dir="$(dirname -- "$app_dir")"
flutter_bin="${FLUTTER_BIN:-/home/pc/devtools/flutter/bin/flutter}"
business_dir="${BUSINESS_SERVICE_DIR:-$project_dir/haalkhata-service}"
auth_dir="${AUTH_SERVICE_DIR:-$project_dir/auth-service}"
business_jdk="${BUSINESS_JAVA_HOME:-/home/pc/devtools/jdk-21.0.12+8}"
auth_jdk="${AUTH_JAVA_HOME:-/home/pc/devtools/jdk-25.0.4+7}"
selection="${1:-all}"
case "$selection" in all|flutter|business|auth) ;; *) echo 'Usage: bash qa/run-tests.sh [all|flutter|business|auth]' >&2; exit 2 ;; esac

run_dir="$qa_dir/artifacts/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p -- "$run_dir"
failed=0

run_check() {
  local name="$1" work_dir="$2"
  shift 2
  echo "Running $name"
  if (cd -- "$work_dir" && "$@") 2>&1 | tee "$run_dir/$name.log"; then
    echo "PASS $name"
  else
    echo "FAIL $name (see $run_dir/$name.log)" >&2
    failed=1
  fi
}

if [[ "$selection" == all || "$selection" == flutter ]]; then
  run_check flutter "$app_dir" "$flutter_bin" test --coverage --concurrency=2 --reporter expanded
fi
if [[ "$selection" == all || "$selection" == business ]]; then
  run_check business "$business_dir" env JAVA_HOME="$business_jdk" PATH="$business_jdk/bin:$PATH" ./gradlew test --rerun-tasks --max-workers=2 --console=plain
fi
if [[ "$selection" == all || "$selection" == auth ]]; then
  run_check auth "$auth_dir" env JAVA_HOME="$auth_jdk" PATH="$auth_jdk/bin:$PATH" ./gradlew test --rerun-tasks --max-workers=2 --console=plain
fi
run_check analyze "$app_dir" "$flutter_bin" analyze
echo "Logs: $run_dir"
exit "$failed"
