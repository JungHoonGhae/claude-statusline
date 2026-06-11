## Summary

<!-- What does this PR change and why? -->

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Refactor / cleanup

## Testing

<!-- How did you verify this works? -->

- [ ] `bash -n` passes on all changed scripts
- [ ] Tested by piping a sample JSON payload into `statusline.sh`
- [ ] Tested on: <!-- macOS / Linux / Windows (Git Bash / WSL) -->

## Checklist

- [ ] Stays pure bash (no new runtime dependencies on the hot path)
- [ ] Fails loudly (dim hint) rather than silently hiding a section
- [ ] Compatible with bash 3.2 (macOS default)
- [ ] README / config docs updated if behavior changed
