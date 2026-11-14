using Funzor.Views;
using Microsoft.UI.Xaml;
using WinUI3Localizer;

namespace Funzor
{
    public partial class App : Application
    {
        private Window? _window;

        public App()
        {
            InitializeComponent();
        }

        protected override async void OnLaunched(LaunchActivatedEventArgs args)
        {
            await InitializeLocalizer();
            _window = new MainWindow();
            _window.Activate();
        }

        private static async Task InitializeLocalizer()
        {
            // 非打包应用: Strings 文件夹由 csproj 复制到 exe 所在目录
            string stringsFolderPath = Path.Combine(AppContext.BaseDirectory, "Strings");

            await new LocalizerBuilder()
                .AddStringResourcesFolderForLanguageDictionaries(stringsFolderPath)
                .SetOptions(options => options.DefaultLanguage = "zh-CN")
                .Build();
        }
    }
}
