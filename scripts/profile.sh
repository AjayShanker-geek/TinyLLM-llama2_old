#!/usr/bin/env bash
# Build and profile the benchmark binaries inside the Docker container.
#
#   docker compose run --rm bench bash scripts/profile.sh                      # all binaries
#   docker compose run --rm bench bash scripts/profile.sh run_int8_baseline    # just one
#
# Settings can be overridden with environment variables, e.g.
#   docker compose run --rm -e STEPS=64 -e RUNS=3 bench bash scripts/profile.sh
#
# Results go to logs/profile/<timestamp>/<binary>/.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build-docker"
GPROF_BUILD_DIR="$ROOT/build-docker-gprof"
LOG_ROOT="$ROOT/${LOG_ROOT:-logs/profile/$(date +%Y%m%d-%H%M%S)}"

FP32_MODEL="${FP32_MODEL:-models/stories110M.bin}"
INT8_MODEL="${INT8_MODEL:-models/stories110M_int8.bin}"
TOKENIZER="${TOKENIZER:-models/tokenizer.bin}"
PROMPT="${PROMPT:-Once upon a time}"
SEED="${SEED:-42}"
STEPS="${STEPS:-128}"
VALGRIND_STEPS="${VALGRIND_STEPS:-16}" # valgrind is ~50x slower
RUNS="${RUNS:-5}"
THREADS_SWEEP="${THREADS_SWEEP:-1,2,4,8}"

# Fixed simulated cache for cachegrind, so miss counts match on every machine
CACHEGRIND_CACHE=(--I1=32768,8,64 --D1=32768,8,64 --LL=8388608,16,64)

ALL_BINARIES=(run_fp32_baseline run_int8_baseline run_fp32_simd run_fp32_openmp)
if (($#)); then BINARIES=("$@"); else BINARIES=("${ALL_BINARIES[@]}"); fi

FAILURES=()

log() { printf '\n==> %s\n' "$*"; }

# Run one profiling step; a failure is recorded but does not stop the others.
# set -e is suspended inside `if`, so multi-command steps chain with &&.
step() {
    local name="$1"; shift
    log "$name"
    if ! "$@"; then
        echo "!! $name failed" >&2
        FAILURES+=("$name")
    fi
}

model_for() {
    case "$1" in
        run_int8_baseline) echo "$INT8_MODEL" ;;
        *)                 echo "$FP32_MODEL" ;;
    esac
}

# Print the command-line arguments for a binary, one per line
args_for() {
    local bin="$1" steps="$2"
    printf '%s\n' "$ROOT/$(model_for "$bin")" -z "$ROOT/$TOKENIZER" \
        -t 0 -s "$SEED" -n "$steps" -i "$PROMPT"
}

check_inputs() {
    local missing=0 bin file
    for bin in "${BINARIES[@]}"; do
        for file in "$(model_for "$bin")" "$TOKENIZER"; do
            if [[ ! -f "$file" ]]; then
                echo "Missing $file (needed by $bin). Copy the shared model files into models/." >&2
                missing=1
            fi
        done
    done
    return "$missing"
}

build() {
    log "Building (normal) into ${BUILD_DIR#"$ROOT"/}"
    cmake -S . -B "$BUILD_DIR" -G Ninja -DENABLE_GPROF=OFF
    cmake --build "$BUILD_DIR"

    log "Building (gprof, -pg) into ${GPROF_BUILD_DIR#"$ROOT"/}"
    cmake -S . -B "$GPROF_BUILD_DIR" -G Ninja -DENABLE_GPROF=ON
    cmake --build "$GPROF_BUILD_DIR"
}

system_info() {
    {
        echo "# date";               date -u
        echo "# uname";              uname -a
        echo "# lscpu";              lscpu
        echo "# nproc";              nproc
        echo "# memory";             free -m
        echo "# cgroup cpu.max";     cat /sys/fs/cgroup/cpu.max 2>/dev/null || true
        echo "# cgroup cpuset";      cat /sys/fs/cgroup/cpuset.cpus.effective 2>/dev/null || true
        echo "# cgroup memory.max";  cat /sys/fs/cgroup/memory.max 2>/dev/null || true
        echo "# compiler";           gcc --version | head -n 1
        echo "# cmake";              cmake --version | head -n 1
        echo "# OpenMP env";         env | grep -E '^OMP_' || true
        echo "# settings"
        echo "STEPS=$STEPS VALGRIND_STEPS=$VALGRIND_STEPS RUNS=$RUNS SEED=$SEED PROMPT=$PROMPT"
    } > "$LOG_ROOT/system.txt"
}

# --- profiling steps --------------------------------------------------------

run_output() {   # program output once, to check results match across machines
    "$BIN" "${ARGS[@]}" > "$OUT/output.txt" 2>&1
}

run_hyperfine() {   # wall time, with warm-up and repeated runs
    hyperfine --warmup 1 --runs "$RUNS" \
        --export-json "$OUT/hyperfine.json" --export-markdown "$OUT/hyperfine.md" \
        "$(printf '%q ' "$BIN" "${ARGS[@]}")" | tee "$OUT/hyperfine.txt"
}

run_time() {   # peak memory (max RSS), page faults, context switches
    /usr/bin/time -v -o "$OUT/time.txt" "$BIN" "${ARGS[@]}" > /dev/null
}

run_gprof() {   # flat profile + call graph; gmon.out is written to the cwd
    local gbin="$GPROF_BUILD_DIR/$NAME"
    (cd "$OUT" && "$gbin" "${ARGS[@]}" > /dev/null) &&
    gprof -b "$gbin" "$OUT/gmon.out" > "$OUT/gprof.txt"
}

run_perf_stat() {   # hardware counters show "<not supported>" inside most VMs
    perf stat -o "$OUT/perf_stat.txt" \
        -e task-clock,context-switches,cpu-migrations,page-faults,cycles,instructions,cache-references,cache-misses,branches,branch-misses \
        -- "$BIN" "${ARGS[@]}" > /dev/null
}

run_perf_record() {   # sampled hotspots across all threads
    perf record -q -F 999 -e cpu-clock -g -o "$OUT/perf.data" -- "$BIN" "${ARGS[@]}" > /dev/null &&
    perf report -i "$OUT/perf.data" --stdio --no-children > "$OUT/perf_report.txt" 2>/dev/null
}

run_callgrind() {   # exact instruction counts per function
    valgrind --tool=callgrind --callgrind-out-file="$OUT/callgrind.out" \
        "$BIN" "${VG_ARGS[@]}" > /dev/null 2> "$OUT/callgrind.log" &&
    callgrind_annotate "$OUT/callgrind.out" > "$OUT/callgrind.txt"
}

run_cachegrind() {   # cache misses on a fixed simulated cache
    valgrind --tool=cachegrind --cache-sim=yes "${CACHEGRIND_CACHE[@]}" \
        --cachegrind-out-file="$OUT/cachegrind.out" \
        "$BIN" "${VG_ARGS[@]}" > /dev/null 2> "$OUT/cachegrind.log" &&
    cg_annotate "$OUT/cachegrind.out" > "$OUT/cachegrind.txt"
}

run_massif() {   # heap usage over time
    valgrind --tool=massif --massif-out-file="$OUT/massif.out" \
        "$BIN" "${VG_ARGS[@]}" > /dev/null 2> "$OUT/massif.log" &&
    ms_print "$OUT/massif.out" > "$OUT/massif.txt"
}

run_thread_sweep() {   # OpenMP scaling
    hyperfine --warmup 1 --runs "$RUNS" \
        --parameter-list threads "$THREADS_SWEEP" \
        --export-json "$OUT/thread_sweep.json" --export-markdown "$OUT/thread_sweep.md" \
        "OMP_NUM_THREADS={threads} $(printf '%q ' "$BIN" "${ARGS[@]}")" | tee "$OUT/thread_sweep.txt"
}

# --- main -------------------------------------------------------------------

check_inputs
build
mkdir -p "$LOG_ROOT"
system_info

for NAME in "${BINARIES[@]}"; do
    BIN="$BUILD_DIR/$NAME"
    OUT="$LOG_ROOT/$NAME"
    mkdir -p "$OUT"
    mapfile -t ARGS < <(args_for "$NAME" "$STEPS")
    mapfile -t VG_ARGS < <(args_for "$NAME" "$VALGRIND_STEPS")

    step "$NAME: output"      run_output
    step "$NAME: hyperfine"   run_hyperfine
    step "$NAME: time -v"     run_time
    step "$NAME: perf stat"   run_perf_stat
    step "$NAME: perf record" run_perf_record

    case "$NAME" in
        run_fp32_baseline|run_int8_baseline)
            step "$NAME: gprof"      run_gprof
            step "$NAME: callgrind"  run_callgrind
            step "$NAME: cachegrind" run_cachegrind
            step "$NAME: massif"     run_massif
            ;;
        run_fp32_simd)
            step "$NAME: gprof"      run_gprof
            step "$NAME: callgrind"  run_callgrind
            step "$NAME: cachegrind" run_cachegrind
            ;;
        run_fp32_openmp)
            # gprof only sees the main thread, so it is skipped here
            step "$NAME: thread sweep" run_thread_sweep
            ;;
    esac
done

log "Results in ${LOG_ROOT#"$ROOT"/}"
if ((${#FAILURES[@]})); then
    printf 'Failed steps:\n'
    printf '  - %s\n' "${FAILURES[@]}"
    exit 1
fi
