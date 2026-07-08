#!/usr/bin/env bash
# Demo script — shows tracedge core loop in action.
# Record with: asciinema rec demo.cast -c "bash scripts/demo.sh"
# Or paste into VHS (see demo.tape).

set -euo pipefail

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║  tracedge — skill reuse eliminates LLM calls    ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

echo "$ tracedge --version"
tracedge --version

echo ""
echo "--- Run 1: Train (baseline variants, LLM called per step) ---"
echo ""
echo "$ tracedge --demo"
tracedge --demo

echo ""
echo "--- Run 2: Reuse (skill loaded, zero LLM calls) ---"
echo ""
echo "$ python -c \""
echo "from tracedge.main import run_tracedge"
echo "from tracedge.ir.upir import UPIR, UPIRNode"
echo ""
echo "skill = UPIR("
echo "    entry='h1',"
echo "    nodes={'h1': UPIRNode(kind='harness_call', node_id='h1', harness_id='h')},"
echo "    edges=[],"
echo "    harness_table={'h': 'result = True'},"
echo ")"
echo "result = run_tracedge(variants={'reuse': skill}, llm=None, seed=42)"
echo "print(f'LLM calls: {result[\\\"llm_calls\\\"]}')"
echo "print(f'Status: {result[\\\"status\\\"]}')"
echo "\""

python -c "
from tracedge.main import run_tracedge
from tracedge.ir.upir import UPIR, UPIRNode

skill = UPIR(
    entry='h1',
    nodes={'h1': UPIRNode(kind='harness_call', node_id='h1', harness_id='h')},
    edges=[],
    harness_table={'h': 'result = True'},
)
result = run_tracedge(variants={'reuse': skill}, llm=None, seed=42)
print(f'LLM calls: {result[\"llm_calls\"]}')
print(f'Status: {result[\"status\"]}')
"

echo ""
echo "--- Benchmark summary ---"
echo ""
python -m benchmarks --dry-run --categories code_gen tool game
