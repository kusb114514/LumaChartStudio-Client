using System.Text;
using System.Text.Json;
using LumaChart.Cli;

// A chart-editing front end for the LumaChart editor, meant to be driven by a
// person or a model over a shell rather than by hand in the GUI.
//
// It deliberately holds no state: every invocation reads the chart, applies one
// change, and writes it back. That keeps a model's turn atomic -- it can dump,
// think, and write -- and it means the tool can never disagree with the file on
// disk about what the chart currently is.
//
// stdout carries JSON and nothing else, so a caller can pipe it straight into a
// parser. Everything meant for a human goes to stderr.

Console.OutputEncoding = Encoding.UTF8;

try
{
    return Run(args);
}
catch (ChartToolException exception)
{
    Console.Error.WriteLine($"lumatool: {exception.Message}");
    return 1;
}
catch (JsonException exception)
{
    Console.Error.WriteLine($"lumatool: the JSON could not be read -- {exception.Message}");
    return 1;
}

static int Run(string[] args)
{
    if (args.Length == 0 || args[0] is "help" or "--help" or "-h")
    {
        PrintUsage();
        return args.Length == 0 ? 2 : 0;
    }

    switch (args[0])
    {
        case "dump":
            return Dump(args[1..]);
        case "write":
            return Write(args[1..]);
        default:
            Console.Error.WriteLine($"lumatool: unknown command '{args[0]}'");
            PrintUsage();
            return 2;
    }
}

static int Dump(string[] args)
{
    if (args.Length == 0) throw new ChartToolException("dump needs a chart path");
    var chartPath = args[0];
    var compact = args.Contains("--compact");

    var dump = ChartTool.Dump(chartPath);
    var json = JsonSerializer.Serialize(dump, compact
        ? new JsonSerializerOptions(ChartToolJson.Options) { WriteIndented = false }
        : ChartToolJson.Options);
    Console.Out.WriteLine(json);

    Console.Error.WriteLine(
        $"lumatool: {dump.Notes.Count} notes, {dump.Drafts.Count} draft notes, " +
        $"{dump.Groups.Count} groups, {dump.Presets.Count} presets, " +
        $"{dump.Annotations.Count} annotations, keyCount {dump.KeyCount}");
    return 0;
}

static int Write(string[] args)
{
    if (args.Length == 0) throw new ChartToolException("write needs a chart path");
    var chartPath = args[0];
    var dryRun = args.Contains("--dry-run");

    var source = ReadPatchSource(args);
    ChartPatch? patch;
    try
    {
        patch = JsonSerializer.Deserialize<ChartPatch>(source, ChartToolJson.Options);
    }
    catch (JsonException exception)
    {
        throw new ChartToolException(
            $"the patch is not valid JSON -- {exception.Message}");
    }
    if (patch is null) throw new ChartToolException("the patch was empty");

    if (patch.Notes is null && patch.Drafts is null && patch.Groups is null &&
        patch.Presets is null && patch.Annotations is null)
    {
        throw new ChartToolException(
            "the patch has none of notes / drafts / groups / presets / annotations, so there is nothing to do");
    }

    var changes = ChartTool.Apply(chartPath, patch, dryRun);
    foreach (var change in changes) Console.Error.WriteLine($"lumatool: {change}");
    Console.Error.WriteLine(dryRun
        ? "lumatool: dry run -- nothing was written"
        : "lumatool: written");
    return 0;
}

static string ReadPatchSource(string[] args)
{
    var fromIndex = Array.IndexOf(args, "--from");
    if (fromIndex >= 0)
    {
        if (fromIndex + 1 >= args.Length)
            throw new ChartToolException("--from needs a file path (use - to read stdin)");
        var path = args[fromIndex + 1];
        return path == "-" ? Console.In.ReadToEnd() : ReadAllText(path);
    }

    if (args.Contains("--stdin")) return Console.In.ReadToEnd();
    return ReadAllText(null);
}

static string ReadAllText(string? path)
{
    if (path is not null)
    {
        if (!File.Exists(path)) throw new ChartToolException($"no such patch file: {path}");
        return File.ReadAllText(path);
    }

    // No flag and no file: take stdin, but only if something is actually piped
    // in. Otherwise the tool would hang waiting on a console nobody is typing at.
    if (Console.IsInputRedirected) return Console.In.ReadToEnd();
    throw new ChartToolException(
        "write needs the patch on stdin, or --from <file>, or --from -");
}

static void PrintUsage()
{
    Console.Error.WriteLine(
        """
        lumatool -- read and write a Malody .mc chart plus its editor metadata.

          lumatool dump  <chart.mc> [--compact]
              Print the chart as JSON: metadata, timing, notes, ProEditor draft
              notes, groups, group presets and annotations.

          lumatool write <chart.mc> [--from <file> | --from - | --stdin] [--dry-run]
              Apply a JSON patch. Any of notes / drafts / groups / presets /
              annotations may be present; each one PRESENT is replaced wholesale,
              each one ABSENT is left alone. A chart write is backed up to
              <chart.mc>.bak-<timestamp> first. --dry-run reports the change and
              writes nothing.

        The JSON shape is exactly what `dump` prints, so a dump can be edited and
        fed straight back:

          {
            "notes":   [ { "lane": 0, "beat": "23:0/4", "endBeat": null, "group": 2 } ],
            "drafts":  [ { "column": 1, "beat": "23:0/4", "group": 7 } ],
            "groups":  [ { "id": 2, "name": "kick", "color": "", "parentId": null } ],
            "presets": [ { "id": 1, "name": "按音轨", "groupIds": [2, 3] } ],
            "annotations": [
              { "id": 1, "text": "这里左手是阶梯", "anchorBeat": "23:0/4",
                "notes": [ { "lane": 1, "beat": "23:0/4" } ] }
            ]
          }

        Beats are written bar:numerator/denominator. Groups, presets and
        annotations live in the editor's local catalog next to its other
        settings, not inside the .mc file, so a chart written here keeps its
        coloured grouping everywhere but only shows group names and annotations
        on this machine.

        Close the editor before writing: it holds the chart in memory and would
        overwrite the file on its next save.
        """);
}
