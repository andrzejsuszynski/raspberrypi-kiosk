using System;
using Avalonia.Controls;
using Avalonia.Threading;

namespace KioskHelloWorld;

public partial class MainView : UserControl
{
    private readonly DispatcherTimer _timer;

    public MainView()
    {
        InitializeComponent();

        UpdateClock();
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _timer.Tick += (_, _) => UpdateClock();
        _timer.Start();
    }

    private void UpdateClock()
    {
        var now = DateTime.Now;
        DateText.Text = now.ToString("dddd, dd MMMM yyyy");
        TimeText.Text = now.ToString("HH:mm:ss");
    }
}
