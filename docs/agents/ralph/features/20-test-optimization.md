# Test Optimization

## Description

The test suite is slow and needs optimization. This feature involves profiling the tests to identify slow ones, analyzing why they are slow, creating an optimization plan, getting user approval, and then implementing the optimizations without losing test coverage.

## Behavior

### Phase 1: Profiling

Use minitest's verbose mode or timing features to identify which tests take the longest. Options to explore:
- `rake test TESTOPTS="-v"` for verbose output
- minitest-reporters gem with timing
- `m` command with verbose flags
- Custom timing wrapper

Run the full test suite with timing enabled and capture:
- Total time for each test file
- Individual test method times
- Identify the slowest tests (top 10 or anything over 1 second)

### Phase 2: Analysis

For each slow test, analyze:
- Is it an integration test hitting a real IRC server?
- Does it have unnecessary sleeps or timeouts?
- Is it doing redundant setup?
- Could it be parallelized?
- Is it testing too much in one test?

Document findings with specific line numbers and explanations.

### Phase 3: Plan Creation

Create a temporary plan document at `docs/agents/ralph/test-optimization-plan.md` containing:
- Summary of profiling results (slowest tests with times)
- Root causes identified
- Proposed optimizations with expected impact
- Risk assessment for each change
- How test coverage will be preserved

### Phase 4: User Approval

Use `AskUserQuestion` tool to ask the user:
> I've created a test optimization plan at docs/agents/ralph/test-optimization-plan.md. Please review it and let me know if you approve. Reply 'approved' to proceed or provide feedback for changes.

If not approved, update the plan based on feedback and ask again.

### Phase 5: Implementation

Only after user approval, implement the optimizations:
- Make changes incrementally
- After each change, run the affected tests to verify they still pass
- Ensure no tests are removed or skipped
- Keep the same assertions and coverage

## Tests

This feature is meta - it's about improving tests, not adding new functionality. Success criteria:

**Profiling Output**
- Generate a report showing test execution times
- Identify tests taking > 500ms

**Plan Document**
- Plan exists at docs/agents/ralph/test-optimization-plan.md
- Contains profiling results with specific times
- Contains proposed changes with rationale
- Contains risk assessment

**Implementation Verification**
- All tests still pass after optimization
- No tests were removed
- No assertions were weakened
- Test count remains the same or increases
- Total test time is reduced

## Implementation Notes

- Use `rake test` and `rake test_unit` / `rake test_integration` to run tests
- Use `bundle exec standardrb -A` for linting
- The IRC server may be in use by another process - check before running integration tests
- If IRC server is unavailable, focus on unit tests first and note integration tests for later

Minitest timing approaches:
1. `TESTOPTS="-v"` shows test names as they run
2. minitest-reporters gem can add timing
3. Custom reporter: create a reporter that tracks per-test time
4. Ruby's Benchmark module around test runs

## Dependencies

None - this is the first and only feature.
