using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using WinUI3Localizer;

namespace Funzor
{
    public sealed partial class MainWindow : Window
    {
        private readonly UpdateService _updateService = new();

        public MainWindow()
        {
            InitializeComponent();
        }

        private async void UpdateCheckButton_Click(object sender, RoutedEventArgs e)
        {
            UpdateCheckButton.IsEnabled = false;
            try
            {
                UpdateInfo? latest = await _updateService.GetLatestAsync();

                if (latest is null ||
                    Version.TryParse(latest.Version, out Version? latestVersion) is false ||
                    latestVersion <= _updateService.CurrentVersion)
                {
                    await ShowMessageAsync("NoUpdateTitle", "NoUpdateMessage");
                    return;
                }

                ProgressBar progressBar = new() { Minimum = 0, Maximum = 100 };
                ContentDialog progressDialog = new()
                {
                    XamlRoot = Content.XamlRoot,
                    Title = Localizer.Get().GetLocalizedString("NoUpdateTitle"),
                    Content = progressBar,
                };

                var showOperation = progressDialog.ShowAsync();
                try
                {
                    await _updateService.DownloadAndRunInstallerAsync(
                        latest,
                        new Progress<double>(value => progressBar.Value = value * 100));
                }
                finally
                {
                    progressDialog.Hide();
                    await showOperation;
                }

                // 安装程序已在运行，退出以释放文件占用
                Application.Current.Exit();
            }
            catch (Exception exception)
            {
                await ShowMessageAsync("NoUpdateTitle", null, $"更新失败：{exception.Message}");
            }
            finally
            {
                UpdateCheckButton.IsEnabled = true;
            }
        }

        private Task ShowMessageAsync(string titleKey, string? messageKey, string? message = null)
        {
            ILocalizer localizer = Localizer.Get();
            ContentDialog dialog = new()
            {
                XamlRoot = Content.XamlRoot,
                Title = localizer.GetLocalizedString(titleKey),
                Content = message ?? localizer.GetLocalizedString(messageKey ?? string.Empty),
                CloseButtonText = "确定",
            };
            return dialog.ShowAsync().AsTask();
        }
    }
}
