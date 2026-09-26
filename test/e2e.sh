#!/usr/bin/env bash
# End-to-end test for the component's job script with the CLI it pins:
#   bash test/e2e.sh
# Runs the template's script, unchanged, in the default image the way a
# GitLab runner would — the pinned release is downloaded and
# checksum-verified — and uploads a real profile to test/fake_server.py.
# The test then checks what arrived: the token, the project and commit the
# CLI detected from the GitLab environment, and the uploader naming exactly
# the release the template pins. Offline apart from the download, and
# secret-free, so it gates the bump PRs a gocov release opens here; the
# GitLab pipeline on the mirror remains the test of the include itself.
set -euo pipefail

cd "$(dirname "$0")/.."
read -r want image < <(python3 - <<'PY'
import yaml
spec = list(yaml.safe_load_all(open("templates/upload.yml")))[0]["spec"]["inputs"]
print(spec["version"]["default"], spec["image"]["default"])
PY
)

dir=$(mktemp -d "$PWD/e2e-scratch.XXXXXX")
chmod 777 "$dir"
python3 - >"$dir/job.sh" <<'PY'
import yaml
job = list(yaml.safe_load_all(open("templates/upload.yml")))[1]
(name, spec), = job.items()
print("\n".join(spec["script"]))
PY
port=18765
python3 test/fake_server.py "$port" "$dir" &
server=$!
trap 'kill "$server" 2>/dev/null; rm -rf "$dir"' EXIT
for _ in $(seq 1 50); do
  (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break
  sleep 0.1
done

printf 'mode: atomic\nexample.com/m/a.go:1.1,3.2 1 1\n' >"$dir/coverage.out"
out=$(docker run --rm --network host \
  -e GOCOV_TOKEN=e2e-token -e GOCOV_SERVER="http://127.0.0.1:$port" \
  -e GOCOV_PART= -e GOCOV_IGNORE= -e GOCOV_FILES=coverage.out \
  -e GOCOV_CLI_VERSION="$want" \
  -e GITLAB_CI=true \
  -e CI_PROJECT_PATH=gocov/e2e \
  -e CI_COMMIT_SHA=0123456789abcdef0123456789abcdef01234567 \
  -e CI_COMMIT_BRANCH=main \
  -v "$dir":/work -w /work "$image" sh /work/job.sh 2>&1) || {
  echo "FAIL: the job script exited non-zero; got:"; printf '%s\n' "$out"; exit 1; }
printf '%s\n' "$out"

grep -q 'uploaded: 75.0% (3/4 statements)' <<<"$out" || {
  echo "FAIL: the CLI did not report the fake server's answer"; exit 1; }
python3 - "$dir/request.json" "$want" <<'PY'
import json, sys
req = json.load(open(sys.argv[1])); f = req["fields"]
checks = {
    "authorization": (req["authorization"], "Bearer e2e-token"),
    "repo": (f.get("repo"), "gocov/e2e"),
    "commit": (f.get("commit"), "0123456789abcdef0123456789abcdef01234567"),
    "branch": (f.get("branch"), "main"),
    "uploader": (f.get("uploader"), "gocov " + sys.argv[2]),
}
bad = [f"{k}: got {g!r}, want {w!r}" for k, (g, w) in checks.items() if g != w]
if "example.com/m/a.go" not in f.get("profile", ""):
    bad.append("profile: the coverage file did not arrive")
if bad:
    print("FAIL:\n  " + "\n  ".join(bad)); sys.exit(1)
PY
echo "e2e passed: $want uploaded through the component's job script in $image"
