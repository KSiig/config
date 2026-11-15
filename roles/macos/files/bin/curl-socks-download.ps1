#Requires -Version 5.1
<#
.SYNOPSIS
    Run a browser "Copy as cURL (bash)" command through a local SOCKS5 proxy.

.DESCRIPTION
    Paste a curl command that uses backslashes for line breaks. The script asks
    for an output filename, then runs curl.exe with:
        --socks5-hostname 127.0.0.1:9150
        -o <filename>.mp4
    .mp4 is added when the filename has no extension.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\curl-socks-download.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\curl-socks-download.ps1 -Clipboard -OutFile episode
#>
param(
    [string]$CommandText,
    [string]$OutFile,
    [switch]$Clipboard,
    [switch]$DryRun
)

$SocksHost = "127.0.0.1:9150"

function Get-ClipboardText {
    $clip = Get-Clipboard -ErrorAction SilentlyContinue
    if ($null -eq $clip) {
        return ""
    }
    if ($clip -is [System.Array]) {
        return ($clip -join "`n")
    }
    return [string]$clip
}

function Read-CurlCommand {
    Write-Host "Paste the curl command. Stop when a line has no trailing backslash."
    Write-Host "Press Enter on an empty line to use the clipboard instead."
    $lines = New-Object System.Collections.Generic.List[string]
    while ($true) {
        $line = Read-Host
        if ($lines.Count -eq 0 -and [string]::IsNullOrWhiteSpace($line)) {
            $clip = Get-ClipboardText
            if ([string]::IsNullOrWhiteSpace($clip)) {
                Write-Host "The clipboard is empty."
                exit 1
            }
            return $clip
        }
        $lines.Add($line)
        if ($line.TrimEnd().EndsWith("\") -eq $false) {
            break
        }
    }
    return ($lines.ToArray() -join "`n")
}

function Join-BashContinuation {
    param([string]$Text)
    $normalized = $Text -replace "`r`n", "`n" -replace "`r", "`n"
    $sb = New-Object System.Text.StringBuilder
    foreach ($line in ($normalized -split "`n")) {
        $trimmedEnd = $line.TrimEnd()
        if ($trimmedEnd.EndsWith("\")) {
            [void]$sb.Append($trimmedEnd.Substring(0, $trimmedEnd.Length - 1))
            [void]$sb.Append(" ")
        }
        else {
            [void]$sb.Append($line)
            [void]$sb.Append("`n")
        }
    }
    return $sb.ToString().Trim()
}

function Get-BashTokens {
    param([string]$Text)
    $tokens = New-Object System.Collections.Generic.List[string]
    $i = 0
    $n = $Text.Length
    while ($i -lt $n) {
        while ($i -lt $n -and [char]::IsWhiteSpace($Text[$i])) {
            $i++
        }
        if ($i -ge $n) {
            break
        }

        $sb = New-Object System.Text.StringBuilder
        while ($i -lt $n -and -not [char]::IsWhiteSpace($Text[$i])) {
            $c = $Text[$i]
            if ($c -eq "'") {
                $i++
                while ($i -lt $n) {
                    if ($Text[$i] -eq "'") {
                        $i++
                        # bash: '\'' embeds a single quote
                        if (($i + 1) -lt $n -and $Text[$i] -eq "\" -and $Text[$i + 1] -eq "'") {
                            [void]$sb.Append("'")
                            $i += 2
                            if ($i -lt $n -and $Text[$i] -eq "'") {
                                $i++
                                continue
                            }
                        }
                        break
                    }
                    [void]$sb.Append($Text[$i])
                    $i++
                }
                continue
            }

            if ($c -eq '"') {
                $i++
                while ($i -lt $n -and $Text[$i] -ne '"') {
                    if ($Text[$i] -eq "\" -and ($i + 1) -lt $n) {
                        $next = $Text[$i + 1]
                        if ($next -eq '"' -or $next -eq "\" -or $next -eq '$' -or $next -eq '`') {
                            [void]$sb.Append($next)
                            $i += 2
                            continue
                        }
                    }
                    [void]$sb.Append($Text[$i])
                    $i++
                }
                if ($i -lt $n -and $Text[$i] -eq '"') {
                    $i++
                }
                continue
            }

            if ($c -eq "\" -and ($i + 1) -lt $n) {
                [void]$sb.Append($Text[$i + 1])
                $i += 2
                continue
            }

            [void]$sb.Append($c)
            $i++
        }
        $tokens.Add($sb.ToString())
    }
    return ,@($tokens.ToArray())
}

function Remove-CurlFlags {
    param(
        [string[]]$ArgumentList,
        [string[]]$FlagNames
    )
    $drop = @{}
    foreach ($name in $FlagNames) {
        $drop[$name] = $true
    }

    $result = New-Object System.Collections.Generic.List[string]
    $skipNext = $false
    foreach ($arg in $ArgumentList) {
        if ($skipNext) {
            $skipNext = $false
            continue
        }

        if ($arg.StartsWith("-o") -and $arg -ne "-o" -and -not $arg.StartsWith("--")) {
            continue
        }

        $name = $arg
        $hasInlineValue = $false
        $eq = $arg.IndexOf("=")
        if ($arg.StartsWith("--") -and $eq -gt 2) {
            $name = $arg.Substring(0, $eq)
            $hasInlineValue = $true
        }

        if ($drop.ContainsKey($name)) {
            if (-not $hasInlineValue) {
                $skipNext = $true
            }
            continue
        }
        $result.Add($arg)
    }
    return ,@($result.ToArray())
}

function Get-CurlUrl {
    param([string[]]$ArgumentList)
    foreach ($arg in $ArgumentList) {
        if ($arg -match '^https?://') {
            return $arg
        }
    }
    return $null
}

function Format-DisplayArg {
    param([string]$Value)
    if ($Value -match '[\s"]') {
        return '"' + ($Value -replace '"', '\"') + '"'
    }
    return $Value
}

if ($Clipboard) {
    $CommandText = Get-ClipboardText
}
elseif ([string]::IsNullOrWhiteSpace($CommandText)) {
    $CommandText = Read-CurlCommand
}

if ([string]::IsNullOrWhiteSpace($CommandText)) {
    Write-Host "No curl command was provided."
    exit 1
}

$joined = Join-BashContinuation -Text $CommandText
$tokens = @(Get-BashTokens -Text $joined)
if ($tokens.Count -lt 2 -or $tokens[0] -notmatch '^(curl|curl\.exe)$') {
    Write-Host "The pasted text does not start with a curl command."
    exit 1
}

$rest = @($tokens[1..($tokens.Count - 1)])
$rest = @(Remove-CurlFlags -ArgumentList $rest -FlagNames @(
        "-o", "--output",
        "-x", "--proxy", "--preproxy",
        "--socks5", "--socks5-hostname", "--socks4", "--socks4a"
    ))

$url = Get-CurlUrl -ArgumentList $rest
if ([string]::IsNullOrWhiteSpace($url)) {
    Write-Host "No http(s) URL was found in the curl command."
    exit 1
}

Write-Host ""
Write-Host "URL: $url"

while ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Read-Host "Output filename"
    if ($null -eq $OutFile) {
        $OutFile = ""
    }
    $OutFile = $OutFile.Trim().Trim('"').Trim("'")
}

$leaf = [System.IO.Path]::GetFileName($OutFile)
if ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($leaf))) {
    $OutFile = "$OutFile.mp4"
}

if ([System.IO.Path]::IsPathRooted($OutFile)) {
    $outPath = $OutFile
}
else {
    $outPath = Join-Path (Get-Location).Path $OutFile
}

$hasLocation = $false
foreach ($arg in $rest) {
    if ($arg -eq "-L" -or $arg -eq "--location" -or $arg -eq "--location-trusted") {
        $hasLocation = $true
        break
    }
}

$final = New-Object System.Collections.Generic.List[string]
foreach ($arg in $rest) {
    $final.Add($arg)
}
if (-not $hasLocation) {
    $final.Add("--location")
}
$final.Add("--socks5-hostname")
$final.Add($SocksHost)
$final.Add("-o")
$final.Add($outPath)

Write-Host "Saving to: $outPath"
Write-Host "Proxy:     socks5h://${SocksHost}"

if ($DryRun) {
    $shown = @("curl.exe")
    foreach ($arg in $final) {
        $shown += (Format-DisplayArg -Value $arg)
    }
    Write-Host ""
    Write-Host ($shown -join " ")
    exit 0
}

if (Test-Path -LiteralPath $outPath) {
    $answer = Read-Host "That file already exists. Overwrite? [y/N]"
    if ($answer -notmatch '^[yY]') {
        Write-Host "Cancelled."
        exit 1
    }
}

$curlCmd = Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $curlCmd) {
    Write-Host "curl.exe was not found. Windows 10 and later include it in System32."
    exit 1
}

Write-Host ""
$finalArgs = $final.ToArray()
& $curlCmd.Source @finalArgs
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Host "curl exited with code $code"
    exit $code
}
