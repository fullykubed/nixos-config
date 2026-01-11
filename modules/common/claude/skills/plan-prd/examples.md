# plan-prd Examples

## Example 1: Plan an incomplete PRD

**User**: `/plan-prd user-auth`

**Assistant**:
Reads `.claude/prds/user-auth/PRD.md` and analyzes:

"I've reviewed the PRD. Here's what I found:

**Complete sections:**
- Objective is clear
- Basic constraints defined

**Missing/incomplete:**
- Architecture section is empty
- Relevant files not specified
- No tasks defined yet

**Questions I have:**
1. Which authentication library should we use?
2. Where should session data be stored?

Let me explore the codebase to understand existing patterns..."

Reads relevant files, then updates PRD with findings.

---

## Example 2: Generate research questions

**User**: `/plan-prd stripe-integration`

**Assistant**:
Reads PRD and identifies unknowns:

"This PRD involves integrating with Stripe. I need to research:
1. How to set up Stripe webhooks
2. Best practices for handling payment failures
3. PCI compliance requirements

Creating research.yaml..."

Creates `.claude/prds/stripe-integration/research.yaml`:
```yaml
questions:
  - text: "How to configure Stripe webhooks for subscription events?"
    mode: answer
  - text: "What are the best practices for handling Stripe payment failures and retries?"
    mode: answer
  - text: "What are the PCI compliance requirements when using Stripe Elements?"
    mode: answer
```

```bash
claude-validate-research .claude/prds/stripe-integration
```

"Research questions created. Run `/research-prd stripe-integration` to get answers."

---

## Example 3: Plan with existing codebase patterns

**User**: `/plan-prd add-user-settings`

**Assistant**:
Explores codebase and finds existing patterns:

"I found existing settings patterns in the codebase:
- `src/settings/theme.ts` - Theme settings implementation
- `src/api/settings.ts` - Settings API endpoints
- `src/hooks/useSettings.ts` - Settings hook pattern

I'll use these as reference for the new user settings. No external research needed since we have clear patterns to follow.

Updating the PRD with:
- Architecture based on existing settings pattern
- Relevant files identified
- Constraints from existing code style"

Updates PRD.md and creates tasks.yaml.

---

## Example 4: PRD needs discussion answers

**User**: `/plan-prd notification-system`

**Assistant**:
Reads PRD and finds unanswered questions in Discussion section:

"The PRD has 2 unanswered discussion questions:

### Notification channels
_Which notification channels should be supported?_

(No answer provided)

### Real-time delivery
_Should notifications be delivered in real-time or batched?_

(No answer provided)

Please answer these questions so I can complete the planning. I can proceed once I understand:
1. Which channels: email, push, in-app, SMS?
2. Real-time via WebSocket or periodic polling?"

---

## Example 5: Research questions already answered

**User**: `/plan-prd oauth-integration`

**Assistant**:
```bash
claude-research-status oauth-integration
```
```json
{"draft": 0, "complete": 4, "total": 4}
```

"All research questions have been answered. Incorporating findings into the PRD..."

Reads research.yaml answers and updates:
- Implementation Details with specific OAuth flow
- Constraints with security requirements from research
- Tasks based on discovered complexity

---

## Example 6: Complex PRD with many questions (limit 25)

**User**: `/plan-prd microservices-migration`

**Assistant**:
"This is a large migration project. I've identified many potential research areas, but I'll limit to the 25 most critical questions:

**Architecture (8 questions):**
- Service communication patterns
- Data consistency strategies
...

**Infrastructure (7 questions):**
- Container orchestration options
- Service mesh requirements
...

**Migration (10 questions):**
- Incremental migration strategies
- Rollback procedures
...

Creating research.yaml with these 25 prioritized questions..."
