# create-prd Examples

## Example 1: Create a new feature PRD

**User**: `/create-prd user-authentication`

**Assistant**:
"I'll help you create a PRD for user authentication. Let me ask a few questions to understand your requirements.

What is the main objective of this feature? What problem are you trying to solve?"

**User**: "We need to add login/logout functionality with email and password"

**Assistant**:
"Got it. A few more questions:
1. Should users be able to register themselves, or will accounts be pre-created?
2. Do you need password reset functionality?
3. Are there any specific security requirements (2FA, session timeouts, etc.)?"

**User**: "Self-registration, yes to password reset, no 2FA for now"

**Assistant**:
Creates `.claude/prds/user-authentication/PRD.md` with the gathered information.

---

## Example 2: Create a bug fix PRD

**User**: `/create-prd fix-memory-leak`

**Assistant**:
"I'll help you create a PRD for fixing a memory leak. Can you describe:
1. Where is the memory leak occurring?
2. What symptoms are you seeing?
3. Do you have any leads on the cause?"

**User**: "The dashboard component keeps growing in memory. We see it in production after a few hours. Might be related to websocket listeners not being cleaned up."

**Assistant**:
Creates `.claude/prds/fix-memory-leak/PRD.md` with the bug context and investigation tasks.

---

## Example 3: Create a refactoring PRD

**User**: `/create-prd refactor-api-layer`

**Assistant**:
"I'll help you create a PRD for refactoring the API layer. What are your goals for this refactoring?
- Improve code organization?
- Better error handling?
- Performance improvements?
- Easier testing?"

**User**: "All of the above, but mainly we want to consolidate duplicate fetch logic across components"

**Assistant**:
Creates `.claude/prds/refactor-api-layer/PRD.md` focused on consolidation with specific constraints about maintaining backward compatibility.

---

## Example 4: PRD name derived from description

**User**: `/create-prd`

**Assistant**:
"What would you like to build or fix? Describe the feature or problem."

**User**: "I want to add dark mode support to the app"

**Assistant**:
"I'll create a PRD called 'dark-mode-support'. Let me ask a few questions..."

Creates `.claude/prds/dark-mode-support/PRD.md` after gathering requirements.
