# PlanPRD Workflow

This workflow guides you through analyzing, researching, and planning an existing PRD to make it ready for implementation.

## Prerequisites

IMPORTANT: You MUST verify the following before proceeding.

1. **Identify the correct PRD name**
   - If PRD name is specified, use that name
   - If PRD name is NOT specified:
     1. Run `claude-PRD-list-prds` to list available PRDs
     2. Present the list to the user with their statuses
     3. Ask which PRD to plan

2. **Verify the PRD exists**
   - Check the PRD.md file exists at `.claude/prds/[prd_name]/PRD.md`
   - Verify it has the required structure (Objective, Motivation, Implementation Details, Discussion sections)
   - Run `claude-PRD-task-status <prd-name>` to understand current state

## Workflow Steps

These workflow steps MUST be followed exactly as written.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                             WORKFLOW DIAGRAM                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│      ┌──────────────────┐                                                    │
│ ┌───►│ 1. Deep Analysis │                                                    │
│ │    └────────┬─────────┘                                                    │
│ │             ▼                                                              │
│ │    ┌────────────────────┐                                                  │
│ │    │ 2. Explore Codebase│                                                  │
│ │    └────────┬───────────┘                                                  │
│ │             ▼                                                              │
│ │    ┌─────────────────────┐                                                 │
│ │    │ 3. Clarify with User│                                                 │
│ │    └────────┬────────────┘                                                 │
│ │             ▼                                                              │
│ │    ╔═══════════════════════════════════════════╗                           │
│ │    ║ 4. CHECKPOINT (Post-Clarification)        ║                           │
│ │    ║    Re-analysis required?                  ║                           │
│ │    ╚════════════╤══════════════════════════════╝                           │
│ │          Yes    │    No                                                    │
│ │◄────────────────┘    │                                                     │
│ │                      ▼                                                     │
│ │    ┌────────────────────────────┐                                          │
│ │    │ 5. Generate Research Qs    │                                          │
│ │    └────────────┬───────────────┘                                          │
│ │                 ▼                                                          │
│ │    ┌────────────────────────────┐                                          │
│ │    │ 6. Research                │─── No questions? ───┐                    │
│ │    └────────────┬───────────────┘                     │                    │
│ │                 ▼                                     ▼                    │
│ │    ╔═══════════════════════════════════════════════════════╗               │
│ │    ║ 7. CHECKPOINT (Post-Research)                         ║               │
│ │    ║    Re-analysis required?                              ║               │
│ │    ╚════════════╤══════════════════════════════════════════╝               │
│ │          Yes    │    No                                                    │
│ └◄────────────────┘    │                                                     │
│                        ▼                                                     │
│              ┌──────────────┐                                                │
│              │ 8. Refine    │                                                │
│              └──────┬───────┘                                                │
│                     ▼                                                        │
│              ┌─────────────────┐                                             │
│              │ 9. Generate Tasks│                                            │
│              └───────┬─────────┘                                             │
│                      ▼                                                       │
│              ┌───────────────────────┐                                       │
│              │ 10. Generate Task Specs│                                      │
│              └───────────┬───────────┘                                       │
│                          ▼                                                   │
│                  ┌─────────────┐                                             │
│                  │ 11. Validate│                                             │
│                  └─────────────┘                                             │
│                                                                              │
│  Legend: ════════ = CHECKPOINT (STOP and evaluate before proceeding)        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 1. Deep Analysis

Before making any changes, thoroughly analyze the PRD:

| Analysis Area | Questions to Answer |
|---------------|---------------------|
| **Completeness** | Which sections are missing or incomplete? |
| **Consistency** | Does the objective align with any existing tasks? |
| **Specificity** | Are tasks specific, measurable, and actionable? |
| **Implementation** | Are implementation details sufficient? |
| **Files** | Are all relevant files identified? |
| **Edge Cases** | Are there constraints or edge cases overlooked? |
| **Architecture** | Does the proposed structure fit the codebase? |

**Document findings:**
- List all gaps and issues found
- Prioritize by impact on implementation success
- Note any contradictions or ambiguities

### 2. Explore Codebase

Search the codebase to discover files relevant to the PRD's objective.

**Discovery Goals:**
- Find files that will need to be modified
- Identify existing patterns and utilities to leverage
- Locate similar features to use as reference
- Determine appropriate locations for new files

**Search Strategy:**
1. Use Glob to find files matching relevant patterns
2. Use Grep to search for related functionality
3. Read discovered files to understand existing patterns
4. Identify potential conflicts or architectural constraints

**Document findings:**
- List all discovered files and their relevance
- Note existing patterns and utilities to leverage
- Identify architectural constraints or conflicts
- Record any gaps in the codebase that need addressing

### 3. Clarify with User

Present your findings from Steps 1-2 to the user and ask clarifying questions.

**You MUST ask clarifying questions if ANY of these apply:**
- Ambiguities or gaps discovered during analysis
- Multiple valid implementation approaches exist
- Scope boundaries are unclear or implicit
- Architectural decisions require user input
- Trade-offs exist that affect user experience or maintainability
- The PRD references external systems or dependencies not fully specified

**You MAY skip ONLY if ALL of these are true:**
- Zero ambiguities found during analysis (document this explicitly)
- Single obvious implementation approach with no alternatives
- PRD explicitly addresses all edge cases and constraints
- All architectural decisions are already specified
- No trade-offs require user preference

**Format questions clearly:**
- Summarize what you found during exploration
- Present options with pros/cons if applicable
- Ask specific questions that enable a decision

**Mandatory output:**
Document one of the following in your response:
- "Questions asked: [list of questions]" with user responses
- "Clarification skipped: [specific reasons why ALL skip conditions are met]"

### 4. Checkpoint: Evaluate Re-analysis (Post-Clarification)

STOP. Before proceeding to research, you MUST evaluate whether user clarifications require returning to Step 1.

**Explicitly assess each condition:**

| Condition | Assessment Required |
|-----------|---------------------|
| New requirements | Did user clarifications reveal new requirements or scope changes? |
| New constraints | Did discussion uncover constraints not identified during analysis? |
| Approach changes | Do the user's answers significantly change the approach or architecture? |

**Mandatory output:**
Document one of the following:
- "Returning to Step 1: [specific clarifications that require re-analysis]"
- "Proceeding to Step 5: [explicit confirmation for each condition above]"

Do NOT proceed until you have documented your assessment.

### 5. Generate Research Questions

If there are unknowns or questions that require external research, generate a `research.yaml` file.

**When to generate research questions:**
- Implementation involves unfamiliar libraries, APIs, or tools
- Best practices are unclear
- Multiple valid approaches exist and you need guidance
- Technical details are missing from documentation

**Research Question Guidelines:**

| Rule | Description |
|------|-------------|
| **Maximum questions** | Never generate more than 25 research questions total |
| **3rd-party interfaces** | Always ask about library/tool interfaces if implementation involves external dependencies |
| **Exception** | Skip interface questions if existing codebase demonstrates clear patterns |
| **Mode selection** | Use `answer` for straightforward questions, `deep-research` sparingly for complex questions |

**research.yaml structure:**
@../schemas/research.schema.json

### 6. Research

Execute research if there are unanswered questions.

**Get unanswered questions:**
```bash
claude-PRD-get-unanswered-research [prd_name]
```

Returns a JSON array of questions with `text` and `mode` fields. If the array is empty, skip to Step 7.

**Research execution:**

For each question in the array, use the Task tool to spawn a `prd-researcher` subagent:

| Parameter | Value |
|-----------|-------|
| `subagent_type` | `"prd-researcher"` |
| `prompt` | `"Research this question: [question text]. Mode: [mode]"` |
| `description` | `"Research: [short summary]"` |
| `model` | `"haiku"` |

**Example invocation:**

For a question with `text: "What is the best OAuth flow for CLI applications?"` and `mode: "answer"`:

```
subagent_type: "prd-researcher"
prompt: "Research this question: What is the best OAuth flow for CLI applications? Mode: answer"
description: "Research: OAuth CLI flow"
model: "haiku"
```

**Execution order:**
- Launch all research subagents in parallel for efficiency
- Wait for all to complete before proceeding

**Update research.yaml with answers:**
- Populate the `answer` field with the subagent's returned answer
- Populate the `citations` array with the subagent's returned citations

### 7. Checkpoint: Evaluate Re-analysis (Post-Research)

STOP. Before refining the PRD, you MUST evaluate whether research findings require returning to Step 1.

**Explicitly assess each condition:**

| Condition | Assessment Required |
|-----------|---------------------|
| Research impact | Did research reveal information that invalidates or changes the analysis? |
| New constraints | Were architectural constraints, edge cases, or limitations discovered? |
| Approach changes | Does research suggest a different implementation approach? |
| Missing information | Did research reveal gaps that require additional user clarification? |

**Mandatory output:**
Document one of the following:
- "Returning to Step 1: [specific findings that require re-analysis]"
- "Proceeding to Step 8: [explicit confirmation for each condition above]"

Do NOT proceed until you have documented your assessment.

### 8. Refine

Review and refine the PRD based on research findings.

**Update PRD.md with research findings:**

IMPORTANT: All relevant research findings MUST be incorporated into the PRD document. The PRD should be self-contained so that research.yaml does not need to be referenced during implementation.

- Add new constraints discovered during research to the Constraints section
- Update Implementation Details with technical approaches validated by research
- Add relevant documentation links to the Relevant Guides section
- Update Architecture section with design decisions informed by research
- Answer any Discussion questions that research resolved
- Revise Relevant Files if research revealed additional files to review or modify
- Include code examples, patterns, or API details from research in Implementation Details

### 9. Generate Tasks

With research complete and user feedback incorporated, update the PRD and create tasks.

**Update PRD.md:**
- Complete the Architecture section with design decisions
- Fill in Relevant Guides with discovered documentation
- Update Relevant Files with all files discovered during exploration
- Incorporate research findings into Constraints

**Create tasks.yaml:**

All tasks must have `draft` status initially.

@../schemas/tasks.schema.json

**Task creation guidelines:**
- Top-level tasks must be worked sequentially
- Subtasks can be worked in parallel
- Each leaf task (no subtasks) needs a spec file
- Keep tasks focused and atomic
- Include clear descriptions

### 10. Generate Task Specs

Generate detailed specification files for each task. These specs will be handed off to subagents during implementation, so they must be self-contained and comprehensive.

**Read the Task Spec Template:** `.claude/specs/task-spec.md`

**Check task status:**
```bash
claude-PRD-task-status [prd_name]
```

**If draft tasks exist (`draft` > 0):**

1. Run `claude-PRD-list-draft-tasks [prd_name]` to get all draft tasks
2. For each draft task:
   - Create a detailed spec file following the Task Spec Template exactly
   - Save spec to the path defined in the task's `spec` field
   - Update task status to `defined`:
     ```bash
     claude-PRD-update-task-status [prd_name] "[task-name]" defined
     ```

**Spec file creation guidelines:**
- Be thorough but focused
- Use concrete file paths and line numbers in code references
- Make acceptance criteria verifiable and specific
- Keep "Out of Scope" clear to prevent scope creep
- If task is complex, suggest breaking into subtasks

### 11. Validate

After planning is complete, validate the PRD is ready for implementation.

**Validation checklist:**

| Check | Command/Action | Pass Criteria |
|-------|----------------|---------------|
| Research complete | `claude-PRD-research-status [prd_name]` | `draft` == 0 |
| Discussion answered | Read PRD.md Discussion section | All questions have answers |
| Objective clear | Review Objective section | Specific and actionable |
| Constraints documented | Review Constraints section | Comprehensive list |
| Tasks defined | Review tasks.yaml | All tasks have descriptions and spec paths |

**If validation fails:**
- Return to the appropriate step
- Ask user for input if blocked
- Document blockers in Discussion section

## Guidelines

- **Be thorough during analysis**: Missing issues early leads to problems later
- **Research before deciding**: External knowledge often reveals better approaches
- **Validate continuously**: Check your work at each step
- **Keep the user informed**: This is a collaborative process
- **Document everything**: Future implementers need context
