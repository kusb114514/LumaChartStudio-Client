using System.Security.Cryptography;
using System.Text;
using Android.Security.Keystore;
using Java.Security;
using Javax.Crypto;
using Javax.Crypto.Spec;
using LumaChart.Storage;

namespace LumaChart.Android.Platform;

internal sealed class AndroidKeystoreSessionTokenStore : ISessionTokenStore
{
    private const string KeyStoreProvider = "AndroidKeyStore";
    private const string KeyAlias = "cc.lumachart.studio.online-session.v1";
    private const string CipherTransformation = "AES/GCM/NoPadding";
    private const int MaximumPlaintextTokenBytes = 8 * 1024;
    private const int MaximumProtectedTokenBytes = 64 * 1024;
    private const int GcmTagBits = 128;
    private static readonly byte[] Header = "LCS1"u8.ToArray();
    private static readonly Encoding StrictUtf8 = new UTF8Encoding(false, true);
    private readonly string storePath;

    public AndroidKeystoreSessionTokenStore(IAppStorageLocations locations)
    {
        ArgumentNullException.ThrowIfNull(locations);
        storePath = Path.Combine(locations.Settings, "online-session.bin");
    }

    public ValueTask<string?> LoadAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!File.Exists(storePath)) return ValueTask.FromResult<string?>(null);

        try
        {
            var protectedBytes = File.ReadAllBytes(storePath);
            if (protectedBytes.Length <= Header.Length + 1 ||
                protectedBytes.Length > MaximumProtectedTokenBytes ||
                !protectedBytes.AsSpan(0, Header.Length).SequenceEqual(Header))
                throw new InvalidDataException("The protected session token has an invalid format.");

            var nonceLength = protectedBytes[Header.Length];
            var payloadOffset = Header.Length + 1 + nonceLength;
            if (nonceLength < 12 || nonceLength > 32 || payloadOffset >= protectedBytes.Length)
                throw new InvalidDataException("The protected session token has an invalid nonce.");

            var nonce = protectedBytes.AsSpan(Header.Length + 1, nonceLength).ToArray();
            var ciphertext = protectedBytes.AsSpan(payloadOffset).ToArray();
            var plaintext = Decrypt(nonce, ciphertext);
            try
            {
                if (plaintext.Length <= 0 || plaintext.Length > MaximumPlaintextTokenBytes)
                    throw new InvalidDataException("The session token has an invalid size.");
                var token = StrictUtf8.GetString(plaintext);
                return ValueTask.FromResult(string.IsNullOrWhiteSpace(token) ? null : token);
            }
            finally
            {
                CryptographicOperations.ZeroMemory(plaintext);
                CryptographicOperations.ZeroMemory(ciphertext);
            }
        }
        catch
        {
            TryDeleteFile();
            return ValueTask.FromResult<string?>(null);
        }
    }

    public ValueTask SaveAsync(string token, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (string.IsNullOrWhiteSpace(token))
            throw new ArgumentException("A session token cannot be empty.", nameof(token));

        var plaintext = StrictUtf8.GetBytes(token);
        if (plaintext.Length > MaximumPlaintextTokenBytes)
        {
            CryptographicOperations.ZeroMemory(plaintext);
            throw new ArgumentException("The session token is too large.", nameof(token));
        }

        byte[] nonce;
        byte[] ciphertext;
        try
        {
            (nonce, ciphertext) = Encrypt(plaintext);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(plaintext);
        }

        var protectedBytes = new byte[Header.Length + 1 + nonce.Length + ciphertext.Length];
        Header.CopyTo(protectedBytes, 0);
        protectedBytes[Header.Length] = checked((byte)nonce.Length);
        nonce.CopyTo(protectedBytes, Header.Length + 1);
        ciphertext.CopyTo(protectedBytes, Header.Length + 1 + nonce.Length);
        CryptographicOperations.ZeroMemory(ciphertext);
        if (protectedBytes.Length > MaximumProtectedTokenBytes)
            throw new InvalidOperationException("The protected session token is too large.");

        Directory.CreateDirectory(Path.GetDirectoryName(storePath)!);
        var temporary = $"{storePath}.{Guid.NewGuid():N}.tmp";
        try
        {
            File.WriteAllBytes(temporary, protectedBytes);
            File.Move(temporary, storePath, true);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(protectedBytes);
            try
            {
                if (File.Exists(temporary)) File.Delete(temporary);
            }
            catch
            {
                // Preserve the primary secure-write failure.
            }
        }
        return ValueTask.CompletedTask;
    }

    public ValueTask DeleteAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        TryDeleteFile();
        using var keyStore = LoadKeyStore();
        if (keyStore.ContainsAlias(KeyAlias)) keyStore.DeleteEntry(KeyAlias);
        return ValueTask.CompletedTask;
    }

    private static (byte[] Nonce, byte[] Ciphertext) Encrypt(byte[] plaintext)
    {
        using var cipher = Cipher.GetInstance(CipherTransformation)
            ?? throw new InvalidOperationException("Android AES-GCM is unavailable.");
        using var key = GetOrCreateKey();
        cipher.Init(Javax.Crypto.CipherMode.EncryptMode, key);
        var ciphertext = cipher.DoFinal(plaintext)
            ?? throw new InvalidOperationException("Android Keystore encryption returned no data.");
        var nonce = cipher.GetIV()
            ?? throw new InvalidOperationException("Android Keystore encryption returned no nonce.");
        return (nonce, ciphertext);
    }

    private static byte[] Decrypt(byte[] nonce, byte[] ciphertext)
    {
        using var cipher = Cipher.GetInstance(CipherTransformation)
            ?? throw new InvalidOperationException("Android AES-GCM is unavailable.");
        using var key = GetOrCreateKey();
        using var parameters = new GCMParameterSpec(GcmTagBits, nonce);
        cipher.Init(Javax.Crypto.CipherMode.DecryptMode, key, parameters);
        return cipher.DoFinal(ciphertext)
            ?? throw new InvalidOperationException("Android Keystore decryption returned no data.");
    }

    private static Java.Security.IKey GetOrCreateKey()
    {
        using var keyStore = LoadKeyStore();
        if (keyStore.ContainsAlias(KeyAlias))
            return keyStore.GetKey(KeyAlias, null)
                ?? throw new InvalidOperationException("Android Keystore did not return the session key.");

        using var generator = KeyGenerator.GetInstance(KeyProperties.KeyAlgorithmAes, KeyStoreProvider)
            ?? throw new InvalidOperationException("Android Keystore AES generator is unavailable.");
        using var specification = new KeyGenParameterSpec.Builder(
                KeyAlias,
                KeyStorePurpose.Encrypt | KeyStorePurpose.Decrypt)
            .SetBlockModes(KeyProperties.BlockModeGcm)
            .SetEncryptionPaddings(KeyProperties.EncryptionPaddingNone)
            .SetRandomizedEncryptionRequired(true)
            .Build();
        generator.Init(specification);
        return generator.GenerateKey()
            ?? throw new InvalidOperationException("Android Keystore did not generate the session key.");
    }

    private static KeyStore LoadKeyStore()
    {
        var keyStore = KeyStore.GetInstance(KeyStoreProvider)
            ?? throw new InvalidOperationException("Android Keystore is unavailable.");
        keyStore.Load(null);
        return keyStore;
    }

    private void TryDeleteFile()
    {
        try
        {
            if (File.Exists(storePath)) File.Delete(storePath);
        }
        catch
        {
            // Corrupt or obsolete state remains unusable even if cleanup is denied.
        }
    }
}
