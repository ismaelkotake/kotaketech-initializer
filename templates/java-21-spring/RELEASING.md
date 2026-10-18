# Releasing

This project follows [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/).

## Branches

| Branch      | Purpose                                              | Created from | Merged into        |
|-------------|------------------------------------------------------|--------------|--------------------|
| `main`      | Production-ready code. Every merge is a release.     | —            | —                  |
| `develop`   | Integration branch (default). Next release.          | —            | —                  |
| `feature/*` | New features and non-urgent changes.                 | `develop`    | `develop`          |
| `release/*` | Release preparation (version, changelog, fixes).     | `develop`    | `main` + `develop` |
| `hotfix/*`  | Urgent fixes for production.                         | `main`       | `main` + `develop` |

CI runs on pushes and pull requests targeting `main`, `develop`, `release/**` and `hotfix/**`,
using the shared workflows in [`ismaelkotake/workflows`](https://github.com/ismaelkotake/workflows).

## Feature

```bash
git checkout develop && git pull
git checkout -b feature/<short-name>
# ...commit...
git push -u origin feature/<short-name>
gh pr create --base develop
```

## Release

1. Create the release branch from `develop`:
   ```bash
   git checkout develop && git pull
   git checkout -b release/X.Y.Z
   ```
2. Set the version and update the changelog:
   ```bash
   mvn versions:set -DnewVersion=X.Y.Z -DgenerateBackupPoms=false
   ```
   Move the `[Unreleased]` entries in `CHANGELOG.md` to a new `[X.Y.Z] - YYYY-MM-DD` section.
   Only bug fixes and release-related changes go into this branch.
3. Open a pull request into `main`:
   ```bash
   git push -u origin release/X.Y.Z
   gh pr create --base main --title "release: X.Y.Z"
   ```
4. After merging, tag the release from `main`:
   ```bash
   gh release create X.Y.Z --target main --title "X.Y.Z" --generate-notes
   ```
5. Merge `main` back into `develop` and start the next development version:
   ```bash
   git checkout develop && git pull
   git merge --no-ff origin/main
   mvn versions:set -DnewVersion=X.Y.(Z+1)-SNAPSHOT -DgenerateBackupPoms=false
   git commit -am "chore: start next development version"
   git push
   ```
6. Delete the release branch.

## Hotfix

1. Create the hotfix branch from `main`:
   ```bash
   git checkout main && git pull
   git checkout -b hotfix/X.Y.Z
   ```
2. Fix, set the version, add a `[X.Y.Z]` entry to `CHANGELOG.md`, and open a pull request into `main`.
3. After merging, follow steps 4–6 of the release process.

## Versioning

Versions follow [Semantic Versioning](https://semver.org/). Tags have no `v` prefix (`1.2.0`).
