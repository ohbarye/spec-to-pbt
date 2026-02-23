# Repo Rename Checklist (`alloy-to-pbt` -> `spec-to-pbt`)

## Scope (this phase)

- Rename the GitHub repository
- Update local git remote URL
- Update README/project description to reflect the broader `spec -> pbt` scope
- Keep Ruby package/module names (`alloy_to_pbt`, `AlloyToPbt`) unchanged for now

## Why phased?

Changing the repo name is low-risk and improves project positioning immediately.
Changing gem/module/CLI names is higher-cost and can be done later with a separate migration plan.

## Manual Steps

1. Rename the GitHub repository (Settings -> General -> Repository name)
   - Suggested new name: `spec-to-pbt`

2. Update local remotes

```bash
git remote set-url origin https://github.com/ohbarye/spec-to-pbt.git
git remote -v
```

3. Confirm branches still track correctly

```bash
git fetch origin --prune
git branch -vv
```

4. Update references in docs/automation/scripts (as needed)
   - repo URL
   - local filesystem paths in handoff docs (if kept as current-operational docs)

## Deferred (separate migration)

- Rename gem (`alloy_to_pbt`)
- Rename CLI (`bin/alloy_to_pbt`)
- Rename Ruby module (`AlloyToPbt`)
- Rename generated require paths/templates/tests
- Add compatibility shims / deprecation path
