# research-prd Examples

## Example 1: Research all unanswered questions

**User**: `/research-prd stripe-integration`

**Assistant**:
```bash
claude-research-status stripe-integration
```
```json
{"draft": 3, "complete": 0, "total": 3}
```

"3 unanswered research questions. Researching each..."

Uses exa MCP server to search for answers:

**Question 1**: "How to configure Stripe webhooks for subscription events?"
- Searches: `Stripe webhook configuration subscription events`
- Finds official Stripe docs and best practices
- Adds answer with citations

**Question 2**: "What are the best practices for handling Stripe payment failures?"
- Searches: `Stripe payment failure handling retry logic`
- Finds patterns for exponential backoff and customer notification
- Adds answer with citations

**Question 3**: "PCI compliance requirements when using Stripe Elements?"
- Searches: `Stripe Elements PCI compliance SAQ`
- Finds that Stripe Elements qualifies for SAQ-A
- Adds answer with citations

"All questions answered. Run `/plan-prd stripe-integration` to incorporate findings."

---

## Example 2: Deep research mode

**User**: `/research-prd authentication-overhaul`

**Assistant**:
```bash
claude-research-status authentication-overhaul
```

Reads research.yaml and finds a deep-research question:
```yaml
questions:
  - text: "What are the current best practices for session management in 2024?"
    mode: deep-research
```

"This question is marked for deep research. Starting comprehensive analysis..."

Uses exa deep researcher:
- Searches multiple sources
- Compares different approaches (JWT vs sessions vs hybrid)
- Analyzes security implications
- Compiles findings into detailed answer

"Deep research complete. Found significant changes in recommendations since 2023..."

---

## Example 3: Research specific question

**User**: `/research-prd api-gateway "Rate limiting strategies"`

**Assistant**:
Finds the specific question in research.yaml:
```yaml
- text: "What rate limiting strategies work best for API gateways?"
  mode: answer
```

"Researching rate limiting strategies..."

Uses exa to search and compile answer:
- Token bucket vs leaky bucket algorithms
- Distributed rate limiting with Redis
- Client identification strategies

Updates just that one question's answer.

---

## Example 4: All questions already answered

**User**: `/research-prd user-auth`

**Assistant**:
```bash
claude-research-status user-auth
```
```json
{"draft": 0, "complete": 5, "total": 5}
```

"All 5 research questions for 'user-auth' have already been answered.

Would you like to:
1. Review the existing answers
2. Add new research questions
3. Re-research a specific question with fresh data"

---

## Example 5: No research.yaml exists

**User**: `/research-prd dark-mode`

**Assistant**:
"The PRD 'dark-mode' doesn't have a research.yaml file. This means either:
1. No external research was needed
2. Research questions haven't been generated yet

Would you like me to run `/plan-prd dark-mode` to analyze if research is needed?"

---

## Example 6: Research with codebase context

**User**: `/research-prd graphql-migration`

**Assistant**:
Reads research.yaml:
```yaml
- text: "How to incrementally migrate REST to GraphQL without breaking existing clients?"
  mode: answer
```

"Researching GraphQL migration strategies..."

Searches with context about the existing REST API structure found in the codebase:
- Finds schema stitching approaches
- Discovers REST-to-GraphQL wrapper patterns
- Identifies versioning strategies

"Found migration patterns that work with your existing Express REST setup. Added answer with specific recommendations for your architecture."
