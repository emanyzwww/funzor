param(
    [string]$Version = "0.0.0"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$publishDir = Join-Path $root "artifacts\publish"
$outputDir = Join-Path $root "installer\Output"
$outputBaseFilename = "FunzorSetup-v$Version-x64"

# 发布应用
dotnet publish (Join-Path $root "Funzor\Funzor.csproj") `
    -c Release `
    -p:Platform=x64 `
    -p:Version=$Version `
    -o $publishDir `
    -nologo

if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish 失败"
}

# 查找 Inno Setup 7 编译器
$iscc = @(
    (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Inno Setup 7\ISCC.exe')
    (Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'Inno Setup 7\ISCC.exe')
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
    throw "找不到 ISCC.exe，请先安装 Inno Setup 7"
}

# 编译安装程序
& $iscc `
    (Join-Path $root "installer\Funzor.iss") `
    "/DAppVersion=$Version" `
    "/DPublishDir=$publishDir" `
    "/DOutputBaseFilename=$outputBaseFilename"

if ($LASTEXITCODE -ne 0) {
    throw "安装包编译失败"
}

# 输出最终安装包路径
$outputFile = Join-Path $outputDir "$outputBaseFilename.exe"

if (-not (Test-Path $outputFile)) {
    throw "安装包未生成或输出路径不正确: $outputFile"
}

Write-Host "安装包已生成: $outputFile"
