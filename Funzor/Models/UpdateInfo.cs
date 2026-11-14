namespace Funzor.Models;

public sealed class UpdateInfo
{
	public string Version { get; set; } = string.Empty;

	public string Url { get; set; } = string.Empty;

	public string Sha256 { get; set; } = string.Empty;

	public string Notes { get; set; } = string.Empty;
}
