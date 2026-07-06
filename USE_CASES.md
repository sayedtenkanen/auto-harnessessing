# AutoHarness — Use Cases & Detailed Instructions

## Table of Contents

1. [Use Case 1: Self-Improving Coding Agent](#use-case-1-self-improving-coding-agent)
2. [Use Case 2: Automated Data Pipeline](#use-case-2-automated-data-pipeline)
3. [Use Case 3: Game Strategy Discovery](#use-case-3-game-strategy-discovery)
4. [Use Case 4: Multi-Step Research Assistant](#use-case-4-multi-step-research-assistant)
5. [Use Case 5: Tool-Augmented Agent with Skill Reuse](#use-case-5-tool-augmented-agent-with-skill-reuse)
6. [Use Case 6: Custom Agent from Scratch](#use-case-6-custom-agent-from-scratch)

---

## Use Case 1: Self-Improving Coding Agent

**Scenario:** An agent that writes code, runs tests, and fixes errors — learning from successful fix patterns.

### What AutoHarness does
1. Watches the agent succeed at "write → test → fix" cycles
2. Extracts the repeated pattern as a reusable skill
3. Reuses the skill in future coding tasks, reducing token cost

### Step-by-step

#### 1. Define the coding agent UPIR

```python
from autoharness.ir.upir import UPIR, UPIRNode, Edge
from autoharness.runtime.vm import VM
from autoharness.environment.tool_env import ToolEnvironment
from autoharness.reward.scorer import score_trace, value

# Define the agent's workflow
coding_agent = UPIR(
    entry="read_task",
    nodes={
        "read_task": UPIRNode(
            kind="observe", node_id="read_task",
            query="Read the task description and existing code"
        ),
        "write_code": UPIRNode(
            kind="act", node_id="write_code",
            tool="write_file", args={"filename": "solution.py", "content": ""}
        ),
        "run_tests": UPIRNode(
            kind="act", node_id="run_tests",
            tool="execute", args={"command": "pytest tests/ -x"}
        ),
        "check_result": UPIRNode(
            kind="branch", node_id="check_result",
            condition="tests_passed"
        ),
        "fix_code": UPIRNode(
            kind="act", node_id="fix_code",
            tool="write_file", args={"filename": "solution.py", "content": ""}
        ),
        "done": UPIRNode(
            kind="act", node_id="done",
            tool="respond", args={"message": "All tests pass!"}
        ),
    },
    edges=[
        Edge(from_="read_task", to="write_code", kind="sequential"),
        Edge(from_="write_code", to="run_tests", kind="sequential"),
        Edge(from_="run_tests", to="check_result", kind="sequential"),
        Edge(from_="check_result", to="done", kind="branch_false"),      # tests passed → done
        Edge(from_="check_result", to="fix_code", kind="branch_true"),   # tests failed → fix
        Edge(from_="fix_code", to="run_tests", kind="sequential"),       # loop back
    ],
)
```

#### 2. Create a coding LLM

```python
class CodingLLM:
    def __init__(self):
        self.fix_count = 0

    def chat(self, prompt: str) -> str:
        if "fix" in prompt.lower() or "error" in prompt.lower():
            self.fix_count += 1
            return "Fixed the bug by adding input validation"
        return "Writing solution code..."
```

#### 3. Run the agent

```python
env = ToolEnvironment(workspace="/tmp/coding_agent")
llm = CodingLLM()

vm = VM(upir=coding_agent, llm=llm, seed=42, environment=env)
trace = vm.run()

# Score the execution
reward = score_trace(trace, env_kind="tool")
print(f"Reward: {value(reward):.2f}")  # e.g., 0.85
```

#### 4. Extract skills from successful runs

```python
from autoharness.skills.extractor import SkillExtractor
from autoharness.trace.trace_ir import TraceEvent, TraceLog

# Run the agent multiple times
traces = []
for i in range(3):
    vm = VM(upir=coding_agent, llm=CodingLLM(), seed=i, environment=env)
    trace = vm.run()
    traces.append(trace)

# Convert to TraceLog for skill extraction
trace_log = TraceLog()
for t in traces:
    for event in t:
        trace_log.append(TraceEvent(
            node_id=event.get("node_id", ""),
            kind=event.get("kind", ""),
        ))

# Extract patterns
extractor = SkillExtractor(min_occurrences=2)
patterns = extractor.detect_patterns(trace_log)

for pattern in patterns:
    skill_node = extractor.extract_skill(pattern, coding_agent)
    if skill_node is not None:
        print(f"Extracted skill: {skill_node.skill_id}")
```

#### 5. Use extracted skills

```python
# The skill is now available for reuse
print(f"Available skills: {list(extractor.skill_table.keys())}")

# Create a new UPIR that uses the extracted skill
optimized_agent = UPIR(
    entry="read_task",
    nodes={
        "read_task": UPIRNode(kind="observe", node_id="read_task", query="Read task"),
        "use_skill": UPIRNode(
            kind="skill_call", node_id="use_skill",
            skill_id=skill_node.skill_id
        ),
    },
    edges=[Edge(from_="read_task", to="use_skill", kind="sequential")],
    skill_table=extractor.skill_table,
)

# Run with the optimized agent — fewer tokens, same result
vm = VM(upir=optimized_agent, llm=llm, seed=42, environment=env)
trace = vm.run()
```

#### 6. Prune low-quality skills

```python
from autoharness.skills.pruner import SkillPruner

pruner = SkillPruner(
    skill_table=extractor.skill_table,
    stats={
        skill_node.skill_id: {"usage": 10, "successes": 8},
    },
    min_success_rate=0.5,
)
pruned = pruner.prune()
print(f"Remaining skills: {list(pruned.keys())}")
```

---

## Use Case 2: Automated Data Pipeline

**Scenario:** An agent that reads data files, transforms them, and writes outputs — learning which transformation patterns work.

### What AutoHarness does
1. Watches the agent process data successfully
2. Extracts the "read → transform → validate → write" pattern
3. Reuses the skill for similar data processing tasks

### Step-by-step

#### 1. Define the pipeline UPIR

```python
pipeline = UPIR(
    entry="read_data",
    nodes={
        "read_data": UPIRNode(
            kind="act", node_id="read_data",
            tool="read_file", args={"path": "input.csv"}
        ),
        "transform": UPIRNode(
            kind="harness_call", node_id="transform",
            harness_id="csv_transform"
        ),
        "validate": UPIRNode(
            kind="harness_call", node_id="validate",
            harness_id="schema_check"
        ),
        "is_valid": UPIRNode(
            kind="branch", node_id="is_valid",
            condition="validation_passed"
        ),
        "write_output": UPIRNode(
            kind="act", node_id="write_output",
            tool="write_file", args={"path": "output.csv"}
        ),
        "log_error": UPIRNode(
            kind="act", node_id="log_error",
            tool="respond", args={"message": "Validation failed"}
        ),
    },
    edges=[
        Edge(from_="read_data", to="transform", kind="sequential"),
        Edge(from_="transform", to="validate", kind="sequential"),
        Edge(from_="validate", to="is_valid", kind="sequential"),
        Edge(from_="is_valid", to="write_output", kind="branch_false"),
        Edge(from_="is_valid", to="log_error", kind="branch_true"),
    ],
    harness_table={
        "csv_transform": {
            "code": "result = [row.upper() for row in inputs.get('data', [])]",
        },
        "schema_check": {
            "code": "result = {'valid': True, 'errors': []}",
        },
    },
)
```

#### 2. Run and score

```python
env = ToolEnvironment(workspace="/tmp/pipeline")
vm = VM(upir=pipeline, llm=SimpleLLM(), seed=42, environment=env)
trace = vm.run()

reward = score_trace(trace, env_kind="tool")
print(f"Pipeline reward: {value(reward):.2f}")
```

#### 3. Extract the pipeline pattern

```python
trace_log = TraceLog()
for event in trace:
    trace_log.append(TraceEvent(
        node_id=event["node_id"],
        kind=event["kind"],
    ))

extractor = SkillExtractor(min_occurrences=2)
patterns = extractor.detect_patterns(trace_log)

for pattern in patterns:
    skill = extractor.extract_skill(pattern, pipeline)
    if skill is not None:
        print(f"Pipeline skill extracted: {skill.skill_id}")
```

#### 4. Persist the skill

```python
from pathlib import Path
from autoharness.memory.store import MemoryStore

store = MemoryStore(data_dir=Path("./pipeline_memory"))

# Save the skill stats
store.save_skill_stats(
    skill.skill_id,
    usage=5,
    successes=4,
)

# Load later
stats = store.load_skill_stats(skill.skill_id)
print(f"Skill stats: {stats}")
```

---

## Use Case 3: Game Strategy Discovery

**Scenario:** An agent playing Tic-Tac-Toe, discovering winning strategies through Thompson search.

### What AutoHarness does
1. Defines multiple strategies as UPIR graphs
2. Uses Thompson sampling to explore which strategies win most
3. Compiles winning strategies into reusable skills

### Step-by-step

#### 1. Define strategies

```python
from autoharness.ir.upir import UPIR, UPIRNode, Edge
from autoharness.environment.game_env import GameEnvironment

# Strategy 1: Always take center
center_first = UPIR(
    entry="observe",
    nodes={
        "observe": UPIRNode(kind="observe", node_id="observe", query="Get board state"),
        "act": UPIRNode(kind="act", node_id="act", tool="make_move", args={"position": 4}),
    },
    edges=[Edge(from_="observe", to="act", kind="sequential")],
)

# Strategy 2: Take corners
corner_first = UPIR(
    entry="observe",
    nodes={
        "observe": UPIRNode(kind="observe", node_id="observe", query="Get board state"),
        "act": UPIRNode(kind="act", node_id="act", tool="make_move", args={"position": 0}),
    },
    edges=[Edge(from_="observe", to="act", kind="sequential")],
)

# Strategy 3: Random
random_strategy = UPIR(
    entry="observe",
    nodes={
        "observe": UPIRNode(kind="observe", node_id="observe", query="Get board state"),
        "act": UPIRNode(kind="act", node_id="act", tool="make_move"),
    },
    edges=[Edge(from_="observe", to="act", kind="sequential")],
)
```

#### 2. Run Thompson search

```python
from autoharness.search.thompson import ThompsonTreeSearch, SearchConfig
from autoharness.ir.harness import Harness

strategies = {
    "center_first": center_first,
    "corner_first": corner_first,
    "random": random_strategy,
}

config = SearchConfig(
    max_search_iterations=30,
    max_total_failures=5,
    prior_alpha=1.0,
    prior_beta=1.0,
)

search = ThompsonTreeSearch(config=config, env_kind="game")

# Add each strategy as a branch
for name, upir in strategies.items():
    harness = Harness(kind="policy", code=f"# {name}")
    search.add_branch(harness)

def play_game(harness, seed):
    # Look up which strategy this branch represents
    strategy_name = harness.code.lstrip("# ").strip()
    upir = strategies[strategy_name]
    env = GameEnvironment()
    env.reset(seed=seed)

    vm = VM(upir=upir, llm=GameLLM(), seed=seed, environment=env)
    trace = vm.run()

    reward = score_trace(trace, env_kind="game")
    return value(reward, env_kind="game"), False

result = search.run(rollout_fn=play_game, rng_seed=42)
if result.best_branch is not None:
    print(f"Best strategy: {result.best_branch.harness.code}")
```

#### 3. Extract winning skill

```python
# Run the best strategy to get a trace for extraction
best_harness = result.best_branch.harness
strategy_name = best_harness.code.lstrip("# ").strip()
best_upir = strategies[strategy_name]

vm = VM(upir=best_upir, llm=GameLLM(), seed=42, environment=GameEnvironment())
trace = vm.run()

# Build TraceLog and extract
trace_log = TraceLog()
for event in trace:
    trace_log.append(TraceEvent(node_id=event["node_id"], kind=event["kind"]))

extractor = SkillExtractor(min_occurrences=1)
patterns = extractor.detect_patterns(trace_log)

for pattern in patterns:
    skill_node = extractor.extract_skill(pattern, best_upir)
    if skill_node is not None:
        print(f"Winning skill: {skill_node.skill_id}")
```

---

## Use Case 4: Multi-Step Research Assistant

**Scenario:** An agent that researches topics, summarizes findings, and formats output — learning the research→summarize pipeline.

### What AutoHarness does
1. Watches the agent complete research tasks
2. Extracts the "research → summarize → format" pattern
3. Reuses the skill for future research queries

### Step-by-step

#### 1. Define the research agent

```python
research_agent = UPIR(
    entry="research",
    nodes={
        "research": UPIRNode(
            kind="observe", node_id="research",
            query="Research the topic thoroughly"
        ),
        "summarize": UPIRNode(
            kind="think", node_id="summarize",
            prompt="Create a concise summary of key findings"
        ),
        "format": UPIRNode(
            kind="act", node_id="format",
            tool="write_file", args={"path": "report.md"}
        ),
        "check_quality": UPIRNode(
            kind="branch", node_id="check_quality",
            condition="summary_quality >= 0.8"
        ),
        "revise": UPIRNode(
            kind="think", node_id="revise",
            prompt="Improve the summary based on feedback"
        ),
    },
    edges=[
        Edge(from_="research", to="summarize", kind="sequential"),
        Edge(from_="summarize", to="format", kind="sequential"),
        Edge(from_="format", to="check_quality", kind="sequential"),
        Edge(from_="check_quality", to="revise", kind="branch_true"),
        Edge(from_="check_quality", to="summarize", kind="branch_false"),  # Done
    ],
)
```

#### 2. Run and extract skills

```python
vm = VM(upir=research_agent, llm=ResearchLLM(), seed=42)
trace = vm.run()

# Score
reward = score_trace(trace, env_kind="tool")
print(f"Research quality: {value(reward):.2f}")

# Extract the research→summarize pattern
trace_log = TraceLog()
for event in trace:
    trace_log.append(TraceEvent(node_id=event["node_id"], kind=event["kind"]))

extractor = SkillExtractor(min_occurrences=2)
patterns = extractor.detect_patterns(trace_log)

for pattern in patterns:
    skill = extractor.extract_skill(pattern, research_agent)
    if skill is not None:
        print(f"Research skill: {skill.skill_id}")
```

#### 3. Use the skill for new topics

```python
new_research = UPIR(
    entry="topic",
    nodes={
        "topic": UPIRNode(
            kind="observe", node_id="topic",
            query="Research quantum computing advances"
        ),
        "use_research_skill": UPIRNode(
            kind="skill_call", node_id="use_research_skill",
            skill_id=skill.skill_id
        ),
    },
    edges=[Edge(from_="topic", to="use_research_skill", kind="sequential")],
    skill_table=extractor.skill_table,
)
```

---

## Use Case 5: Tool-Augmented Agent with Skill Reuse

**Scenario:** An agent that reads files, processes data, and writes outputs — capturing successful tool-use patterns.

### What AutoHarness does
1. Watches the agent use tools successfully
2. Extracts tool-use patterns (e.g., "read → parse → validate → write")
3. Reuses the pattern for similar file operations

### Step-by-step

#### 1. Define the tool agent

```python
tool_agent = UPIR(
    entry="scan",
    nodes={
        "scan": UPIRNode(
            kind="act", node_id="scan",
            tool="read_file", args={"path": "config.yaml"}
        ),
        "parse": UPIRNode(
            kind="harness_call", node_id="parse",
            harness_id="yaml_parser"
        ),
        "validate": UPIRNode(
            kind="harness_call", node_id="validate",
            harness_id="config_validator"
        ),
        "write": UPIRNode(
            kind="act", node_id="write",
            tool="write_file", args={"path": "validated_config.yaml"}
        ),
    },
    edges=[
        Edge(from_="scan", to="parse", kind="sequential"),
        Edge(from_="parse", to="validate", kind="sequential"),
        Edge(from_="validate", to="write", kind="sequential"),
    ],
    harness_table={
        "yaml_parser": {
            "code": "result = inputs.get('data', '')",
        },
        "config_validator": {
            "code": "result = {'valid': True, 'errors': []}",
        },
    },
)
```

#### 2. Run and persist

```python
from pathlib import Path
from autoharness.memory.store import MemoryStore

store = MemoryStore(data_dir=Path("./tool_memory"))

# Run
vm = VM(upir=tool_agent, llm=SimpleLLM(), seed=42, environment=ToolEnvironment("/tmp"))
trace = vm.run()

# Save episode
reward = score_trace(trace, env_kind="tool")
store.save_episode("tool_run_1", trace, reward=value(reward))

# Extract and save skill
trace_log = TraceLog()
for event in trace:
    trace_log.append(TraceEvent(node_id=event["node_id"], kind=event["kind"]))

extractor = SkillExtractor(min_occurrences=2)
patterns = extractor.detect_patterns(trace_log)

for pattern in patterns:
    skill = extractor.extract_skill(pattern, tool_agent)
    if skill is not None:
        store.save_skill_stats(skill.skill_id, usage=1, successes=1)
```

---

## Use Case 6: Custom Agent from Scratch

**Scenario:** Building a completely custom agent with AutoHarness.

### Step-by-step

#### 1. Plan your agent's workflow

Before writing code, sketch your agent's execution flow:

```
[Start] → [Observe] → [Think] → [Act] → [Check] → [End]
                                        ↓
                                   [Fix] → [Check]
```

#### 2. Define nodes

```python
from autoharness.ir.upir import UPIR, UPIRNode, Edge

nodes = {
    "start": UPIRNode(
        kind="observe",
        node_id="start",
        query="What task should I complete?"
    ),
    "plan": UPIRNode(
        kind="think",
        node_id="plan",
        prompt="Create a step-by-step plan"
    ),
    "execute": UPIRNode(
        kind="act",
        node_id="execute",
        tool="execute_plan"
    ),
    "check": UPIRNode(
        kind="branch",
        node_id="check",
        condition="task_complete"
    ),
    "fix": UPIRNode(
        kind="think",
        node_id="fix",
        prompt="Analyze what went wrong and fix it"
    ),
    "done": UPIRNode(
        kind="act",
        node_id="done",
        tool="respond",
        args={"message": "Task complete!"}
    ),
}
```

#### 3. Define edges

```python
edges = [
    Edge(from_="start", to="plan", kind="sequential"),
    Edge(from_="plan", to="execute", kind="sequential"),
    Edge(from_="execute", to="check", kind="sequential"),
    Edge(from_="check", to="done", kind="branch_false"),   # task not complete → done
    Edge(from_="check", to="fix", kind="branch_true"),     # task complete → needs fix
    Edge(from_="fix", to="execute", kind="sequential"),    # loop back
]
```

#### 4. Create the UPIR

```python
upir = UPIR(
    entry="start",
    nodes=nodes,
    edges=edges,
)
```

#### 5. Implement your LLM

```python
class MyLLM:
    def chat(self, prompt: str) -> str:
        if "plan" in prompt.lower():
            return "Step 1: Read input\nStep 2: Process\nStep 3: Output"
        elif "fix" in prompt.lower():
            return "The issue was X, fixing by Y"
        elif "complete" in prompt.lower():
            return "false"  # Not complete yet
        return "Processing..."
```

#### 6. Run and iterate

```python
vm = VM(upir=upir, llm=MyLLM(), seed=42)
trace = vm.run()

# Inspect
for event in trace:
    print(f"{event['kind']}: {event.get('outputs', {})}")

# Score
from autoharness.reward.scorer import score_trace, value
reward = score_trace(trace, env_kind="tool")
print(f"Score: {value(reward):.2f}")
```

#### 7. Extract skills after multiple runs

```python
traces = []
for i in range(5):
    vm = VM(upir=upir, llm=MyLLM(), seed=i)
    trace = vm.run()
    traces.append(trace)

from autoharness.skills.extractor import SkillExtractor
from autoharness.trace.trace_ir import TraceEvent, TraceLog

trace_log = TraceLog()
for t in traces:
    for event in t:
        trace_log.append(TraceEvent(
            node_id=event["node_id"],
            kind=event["kind"],
        ))

extractor = SkillExtractor(min_occurrences=2)
patterns = extractor.detect_patterns(trace_log)

print(f"Found {len(patterns)} reusable patterns")
for p in patterns:
    skill = extractor.extract_skill(p, upir)
    if skill is not None:
        print(f"  Skill: {skill.skill_id}")
```

#### 8. Optimize with Thompson search

```python
from autoharness.search.thompson import ThompsonTreeSearch, SearchConfig
from autoharness.ir.harness import Harness

variants = {
    "fast": fast_upir,
    "thorough": thorough_upir,
    "balanced": balanced_upir,
}

config = SearchConfig(max_search_iterations=20, max_total_failures=3)
search = ThompsonTreeSearch(config=config)

for name, v_upir in variants.items():
    search.add_branch(Harness(kind="policy", code=f"# {name}"))

def rollout(harness, seed):
    name = harness.code.lstrip("# ").strip()
    vm = VM(upir=variants[name], llm=MyLLM(), seed=seed)
    trace = vm.run()
    r = score_trace(trace, env_kind="tool")
    return value(r), False

result = search.run(rollout_fn=rollout)
if result.best_branch is not None:
    print(f"Best variant: {result.best_branch.harness.code}")
```

#### 9. Persist everything

```python
from pathlib import Path
from autoharness.memory.store import MemoryStore

store = MemoryStore(data_dir=Path("./my_agent_memory"))

# Save episodes
for i, trace in enumerate(traces):
    reward = score_trace(trace, env_kind="tool")
    store.save_episode(f"run_{i}", trace, reward=value(reward))

# Save skill stats
for skill_id in extractor.skill_table:
    store.save_skill_stats(skill_id, usage=5, successes=4)

# Save global stats
store.save_global_stats(total_runs=5, success_rate=0.8)
```

---

## Quick Reference: Common Patterns

| Pattern | How |
|---------|-----|
| **Run an agent** | `VM(upir, llm, seed).run()` |
| **Score a trace** | `score_trace(trace, env_kind="tool")` |
| **Extract skills** | `SkillExtractor(min_occurrences).detect_patterns(trace_log)` |
| **Prune skills** | `SkillPruner(table, stats, min_success_rate).prune()` |
| **Search strategies** | `ThompsonTreeSearch(config).run(rollout_fn)` |
| **Improve harness** | `Refiner(llm_fn).refine(harness, feedback)` |
| **Save data** | `MemoryStore(data_dir).save_episode(id, trace, reward)` |
| **Load data** | `MemoryStore(data_dir).load_episode(id)` |
