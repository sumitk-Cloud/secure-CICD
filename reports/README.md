# Scan reports

Replace the two placeholder files in this folder with REAL output from your own Jenkins runs:

- `trivy-report-PASSED.txt`  : download from Build Artifacts of the green build
- `trivy-report-FAILED.txt`  : download from Build Artifacts of the failed (vulnerable) build

The files currently here only show the expected layout. CVE IDs depend on the Trivy
database on the day you run the scan, so do not submit them as real results.
