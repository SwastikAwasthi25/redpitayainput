#requires -Version 5.1
<#
Publishes the actual exported sources to a NEW PRIVATE GitHub repository.
Requires locally installed Git, GitHub CLI (gh) and a logged-in account.
Never force-pushes, overwrites an existing remote or changes the Vivado project.
#>
[CmdletBinding()]
param([string]$RepositoryName = 'redpitaya-4ch-adc-validation')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Push-Location $repo
try {
    if (!(Test-Path -LiteralPath 'fpga\provenance_manifest.csv')) { throw 'STOP: Export real Vivado files first' }
    python scripts/verify_export.py --require-source
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Source hash verification failed' }
    python -m unittest discover -s tests -v
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Evidence tests failed' }
    python scripts/audit_for_sharing.py
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Potential secret; review files before publishing' }
    if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'STOP: Install Git first' }
    if (!(Get-Command gh -ErrorAction SilentlyContinue)) { throw 'STOP: Install GitHub CLI first' }
    gh auth status
    if ($LASTEXITCODE -ne 0) { throw 'STOP: Authenticate with gh auth login first' }
    if (Test-Path -LiteralPath '.git') { throw 'STOP: Existing Git repository: inspect its remotes manually' }
    gh repo view $RepositoryName --json name *> $null
    if ($LASTEXITCODE -eq 0) { throw "STOP: GitHub repo already exists: $RepositoryName" }
    Write-Host 'Verified local export. Review all source files and licenses before pushing.' -ForegroundColor Yellow
    Write-Host "Will create a NEW PRIVATE repository: $RepositoryName" -ForegroundColor Yellow
    $confirm = Read-Host 'Type PUBLISH-PRIVATE to continue'
    if ($confirm -cne 'PUBLISH-PRIVATE') { throw 'STOP: No publishing confirmation' }
    git init
    if ($LASTEXITCODE -ne 0) { throw 'STOP: git init failed' }
    git add .
    if ($LASTEXITCODE -ne 0) { throw 'STOP: git add failed' }
    git status --short
    git commit -m 'Add hardware-validated Red Pitaya 4-channel ADC DDR firmware evidence and source snapshot'
    if ($LASTEXITCODE -ne 0) { throw 'STOP: git commit failed (check git user.name and user.email)' }
    gh repo create $RepositoryName --private --source . --remote origin --push
    if ($LASTEXITCODE -ne 0) { throw 'STOP: GitHub CLI push/create failed; inspect the local repository' }
    Write-Host "PRIVATE_REPOSITORY_PUBLISHED: $RepositoryName" -ForegroundColor Green
} finally {
    Pop-Location
}
