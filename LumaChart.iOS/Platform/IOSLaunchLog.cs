using System.Runtime.CompilerServices;
using System.Text;
using Foundation;

namespace LumaChart.iOS.Platform;

/// <summary>
/// Startup breadcrumb and crash trail for the iOS host.
///
/// The build VM cannot run the app, and a Mono unhandled exception reaches the
/// device only as a bare <c>abort()</c>: the crash report carries no managed
/// stack, and the runtime's own message reaches the system log redacted as
/// <c>&lt;private&gt;</c>, which cannot be unredacted without an Apple-signed
/// logging profile. Without this file the only available signal is "it closed".
///
/// The file lives in <c>Library/Caches</c>. It used to sit in <c>Documents</c>,
/// where the Files app showed it to users beside their charts and iCloud backed
/// it up. A development-signed build still lets the house-arrest container
/// service reach it: <c>apps pull &lt;bundle&gt; /Library/Caches/launch-log.txt</c>.
///
/// The file is capped (<see cref="MaximumLogBytes"/>, one previous generation
/// kept) and a failure that repeats — a handler throwing every frame — is
/// written once per <see cref="RepeatedFailureInterval"/> with a count, instead
/// of a full stack per frame.
/// </summary>
internal static class IOSLaunchLog
{
    private const string FileName = "launch-log.txt";
    private const string PreviousFileName = "launch-log.previous.txt";
    private const long MaximumLogBytes = 1024 * 1024;
    private const int MaximumTrackedFailures = 64;
    private static readonly TimeSpan RepeatedFailureInterval = TimeSpan.FromSeconds(30);
    private static readonly object Gate = new();
    private static readonly Dictionary<string, RepeatedFailure> RecentFailures = new(StringComparer.Ordinal);
    private static string? logPath;
    private static long logBytes;
    private static bool installed;

    /// <summary>
    /// Runs when this assembly is loaded, before <c>Main</c>. An earlier
    /// version installed from <c>Main</c> and produced no file at all, which
    /// left "managed code never ran" and "logging itself failed"
    /// indistinguishable. Starting here separates them.
    /// </summary>
    [ModuleInitializer]
    internal static void OnModuleLoad() => Install("module initializer");

    public static void Install(string origin = "explicit")
    {
        lock (Gate)
        {
            if (installed) return;
            installed = true;
        }

        TryOpen(origin);

        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
            WriteException("AppDomain.UnhandledException", args.ExceptionObject as Exception);

        TaskScheduler.UnobservedTaskException += (_, args) =>
            WriteException("TaskScheduler.UnobservedTaskException", args.Exception);

        AppDomain.CurrentDomain.FirstChanceException += (_, args) =>
        {
            // First-chance is noisy by nature, but a DllNotFoundException or
            // TypeInitializationException during startup is the exact class of
            // failure that otherwise dies as a bare abort().
            if (args.Exception is DllNotFoundException or TypeInitializationException
                or EntryPointNotFoundException or FileNotFoundException)
                WriteException($"FirstChance:{args.Exception.GetType().Name}", args.Exception);
        };

        Write($"log installed at {logPath ?? "(not resolvable yet)"}");
    }

    /// <summary>
    /// Resolves a writable location and starts the file, returning whether the
    /// trail is now open.
    ///
    /// Retried from <see cref="Write"/> rather than run once, because the
    /// module initializer that first calls it runs before the Xamarin runtime
    /// has finished coming up: every candidate below resolves to null that
    /// early, and the original one-shot version therefore left logPath null for
    /// the rest of the process and silently discarded every line. That is why
    /// no launch log ever reached the device through 1.2.0.8 and 1.2.0.9 —
    /// checked over AFC, Documents held only the chart library folder.
    /// </summary>
    private static bool TryOpen(string origin)
    {
        // Several candidates, because the first one is exactly what failed
        // before. Anything writable is better than no trail at all.
        foreach (var candidate in EnumerateCandidateDirectories())
        {
            try
            {
                if (string.IsNullOrWhiteSpace(candidate))
                {
                    Console.WriteLine($"launch-log: candidate unavailable (via {origin})");
                    continue;
                }

                Directory.CreateDirectory(candidate);
                var path = Path.Combine(candidate, FileName);
                var header =
                    $"=== LumaChart Studio iOS launch {DateTimeOffset.Now:O} (via {origin}) ==={Environment.NewLine}";
                File.WriteAllText(path, header, Encoding.UTF8);
                lock (Gate)
                {
                    logPath = path;
                    logBytes = Encoding.UTF8.GetByteCount(header);
                }
                Console.WriteLine($"launch-log: writing to {path}");
                RemoveLegacyDocumentsLog();
                return true;
            }
            catch (Exception exception)
            {
                // Try the next candidate; diagnostics must never be the reason
                // the app fails to start. Reported on stdout because a failure
                // here is precisely a failure to record anything in the file.
                Console.WriteLine(
                    $"launch-log: candidate '{candidate}' rejected: {exception.GetType().Name}: {exception.Message}");
            }
        }

        return false;
    }

    private static IEnumerable<string?> EnumerateCandidateDirectories()
    {
        yield return TryNative(() => NSFileManager.DefaultManager
            .GetUrls(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomain.User)
            .FirstOrDefault()?.Path);

        yield return TryNative(() =>
        {
            var library = NSFileManager.DefaultManager.GetUrls(
                NSSearchPathDirectory.LibraryDirectory, NSSearchPathDomain.User).FirstOrDefault()?.Path;
            return library == null ? null : Path.Combine(library, "Caches");
        });

        yield return TryNative(() =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Library", "Caches"));

        yield return TryNative(Path.GetTempPath);
    }

    /// <summary>
    /// Builds before the move left their trail in <c>Documents</c>, where the
    /// Files app lists it beside the user's charts. It is rewritten on every
    /// launch anyway, so nothing is lost by removing it once the new one is open.
    /// </summary>
    private static void RemoveLegacyDocumentsLog()
    {
        try
        {
            var documents = NSFileManager.DefaultManager
                .GetUrls(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomain.User)
                .FirstOrDefault()?.Path;
            if (string.IsNullOrWhiteSpace(documents)) return;
            var legacy = Path.Combine(documents, FileName);
            if (File.Exists(legacy)) File.Delete(legacy);
        }
        catch (Exception)
        {
            // A stale diagnostic file is harmless; see Install.
        }
    }

    private static string? TryNative(Func<string?> resolve)
    {
        try { return resolve(); }
        catch (Exception) { return null; }
    }

    /// <summary>
    /// The trail's path, opening it first if the earlier attempt was too early
    /// to resolve one. See <see cref="TryOpen"/>.
    /// </summary>
    private static string? EnsurePath()
    {
        if (logPath == null) TryOpen("deferred");
        return logPath;
    }

    public static void Write(string stage)
    {
        var line = $"[{DateTimeOffset.Now:HH:mm:ss.fff}] {stage}";

        // Standard output first, and unconditionally. It reaches the host over
        // `pymobiledevice3 developer dvt launch --stream`, which is the only
        // channel proven to carry this app's own text off the device — the file
        // below has never appeared in the sandbox on any build so far, and a
        // trail that silently depends on the thing being debugged is worthless.
        Console.WriteLine(line);

        var path = EnsurePath();
        if (path == null) return;
        AppendToFile(path, line);
    }

    /// <summary>
    /// Records a failure, cheapest and safest fact first.
    ///
    /// The order is not cosmetic. Reading <see cref="Exception.Message"/> — which
    /// <c>ToString</c> does — asks System.Private.CoreLib for a resource string,
    /// and that lookup guards itself against re-entry by calling
    /// <see cref="Environment.FailFast(string)"/>:
    ///
    ///   Encountered infinite recursion while looking up resource
    ///   'IO_FileName_Name' in System.Private.CoreLib.
    ///
    /// which no catch block can stop. That is exactly what happened the first
    /// time this method reached its body: until file I/O worked it always
    /// returned early at the null path check, so the first exception it ever
    /// formatted took the process down with it, during Avalonia setup, and left
    /// no record of which exception it was.
    ///
    /// So the type name and the stack — neither of which needs a resource — are
    /// written and flushed before the message is touched. If formatting still
    /// aborts the process, the log already names the culprit.
    ///
    /// The same pair also identifies a repeat. The dispatcher guard reports
    /// every exception a handler throws, and a broken per-frame handler throws
    /// up to 120 times a second; each used to append a full stack, synchronously,
    /// with no bound on the file. A repeat within
    /// <see cref="RepeatedFailureInterval"/> is now only counted, and the count
    /// is written with the next occurrence that is recorded.
    /// </summary>
    public static void WriteException(string stage, Exception? exception)
    {
        if (exception == null) return;
        var path = EnsurePath();
        if (path == null) return;

        var typeName = exception.GetType().FullName;
        string stack;
        try { stack = exception.StackTrace ?? "(no stack)"; }
        catch (Exception) { stack = "(stack unavailable)"; }

        if (!ShouldRecordFailure($"{stage}|{typeName}|{stack}", out var repeats)) return;

        Append(path, $"[{DateTimeOffset.Now:HH:mm:ss.fff}] FAILED at {stage}: {typeName}" +
            (repeats > 0 ? $" (+{repeats} identical since last recorded)" : string.Empty));
        Append(path, stack);

        try { Append(path, exception.ToString()); }
        catch (Exception) { Append(path, "(message unavailable)"); }
    }

    /// <summary>
    /// Whether this failure should be written now, and how many identical ones
    /// were swallowed since it last was.
    /// </summary>
    private static bool ShouldRecordFailure(string key, out int repeats)
    {
        var now = DateTimeOffset.UtcNow;
        lock (Gate)
        {
            if (RecentFailures.TryGetValue(key, out var failure) &&
                now - failure.LastRecorded < RepeatedFailureInterval)
            {
                failure.Suppressed++;
                repeats = 0;
                return false;
            }

            repeats = failure?.Suppressed ?? 0;
            if (failure == null && RecentFailures.Count >= MaximumTrackedFailures)
                RecentFailures.Clear();
            RecentFailures[key] = new RepeatedFailure { LastRecorded = now };
            return true;
        }
    }

    private static void Append(string path, string text)
    {
        Console.WriteLine(text);
        AppendToFile(path, text);
    }

    /// <summary>
    /// Appends one line, starting a fresh file once this one would pass
    /// <see cref="MaximumLogBytes"/>. The full file becomes
    /// <see cref="PreviousFileName"/>, so the newest lines — the ones that
    /// explain a failure — and one generation before them are always kept.
    /// </summary>
    private static void AppendToFile(string path, string text)
    {
        try
        {
            lock (Gate)
            {
                var line = text + Environment.NewLine;
                var length = Encoding.UTF8.GetByteCount(line);
                if (logBytes + length > MaximumLogBytes)
                {
                    File.Move(
                        path,
                        Path.Combine(Path.GetDirectoryName(path)!, PreviousFileName),
                        overwrite: true);
                    var header =
                        $"=== continued from {PreviousFileName} at {DateTimeOffset.Now:O} ==={Environment.NewLine}";
                    File.WriteAllText(path, header, Encoding.UTF8);
                    logBytes = Encoding.UTF8.GetByteCount(header);
                }

                File.AppendAllText(path, line, Encoding.UTF8);
                logBytes += length;
            }
        }
        catch (Exception)
        {
            // See Install.
        }
    }

    private sealed class RepeatedFailure
    {
        public DateTimeOffset LastRecorded { get; init; }
        public int Suppressed { get; set; }
    }
}
