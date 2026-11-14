using System.Diagnostics;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using Funzor.Models;

namespace Funzor.Services;

/// <summary>
/// 通过 GitHub Release 上的分发清单检查更新, 下载安装包并启动安装程序.
/// </summary>
internal sealed class UpdateService
{
    private const string ManifestUrl = "https://github.com/emanyzwww/Funzor/releases/latest/download/latest.json";

    private static readonly HttpClient Http = new();
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    /// <summary>当前程序版本, 来自程序集版本 (发版时由 CI 的 /p:Version 注入).</summary>
    public Version CurrentVersion { get; } = ReadCurrentVersion();

    public async Task<UpdateInfo?> GetLatestAsync()
    {
        string json = await Http.GetStringAsync(ManifestUrl);
        return JsonSerializer.Deserialize<UpdateInfo>(json, JsonOptions);
    }

    /// <summary>下载安装包, 校验 SHA256, 然后静默启动安装程序.</summary>
    public async Task DownloadAndRunInstallerAsync(UpdateInfo info, IProgress<double> progress)
    {
        string directory = Path.Combine(Path.GetTempPath(), "FunzorUpdate");
        Directory.CreateDirectory(directory);
        string installerPath = Path.Combine(directory, "FunzorSetup-x64.exe");

        using (HttpResponseMessage response = await Http.GetAsync(info.Url, HttpCompletionOption.ResponseHeadersRead))
        {
            response.EnsureSuccessStatusCode();

            long? totalLength = response.Content.Headers.ContentLength;
            await using Stream source = await response.Content.ReadAsStreamAsync();
            await using FileStream target = File.Create(installerPath);

            byte[] buffer = new byte[81920];
            long received = 0;
            int read;
            while ((read = await source.ReadAsync(buffer)) > 0)
            {
                await target.WriteAsync(buffer.AsMemory(0, read));
                received += read;

                if (totalLength is long total)
                {
                    progress.Report((double)received / total);
                }
            }
        }

        if (string.Equals(ComputeSha256(installerPath), info.Sha256, StringComparison.OrdinalIgnoreCase) is false)
        {
            throw new InvalidOperationException("更新包校验失败，已取消安装。");
        }

        // 主程序以管理员身份运行, 安装程序继承已提权令牌, 不会再弹 UAC
        Process.Start(new ProcessStartInfo(
            installerPath,
            "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS")
        {
            UseShellExecute = true,
        });
    }

    private static string ComputeSha256(string filePath)
    {
        using FileStream stream = File.OpenRead(filePath);
        return Convert.ToHexString(SHA256.HashData(stream));
    }

    private static Version ReadCurrentVersion()
    {
        Version? version = Assembly.GetExecutingAssembly().GetName().Version;
        return version is null
            ? new Version(0, 0, 0)
            : new Version(version.Major, version.Minor, Math.Max(version.Build, 0));
    }
}
