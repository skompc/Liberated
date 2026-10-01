# Builds a self-contained dist\Liberated-windows\ folder (nginx + PHP 8 + Python 3 venv w/ dnslib + site content)
# with a Liberated.exe launcher. Everything lives inside the folder; deleting it removes everything.
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File .\scripts\build-windows.ps1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$NginxVersion = '1.26.2'
$PhpVersion   = '8.3.35'
$PyVersion    = '3.12.7'
$PyRelease    = '20241016'

$Scripts = $PSScriptRoot
$Root = (Resolve-Path (Join-Path $Scripts '..')).Path
$Out  = Join-Path $Root 'dist\Liberated-windows'
$Res  = Join-Path $Out 'resources'
$BuildRoot = Join-Path $Root 'build'
$Work = Join-Path $BuildRoot ('windows-' + [Guid]::NewGuid())

function Fetch($url, $file) {
    Write-Host "==> Downloading $url"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $file
}

function New-Ico($pngPath, $icoPath) {
    Add-Type -AssemblyName System.Drawing
    $src = [System.Drawing.Image]::FromFile($pngPath)
    $images = @()
    foreach ($s in 16, 32, 48, 256) {
        $bmp = New-Object System.Drawing.Bitmap $s, $s, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($src, 0, 0, $s, $s)
        $g.Dispose()
        # Classic 32-bit DIB icon entry (BITMAPINFOHEADER + bottom-up BGRA + empty AND mask)
        $ms = New-Object IO.MemoryStream
        $w = New-Object IO.BinaryWriter $ms
        $maskRow = [int]([Math]::Ceiling($s / 32) * 4)
        $w.Write([int]40); $w.Write([int]$s); $w.Write([int]($s * 2))
        $w.Write([int16]1); $w.Write([int16]32); $w.Write([int]0)
        $w.Write([int]($s * $s * 4 + $maskRow * $s))
        $w.Write([int]0); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0)
        for ($y = $s - 1; $y -ge 0; $y--) {
            for ($x = 0; $x -lt $s; $x++) {
                $c = $bmp.GetPixel($x, $y)
                $w.Write([byte]$c.B); $w.Write([byte]$c.G); $w.Write([byte]$c.R); $w.Write([byte]$c.A)
            }
        }
        $w.Write((New-Object byte[] ($maskRow * $s)))
        $w.Flush()
        $images += , @($s, $ms.ToArray())
        $bmp.Dispose()
    }
    $src.Dispose()

    $fs = [IO.File]::Create($icoPath)
    $w = New-Object IO.BinaryWriter $fs
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$images.Count)
    $offset = 6 + 16 * $images.Count
    foreach ($img in $images) {
        $dim = if ($img[0] -ge 256) { 0 } else { $img[0] }
        $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32)
        $w.Write([uint32]$img[1].Length); $w.Write([uint32]$offset)
        $offset += $img[1].Length
    }
    foreach ($img in $images) { $w.Write([byte[]]$img[1]) }
    $w.Close()
}

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "C# compiler not found at $csc (.NET Framework 4.x is required)" }
if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) { throw 'tar.exe not found (requires Windows 10 1803 or newer)' }

    New-Item -ItemType Directory -Force -Path $Work | Out-Null
try {
    if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
    foreach ($d in 'php', 'dns', 'run', 'web\conf', 'web\logs', 'web\temp') {
        New-Item -ItemType Directory -Force -Path (Join-Path $Res $d) | Out-Null
    }

    # ------------------------------------------------------------ nginx (official Windows build)
    Fetch "https://nginx.org/download/nginx-$NginxVersion.zip" "$Work\nginx.zip"
    Expand-Archive "$Work\nginx.zip" -DestinationPath $Work
    Copy-Item "$Work\nginx-$NginxVersion\nginx.exe" "$Res\web\"
    Copy-Item "$Root\src\web\conf\fastcgi_params" "$Res\web\conf\"
    Copy-Item -Recurse "$Root\src\web\conf\ssl" "$Res\web\conf\ssl"

    # ------------------------------------------------------------ PHP 8 (NTS, php-cgi)
    $phpZip = "php-$PhpVersion-nts-Win32-vs16-x64.zip"
    try { Fetch "https://downloads.php.net/~windows/releases/$phpZip" "$Work\php.zip" }
    catch { Fetch "https://downloads.php.net/~windows/releases/archives/$phpZip" "$Work\php.zip" }
    Expand-Archive "$Work\php.zip" -DestinationPath "$Res\php" -Force

    # Bundle the VC++ runtime next to php-cgi so the target PC doesn't need the redistributable
    foreach ($dll in 'vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll') {
        $sys = Join-Path $env:WINDIR "System32\$dll"
        if (Test-Path $sys) { Copy-Item $sys "$Res\php\" }
    }

    # Reuse the project's php.ini, disabling extensions this PHP build doesn't ship
    $ini = Get-Content "$Root\src\php\php.ini" | ForEach-Object {
        if ($_ -match '^\s*(zend_)?extension\s*=\s*"?([^"\s;]+)') {
            $name = $Matches[2]
            if ($name -notmatch '\.dll$') { $name = "php_$name.dll" }
            if (-not (Test-Path (Join-Path "$Res\php\ext" $name))) { return ";$_" }
        }
        $_
    }
    Set-Content -Path "$Res\php\php.ini" -Value $ini -Encoding ASCII

    # ------------------------------------------------------------ Python 3 + venv + dnslib
    Fetch "https://github.com/astral-sh/python-build-standalone/releases/download/$PyRelease/cpython-$PyVersion+$PyRelease-x86_64-pc-windows-msvc-install_only.tar.gz" "$Work\python.tgz"
    tar.exe -xzf "$Work\python.tgz" -C $Res
    if ($LASTEXITCODE -ne 0) { throw 'Failed to extract Python' }

    Write-Host '==> Creating venv and installing dnslib'
    & "$Res\python\python.exe" -m venv "$Res\venv"
    if ($LASTEXITCODE -ne 0) { throw 'venv creation failed' }
    $env:PIP_DISABLE_PIP_VERSION_CHECK = '1'
    & "$Res\venv\Scripts\python.exe" -m pip install --no-cache-dir dnslib certifi
    if ($LASTEXITCODE -ne 0) { throw 'pip install failed' }

    Copy-Item "$Root\src\python\dnsserver.py" "$Res\dns\"
    New-Item -ItemType Directory -Force -Path "$Res\scraper" | Out-Null
    Copy-Item "$Root\src\python\scraper\scraper.py", "$Root\src\python\scraper\scraper-config.json" "$Res\scraper\"

    # ------------------------------------------------------------ Site content + nginx config
    Write-Host '==> Copying site content'
    Copy-Item -Recurse "$Root\src\web\html" "$Res\web\html"

    Set-Content -Path "$Res\web\conf\nginx.conf" -Encoding ASCII -Value @'
worker_processes 1;
error_log logs/error.log;
pid       logs/nginx.pid;

events { worker_connections 1024; }

http {
    client_body_temp_path temp/client_body;
    fastcgi_temp_path     temp/fastcgi;
    access_log            logs/access.log;

    server {
        listen 80;
        listen 443 ssl;
        server_name d2-megaten-l.sega.com d2r-dl.d2megaten.com d2r-sim.d2megaten.com d2r-chat.d2megaten.com liberated.dx2 localhost;

        ssl_certificate     ssl/site.crt;
        ssl_certificate_key ssl/site.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:MD5;

        root  html;
        index index.php index.html index.htm;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.(do|php)$ {
            include fastcgi_params;
            fastcgi_pass 127.0.0.1:9123;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    }
}
'@

    # ------------------------------------------------------------ Launcher (Liberated.exe with icon)
    Write-Host '==> Compiling Liberated.exe'
    New-Ico "$Root\icon.png" "$Work\icon.ico"
    Copy-Item "$Root\icon.png" "$Res\icon.png"

    Set-Content -Path "$Work\Launcher.cs" -Encoding UTF8 -Value @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

static class Launcher
{
    static string Res, Run, Web;
    static Process Php, Nginx, Dns;
    static volatile bool Stopping;
    static volatile bool WebEnabled;
    static volatile bool DnsEnabled;
    static readonly object LogLock = new object();
    static Icon AppIcon;

    static string PyExe { get { return Path.Combine(Res, @"venv\Scripts\python.exe"); } }
    static string Scraper { get { return Path.Combine(Res, @"scraper\scraper.py"); } }

    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        AppIcon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        Res = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "resources");
        Run = Path.Combine(Res, "run");
        Web = Path.Combine(Res, "web");
        Directory.CreateDirectory(Run);
        Directory.CreateDirectory(Path.Combine(Web, "logs"));
        Directory.CreateDirectory(Path.Combine(Web, "temp"));

        try
        {
            FixVenv();
            string ip = LocalIp();
            Application.Run(new MainForm(ip.Length > 0 ? ip : "unknown"));
        }
        catch (Exception e)
        {
            MessageBox.Show(e.Message, "Liberated", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            StopAll();
        }
    }

    // Re-point the venv at the bundled interpreter (the folder may have been moved)
    static void FixVenv()
    {
        string cfg = Path.Combine(Res, @"venv\pyvenv.cfg");
        var lines = File.ReadAllLines(cfg)
            .Where(l => !l.StartsWith("home") && !l.StartsWith("executable") && !l.StartsWith("command"))
            .ToList();
        lines.Insert(0, "home = " + Path.Combine(Res, "python"));
        File.WriteAllLines(cfg, lines);
    }

    static string LocalIp()
    {
        foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (ni.OperationalStatus != OperationalStatus.Up || ni.NetworkInterfaceType == NetworkInterfaceType.Loopback)
                continue;
            var props = ni.GetIPProperties();
            if (!props.GatewayAddresses.Any(g => g.Address.AddressFamily == AddressFamily.InterNetwork && !g.Address.Equals(IPAddress.Any)))
                continue;
            foreach (var ua in props.UnicastAddresses)
                if (ua.Address.AddressFamily == AddressFamily.InterNetwork)
                    return ua.Address.ToString();
        }
        return "";
    }

    // php-cgi exits after PHP_FCGI_MAX_REQUESTS; disable that and restart it if it dies anyway
    static void StartPhp()
    {
        var p = Start(Path.Combine(Res, @"php\php-cgi.exe"), "-b 127.0.0.1:9123 -c php.ini",
                      Path.Combine(Res, "php"), Path.Combine(Run, "php.log"));
        p.EnableRaisingEvents = true;
        p.Exited += (s, e) => { if (!Stopping && WebEnabled) { Thread.Sleep(1000); if (!Stopping && WebEnabled) StartPhp(); } };
        Php = p;
    }

    public static bool WebRunning { get { return WebEnabled && Nginx != null && !Nginx.HasExited; } }
    public static bool DnsRunning { get { return DnsEnabled && Dns != null && !Dns.HasExited; } }

    public static void StartWeb()
    {
        if (WebRunning) return;
        WebEnabled = true;
        try
        {
            StartPhp();
            Nginx = Start(Path.Combine(Web, "nginx.exe"), "", Web, null);
        }
        catch (Exception e)
        {
            WebEnabled = false;
            MessageBox.Show("Web server failed to start: " + e.Message + "\nSee resources\\web\\logs\\error.log", "Liberated", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    public static void StopWeb()
    {
        WebEnabled = false;
        try
        {
            if (Nginx != null && !Nginx.HasExited)
                Start(Path.Combine(Web, "nginx.exe"), "-s quit", Web, null).WaitForExit(3000);
        }
        catch { }
        Kill(Nginx);
        Kill(Php);
        Nginx = null;
        Php = null;
    }

    public static void StartDns(string ip)
    {
        if (DnsRunning) return;
        DnsEnabled = true;
        try
        {
            Dns = Start(Path.Combine(Res, @"venv\Scripts\python.exe"),
                        "-u \"" + Path.Combine(Res, @"dns\dnsserver.py") + "\" " + ip,
                        Path.Combine(Res, "dns"), Path.Combine(Run, "dns.log"));
        }
        catch (Exception e)
        {
            DnsEnabled = false;
            MessageBox.Show("DNS server failed to start: " + e.Message + "\nSee resources\\run\\dns.log", "Liberated", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    public static void StopDns()
    {
        DnsEnabled = false;
        Kill(Dns);
        Dns = null;
    }

    static Process Start(string file, string args, string cwd, string log)
    {
        var psi = new ProcessStartInfo(file, args)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            WorkingDirectory = cwd,
            RedirectStandardOutput = log != null,
            RedirectStandardError = log != null
        };
        psi.EnvironmentVariables["PHP_FCGI_MAX_REQUESTS"] = "0";
        var p = Process.Start(psi);
        if (log != null)
        {
            DataReceivedEventHandler h = (s, e) => { if (e.Data != null) lock (LogLock) File.AppendAllText(log, e.Data + Environment.NewLine); };
            p.OutputDataReceived += h;
            p.ErrorDataReceived += h;
            p.BeginOutputReadLine();
            p.BeginErrorReadLine();
        }
        return p;
    }

    public static void StopAll()
    {
        Stopping = true;
        StopWeb();
        StopDns();
    }

    static void Kill(Process p)
    {
        try { if (p != null && !p.HasExited) { p.Kill(); p.WaitForExit(3000); } } catch { }
    }

    public static bool AssetsPresent()
    {
        var psi = new ProcessStartInfo(PyExe, "\"" + Scraper + "\" --check") { UseShellExecute = false, CreateNoWindow = true };
        using (var p = Process.Start(psi))
        {
            p.WaitForExit();
            return p.ExitCode == 0;
        }
    }

    // Runs the scraper in a window that streams its output; closing the window cancels the download
    public static void DownloadAssets(IWin32Window owner)
    {
        var form = new Form
        {
            Text = "Liberated - Downloading game assets",
            Icon = AppIcon,
            ClientSize = new Size(600, 340),
            FormBorderStyle = FormBorderStyle.FixedDialog,
            MaximizeBox = false,
            MinimizeBox = false,
            StartPosition = owner == null ? FormStartPosition.CenterScreen : FormStartPosition.CenterParent
        };
        var bar = new ProgressBar
        {
            Location = new Point(12, 12),
            Size = new Size(576, 22),
            Style = ProgressBarStyle.Marquee,
            Maximum = 100
        };
        var count = new Label { Location = new Point(12, 40), Size = new Size(576, 18), Text = "Starting..." };
        var box = new TextBox
        {
            Multiline = true,
            ReadOnly = true,
            ScrollBars = ScrollBars.Vertical,
            Location = new Point(12, 62),
            Size = new Size(576, 224),
            Font = new Font(FontFamily.GenericMonospace, 8.25f)
        };
        var button = new Button { Text = "Cancel", Location = new Point(488, 298), Size = new Size(100, 30) };
        form.Controls.Add(bar);
        form.Controls.Add(count);
        form.Controls.Add(box);
        form.Controls.Add(button);

        Process proc = null;
        bool finished = false;
        var progressLine = new Regex(@"^\[(\d+)/(\d+)\]");
        Action<string> append = line =>
        {
            try
            {
                form.BeginInvoke((Action)(() =>
                {
                    box.AppendText(line + Environment.NewLine);
                    var m = progressLine.Match(line);
                    int done, total;
                    if (m.Success && int.TryParse(m.Groups[1].Value, out done) && int.TryParse(m.Groups[2].Value, out total) && total > 0)
                    {
                        bar.Style = ProgressBarStyle.Continuous;
                        bar.Value = Math.Min(100, done * 100 / total);
                        count.Text = done + " / " + total + " files (" + bar.Value + "%)";
                    }
                }));
            }
            catch { }
        };

        form.Shown += (s, e) =>
        {
            var psi = new ProcessStartInfo(PyExe, "-u \"" + Scraper + "\"")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
            DataReceivedEventHandler handler = (s2, e2) =>
            {
                if (e2.Data == null) return;
                append(e2.Data);
                lock (LogLock) File.AppendAllText(Path.Combine(Run, "scraper.log"), e2.Data + Environment.NewLine);
            };
            proc.OutputDataReceived += handler;
            proc.ErrorDataReceived += handler;
            proc.Exited += (s2, e2) =>
            {
                proc.WaitForExit();   // flush remaining output
                int code = proc.ExitCode;
                try
                {
                    form.BeginInvoke((Action)(() =>
                    {
                        finished = true;
                        button.Text = "Close";
                        bar.Style = ProgressBarStyle.Continuous;
                        if (code == 0) bar.Value = 100;
                        count.Text = code == 0 ? "Done." : "Failed.";
                        box.AppendText(Environment.NewLine + (code == 0 ? "Game assets downloaded." : "Download failed (see resources\\run\\scraper.log).") + Environment.NewLine);
                    }));
                }
                catch { }
            };
            proc.Start();
            proc.BeginOutputReadLine();
            proc.BeginErrorReadLine();
        };
        button.Click += (s, e) => form.Close();
        form.FormClosing += (s, e) => { if (!finished) Kill(proc); };
        form.ShowDialog(owner);
        form.Dispose();
    }
}

class MainForm : Form
{
    readonly string ip;
    readonly Label webStatus;
    readonly Label dnsStatus;
    readonly Label assetStatus;
    readonly Button webButton;
    readonly Button dnsButton;
    readonly System.Windows.Forms.Timer refreshTimer;

    public MainForm(string ipAddress)
    {
        ip = ipAddress;
        Text = "Liberated";
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        ClientSize = new Size(540, 300);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;

        var heading = new Label { Text = "Liberated", Font = new Font(Font, FontStyle.Bold), Location = new Point(16, 14), Size = new Size(500, 24) };
        var address = new Label { Text = "Set your device DNS to: " + ip, Location = new Point(16, 44), Size = new Size(500, 22) };
        webStatus = new Label { Location = new Point(16, 84), Size = new Size(330, 24) };
        webButton = new Button { Location = new Point(380, 78), Size = new Size(140, 32) };
        webButton.Click += (s, e) => { if (Launcher.WebRunning) Launcher.StopWeb(); else Launcher.StartWeb(); RefreshStatus(); };
        dnsStatus = new Label { Location = new Point(16, 124), Size = new Size(330, 24) };
        dnsButton = new Button { Location = new Point(380, 118), Size = new Size(140, 32) };
        dnsButton.Click += (s, e) => { if (Launcher.DnsRunning) Launcher.StopDns(); else Launcher.StartDns(ip); RefreshStatus(); };
        assetStatus = new Label { Text = Launcher.AssetsPresent() ? "Game assets are ready." : "Game assets are missing.", Location = new Point(16, 162), Size = new Size(500, 24) };

        var update = new Button { Text = "Update Assets", Location = new Point(16, 220), Size = new Size(112, 32) };
        update.Click += (s, e) =>
        {
            Launcher.DownloadAssets(this);
            assetStatus.Text = Launcher.AssetsPresent() ? "Game assets are ready." : "Game assets are missing.";
        };
        var editConfig = new Button { Text = "Edit Scraper Config", Location = new Point(138, 220), Size = new Size(142, 32) };
        editConfig.Click += (s, e) => OpenPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "resources", "scraper", "scraper-config.json"));
        var logs = new Button { Text = "Show Logs", Location = new Point(290, 220), Size = new Size(100, 32) };
        logs.Click += (s, e) => { OpenPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "resources", "run")); OpenPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "resources", "web", "logs")); };
        var stopAll = new Button { Text = "Stop All", Location = new Point(400, 220), Size = new Size(120, 32) };
        stopAll.Click += (s, e) => { Launcher.StopWeb(); Launcher.StopDns(); RefreshStatus(); };
        var quit = new Button { Text = "Quit", Location = new Point(420, 260), Size = new Size(100, 28) };
        quit.Click += (s, e) => Close();

        Controls.AddRange(new Control[] { heading, address, webStatus, webButton, dnsStatus, dnsButton, assetStatus, update, editConfig, logs, stopAll, quit });
        refreshTimer = new System.Windows.Forms.Timer { Interval = 700 };
        refreshTimer.Tick += (s, e) => RefreshStatus();
        refreshTimer.Start();
        Shown += (s, e) => { Launcher.StartWeb(); RefreshStatus(); };
        FormClosed += (s, e) => { refreshTimer.Stop(); Launcher.StopAll(); };
        AcceptButton = quit;
        RefreshStatus();
    }

    static void OpenPath(string path)
    {
        try { Process.Start(new ProcessStartInfo(path) { UseShellExecute = true }); }
        catch (Exception e) { MessageBox.Show(e.Message, "Liberated", MessageBoxButtons.OK, MessageBoxIcon.Error); }
    }

    void RefreshStatus()
    {
        bool web = Launcher.WebRunning;
        bool dns = Launcher.DnsRunning;
        webStatus.Text = "Web server: " + (web ? "Running" : "Stopped");
        dnsStatus.Text = "DNS server: " + (dns ? "Running" : "Stopped");
        webButton.Text = web ? "Stop Web" : "Start Web";
        dnsButton.Text = dns ? "Stop DNS" : "Start DNS";
    }
}
'@

    & $csc /nologo /target:winexe /optimize+ "/out:$Out\Liberated.exe" "/win32icon:$Work\icon.ico" `
        /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll "$Work\Launcher.cs"
    if ($LASTEXITCODE -ne 0) { throw 'Failed to compile Liberated.exe' }

    $size = (Get-ChildItem -Recurse $Out | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host ''
    Write-Host "==> Built: $Out"
    Write-Host ('    Size: {0:N0} MB' -f $size)
}
finally {
    Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}
