#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="$REPO_ROOT/Dockerfile"

echo "=== Running Workspace Symlink Tests ==="

# Check 1: Dockerfile must define the build-time symlink
echo -n "Checking Dockerfile for build-time symlink... "
if grep -E 'RUN ln -s[f]? /workspace /root/Documents' "$DOCKERFILE" >/dev/null; then
    echo "OK"
else
    echo "FAILED"
    echo "Error: Dockerfile missing 'RUN ln -s /workspace /root/Documents'" >&2
    exit 1
fi

# Check 2: Dockerfile's entrypoint.sh section must contain the runtime check (safe against dangling symlinks)
echo -n "Checking entrypoint.sh in Dockerfile for runtime symlink guarantee... "
if grep -F '[ -e /root/Documents ] || [ -L /root/Documents ] || ln -s /workspace /root/Documents' "$DOCKERFILE" >/dev/null; then
    echo "OK"
else
    echo "FAILED"
    echo "Error: entrypoint script in Dockerfile missing hardened '[ -e /root/Documents ] || [ -L /root/Documents ] || ln -s /workspace /root/Documents'" >&2
    exit 1
fi

# Check 3: Runtime simulation of symlink creation
echo -n "Testing runtime symlink creation and resolution... "
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

MOCK_ROOT="$TEST_DIR/root"
MOCK_WORKSPACE="$TEST_DIR/workspace"
mkdir -p "$MOCK_ROOT" "$MOCK_WORKSPACE"

# Simulate the entrypoint command inside the mock environment
(
    TARGET="$MOCK_WORKSPACE"
    LINK="$MOCK_ROOT/Documents"
    [ -e "$LINK" ] || ln -s "$TARGET" "$LINK"
)

if [ ! -L "$MOCK_ROOT/Documents" ]; then
    echo "FAILED"
    echo "Error: Expected $MOCK_ROOT/Documents to be a symlink." >&2
    exit 1
fi

RESOLVED_TARGET="$(readlink "$MOCK_ROOT/Documents")"
if [ "$RESOLVED_TARGET" != "$MOCK_WORKSPACE" ]; then
    echo "FAILED"
    echo "Error: Symlink resolved to '$RESOLVED_TARGET', expected '$MOCK_WORKSPACE'" >&2
    exit 1
fi
echo "OK"

# Check 4: Idempotency check (running snippet again should not error or overwrite)
echo -n "Testing runtime symlink idempotency... "
(
    TARGET="$MOCK_WORKSPACE"
    LINK="$MOCK_ROOT/Documents"
    [ -e "$LINK" ] || [ -L "$LINK" ] || ln -s "$TARGET" "$LINK"
)
echo "OK"

# Check 5: Dangling symlink safety (when target is missing, [ -e ] is false but [ -L ] is true)
echo -n "Testing runtime safety with dangling symlinks... "
DANGLING_ROOT="$TEST_DIR/dangling_root"
mkdir -p "$DANGLING_ROOT"
# Create a dangling symlink pointing to a non-existent directory
ln -s "$TEST_DIR/nonexistent_workspace" "$DANGLING_ROOT/Documents"

# Running the hardened snippet under set -e must not attempt ln -s and fail
(
    set -e
    TARGET="$TEST_DIR/nonexistent_workspace"
    LINK="$DANGLING_ROOT/Documents"
    [ -e "$LINK" ] || [ -L "$LINK" ] || ln -s "$TARGET" "$LINK"
)
echo "OK"

echo "=== All Tests Passed Successfully ==="
