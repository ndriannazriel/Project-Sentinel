# Security Fixes and Pipeline Enhancements Summary

This document summarizes the challenges we encountered while setting up the CI/CD pipeline and securing the Docker container for `sentinel-app`, the reasoning behind them, and the solutions we implemented.

## 1. SonarCloud Scanning Configuration Typo

**Issue:** The SonarCloud GitHub Action failed to find the project and could not complete the scan. 
**Reasoning:** In `sonar-project.properties`, the `sonar.organization` key had a typo (`ndrlannazriel` instead of `ndriannazriel`). This prevented SonarCloud from matching the repository with the correct organization.
**Solution:** Corrected the typo in `sonar-project.properties` so the configuration accurately matched the SonarCloud dashboard.

## 2. GitHub Action CI Pipeline Not Failing on Vulnerabilities

**Issue:** Trivy and SonarCloud scans were running in the GitHub Action, but they would not cancel or fail the build even if severe vulnerabilities were found.
**Reasoning:** 
- The `aquasecurity/trivy-action` was explicitly set with `exit-code: '0'`, telling it to report success regardless of the findings.
- The pipeline was missing a "Quality Gate Check" step, meaning it would run the scan and upload the code to SonarCloud, but wouldn't wait for SonarCloud's Pass/Fail verdict.
**Solution:** 
- Modified `.github/workflows/security-scan.yml` to set `exit-code: '1'` on the Trivy step.
- Added the `SonarSource/sonarqube-quality-gate-action` step to halt the pipeline if the code fails the SonarCloud quality gate.

## 3. Simultaneous Automatic and CI Analysis Error in SonarCloud

**Issue:** The SonarCloud scan in GitHub Actions failed with an error stating: *"You are running CI analysis while Automatic Analysis is enabled."*
**Reasoning:** SonarCloud enables Automatic Analysis by default when a GitHub repository is connected. When the GitHub Action tried to initiate a manual CI analysis (required for features like code coverage), they conflicted.
**Solution:** Disabled Automatic Analysis through the SonarCloud dashboard (Administration -> Analysis Method).

## 4. Trivy Docker Image Vulnerabilities

When running Trivy locally (`trivy image --severity HIGH,CRITICAL sentinel-app`), several vulnerabilities were discovered inside the Docker image. We fixed them iteratively:

### A. Vulnerabilities in `glob`, `tar`, and `minimatch`
**Issue:** DOZENS of HIGH and CRITICAL vulnerabilities in the dependencies shipped with the Node.js image `node:18`.
**Reasoning:** The `Dockerfile` was using `node:18-alpine`. While lightweight, Node 18 is an older release, and the native versions of tools bundled internally contained known vulnerabilities.
**Solution:** Upgraded the base image from `node:18-alpine` to `node:22-alpine` in both the builder and production stages.

### B. Vulnerability in Alpine OS (`zlib`, CVE-2026-22184)
**Issue:** Trivy reported a CRITICAL vulnerability in the `zlib` library.
**Reasoning:** `zlib` is part of the underlying Alpine Linux operating system inside the container. Even the latest Docker base images can be a few days behind on patching low-level OS packages.
**Solution:** Added `RUN apk upgrade --no-cache` to the `Dockerfile` to automatically pull and install the latest OS security patches during the build.

### C. Lingering Node Manager Vulnerabilities inside `npm`
**Issue:** After all upgrades, Trivy still reported three HIGH vulnerabilities tied to `glob`, `tar`, and `minimatch`.
**Reasoning:** Unlike normal app dependencies, these vulnerable packages were bundled deeply inside the source code of the `npm` package manager itself (`/usr/local/lib/node_modules/npm/...`). Even upgrading `npm` couldn't clear them up entirely.
**Solution:** Because we use a multi-stage Docker build, our production stage only needs to *run* the app (`node src/index.js`), it doesn't need to *install* it. We updated the `Dockerfile` to completely delete the `npm` executables and modules from the production image (`rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx`).

---

### End Result
By systematically addressing the CI/CD configuration, keeping our base image up-to-date, patching the underlying OS on build, and stripping out unnecessary development tools like `npm` from our production stage, we've successfully hardened the Docker image and ensured that Trivy passes with exactly **0 HIGH or CRITICAL issues**.
