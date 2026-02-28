#!/usr/bin/env bash
# NanoSpark Installer
# Usage: curl -fsSL <url>/install.sh | bash
#    or: bash install.sh [--version X.Y.Z] [--from-source]
#
# Installs NanoSpark into ~/.nanospark with a uv-managed Python environment.
# Users do NOT need Python pre-installed — uv handles everything.
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
NANOSPARK_HOME="${NANOSPARK_HOME:-$HOME/.nanospark}"
NANOSPARK_VENV="$NANOSPARK_HOME/venv"
NANOSPARK_BIN="$NANOSPARK_HOME/bin"
PYTHON_VERSION="3.12"
NANOSPARK_REPO="https://github.com/agentscope-ai/NanoSpark.git"

VERSION=""
FROM_SOURCE=false
SOURCE_DIR=""
EXTRAS=""

# ── Colors ────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    RED="\033[0;31m"
    RESET="\033[0m"
else
    BOLD="" GREEN="" YELLOW="" RED="" RESET=""
fi

info()  { printf "${GREEN}[nanospark]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[nanospark]${RESET} %s\n" "$*"; }
error() { printf "${RED}[nanospark]${RESET} %s\n" "$*" >&2; }
die()   { error "$@"; exit 1; }

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"; shift 2 ;;
        --from-source)
            FROM_SOURCE=true
            # Accept optional path argument (next arg that doesn't start with --)
            if [[ $# -ge 2 && "$2" != --* ]]; then
                SOURCE_DIR="$(cd "$2" && pwd)" || die "Directory not found: $2"
                shift
            fi
            shift ;;
        --extras)
            EXTRAS="$2"; shift 2 ;;
        -h|--help)
            cat <<EOF
NanoSpark Installer

Usage: bash install.sh [OPTIONS]

Options:
  --version <VER>       Install a specific version (e.g. 0.0.2)
  --from-source [DIR]   Install from source. If DIR is given, use that local
                        directory; otherwise clone from GitHub.
  --extras <EXTRAS>     Comma-separated optional extras to install
                        (e.g. llamacpp, mlx, llamacpp,mlx)
  -h, --help            Show this help

Environment:
  NANOSPARK_HOME        Installation directory (default: ~/.nanospark)
EOF
            exit 0 ;;
        *)
            die "Unknown option: $1 (try --help)" ;;
    esac
done

# ── OS check ──────────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
    Linux|Darwin) ;;
    *) die "Unsupported OS: $OS. This installer supports Linux and macOS only." ;;
esac

printf "${GREEN}[nanospark]${RESET} Installing NanoSpark into ${BOLD}%s${RESET}\n" "$NANOSPARK_HOME"

# ── Step 1: Ensure uv is available ───────────────────────────────────────────
ensure_uv() {
    if command -v uv &>/dev/null; then
        info "uv found: $(command -v uv)"
        return
    fi

    # Check common install locations not yet on PATH
    for candidate in "$HOME/.local/bin/uv" "$HOME/.cargo/bin/uv"; do
        if [ -x "$candidate" ]; then
            export PATH="$(dirname "$candidate"):$PATH"
            info "uv found: $candidate"
            return
        fi
    done

    info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Source the env file uv's installer creates, or add common paths
    if [ -f "$HOME/.local/bin/env" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.local/bin/env"
    fi
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    command -v uv &>/dev/null || die "Failed to install uv. Please install it manually: https://docs.astral.sh/uv/"
    info "uv installed successfully"
}

ensure_uv

# ── Step 2: Create / update virtual environment ──────────────────────────────
if [ -d "$NANOSPARK_VENV" ]; then
    info "Existing environment found, upgrading..."
else
    info "Creating Python $PYTHON_VERSION environment..."
fi

uv venv "$NANOSPARK_VENV" --python "$PYTHON_VERSION" --quiet

# Verify the venv was created
[ -x "$NANOSPARK_VENV/bin/python" ] || die "Failed to create virtual environment"
info "Python environment ready ($("$NANOSPARK_VENV/bin/python" --version))"

# ── Step 3: Install NanoSpark ────────────────────────────────────────────────────
# Build extras suffix: "" or "[llamacpp,mlx]"
EXTRAS_SUFFIX=""
if [ -n "$EXTRAS" ]; then
    EXTRAS_SUFFIX="[$EXTRAS]"
fi

## Ensure console frontend assets are in src/nanospark/console/ for source installs.
## Sets _CONSOLE_COPIED=1 if we populated the directory (so we can clean up).
_CONSOLE_COPIED=0
_CONSOLE_AVAILABLE=0
prepare_console() {
    local repo_dir="$1"
    local console_src="$repo_dir/console/dist"
    local console_dest="$repo_dir/src/nanospark/console"

    # Already populated
    if [ -f "$console_dest/index.html" ]; then
        _CONSOLE_AVAILABLE=1
        return
    fi

    # Copy pre-built assets if available (e.g. developer already ran npm build)
    if [ -d "$console_src" ] && [ -f "$console_src/index.html" ]; then
        info "Copying console frontend assets..."
        mkdir -p "$console_dest"
        cp -R "$console_src/"* "$console_dest/"
        _CONSOLE_COPIED=1
        _CONSOLE_AVAILABLE=1
        return
    fi

    # Try to build if npm is available
    if [ ! -f "$repo_dir/console/package.json" ]; then
        warn "Console source not found — the web UI won't be available."
        return
    fi

    if ! command -v npm &>/dev/null; then
        warn "npm not found — skipping console frontend build."
        warn "Install Node.js from https://nodejs.org/ then re-run this installer,"
        warn "or run 'cd console && npm ci && npm run build' manually."
        return
    fi

    info "Building console frontend (npm ci && npm run build)..."
    (cd "$repo_dir/console" && npm ci && npm run build)
    if [ -f "$console_src/index.html" ]; then
        mkdir -p "$console_dest"
        cp -R "$console_src/"* "$console_dest/"
        _CONSOLE_COPIED=1
        _CONSOLE_AVAILABLE=1
        info "Console frontend built successfully"
        return
    fi

    warn "Console build completed but index.html not found — the web UI won't be available."
}

## Remove console assets we copied into the source tree.
cleanup_console() {
    local repo_dir="$1"
    if [ "$_CONSOLE_COPIED" = 1 ]; then
        rm -rf "$repo_dir/src/nanospark/console/"*
    fi
}

if [ "$FROM_SOURCE" = true ]; then
    if [ -n "$SOURCE_DIR" ]; then
        info "Installing NanoSpark from local source: $SOURCE_DIR"
        prepare_console "$SOURCE_DIR"
        info "Installing package from source..."
        uv pip install "${SOURCE_DIR}${EXTRAS_SUFFIX}" --python "$NANOSPARK_VENV/bin/python" --prerelease=allow
        cleanup_console "$SOURCE_DIR"
    else
        info "Installing NanoSpark from source (GitHub)..."
        CLONE_DIR="$(mktemp -d)"
        trap 'rm -rf "$CLONE_DIR"' EXIT
        git clone --depth 1 "$NANOSPARK_REPO" "$CLONE_DIR"
        prepare_console "$CLONE_DIR"
        info "Installing package from source..."
        uv pip install "${CLONE_DIR}${EXTRAS_SUFFIX}" --python "$NANOSPARK_VENV/bin/python" --prerelease=allow
        # CLONE_DIR is cleaned up by trap; no need for cleanup_console
    fi
else
    PACKAGE="nanospark"
    if [ -n "$VERSION" ]; then
        PACKAGE="nanospark==$VERSION"
    fi

    info "Installing ${PACKAGE}${EXTRAS_SUFFIX} from PyPI..."
    uv pip install "${PACKAGE}${EXTRAS_SUFFIX}" --python "$NANOSPARK_VENV/bin/python" --prerelease=allow --quiet
fi

# Verify the CLI entry point exists
[ -x "$NANOSPARK_VENV/bin/nanospark" ] || die "Installation failed: nanospark CLI not found in venv"
info "NanoSpark installed successfully"

# Check console availability (for PyPI installs, check the installed package)
if [ "$_CONSOLE_AVAILABLE" = 0 ]; then
    # Check if console assets were included in the installed package
    CONSOLE_CHECK="$("$NANOSPARK_VENV/bin/python" -c "import importlib.resources, nanospark; p=importlib.resources.files('nanospark')/'console'/'index.html'; print('yes' if p.is_file() else 'no')" 2>/dev/null || echo 'no')"
    if [ "$CONSOLE_CHECK" = "yes" ]; then
        _CONSOLE_AVAILABLE=1
    fi
fi

# ── Step 4: Create wrapper script ────────────────────────────────────────────
mkdir -p "$NANOSPARK_BIN"

cat > "$NANOSPARK_BIN/nanospark" << 'WRAPPER'
#!/usr/bin/env bash
# NanoSpark CLI wrapper — delegates to the uv-managed environment.
set -euo pipefail

NANOSPARK_HOME="${NANOSPARK_HOME:-$HOME/.nanospark}"
REAL_BIN="$NANOSPARK_HOME/venv/bin/nanospark"

if [ ! -x "$REAL_BIN" ]; then
    echo "Error: NanoSpark environment not found at $NANOSPARK_HOME/venv" >&2
    echo "Please reinstall: curl -fsSL <install-url> | bash" >&2
    exit 1
fi

exec "$REAL_BIN" "$@"
WRAPPER

chmod +x "$NANOSPARK_BIN/nanospark"
info "Wrapper created at $NANOSPARK_BIN/nanospark"

# ── Step 5: Update PATH in shell profile ─────────────────────────────────────
PATH_ENTRY="export PATH=\"\$HOME/.nanospark/bin:\$PATH\""

add_to_profile() {
    local profile="$1"
    if [ -f "$profile" ] && grep -qF '.nanospark/bin' "$profile"; then
        return 0  # already present
    fi
    if [ -f "$profile" ] || [ "$2" = "create" ]; then
        printf '\n# NanoSpark\n%s\n' "$PATH_ENTRY" >> "$profile"
        info "Updated $profile"
        return 0
    fi
    return 1
}

UPDATED_PROFILE=false

case "$OS" in
    Darwin)
        add_to_profile "$HOME/.zshrc" "create" && UPDATED_PROFILE=true
        # Also update bash profile if it exists
        add_to_profile "$HOME/.bash_profile" "no-create" || true
        ;;
    Linux)
        add_to_profile "$HOME/.bashrc" "create" && UPDATED_PROFILE=true
        # Also update zshrc if it exists
        add_to_profile "$HOME/.zshrc" "no-create" || true
        ;;
esac

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}NanoSpark installed successfully!${RESET}\n"
echo ""

# Install summary
printf "  Install location:  ${BOLD}%s${RESET}\n" "$NANOSPARK_HOME"
printf "  Python:            ${BOLD}%s${RESET}\n" "$("$NANOSPARK_VENV/bin/python" --version 2>&1)"
if [ "$_CONSOLE_AVAILABLE" = 1 ]; then
    printf "  Console (web UI):  ${GREEN}available${RESET}\n"
else
    printf "  Console (web UI):  ${YELLOW}not available${RESET}\n"
    echo "                     Install Node.js and re-run to enable the web UI."
fi
echo ""

if [ "$UPDATED_PROFILE" = true ]; then
    echo "To get started, open a new terminal or run:"
    echo ""
    printf "  ${BOLD}source ~/.zshrc${RESET}  # or ~/.bashrc\n"
    echo ""
fi

echo "Then run:"
echo ""
printf "  ${BOLD}nanospark init${RESET}       # first-time setup\n"
printf "  ${BOLD}nanospark app${RESET}        # start NanoSpark\n"
echo ""
printf "To upgrade later, re-run this installer.\n"
printf "To uninstall, run: ${BOLD}nanospark uninstall${RESET}\n"
