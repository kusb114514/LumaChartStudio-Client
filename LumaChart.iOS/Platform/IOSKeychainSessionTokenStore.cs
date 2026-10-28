using Foundation;
using LumaChart.Storage;
using Security;

namespace LumaChart.iOS.Platform;

/// <summary>
/// Stores only the revocable server session token, in the iOS Keychain.
///
/// The contract requires failing closed: a Keychain error is surfaced rather
/// than answered with a plaintext file, so a device that cannot protect the
/// token simply has no stored session and the user signs in again.
/// </summary>
internal sealed class IOSKeychainSessionTokenStore : ISessionTokenStore
{
    private const string ServiceName = "cc.lumachart.studio.online-session";
    private const string AccountName = "session.v1";
    private const int MaximumTokenBytes = 8 * 1024;

    public ValueTask<string?> LoadAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        using var query = CreateQuery();
        var data = SecKeyChain.QueryAsData(query, false, out var status);

        if (status == SecStatusCode.ItemNotFound) return ValueTask.FromResult<string?>(null);
        if (status != SecStatusCode.Success)
            throw new InvalidOperationException($"Reading the session token failed: {status}.");
        if (data == null || data.Length == 0) return ValueTask.FromResult<string?>(null);

        // A stored value that is not valid UTF-8, or is implausibly large, is
        // treated as corruption rather than decoded loosely.
        if (data.Length > MaximumTokenBytes)
            throw new InvalidDataException("The stored session token has an invalid length.");

        var token = NSString.FromData(data, NSStringEncoding.UTF8)?.ToString();
        if (string.IsNullOrEmpty(token))
            throw new InvalidDataException("The stored session token is not valid UTF-8.");

        return ValueTask.FromResult<string?>(token);
    }

    public ValueTask SaveAsync(string token, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrEmpty(token);
        cancellationToken.ThrowIfCancellationRequested();

        using var value = NSData.FromString(token, NSStringEncoding.UTF8)
            ?? throw new InvalidOperationException("The session token could not be encoded.");
        if (value.Length > MaximumTokenBytes)
            throw new ArgumentOutOfRangeException(nameof(token), "The session token is too large to store.");

        // Keychain Add refuses to overwrite, so an existing entry is removed
        // first. A stale token left behind after a failed write would be worse
        // than having none.
        Delete();

        using var record = CreateQuery();
        record.ValueData = value;
        // The token is device-bound and revocable: it must not ride along in an
        // encrypted backup onto another device.
        record.Accessible = SecAccessible.WhenUnlockedThisDeviceOnly;

        var status = SecKeyChain.Add(record);
        if (status != SecStatusCode.Success)
            throw new InvalidOperationException($"Storing the session token failed: {status}.");

        return ValueTask.CompletedTask;
    }

    public ValueTask DeleteAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Delete();
        return ValueTask.CompletedTask;
    }

    private static void Delete()
    {
        using var query = CreateQuery();
        var status = SecKeyChain.Remove(query);
        if (status is not (SecStatusCode.Success or SecStatusCode.ItemNotFound))
            throw new InvalidOperationException($"Removing the session token failed: {status}.");
    }

    private static SecRecord CreateQuery() =>
        new(SecKind.GenericPassword)
        {
            Service = ServiceName,
            Account = AccountName
        };
}
