#requires -Version 5.1
<#
.SYNOPSIS
Exports ACTUAL, user-verified Red Pitaya Vivado project sources, releases and reports.
Copies files byte-for-byte from the Windows PC. Never edits the Vivado project.
Never generates substitute RTL, IP, XDC, or firmware.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = 'D:\rp-adc-ila-puzzle-trial\adc_clock_sandbox',
    [switch]$IncludeRoutedCheckpoint
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$sourceRoot = Join-Path $ProjectRoot 'adc_clock_sandbox.srcs'
$projectFile = Join-Path $ProjectRoot 'adc_clock_sandbox.xpr'
$rtl = Join-Path $sourceRoot 'sources_1\imports\rtl\adc_ddr_unpack.sv'
$trial169 = Join-Path $ProjectRoot 'adc_validation_trial_169'
$trial202 = Join-Path $ProjectRoot 'adc_validation_trial_202'
$adcXdc = Join-Path $trial169 'adc_ddr_trial_184.xdc'
$cdcXdc = Join-Path $trial169 'adc_cdc_verified_199.xdc'
$newBit = Join-Path $trial202 'adc_ddr_corrected_202.bit'
$newLtx = Join-Path $trial202 'adc_ddr_corrected_202.ltx'
$manifestPath = Join-Path $repo 'fpga\provenance_manifest.csv'
$rows = New-Object 'System.Collections.Generic.List[object]'

# Preflight checks BEFORE creating any files. The working project is READ ONLY.
foreach ($p in @($projectFile, $sourceRoot, $rtl, $adcXdc, $cdcXdc, $newBit, $newLtx)) {
    if (!(Test-Path -LiteralPath $p)) { throw "STOP: Real Vivado source/artifact missing: $p" }
}
if (Test-Path -LiteralPath $manifestPath) {
    throw "STOP: Export already exists. Do not overwrite verified snapshots: $manifestPath"
}
$ddr = [System.IO.File]::ReadAllText($rtl)
foreach ($expected in @('.DDR_CLK_EDGE("SAME_EDGE_PIPELINED")', '.Q1(adc_raw[ch][2*bit_idx])', '.Q2(adc_raw[ch][2*bit_idx+1])')) {
    if (!$ddr.Contains($expected)) { throw "STOP: Current RTL differs from the experimentally tested version: $expected" }
}
if ($ddr.Contains('.DDR_CLK_EDGE("SAME_EDGE")')) { throw 'STOP: Old IDDR mode still present' }
$adcText = [System.IO.File]::ReadAllText($adcXdc)
if ($adcText -match '(?m)^\s*foreach\b' -or $adcText -notmatch 'set_input_delay') {
    throw 'STOP: ADC trial XDC is not the verified corrected declarative version'
}
$cdcText = [System.IO.File]::ReadAllText($cdcXdc)
if (([regex]::Matches($cdcText, '(?m)^\s*set_false_path\b')).Count -ne 2 -or
    !$cdcText.Contains('status12_meta_reg[3]') -or !$cdcText.Contains('status34_meta_reg[3]')) {
    throw 'STOP: CDC XDC must contain the two documented targeted synchronizer exclusions'
}
if ((Get-Item -LiteralPath $newBit).Length -ne 4045690) { throw 'STOP: Corrected bitstream size differs from the working Step202 output' }
if ((Get-Item -LiteralPath $newLtx).Length -ne 41511) { throw 'STOP: Corrected LTX size differs from the working Step202 output' }

function Copy-Audited {
    param(
        [string]$Source,
        [string]$RepoRelative,
        [string]$OriginRelative
    )

    $target = Join-Path $repo ($RepoRelative.Replace('/', '\'))

    $sourceSha = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.ToLowerInvariant()

    if (Test-Path -LiteralPath $target) {
        $targetSha = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()

        if ($sourceSha -ne $targetSha) {
            throw "STOP: Existing export differs from actual source: $RepoRelative"
        }
    }
    else {
        $parent = Split-Path -Parent $target

        if (!(Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        Copy-Item -LiteralPath $Source -Destination $target -ErrorAction Stop

        $targetSha = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()

        if ($sourceSha -ne $targetSha) {
            throw "STOP: Copied file checksum mismatch: $RepoRelative"
        }
    }

    $rows.Add([pscustomobject]@{
        repo_relative_path = $RepoRelative
        origin_relative_to_project = $OriginRelative.Replace('\', '/')
        size_bytes = (Get-Item -LiteralPath $target).Length
        sha256 = $targetSha
    })
}

# The project metadata is copied as-is; absolute paths inside .xpr must be audited before public release.
Copy-Audited $projectFile 'fpga/source_snapshot/adc_clock_sandbox.xpr' 'adc_clock_sandbox.xpr'

$sourceExtensions = @('.sv','.v','.svh','.vh','.vhd','.vhdl','.xdc','.bd','.xci','.tcl','.coe','.mem','.hex','.mif','.prj','.xml','.dat','.txt','.csv')
$sourceCount = 0
foreach ($file in (Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Sort-Object FullName)) {
    if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "STOP: Symlink/reparse-point not allowed: $($file.FullName)" }
    if ($sourceExtensions -notcontains $file.Extension.ToLowerInvariant()) { continue }
    $rel = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
    $normalized = $rel.Replace('\','/')
    Copy-Audited $file.FullName "fpga/source_snapshot/adc_clock_sandbox.srcs/$normalized" "adc_clock_sandbox.srcs/$normalized"
    $sourceCount++
}
if ($sourceCount -eq 0) { throw 'STOP: No native source files found in adc_clock_sandbox.srcs' }

# Constraints located outside the .srcs tree need explicit copies.
$external = @(
    @{path=(Join-Path (Split-Path -Parent $ProjectRoot) 'adc_input_clocks_153.xdc'); relative='adc_input_clocks_153.xdc'},
    @{path=$adcXdc; relative='adc_validation_trial_169/adc_ddr_trial_184.xdc'},
    @{path=$cdcXdc; relative='adc_validation_trial_169/adc_cdc_verified_199.xdc'}
)
foreach ($entry in $external) {
    if (!(Test-Path -LiteralPath $entry.path)) {
        if ($entry.relative -eq 'adc_input_clocks_153.xdc') { throw 'STOP: Actual ADC clock XDC missing' }
        throw "STOP: External constraint missing: $($entry.relative)"
    }
    $name = Split-Path -Leaf $entry.path
    Copy-Audited $entry.path "fpga/external_constraints/$name" $entry.relative
}

# The bitstream and LTX are copied byte-for-byte; neither is regenerated here.
foreach ($release in @(
    @{path=(Join-Path $trial169 'adc_validation_trial.bit'); group='original_169'},
    @{path=(Join-Path $trial169 'adc_validation_trial.ltx'); group='original_169'},
    @{path=$newBit; group='corrected_202'},
    @{path=$newLtx; group='corrected_202'}
)) {
    if (!(Test-Path -LiteralPath $release.path)) { throw "STOP: Firmware evidence file missing: $($release.path)" }
    $base = Split-Path -Leaf $release.path
    Copy-Audited $release.path "fpga/releases/$($release.group)/$base" "original local release: $($release.group)/$base"
}

# Copy only available, actual report/log artifacts. Never invent reports.
$reports = @(
    @{path=(Join-Path $trial169 'step200_timing_summary.rpt'); name='step200_timing_summary.rpt'},
    @{path=(Join-Path $trial202 'step202_drc.rpt'); name='step202_drc.rpt'},
    @{path=(Join-Path $trial169 'pre_bitstream_drc.rpt'); name='step169_pre_bitstream_drc.rpt'},
    @{path=(Join-Path $ProjectRoot 'adc_clock_sandbox.runs\impl_adc_fix_200\runme.log'); name='impl_adc_fix_200_runme.log'},
    @{path=(Join-Path $ProjectRoot 'adc_clock_sandbox.runs\synth_adc_fix_200\runme.log'); name='synth_adc_fix_200_runme.log'}
)
$reportCount = 0
foreach ($item in $reports) {
    if (!(Test-Path -LiteralPath $item.path)) { Write-Warning "Evidence report missing (not fabricated): $($item.path)"; continue }
    Copy-Audited $item.path "evidence/reports/$($item.name)" "PC run/report: $($item.name)"
    $reportCount++
}
if ($IncludeRoutedCheckpoint) {
    $routed = Join-Path $ProjectRoot 'adc_clock_sandbox.runs\impl_adc_fix_200\adc_system_top_routed.dcp'
    if (!(Test-Path -LiteralPath $routed)) { throw 'STOP: Routed implementation checkpoint not found' }
    Copy-Audited $routed 'fpga/releases/corrected_202/adc_system_top_routed.dcp' 'adc_clock_sandbox.runs/impl_adc_fix_200/adc_system_top_routed.dcp'
}

$parent = Split-Path -Parent $manifestPath
if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$rows | Sort-Object repo_relative_path | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
Write-Host "SOURCE_EXPORT_COMPLETE: $($rows.Count) exact files" -ForegroundColor Green
Write-Host "VIVADO_SOURCE_FILES: $sourceCount"
Write-Host "COPIED_REPORTS: $reportCount"
Write-Host "PROVENANCE_MANIFEST: $manifestPath"
Write-Host "IMPORTANT: Inspect original XPR/external absolute paths and third-party licenses before public GitHub upload."
Write-Host "NEXT: python scripts/verify_export.py --require-source"
