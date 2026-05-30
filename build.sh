#!/bin/bash
set -e

OPT_DIR="/opt"
CUSTOM_DIR="$OPT_DIR/custom"
OPENWRT_SRC="/opt/openwrt-src"
OPENWRT_DIR="/home/builder/openwrt"
OUTPUT_DIR="/home/builder/output"

usage() {
    echo "Usage: $0 <command> <config> [config...]"
    echo ""
    echo "Commands:"
    echo "  prepare <configs...>  Apply patches, merge configs, run defconfig"
    echo "  build <configs...>    Prepare + compile firmware"
    echo ""
    echo "Examples:"
    echo "  $0 prepare custom/configs/common.config custom/configs/tr.config"
    echo "  $0 build custom/configs/common.config custom/configs/mt7981.config"
    echo ""
    echo "Environment variables for build:"
    echo "  MAKE_JOBS     Number of parallel jobs (default: \$(nproc))"
    echo "  MAKE_OPTS     Extra make options (e.g. V=s for debug)"
    exit 1
}

prepare() {
    local configs=("$@")

    for cfg in "${configs[@]}"; do
        local path="$OPT_DIR/$cfg"
        if [ ! -f "$path" ]; then
            echo "Error: config not found: $path"
            exit 1
        fi
    done

    echo "=== Preparing ==="

    if [ ! -d "$OPENWRT_DIR/.git" ]; then
        echo "[0/7] Copying OpenWrt source tree..."
        cp -a "$OPENWRT_SRC"/. "$OPENWRT_DIR/"
    else
        echo "[0/7] Resetting source tree..."
        git -C "$OPENWRT_DIR" checkout -- .
        git -C "$OPENWRT_DIR" clean -fd -e feeds/
    fi

    if [ -d "$CUSTOM_DIR" ]; then
        echo "[1/7] Applying base-files patches..."
        for patch in "$CUSTOM_DIR"/base-files/*.patch; do
            [ -f "$patch" ] || continue
            echo "  $(basename "$patch")"
            git -C "$OPENWRT_DIR" apply "$patch"
        done

        echo "[2/7] Copying base-files overlay..."
        if [ -d "$CUSTOM_DIR/base-files/etc" ]; then
            cp -rv "$CUSTOM_DIR/base-files/etc" "$OPENWRT_DIR/package/base-files/files/"
        fi

        echo "[3/7] Copying device files..."
        for device_dir in "$CUSTOM_DIR"/devices/*/; do
            [ -d "$device_dir/files" ] || continue
            device=$(basename "$device_dir")
            echo "  Device: $device"
            cp -rv "$device_dir/files/"* "$OPENWRT_DIR/"
        done

        echo "[4/7] Applying device patches..."
        for device_dir in "$CUSTOM_DIR"/devices/*/; do
            [ -d "$device_dir/patches" ] || continue
            device=$(basename "$device_dir")
            for patch in "$device_dir"/patches/**/*.patch; do
                [ -f "$patch" ] || continue
                echo "  [$device] $(basename "$patch")"
                git -C "$OPENWRT_DIR" apply "$patch"
            done
        done
    else
        echo "[1-4/7] No custom directory, skipping patches and devices"
    fi

    # radcli install-exec-hook uses `ln -s` (not -sf); a stale symlink in the
    # cached build_dir makes it fail on rebuild. Force a clean rebuild.
    rm -rf "$OPENWRT_DIR"/build_dir/target-*/radcli-*

    echo "[5/7] Updating feeds..."
    "$OPENWRT_DIR"/scripts/feeds update -a
    "$OPENWRT_DIR"/scripts/feeds install -a

    echo "[6/7] Generating .config..."
    : > "$OPENWRT_DIR/.config"
    for cfg in "${configs[@]}"; do
        local path="$OPT_DIR/$cfg"
        echo "  + $cfg"
        cat "$path" >> "$OPENWRT_DIR/.config"
    done
    make -C "$OPENWRT_DIR" defconfig

    echo "[7/7] Downloading sources..."
    make -C "$OPENWRT_DIR" download -j"${MAKE_JOBS:-$(nproc)}"

    echo "=== Prepare done ==="
}

build() {
    local jobs="${MAKE_JOBS:-$(nproc)}"

    prepare "$@"

    local log="$OPENWRT_DIR/logs/build.log"

    echo "=== Building (jobs=$jobs) ==="
    echo "=== Log: $log ==="
    set +e
    make -C "$OPENWRT_DIR" -j"$jobs" ${MAKE_OPTS} 2>&1 | tee "$log"
    local rc=${PIPESTATUS[0]}
    set -e

    if [ "$rc" -ne 0 ]; then
        echo ""
        echo "=== Build failed. Errors: ==="
        grep -i "error:" "$log" | grep -v "Warning" | tail -20
        exit "$rc"
    fi

    echo "=== Copying output ==="
    cp -rv "$OPENWRT_DIR"/bin/targets/*/* "$OUTPUT_DIR/"
    echo "=== Build done. Output: $OUTPUT_DIR ==="
}

case "${1:-}" in
    prepare)
        shift
        [ $# -gt 0 ] || usage
        prepare "$@"
        ;;
    build)
        shift
        [ $# -gt 0 ] || usage
        build "$@"
        ;;
    *)
        usage
        ;;
esac
