# Brakeman Security Scanning

## Description

Add Brakeman security scanning to CI. Brakeman is a static analysis tool that checks Ruby on Rails applications for security vulnerabilities. This runs as a separate GitHub Actions job.

## Behavior

### Workflow Integration

Add a new job to `.github/workflows/main.yml`:

**Security Job**
- Runs `bin/brakeman` (or `bundle exec brakeman`)
- Single job, not matrixed (security scanning doesn't need multiple Ruby versions)
- Can run in parallel with other jobs

### Brakeman Setup

If `bin/brakeman` doesn't exist, create it as a binstub or run via `bundle exec brakeman`.

Add `brakeman` gem to Gemfile if not present (in development/test group).

## Implementation Notes

- Brakeman may report existing issues in the codebase
- If Brakeman fails, fix the issues or configure Brakeman to ignore false positives
- Use `brakeman --no-pager` for CI output
- Consider `brakeman -o /dev/stdout -o brakeman-output.html` for both console and artifact output

### Handling Existing Issues

If the codebase has existing Brakeman warnings:
1. Run `brakeman` locally first
2. Fix any real security issues
3. For false positives, use `brakeman -I` to create/update `config/brakeman.ignore`
4. Commit the ignore file if needed

## Tests

This feature has no unit tests. Verification is done by:

1. Ensure Brakeman passes locally: `bundle exec brakeman`
2. Push changes and verify CI runs
3. Security job must pass in GitHub Actions

### Verification Commands

```bash
# Run Brakeman locally
bundle exec brakeman

# Check CI status
gh run list --limit 5
gh run view <run-id>
```

## Completion Criteria

- [ ] Brakeman gem added to Gemfile (if not present)
- [ ] Brakeman runs successfully locally with no errors
- [ ] Security job added to `.github/workflows/main.yml`
- [ ] CI run passes including the security job (verified via `gh run list`)

## Dependencies

- Requires `17-github-actions-ci.md` (workflow file must exist and work)
