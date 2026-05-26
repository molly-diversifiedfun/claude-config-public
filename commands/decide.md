Launch the **strategist** agent to make a decision.

Usage: /decide [question or choice between options]

Produces a one-page decision brief with an opinionated recommendation, numeric confidence, and built-in bias countermeasures.

## Pre-flight

**Before spawning the strategist, check MemPalace** for prior decisions on the same topic:

1. `mcp__mempalace__mempalace_search` for the decision topic
2. If a past decision exists + <30 days old, surface it: "Found a prior decision on [topic] from [date]. Want to revisit or use the existing?"
3. Only proceed with fresh analysis after confirming no prior decision applies

## What the strategist does

1. Invoke the **decision-maker** skill to structure the choice
2. Use **mental-models** to analyze from multiple frameworks
3. Run **devils-advocate** to stress-test the recommendation
4. Output: one-page brief with recommendation, confidence score, assumptions, pre-mortem, and kill conditions

## Output format

The brief includes:
- **Recommendation** (opinionated, not both-sides)
- **Confidence** (1-10 numeric)
- **Assumptions** (what must be true for this to work)
- **Pre-mortem** (how this fails)
- **Kill conditions** (when to reverse the decision)

Example: /decide should we use Stripe or Lemon Squeezy for payments
Example: /decide should I split this into two PRs or ship as one
Example: /decide which brand should own this content piece
