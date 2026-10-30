# Secure CI/CD Pipeline: Automated Docker Security Scanning and Kubernetes Deployment

A Jenkins pipeline that builds a Docker image, scans it with **Trivy**, and only pushes
and deploys it to **Kubernetes** if it passes a vulnerability gate.

## Architecture

```
GitHub -> Jenkins -> Docker Build -> Trivy Report -> Security Gate -> Push (Docker Hub) -> Deploy (K8s) -> Verify
                                                          |
                                     HIGH/CRITICAL found -> pipeline FAILS, nothing pushed or deployed
```

## Tools

| Tool | Purpose |
|---|---|
| Flask + Gunicorn | Sample app |
| Docker | Containerization |
| Jenkins | CI/CD |
| Trivy | Image vulnerability scanner |
| Minikube + kubectl | Kubernetes cluster |
| Docker Hub | Image registry |

(Record your exact tool versions here.)

## Repository structure

```
app/            Flask app and requirements
k8s/            Deployment and Service manifests
reports/        Sample Trivy scan reports
tests/          Deliberately vulnerable requirements (for validation)
scripts/        Helpers to inject/restore the vulnerability
Dockerfile
Jenkinsfile
```

## Setup (summary)

1. Install Docker, Jenkins (Java 17/21), Trivy, kubectl, Minikube on one Ubuntu machine.
2. `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins`
3. Start the cluster: `minikube start --driver=docker`
4. Add Jenkins credentials:
   - `dockerhub-creds` (Username/password; use a Docker Hub access token)
   - `kubeconfig` (Secret file from `kubectl config view --flatten --minify`)
5. Edit `IMAGE_NAME` in the `Jenkinsfile` with your Docker Hub username.
6. Create a Pipeline job: *Pipeline script from SCM* -> this repo -> `Jenkinsfile`.

## Security gating logic

The gate is the `Security Gate` stage:

```
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 <image>
```

- **Threshold:** HIGH and CRITICAL (selectable via the `SEVERITY_THRESHOLD` build parameter).
- **Fail mechanism:** `--exit-code 1` returns non-zero when matching findings exist, so Jenkins fails the stage and skips all later stages.
- **Scan before push:** the image is scanned locally before it is pushed, so a vulnerable image never reaches the registry.
- **`--ignore-unfixed`:** vulnerabilities with no available patch are not counted, since the team cannot act on them. Tradeoff: some risk is accepted until a fix is published. Remove the flag for a stricter policy.
- **Full report is separate:** a prior stage records all severities with `--exit-code 0`, so a report is always archived, even when the gate fails.
- **Exceptions:** reviewed, justified exceptions go in `.trivyignore`.

## Deployment workflow

| # | Stage | What happens |
|---|---|---|
| 1 | Checkout | Pull code from GitHub |
| 2 | Build Docker Image | Tag image with the build number |
| 3 | Trivy Scan - Generate Report | Full table and JSON report, archived |
| 4 | Security Gate | Fail on HIGH/CRITICAL |
| 5 | Push to Registry | Only if gate passed |
| 6 | Deploy to Kubernetes | Substitute image tag, `kubectl apply`, wait for rollout |
| 7 | Verify Deployment | Show pods, service, deployed image |

## Kubernetes hardening

Non-root user, no privilege escalation, read-only root filesystem, all capabilities dropped,
resource limits, readiness and liveness probes.

## Security validation

1. **Baseline:** clean build passes, app deployed. Verify:
   ```bash
   kubectl get pods
   curl $(minikube service secure-flask-app-svc --url)/health
   ```
2. **Inject vulnerability:**
   ```bash
   ./scripts/inject-vulnerability.sh
   git add . && git commit -m "Test: vulnerable deps" && git push
   ```
   Result: `Security Gate` fails, Push and Deploy are skipped.
3. **Prove nothing deployed:**
   ```bash
   kubectl get deployment secure-flask-app -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```
   Still shows the previous good build number; no new tag in Docker Hub.
4. **Fix:**
   ```bash
   ./scripts/restore-clean.sh
   git add . && git commit -m "Fix: restore clean deps" && git push
   ```
   Pipeline passes again.

### Results

Add screenshots to `docs/screenshots/`:
- Green pipeline
- Failed Security Gate with CVE table
- Pods running / curl output
- Deployed image tag unchanged after failure

Sample reports: `reports/trivy-report-PASSED.txt`, `reports/trivy-report-FAILED.txt`

## Challenges and fixes

(Fill in from your experience, e.g. Docker socket permissions, kubeconfig embedding, Trivy DB download.)

## Future improvements

Image signing (Cosign), `trivy config` for IaC scanning, Slack/email alerts, NetworkPolicy, Helm, GitOps with Argo CD.
