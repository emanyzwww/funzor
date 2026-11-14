<#
.SYNOPSIS
    合成最终发行说明: 版本标题 + 手写摘要 + git-cliff 分组 + 贡献者 + 结尾.

.DESCRIPTION
    git-cliff 只输出按类型分组的条目, 本脚本在此基础上拼装完整版式.
    版本摘要放在 changelog/notes/<tag>.md (可选), 没有该文件时只输出标题与分组.
    贡献者来自 GitHub compare API 的 author.login, 无需手工维护名单.

.PARAMETER Version
    版本号, 例如 0.1.0.

.PARAMETER TagName
    版本 tag, 例如 v0.1.0, 用于查找摘要文件并生成链接.

.PARAMETER Ref
    git 引用, 默认等于 TagName. 本地验证时可传 HEAD.

.PARAMETER Repository
    owner/repo, 用于查询贡献者与生成对比链接.

.PARAMETER NotesPath
    git-cliff 输出的说明文件, 脚本读入后覆盖写回.

.PARAMETER SummaryDir
    版本摘要目录, 文件名与 tag 相同.
#>
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$TagName,
    [string]$Ref = "",
    [string]$Repository = "",
    [string]$NotesPath = "RELEASE_NOTES.md",
    [string]$SummaryDir = "changelog/notes"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Ref)) { $Ref = $TagName }

# 1. git-cliff 的分组内容
$sections = ""
if (Test-Path $NotesPath) {
    $sections = (Get-Content $NotesPath -Raw).Trim()
    $sections = $sections.Replace([string][char]13, "").Replace([string][char]10, [string][char]13 + [char]10)
}

# 2. 手写版本摘要 (可选)
$summaryPath = Join-Path $SummaryDir "$TagName.md"
$summary = ""
if (Test-Path $summaryPath) {
    $summary = (Get-Content $summaryPath -Raw).Trim()
}

# 3. 上一个 tag, 用于确定提交区间与对比链接
$previousTag = ""
try {
    $previousTag = (git describe --tags --abbrev=0 "$Ref^" 2>$null)
    if ($LASTEXITCODE -ne 0) { $previousTag = "" }
} catch { $previousTag = "" }
$range = if ($previousTag) { "$previousTag..$Ref" } else { $Ref }

# 4. 贡献者: 优先用 GitHub compare API 返回的 author.login, 失败时退回提交作者姓名
$counts = @{}

function Add-Author([hashtable]$table, [string]$login, [string]$name) {
    $key = if ([string]::IsNullOrWhiteSpace($login)) { "name:" + $name } else { "login:" + $login }
    if (-not $table.ContainsKey($key)) {
        $table[$key] = [pscustomobject]@{ Login = $login; Name = $name; Count = 0 }
    }
    $table[$key].Count += 1
}

$usedApi = $false
if ($Repository -and $previousTag) {
    $compareRange = "$previousTag...$TagName"
    $tab = [string][char]9

    # 4.1 CI 环境: gh CLI 带 token
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $lines = & gh api "repos/$Repository/compare/$compareRange" --paginate --jq ".commits[] | [.author.login // """", .commit.author.name] | @tsv" 2>$null
            if ($LASTEXITCODE -eq 0 -and $lines) {
                foreach ($line in $lines) {
                    $parts = $line -split $tab
                    Add-Author $counts $parts[0] $parts[1]
                }
                $usedApi = $true
            }
        } catch { }
    }

    # 4.2 本地环境: 匿名调用公开仓库的 REST API
    if (-not $usedApi) {
        try {
            $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/compare/$compareRange" -Headers @{ "User-Agent" = "funzor-release-notes" }
            foreach ($commit in $resp.commits) {
                Add-Author $counts $commit.author.login $commit.commit.author.name
            }
            $usedApi = $true
        } catch { }
    }
}

# 4.3 回退: 直接从 git 历史取作者姓名 (无链接)
if (-not $usedApi) {
    foreach ($name in (git log $range --format="%an")) {
        Add-Author $counts "" $name
    }
}

$contributors = $counts.Values |
    Sort-Object -Property @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { ($_.Login + $_.Name).ToLower() } }

function Format-Contributor($item) {
    if (-not [string]::IsNullOrWhiteSpace($item.Login)) {
        return "- [@$($item.Login)](https://github.com/$($item.Login))"
    }
    return "- $($item.Name)"
}

# 5. 拼装
$builder = [System.Text.StringBuilder]::new()
[void]$builder.AppendLine("# V$Version")
[void]$builder.AppendLine()

if ($summary) {
    [void]$builder.AppendLine($summary)
    [void]$builder.AppendLine()
}

if ($sections) {
    [void]$builder.AppendLine($sections)
    [void]$builder.AppendLine()
}

if ($contributors.Count -gt 0) {
    [void]$builder.AppendLine("## 贡献者")
    [void]$builder.AppendLine()
    [void]$builder.AppendLine("感谢以下贡献者对本次版本的支持:")
    [void]$builder.AppendLine()

    foreach ($item in ($contributors | Select-Object -First 10)) {
        [void]$builder.AppendLine((Format-Contributor $item))
    }

    if ($contributors.Count -gt 10) {
        [void]$builder.AppendLine()
        [void]$builder.AppendLine("<details>")
        [void]$builder.AppendLine("<summary>展开全部 $($contributors.Count) 位贡献者</summary>")
        [void]$builder.AppendLine()
        foreach ($item in $contributors) {
            [void]$builder.AppendLine((Format-Contributor $item))
        }
        [void]$builder.AppendLine()
        [void]$builder.AppendLine("</details>")
    }

    [void]$builder.AppendLine()
}

[void]$builder.AppendLine("---")
[void]$builder.AppendLine()
[void]$builder.AppendLine("**感谢所有为项目做出贡献的人.**")
[void]$builder.AppendLine()

if ($Repository) {
    if ($previousTag) {
        [void]$builder.AppendLine("[查看本次更新的全部提交](https://github.com/$Repository/compare/$previousTag...$TagName)")
    } else {
        [void]$builder.AppendLine("[查看本次更新的全部提交](https://github.com/$Repository/commits/$TagName)")
    }
}

Set-Content -Path $NotesPath -Value $builder.ToString().TrimEnd() -Encoding utf8
Write-Host "发行说明已生成: $NotesPath"
