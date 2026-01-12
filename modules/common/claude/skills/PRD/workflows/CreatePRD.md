# CreatePRD Workflow

This workflow guides you through creating a new PRD (Product Requirements Document) from scratch.

## Workflow Steps

These workflow steps MUST be followed exactly as written.

### 1. Gather the Objective

Ask the user to describe what they want to accomplish. Get a clear understanding of the feature, fix, or improvement they need.

**Questions to ask:**
- What problem are you trying to solve?
- Who is this for (users, developers, system)?
- What does success look like?

**Follow-up as needed:**
- Clarify ambiguous requirements
- Identify scope boundaries

### 2. Gather the Motivation

Understand why this objective matters. This provides context for decision-making during planning and implementation.

**Questions to ask:**
- Why is this important now?
- What problem does this solve?
- What is the impact of not doing this?
- What value does this provide to users/developers/the system?

### 3. Identify Constraints

Work with the user to identify constraints for the implementation:

- **Technical constraints**: Language, framework, library requirements
- **Compatibility constraints**: Must work with existing systems/patterns
- **Performance constraints**: Speed, memory, scalability requirements
- **Scope constraints**: What is explicitly out of scope

### 4. Document Discussion

Record all clarifying questions and their answers in the Discussion section. This creates a record of decisions and context for future reference.

Format each Q&A as:
```md
### [Question Title]

_[Full question text]_

[User's answer]
```

### 5. Create the PRD File

Create a PRD file following the exact structure defined in the PRD Specification.

**File location:** `.claude/prds/[prd_name]/PRD.md`

Where `[prd_name]` is a kebab-case name derived from the objective (e.g., `user-authentication`, `dark-mode-toggle`).

### 6. Fill Out Sections

Focus on gathering information and filling out only:

| Section | Action |
|---------|--------|
| **Objective** | Fill with user-provided description of what they want to accomplish |
| **Motivation** | Fill with why this objective matters, the problem it solves, and impact |
| **Constraints** | Fill with any constraints mentioned by the user or that you identify |
| **Discussion** | Fill with clarifying questions and their answers |

### 7. Leave Placeholders

The following sections should be left as placeholders for the planning workflow. Do NOT fill these out during PRD creation:

| Section | Placeholder Text |
|---------|------------------|
| **Architecture** | `<To be determined during planning>` |
| **Relevant Guides** | `<To be determined during planning>` |
| **Relevant Files** | `<To be determined during planning>` |

### 8. Do NOT Create tasks.yaml

Task generation is handled separately during the PlanPRD workflow. Creating tasks prematurely may lead to:
- Incomplete task definitions
- Tasks that don't align with discovered constraints
- Missing research-informed decisions

### 9. Validate and Confirm

Before completing:

1. **Read back the PRD** to the user for confirmation
2. **Verify** the objective clearly captures what they want
3. **Verify** the motivation explains why this matters
4. **Confirm** all known constraints are documented
5. **Check** the Discussion section captures key decisions

## Guidelines

- **Keep the objective focused**: A PRD should address one feature or improvement
- **Be thorough with constraints**: Better to capture too many than miss important ones
- **Document decisions**: The Discussion section is valuable context for planning
- **Don't over-specify**: Leave room for the planning phase to determine implementation details
