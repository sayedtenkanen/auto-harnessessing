Output demo.gif
Width 120
Height 30
FontSize 16
FontFamily "JetBrains Mono"
Theme "Dracula"

Shell "bash"

Type "echo ''"
Enter
Type "echo '  tracedge — skill reuse eliminates LLM calls'"
Enter
Sleep 1s

Type "echo ''"
Enter
Type "echo '--- Run 1: Train (baseline, LLM called per step) ---'"
Enter
Sleep 500ms

Type "tracedge --demo"
Enter
Sleep 3s

Type "echo ''"
Enter
Type "echo '--- Run 2: Reuse (skill loaded, zero LLM calls) ---'"
Enter
Sleep 500ms

Type "python -c \"from tracedge.main import run_tracedge; from tracedge.ir.upir import UPIR, UPIRNode; skill = UPIR(entry='h1', nodes={'h1': UPIRNode(kind='harness_call', node_id='h1', harness_id='h')}, edges=[], harness_table={'h': 'result = True'}); result = run_tracedge(variants={'reuse': skill}, llm=None, seed=42); print(f'LLM calls: {result[\\\"llm_calls\\\"]}'); print(f'Status: {result[\\\"status\\\"]}')\""
Enter
Sleep 2s

Type "echo ''"
Enter
Type "python -m benchmarks --dry-run --categories code_gen tool game"
Enter
Sleep 2s
