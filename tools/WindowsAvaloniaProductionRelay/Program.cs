using System.Net;

var builder = WebApplication.CreateSlimBuilder(args);
builder.Logging.ClearProviders();
builder.WebHost.ConfigureKestrel(options =>
{
    var port = ReadIntArgument(args, "--port", 0);
    if (port <= 0) throw new ArgumentException("--port must be a positive integer.");
    options.Listen(IPAddress.Loopback, port);
});

var upstream = new Uri(
    ReadArgument(args, "--upstream") ?? "https://api.lumachart.cc/",
    UriKind.Absolute);
var blackoutFile = Path.GetFullPath(
    ReadArgument(args, "--blackout-file") ??
    Path.Combine(Path.GetTempPath(), "lumachart-production-relay.blackout"));
var blackout = new RelayBlackoutState();
var handler = new SocketsHttpHandler
{
    AllowAutoRedirect = false,
    AutomaticDecompression = DecompressionMethods.None,
    PooledConnectionLifetime = TimeSpan.FromMinutes(3),
    ConnectTimeout = TimeSpan.FromSeconds(15),
    EnableMultipleHttp2Connections = true
};
var client = new HttpClient(handler)
{
    BaseAddress = upstream,
    Timeout = Timeout.InfiniteTimeSpan
};

var app = builder.Build();
app.MapGet("/__relay/health", () => Results.Json(new
{
    status = "ready",
    upstream = upstream.GetLeftPart(UriPartial.Authority),
    blackout = blackout.Enabled || File.Exists(blackoutFile)
}));
app.MapPut("/__relay/blackout/{enabled:bool}", (bool enabled) =>
{
    blackout.Enabled = enabled;
    return Results.Json(new { blackout = blackout.Enabled });
});
app.Map("/{**path}", ForwardAsync);
await app.RunAsync();

async Task ForwardAsync(HttpContext context)
{
    if (blackout.Enabled || File.Exists(blackoutFile))
    {
        context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
        context.Response.Headers.RetryAfter = "1";
        await context.Response.WriteAsJsonAsync(new
        {
            error = "relay_blackout",
            message = "Temporary client-local network interruption."
        });
        return;
    }

    var relative = context.Request.PathBase.Add(context.Request.Path) +
                   context.Request.QueryString;
    using var request = new HttpRequestMessage(
        new HttpMethod(context.Request.Method),
        new Uri(relative, UriKind.Relative));
    if (context.Request.ContentLength is > 0 ||
        context.Request.Headers.ContainsKey("Transfer-Encoding"))
    {
        request.Content = new StreamContent(context.Request.Body);
    }

    foreach (var header in context.Request.Headers)
    {
        if (header.Key.Equals("Host", StringComparison.OrdinalIgnoreCase))
            continue;
        if (!request.Headers.TryAddWithoutValidation(header.Key, header.Value.ToArray()))
            request.Content?.Headers.TryAddWithoutValidation(
                header.Key,
                header.Value.ToArray());
    }

    using var response = await client.SendAsync(
        request,
        HttpCompletionOption.ResponseHeadersRead,
        context.RequestAborted);
    context.Response.StatusCode = (int)response.StatusCode;
    foreach (var header in response.Headers)
        context.Response.Headers[header.Key] = header.Value.ToArray();
    foreach (var header in response.Content.Headers)
        context.Response.Headers[header.Key] = header.Value.ToArray();
    context.Response.Headers.Remove("transfer-encoding");
    await response.Content.CopyToAsync(
        context.Response.Body,
        context.RequestAborted);
}

static string? ReadArgument(string[] arguments, string name)
{
    var index = Array.FindIndex(
        arguments,
        argument => string.Equals(argument, name, StringComparison.Ordinal));
    return index >= 0 && index + 1 < arguments.Length
        ? arguments[index + 1]
        : null;
}

static int ReadIntArgument(string[] arguments, string name, int fallback) =>
    int.TryParse(ReadArgument(arguments, name), out var value) ? value : fallback;

sealed class RelayBlackoutState
{
    private int enabled;

    public bool Enabled
    {
        get => Volatile.Read(ref enabled) != 0;
        set => Interlocked.Exchange(ref enabled, value ? 1 : 0);
    }
}
