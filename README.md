# InvisiRisk PSE GitHub Action

This GitHub Action integrates InvisiRisk PSE into your workflow by setting up a transparent HTTPS proxy and packet forwarding.

## Inputs

### Required

- `scan_id`: The scan ID for InvisiRisk PSE
- `denat_url`: URL to download the denat tool
- `pse_url`: URL to download the PSE proxy

### Optional

- `container_image`: Alpine container image to use (default: 'alpine:latest')

## Example Usage

```yaml
name: InvisiRisk PSE Scan

on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run InvisiRisk PSE
        uses: ./
        with:
          scan_id: 'your-scan-id'
          denat_url: 'https://example.com/denat'
          pse_url: 'https://example.com/pse'
```

## How it Works

1. Downloads and runs an Alpine container
2. Sets up the denat tool for packet forwarding
3. Configures the PSE transparent proxy
4. Monitors the build process
5. Reports build status back to InvisiRisk PSE

## Requirements

- Docker must be available in the GitHub Actions runner
- Proper access to InvisiRisk PSE endpoints
