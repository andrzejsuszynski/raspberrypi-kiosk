using Avalonia;
using Avalonia.LinuxFramebuffer.Input.NullInput;
using System;
using System.Linq;

namespace KioskHelloWorld;

class Program
{
    // Initialization code. Don't use any Avalonia, third-party APIs or any
    // SynchronizationContext-reliant code before AppMain is called: things aren't initialized
    // yet and stuff might break.
    [STAThread]
    public static int Main(string[] args)
    {
        var kioskMode = args.Contains("--kiosk-mode");
        var remainingArgs = args.Where(a => a != "--kiosk-mode").ToArray();

        if (kioskMode)
        {
            // No windowing system on a Raspberry Pi kiosk, so render straight to the
            // Linux framebuffer instead of going through UsePlatformDetect(). A hello-world
            // clock takes no input, so skip the default LibInput backend (and its libinput.so
            // system dependency) entirely.
            return BuildKioskApp().StartLinuxFbDev(remainingArgs, inputBackend: new NullInputBackend());
        }

        BuildDesktopApp().StartWithClassicDesktopLifetime(remainingArgs);
        return 0;
    }

    public static AppBuilder BuildDesktopApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
#if DEBUG
            .WithDeveloperTools()
#endif
            .WithInterFont()
            .LogToTrace();

    public static AppBuilder BuildKioskApp()
        => AppBuilder.Configure<App>()
            .UseSkia()
            .UseHarfBuzz()
            .WithInterFont()
            .LogToTrace();

    // Used by the Avalonia XAML previewer/designer.
    public static AppBuilder BuildAvaloniaApp() => BuildDesktopApp();
}
