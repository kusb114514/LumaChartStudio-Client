using System.Text.Json;
using System.Text.Json.Serialization;
using LumaChart.Core.Models;

namespace LumaChart.Avalonia.Infrastructure;

/// <summary>
/// Beat positions read and write as the same "bar:numerator/denominator" text
/// the chart formats use, so a stored position still resolves after the chart
/// has been saved and reopened.
///
/// Shared by the per-chart catalog and by the editor-metadata archive: both
/// store the same kind of position and both have to survive a round trip
/// through a file on disk, so they must agree on the spelling.
/// </summary>
internal sealed class BeatPositionJsonConverter : JsonConverter<BeatPosition>
{
    public override BeatPosition Read(
        ref Utf8JsonReader reader,
        Type typeToConvert,
        JsonSerializerOptions options) =>
        reader.TokenType == JsonTokenType.String &&
        BeatPosition.TryParse(reader.GetString(), out var position)
            ? position
            : BeatPosition.Zero;

    public override void Write(
        Utf8JsonWriter writer,
        BeatPosition value,
        JsonSerializerOptions options) =>
        writer.WriteStringValue(value.ToString());
}
