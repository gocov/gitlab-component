# gocov coverage upload — GitLab CI/CD component

Upload test coverage to [gocov](https://app.gocov.dev) from GitLab CI —
Go, JavaScript/TypeScript (LCOV), Java (JaCoCo), Python (Cobertura), PHP
(Clover), Ruby (SimpleCov): diff coverage on merge requests, commit
statuses, a coverage gate and a README badge, on the hosted service or your
own server. With a token, or with none at all.

Full documentation: [docs.gocov.dev](https://docs.gocov.dev) — in
particular [GitLab CI](https://docs.gocov.dev/gitlab-ci/), [the coverage
gate](https://docs.gocov.dev/coverage-gate/) and
[parts](https://docs.gocov.dev/parts/) for split builds.

## Quickstart

```yaml
include:
  - component: gitlab.com/gocov/gocov/upload@1
    inputs:
      files: coverage.out
      needs: [test]

test:
  script: go test ./... -covermode=atomic -coverprofile=coverage.out
  artifacts:
    paths: [coverage.out]
```

Then either add `GOCOV_TOKEN` under **Settings → CI/CD → Variables**
(masked, **not** protected — protected variables never reach merge request
pipelines), holding your workspace's upload token from
[app.gocov.dev](https://app.gocov.dev), or add nothing: see
[Uploading without a token](#uploading-without-a-token).

Only the test command and `files` change for other languages —
[Languages & formats](https://docs.gocov.dev/languages/) lists what each
test tool writes.

The job downloads the pinned gocov CLI release for the runner's
architecture and verifies its sha256 against the release's
`checksums.txt`, so there is no toolchain to install. Project, commit,
branch and merge request iid are auto-detected, including the real head
SHA on merged-results pipelines.

## Inputs

| Input | Default | Usage |
|---|---|---|
| `files` | `coverage.out` | Coverage file(s) to upload, comma-separated, shell globs allowed (`coverage.out`, `cover/*.out`). They must be artifacts of the jobs in `needs`. |
| `needs` | *(required)* | The job(s) that produced the files, e.g. `[test]`. The upload runs after them and downloads their artifacts. |
| `stage` | `test` | Stage of the upload job. |
| `job-name` | `gocov-upload` | Name of the upload job; change it when including the component more than once. |
| `server` | `https://app.gocov.dev` | gocov server URL. Override when self-hosting. |
| `part` | | Label for this upload when a commit's coverage is split across jobs; the server merges the parts for the same commit. See [parts](https://docs.gocov.dev/parts/). |
| `ignore` | | Glob patterns for files to leave out of the report, comma-separated (`cmd/preview/**,*_mock.go`). See [ignoring files](https://docs.gocov.dev/ignoring-files/). |
| `allow-failure` | `false` | Let the pipeline pass when the upload fails. |
| `version` | `v0.26.0` | gocov CLI release to install. The default is the one this component release was tested against. |
| `image` | `alpine:3.22` | Image for the upload job. Anything with a POSIX `sh`, `wget` or `curl`, and `sha256sum`. |

The token is never an input: the job reads `GOCOV_TOKEN` from the CI/CD
variables, so it stays masked and never appears in the pipeline definition.

## Uploading without a token

The job always declares an `id_tokens` entry named `GOCOV_ID_TOKEN` with
the gocov server as its audience. When no `GOCOV_TOKEN` variable exists,
the CLI sends that short-lived, signed OIDC token instead, and the server
verifies which project it came from — no secret to create, rotate or leak.

The project's workspace (its GitLab group) must be registered on gocov and
[connected](https://docs.gocov.dev/connecting/) to GitLab — the same
connection that posts the commit status and merge request note. The
project itself needs no setup: its first upload registers it. A pasted
`GOCOV_TOKEN` always takes precedence, and a rejected OIDC upload logs the
reason and exits 0 rather than failing the pipeline.

On a self-managed GitLab, the tokens are issued under your instance's URL;
the gocov operator has to trust that issuer — see
[self-hosting](https://docs.gocov.dev/self-hosting/).

## Split builds

Include the component once per part, each with its own job name:

```yaml
include:
  - component: gitlab.com/gocov/gocov/upload@1
    inputs:
      job-name: gocov-upload-backend
      files: backend/coverage.out
      needs: [test-backend]
      part: backend
  - component: gitlab.com/gocov/gocov/upload@1
    inputs:
      job-name: gocov-upload-frontend
      files: frontend/coverage/lcov.info
      needs: [test-frontend]
      part: frontend
```

## Self-hosting

```yaml
include:
  - component: gitlab.com/gocov/gocov/upload@1
    inputs:
      files: coverage.out
      needs: [test]
      server: https://gocov.example.com
```

A self-managed GitLab cannot include components from gitlab.com's catalog
directly; either mirror this project into your instance and include it from
there, or use the plain download recipe in
[GitLab CI](https://docs.gocov.dev/gitlab-ci/).

## Versioning

`@1` follows the newest 1.x release; `@1.0.0` pins one. Each release of
this component installs one gocov CLI release (the `version` default);
[CHANGELOG.md](CHANGELOG.md) says which. The source of truth is
[github.com/gocov/gitlab-component](https://github.com/gocov/gitlab-component),
mirrored to gitlab.com/gocov/gocov, where the CI/CD Catalog entry lives.

## License

MIT — see [LICENSE](LICENSE).
