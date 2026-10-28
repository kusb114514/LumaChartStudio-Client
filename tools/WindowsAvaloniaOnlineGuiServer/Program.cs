using System.Collections.Concurrent;
using System.Net;
using System.Numerics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using LumaChart.Online;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;

namespace WindowsAvaloniaOnlineGuiServer;

internal static class Program
{
    private static readonly byte[] OwnerAvatarPng = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAFiUAABYlAUlSJPAAAADRSURBVFhH7ZS7DYNADEA9CysgxA7UiIYNqJCoMgINO9AwA01mc0SkCJ/xXXynEApcvAbf550/wGN94pUA//BvTMAETMAEkgTaGhCAUU+HdRriBOYBM36xQ4HVLOwLoBdgl5fjHuv6gkg02PK9AdQCNO30cime9csh7kMpMGH57YU0Q/mAHY970AnQw73NppAU0AmMzV7jewo4E+A5/NQeWBes8o+APAV0FE+YAp6FwH8g4vUbeoEN2gsinvIEiBN445YjJe2UBIHfYgImYAIm8AKTuxoFTfMN4gAAAABJRU5ErkJggg==");
    private static readonly byte[] MemberAvatarPng = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAAFiUAABYlAUlSJPAAAADQSURBVFhH7dS7EcMgDAZgTcECKamoQ+s6G1B4hazAHTukyyCeI+Mo5wsEQTif85DSqFBhrIPvfh5wu5zwnwX9gHQpQAEKUMAuwBIMAkAt63D5oo/WZwAwGFPfN2G0tIcDYA36PLkPU9uXXP5n0BfIzwEbk4+Qfc+o3gQcMBJM3YYavw8OZ07A9Rk12QYSf0xHZgA9bHmBGv/6zQ5oz0RMNP41EQFAjRxwPpcFy5mQAGzeeRHA6+NU3wUhAN2G9kpKAQa34THOAOAsBShAAQq4Ax6eLWZGw7j9AAAAAElFTkSuQmCC");

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true
    };

    public static async Task Main(string[] args)
    {
        var readyPath = Argument(args, "--ready-file");
        var statePath = Argument(args, "--state-file");
        var checkpointPath = Argument(args, "--checkpoint-file");
        var listenUrl = Argument(args, "--listen-url") ?? "http://127.0.0.1:0";
        if (!Uri.TryCreate(listenUrl, UriKind.Absolute, out var listener) ||
            listener.Scheme != Uri.UriSchemeHttp ||
            !IPAddress.IsLoopback(listener.HostNameType == UriHostNameType.IPv6
                ? IPAddress.Parse(listener.Host)
                : listener.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase)
                    ? IPAddress.Loopback
                    : IPAddress.Parse(listener.Host)))
            throw new InvalidOperationException(
                $"The GUI harness listener must be an explicit loopback HTTP URL: {listenUrl}");
        var processGeneration = int.TryParse(
            Argument(args, "--process-generation"),
            out var parsedGeneration)
            ? Math.Max(1, parsedGeneration)
            : 1;
        var appConfiguration = new OnlineAppConfigurationDto(
            Argument(args, "--app-about-content") ??
            "Windows Avalonia owner 管理 GUI 验收内容。",
            Argument(args, "--app-latest-version") ?? "1.1.0",
            Argument(args, "--app-minimum-login-version") ?? "1.1.0",
            Argument(args, "--app-update-notice") ?? "当前为隔离 loopback 验收配置。",
            Argument(args, "--app-download-url") ??
            "https://example.invalid/lumachart",
            DateTimeOffset.Parse("2026-07-27T00:00:00Z"));
        var builder = WebApplication.CreateBuilder(args);
        builder.Logging.ClearProviders();
        builder.WebHost.UseUrls(listenUrl);
        var app = builder.Build();
        var state = new HarnessState(
            statePath,
            checkpointPath,
            processGeneration,
            appConfiguration);
        MapEndpoints(app, state);

        await app.StartAsync().ConfigureAwait(false);
        var addresses = app.Services.GetRequiredService<IServer>()
            .Features.Get<IServerAddressesFeature>()?.Addresses;
        var endpoint = addresses?.SingleOrDefault(address =>
            address.StartsWith("http://127.0.0.1:", StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException("The loopback listener did not publish its endpoint.");
        endpoint = endpoint.TrimEnd('/') + "/";
        if (!string.IsNullOrWhiteSpace(readyPath))
        {
            readyPath = Path.GetFullPath(readyPath);
            Directory.CreateDirectory(Path.GetDirectoryName(readyPath)
                ?? throw new InvalidOperationException("The ready file has no parent directory."));
            await File.WriteAllTextAsync(
                readyPath,
                JsonSerializer.Serialize(new
                {
                    endpoint,
                    ownerToken = HarnessState.OwnerToken,
                    memberToken = HarnessState.MemberToken,
                    roomId = HarnessState.RoomId,
                    roomNumber = HarnessState.RoomNumber,
                    processGeneration = state.ProcessGeneration,
                    restoredFromCheckpoint = state.RestoredFromCheckpoint
                }, JsonOptions)).ConfigureAwait(false);
        }

        Console.WriteLine($"WINDOWS_AVALONIA_ONLINE_GUI_SERVER_READY {endpoint}");
        await app.WaitForShutdownAsync().ConfigureAwait(false);
    }

    private static void MapEndpoints(WebApplication app, HarnessState state)
    {
        app.Use(async (context, next) =>
        {
            state.Requests.Enqueue($"{context.Request.Method} {context.Request.Path}{context.Request.QueryString}");
            if (context.Request.Path.StartsWithSegments("/api") &&
                state.TryRecordTransportAbort(context))
            {
                context.Abort();
                return;
            }
            await next(context).ConfigureAwait(false);
        });

        app.MapGet("/health", () => Results.Json(new { status = "ok" }, JsonOptions));
        app.MapGet("/harness/state", () =>
        {
            lock (state.Gate) return Results.Json(state.Evidence(), JsonOptions);
        });
        app.MapPost("/harness/faults", async (HttpContext context) =>
        {
            var request = await context.Request
                .ReadFromJsonAsync<HarnessFaultInjectionRequest>(JsonOptions)
                .ConfigureAwait(false);
            if (request == null) return Results.BadRequest();
            try
            {
                lock (state.Gate)
                {
                    state.ConfigureFaults(request);
                    state.WriteState();
                    return Results.Json(state.FaultEvidence(), JsonOptions);
                }
            }
            catch (ArgumentOutOfRangeException exception)
            {
                return Results.BadRequest(new { code = "invalid_fault_plan", message = exception.Message });
            }
        });
        app.MapDelete("/harness/faults", () =>
        {
            lock (state.Gate)
            {
                state.ConfigureFaults(new HarnessFaultInjectionRequest());
                state.WriteState();
                return Results.Json(state.FaultEvidence(), JsonOptions);
            }
        });
        app.MapPost("/harness/network-blackout", async (HttpContext context) =>
        {
            var request = await context.Request
                .ReadFromJsonAsync<HarnessNetworkBlackoutRequest>(JsonOptions)
                .ConfigureAwait(false);
            if (request == null) return Results.BadRequest();
            lock (state.Gate)
            {
                if (!state.ConfigureNetworkBlackout(request.UserId, request.Enabled))
                    return Results.BadRequest(new
                    {
                        code = "invalid_blackout_user",
                        message = "The requested harness user does not exist."
                    });
                state.WriteState();
                return Results.Json(state.LeaseEvidence(), JsonOptions);
            }
        });
        app.MapPost("/harness/lease/advance", async (HttpContext context) =>
        {
            var request = await context.Request
                .ReadFromJsonAsync<HarnessLeaseAdvanceRequest>(JsonOptions)
                .ConfigureAwait(false);
            if (request == null || request.Seconds is < 0 or > 3600)
                return Results.BadRequest(new
                {
                    code = "invalid_lease_advance",
                    message = "Lease clock advance must be between 0 and 3600 seconds."
                });
            lock (state.Gate)
            {
                state.AdvanceLeaseClock(TimeSpan.FromSeconds(request.Seconds));
                state.WriteState();
                return Results.Json(state.LeaseEvidence(), JsonOptions);
            }
        });
        app.MapPost("/harness/lease/cleanup", () =>
        {
            lock (state.Gate)
            {
                state.ApplyLeaseCleanup();
                state.WriteState();
                return Results.Json(state.LeaseEvidence(), JsonOptions);
            }
        });
        app.MapPost("/harness/notifications", async (HttpContext context) =>
        {
            var request = await context.Request
                .ReadFromJsonAsync<HarnessNotificationInjectionRequest>(JsonOptions)
                .ConfigureAwait(false);
            if (request == null) return Results.BadRequest();
            lock (state.Gate)
            {
                try
                {
                    var notification = state.AddNotification(request);
                    state.WriteState();
                    return Results.Json(notification, JsonOptions);
                }
                catch (ArgumentException exception)
                {
                    return Results.BadRequest(new
                    {
                        code = "invalid_notification",
                        message = exception.Message
                    });
                }
            }
        });

        app.MapGet("/api/me", (HttpContext context) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            lock (state.Gate)
                return Results.Json(state.UserProfile(user), JsonOptions);
        });
        app.MapGet("/api/app-config", () =>
        {
            lock (state.Gate)
                return Results.Json(state.AppConfiguration, JsonOptions);
        });
        app.MapPut("/api/admin/app-config", async (HttpContext context) =>
        {
            var owner = state.Authenticate(context);
            if (owner?.Role != "owner") return Results.Forbid();
            var request = await context.Request
                .ReadFromJsonAsync<OnlineUpdateAppConfigurationRequestDto>(JsonOptions)
                .ConfigureAwait(false);
            if (request == null) return Results.BadRequest();
            lock (state.Gate)
            {
                state.AdminConfigurationUpdateCount++;
                state.AppConfiguration = new OnlineAppConfigurationDto(
                    request.AboutContent ?? string.Empty,
                    request.LatestVersion ?? string.Empty,
                    request.MinimumLoginVersion ?? string.Empty,
                    request.UpdateNotice ?? string.Empty,
                    request.DownloadUrl ?? string.Empty,
                    DateTimeOffset.UtcNow);
                state.WriteState();
                return Results.Json(state.AppConfiguration, JsonOptions);
            }
        });
        app.MapGet("/api/admin/users/{userId:long}", (HttpContext context, long userId) =>
        {
            var owner = state.Authenticate(context);
            if (owner?.Role != "owner") return Results.Forbid();
            lock (state.Gate)
            {
                var user = state.FindUser(userId);
                if (user == null) return Results.NotFound();
                state.AdminUserReadCount++;
                state.WriteState();
                return Results.Json(state.UserProfile(user), JsonOptions);
            }
        });
        app.MapPut("/api/admin/users/{userId:long}",
            async (HttpContext context, long userId) =>
            {
                var owner = state.Authenticate(context);
                if (owner?.Role != "owner") return Results.Forbid();
                var request = await context.Request
                    .ReadFromJsonAsync<OnlineAdminUpdateUserRequestDto>(JsonOptions)
                    .ConfigureAwait(false);
                if (request == null) return Results.BadRequest();
                lock (state.Gate)
                {
                    var user = state.FindUser(userId);
                    if (user == null) return Results.NotFound();
                    user.Username = request.Username?.Trim() ?? user.Username;
                    user.DisplayName = request.DisplayName?.Trim() ?? user.DisplayName;
                    user.Bio = request.Bio?.Trim() ?? string.Empty;
                    user.Tags = request.Tags?.ToArray() ?? [];
                    state.AdminUserUpdateCount++;
                    state.WriteState();
                    return Results.Json(state.UserProfile(user), JsonOptions);
                }
            });
        app.MapPut("/api/admin/users/{userId:long}/label",
            async (HttpContext context, long userId) =>
            {
                var owner = state.Authenticate(context);
                if (owner?.Role != "owner") return Results.Forbid();
                var request = await context.Request
                    .ReadFromJsonAsync<OnlineSetUserLabelRequestDto>(JsonOptions)
                    .ConfigureAwait(false);
                if (request == null) return Results.BadRequest();
                lock (state.Gate)
                {
                    var user = state.FindUser(userId);
                    if (user == null) return Results.NotFound();
                    user.CustomLabel = request.Label?.Trim() ?? string.Empty;
                    state.AdminUserLabelUpdateCount++;
                    state.WriteState();
                    return Results.Json(state.PlayerProfile(owner.Id, user), JsonOptions);
                }
            });
        app.MapPut("/api/admin/users/{userId:long}/avatar",
            async (HttpContext context, long userId) =>
            {
                var owner = state.Authenticate(context);
                if (owner?.Role != "owner") return Results.Forbid();
                var user = state.FindUser(userId);
                if (user == null) return Results.NotFound();
                await using var buffer = new MemoryStream();
                await context.Request.Body.CopyToAsync(buffer, context.RequestAborted)
                    .ConfigureAwait(false);
                lock (state.Gate)
                {
                    user.AvatarKey = user.Id == HarnessState.OwnerId
                        ? "owner-avatar-v1"
                        : "member-avatar-v1";
                    state.AdminUserAvatarUploadCount++;
                    state.AdminUserAvatarUploadBytes += buffer.Length;
                    state.WriteState();
                    return Results.Json(state.UserProfile(user), JsonOptions);
                }
            });
        app.MapDelete("/api/admin/users/{userId:long}/avatar",
            (HttpContext context, long userId) =>
            {
                var owner = state.Authenticate(context);
                if (owner?.Role != "owner") return Results.Forbid();
                lock (state.Gate)
                {
                    var user = state.FindUser(userId);
                    if (user == null) return Results.NotFound();
                    user.AvatarKey = "default";
                    state.AdminUserAvatarResetCount++;
                    state.WriteState();
                    return Results.Json(state.UserProfile(user), JsonOptions);
                }
            });
        app.MapGet("/api/players", (HttpContext context) =>
        {
            var viewer = state.Authenticate(context);
            if (viewer == null) return Results.Unauthorized();
            var page = int.TryParse(context.Request.Query["page"], out var parsedPage)
                ? Math.Max(1, parsedPage)
                : 1;
            lock (state.Gate)
                return Results.Json(
                    state.PlayerDirectory(viewer.Id, state.AllUsers(), page),
                    JsonOptions);
        });
        app.MapGet("/api/players/search", (HttpContext context) =>
        {
            var viewer = state.Authenticate(context);
            if (viewer == null) return Results.Unauthorized();
            var page = int.TryParse(context.Request.Query["page"], out var parsedPage)
                ? Math.Max(1, parsedPage)
                : 1;
            var query = context.Request.Query["q"].ToString().Trim();
            lock (state.Gate)
                return Results.Json(
                    state.PlayerDirectory(viewer.Id, state.SearchUsers(query), page),
                    JsonOptions);
        });
        app.MapGet("/api/players/leaderboard", (HttpContext context) =>
        {
            var viewer = state.Authenticate(context);
            if (viewer == null) return Results.Unauthorized();
            lock (state.Gate)
                return Results.Json(
                    state.PlayerDirectory(
                        viewer.Id,
                        state.AllUsers().OrderByDescending(user => user.ChartingSeconds),
                        page: 1,
                        paginate: false),
                    JsonOptions);
        });
        app.MapGet("/api/players/{userId:long}", (HttpContext context, long userId) =>
        {
            var viewer = state.Authenticate(context);
            if (viewer == null) return Results.Unauthorized();
            lock (state.Gate)
            {
                var user = state.FindUser(userId);
                return user == null
                    ? Results.NotFound()
                    : Results.Json(state.PlayerProfile(viewer.Id, user), JsonOptions);
            }
        });
        app.MapPut("/api/players/{userId:long}/follow",
            (HttpContext context, long userId) =>
            {
                var actor = state.Authenticate(context);
                if (actor == null) return Results.Unauthorized();
                lock (state.Gate)
                {
                    var result = state.SetFollow(actor, userId, follow: true);
                    state.WriteState();
                    if (result == null)
                        return Results.BadRequest(new
                        {
                            code = "invalid_follow_target",
                            message = "不能关注当前玩家。"
                        });
                    return Results.Json(result, JsonOptions);
                }
            });
        app.MapDelete("/api/players/{userId:long}/follow",
            (HttpContext context, long userId) =>
            {
                var actor = state.Authenticate(context);
                if (actor == null) return Results.Unauthorized();
                lock (state.Gate)
                {
                    var result = state.SetFollow(actor, userId, follow: false);
                    state.WriteState();
                    if (result == null)
                        return Results.BadRequest(new
                        {
                            code = "invalid_follow_target",
                            message = "不能取消关注当前玩家。"
                        });
                    return Results.Json(result, JsonOptions);
                }
            });
        app.MapGet("/api/avatars/{avatarKey}", (string avatarKey) =>
        {
            byte[]? bytes = avatarKey switch
            {
                "owner-avatar-v1" => OwnerAvatarPng,
                "member-avatar-v1" => MemberAvatarPng,
                _ => null
            };
            if (bytes == null) return Results.NotFound();
            lock (state.Gate)
            {
                state.AvatarDownloadCount++;
                state.AvatarDownloadKeys.Add(avatarKey);
                state.WriteState();
            }
            return Results.Bytes(bytes, "image/png");
        });
        app.MapGet("/api/me/notifications", (HttpContext context) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            var after = long.TryParse(context.Request.Query["after"], out var parsedAfter)
                ? parsedAfter
                : (long?)null;
            var limit = int.TryParse(context.Request.Query["limit"], out var parsedLimit)
                ? Math.Clamp(parsedLimit, 1, OnlineCommunityApi.MaximumNotificationPageSize)
                : OnlineCommunityApi.MaximumNotificationPageSize;
            lock (state.Gate)
            {
                state.NotificationFetchCount++;
                var page = state.NotificationPage(user.Id, after, limit);
                state.WriteState();
                return Results.Json(page, JsonOptions);
            }
        });
        app.MapGet("/api/me/friends", (HttpContext context) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            lock (state.Gate)
                return Results.Json(
                    state.PlayerDirectory(
                        user.Id,
                        state.FriendUsers(user.Id),
                        page: 1,
                        paginate: false),
                    JsonOptions);
        });
        app.MapGet("/api/me/following", (HttpContext context) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            var page = int.TryParse(context.Request.Query["page"], out var parsedPage)
                ? Math.Max(1, parsedPage)
                : 1;
            lock (state.Gate)
                return Results.Json(
                    state.PlayerDirectory(user.Id, state.FollowingUsers(user.Id), page),
                    JsonOptions);
        });
        app.MapGet("/api/me/followers", (HttpContext context) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            var page = int.TryParse(context.Request.Query["page"], out var parsedPage)
                ? Math.Max(1, parsedPage)
                : 1;
            lock (state.Gate)
                return Results.Json(
                    state.PlayerDirectory(user.Id, state.FollowerUsers(user.Id), page),
                    JsonOptions);
        });
        app.MapGet("/api/me/invitations", (HttpContext context) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            lock (state.Gate)
            {
                state.InvitationFetchCount++;
                var invitations = state.PendingInvitation != null &&
                                  state.PendingInvitationInviteeUserId == user.Id
                    ? new[] { state.PendingInvitation }
                    : [];
                state.WriteState();
                return Results.Json(invitations, JsonOptions);
            }
        });

        app.MapGet("/api/rooms", () =>
        {
            lock (state.Gate)
            {
                var rooms = state.RoomCreated && !state.RoomHidden
                    ? new[] { state.RoomSummary() }
                    : [];
                return Results.Json(new OnlineRoomDirectoryDto(rooms, 1, 10, rooms.Length), JsonOptions);
            }
        });
        app.MapGet("/api/rooms/by-number/{roomNumber:long}",
            (HttpContext context, long roomNumber) =>
            {
                if (state.Authenticate(context) == null) return Results.Unauthorized();
                lock (state.Gate)
                {
                    return !state.RoomCreated || roomNumber != state.CurrentRoomNumber
                        ? Results.NotFound()
                        : Results.Json(state.RoomSummary(), JsonOptions);
                }
            });
        app.MapPost("/api/rooms", async (HttpContext context) =>
        {
            var user = state.Authenticate(context);
            if (user?.Id != HarnessState.OwnerId) return Results.Unauthorized();
            var request = await context.Request.ReadFromJsonAsync<OnlineCreateRoomRequestDto>(JsonOptions)
                .ConfigureAwait(false);
            if (request == null) return Results.BadRequest();
            lock (state.Gate)
            {
                state.ResetRoom(request);
                state.WriteState();
                return Results.Json(
                    new OnlineCreatedRoomDto(state.RoomSummary()),
                    JsonOptions,
                    statusCode: StatusCodes.Status201Created);
            }
        });
        app.MapPost("/api/rooms/{roomId:guid}/invitations",
            async (HttpContext context, Guid roomId) =>
            {
                var user = state.Authenticate(context);
                if (user == null) return Results.Unauthorized();
                var request = await context.Request
                    .ReadFromJsonAsync<OnlineRoomInviteRequestDto>(JsonOptions)
                    .ConfigureAwait(false);
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (!state.IsActiveMember(user.Id) || !state.ResourcesReady || request == null)
                        return Results.Conflict();
                    if (request.UserId != HarnessState.MemberId || user.Id == request.UserId)
                        return Results.Conflict();
                    var invitation = state.CreateInvitation(user.Id, request.UserId);
                    state.WriteState();
                    return Results.Json(
                        invitation,
                        JsonOptions,
                        statusCode: StatusCodes.Status201Created);
                }
            });
        app.MapPost("/api/me/invitations/{invitationId:guid}/respond",
            async (HttpContext context, Guid invitationId) =>
            {
                var user = state.Authenticate(context);
                if (user == null) return Results.Unauthorized();
                var request = await context.Request
                    .ReadFromJsonAsync<OnlineRoomInviteResponseRequestDto>(JsonOptions)
                    .ConfigureAwait(false);
                var action = request?.Action.Trim().ToLowerInvariant();
                if (action is not ("join" or "watch" or "cancel"))
                    return Results.BadRequest();
                lock (state.Gate)
                {
                    if (state.PendingInvitation?.Id != invitationId ||
                        state.PendingInvitationInviteeUserId != user.Id)
                        return Results.NotFound();
                    state.InvitationResponseActions.Add(action);
                    state.PendingInvitation = null;
                    state.PendingInvitationInviteeUserId = 0;
                    if (action == "cancel")
                    {
                        state.WriteState();
                        return Results.NoContent();
                    }

                    state.InstallMember(user.Id, action == "watch" ? "viewer" : "editor");
                    state.InvitationJoinCount++;
                    state.WriteState();
                    return Results.Json(state.RoomSummary(), JsonOptions);
                }
            });
        app.MapPost("/api/rooms/{roomId:guid}/join", async (HttpContext context, Guid roomId) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            var request = await context.Request.ReadFromJsonAsync<OnlineJoinRoomRequestDto>(JsonOptions)
                .ConfigureAwait(false);
            lock (state.Gate)
            {
                if (!state.ValidRoom(roomId)) return Results.NotFound();
                if (user.Id == HarnessState.MemberId)
                {
                    state.MemberNormalJoinRequestCount++;
                    if (!string.IsNullOrEmpty(request?.Password))
                        state.MemberJoinPasswordSubmissionCount++;
                }
                if (state.RoomPrivate && request?.Password != state.RoomPassword)
                    return Error(StatusCodes.Status403Forbidden, "password_invalid", "房间密码错误。");
                state.InstallMember(user.Id, request?.MemberRole ?? "editor");
                state.WriteState();
                return Results.Json(state.RoomSummary(), JsonOptions);
            }
        });

        app.MapGet("/api/rooms/{roomId:guid}/live", (HttpContext context, Guid roomId, long? after) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            lock (state.Gate)
            {
                if (!state.ValidRoom(roomId)) return Results.NotFound();
                if (!state.IsActiveMember(user.Id)) return MemberRequired();
                state.RenewRoomPresence(user.Id);
                var threshold = Math.Max(0, after ?? 0);
                var messages = state.Messages.Where(message => message.Id > threshold).ToArray();
                state.WriteState();
                return Results.Json(new OnlineRoomLiveStateDto(
                    state.RoomSummary(),
                    state.Members.Values.OrderByDescending(member => member.Active)
                        .ThenBy(member => member.UserId)
                        .Select(state.MemberDto).ToArray(),
                    messages,
                    state.Messages.Count == 0 ? 0 : state.Messages[^1].Id), JsonOptions);
            }
        });
        app.MapPost("/api/rooms/{roomId:guid}/heartbeat", (HttpContext context, Guid roomId) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            lock (state.Gate)
            {
                if (!state.ValidRoom(roomId)) return Results.NotFound();
                if (!state.IsActiveMember(user.Id)) return MemberRequired();
                state.RenewRoomPresence(user.Id);
                state.WriteState();
                return Results.NoContent();
            }
        });
        app.MapPost("/api/rooms/{roomId:guid}/chat", async (HttpContext context, Guid roomId) =>
        {
            var user = state.Authenticate(context);
            if (user == null) return Results.Unauthorized();
            var request = await context.Request.ReadFromJsonAsync<OnlineRoomChatRequestDto>(JsonOptions)
                .ConfigureAwait(false);
            lock (state.Gate)
            {
                if (!state.ValidRoom(roomId)) return Results.NotFound();
                if (!state.IsActiveMember(user.Id)) return MemberRequired();
                var member = state.Members[user.Id];
                var message = new OnlineRoomChatMessageDto(
                    state.Messages.Count + 1,
                    user.Id,
                    user.Username,
                    user.DisplayName,
                    "default",
                    member.Role,
                    request?.Message ?? string.Empty,
                    DateTimeOffset.UtcNow);
                state.Messages.Add(message);
                state.WriteState();
                return Results.Json(message, JsonOptions, statusCode: StatusCodes.Status201Created);
            }
        });
        app.MapPut("/api/rooms/{roomId:guid}/members/{userId:long}/access",
            async (HttpContext context, Guid roomId, long userId) =>
            {
                var actor = state.Authenticate(context);
                var request = await context.Request
                    .ReadFromJsonAsync<OnlineRoomMemberAccessRequestDto>(JsonOptions)
                    .ConfigureAwait(false);
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (actor?.Id != HarnessState.OwnerId) return Results.StatusCode(403);
                    if (!state.Members.TryGetValue(userId, out var member)) return Results.NotFound();
                    member.Role = request?.MemberRole == "viewer" ? "viewer" : "editor";
                    member.CanEditMetadata = request?.CanEditMetadata == true;
                    member.CanEditTiming = request?.CanEditTiming == true;
                    member.CanEditNotes = request?.CanEditNotes == true;
                    state.WriteState();
                    return Results.NoContent();
                }
            });
        app.MapDelete("/api/rooms/{roomId:guid}/members/{userId:long}",
            (HttpContext context, Guid roomId, long userId) =>
            {
                var actor = state.Authenticate(context);
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (actor?.Id != HarnessState.OwnerId) return Results.StatusCode(403);
                    if (!state.Members.TryGetValue(userId, out var member)) return Results.NotFound();
                    member.Active = false;
                    member.Online = false;
                    state.WriteState();
                    return Results.NoContent();
                }
            });
        app.MapDelete("/api/rooms/{roomId:guid}", (HttpContext context, Guid roomId) =>
        {
            var user = state.Authenticate(context);
            lock (state.Gate)
            {
                if (!state.ValidRoom(roomId)) return Results.NotFound();
                if (user == null || !state.Members.TryGetValue(user.Id, out var member))
                    return MemberRequired();
                state.LeaveRoom(user.Id, member);
                state.WriteState();
                return Results.NoContent();
            }
        });

        app.MapPost("/api/rooms/{roomId:guid}/resources/plan",
            async (HttpContext context, Guid roomId) =>
            {
                var user = state.Authenticate(context);
                var request = await context.Request
                    .ReadFromJsonAsync<OnlineRoomResourcePlanRequestDto>(JsonOptions)
                    .ConfigureAwait(false);
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (user == null || !state.IsActiveMember(user.Id)) return MemberRequired();
                    var entries = request?.Entries?.ToArray() ?? [];
                    state.PlannedEntries = entries;
                    var missing = entries.Select(entry => entry.Sha256)
                        .Distinct(StringComparer.OrdinalIgnoreCase)
                        .Where(hash => !state.Blobs.ContainsKey(hash)).ToArray();
                    var missingSet = missing.ToHashSet(StringComparer.OrdinalIgnoreCase);
                    var missingBytes = entries.Where(entry => missingSet.Contains(entry.Sha256))
                        .GroupBy(entry => entry.Sha256, StringComparer.OrdinalIgnoreCase)
                        .Sum(group => group.First().Length);
                    return Results.Json(new OnlineRoomResourcePlanDto(
                        entries.Sum(entry => entry.Length), missingBytes, missing), JsonOptions);
                }
            });
        app.MapPut("/api/rooms/{roomId:guid}/resources/blobs/{sha256}",
            async (HttpContext context, Guid roomId, string sha256) =>
            {
                var user = state.Authenticate(context);
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (user == null || !state.IsActiveMember(user.Id)) return MemberRequired();
                }
                using var memory = new MemoryStream();
                await context.Request.Body.CopyToAsync(memory, context.RequestAborted).ConfigureAwait(false);
                var bytes = memory.ToArray();
                var actual = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
                if (!actual.Equals(sha256, StringComparison.OrdinalIgnoreCase))
                    return Results.BadRequest(new { code = "hash_mismatch", message = "SHA-256 mismatch." });
                lock (state.Gate)
                {
                    state.Blobs[sha256] = bytes;
                    state.UploadedBlobCount++;
                    state.WriteState();
                }
                return Results.NoContent();
            });
        app.MapPost("/api/rooms/{roomId:guid}/resources/commit",
            async (HttpContext context, Guid roomId) =>
            {
                var user = state.Authenticate(context);
                var request = await context.Request
                    .ReadFromJsonAsync<OnlineRoomResourcePlanRequestDto>(JsonOptions)
                    .ConfigureAwait(false);
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (user == null || !state.IsActiveMember(user.Id)) return MemberRequired();
                    var entries = request?.Entries?.ToArray() ?? [];
                    if (entries.Any(entry => !state.Blobs.TryGetValue(entry.Sha256, out var bytes) ||
                                             bytes.LongLength != entry.Length))
                        return Results.BadRequest(new { code = "blob_missing", message = "Blob is missing." });
                    state.ResourceEntries = entries;
                    state.ResourcesReady = true;
                    state.ResourceCommitCount++;
                    state.WriteState();
                    return Results.Json(state.ResourceManifest(), JsonOptions);
                }
            });
        app.MapGet("/api/rooms/{roomId:guid}/resources", (HttpContext context, Guid roomId) =>
        {
            var user = state.Authenticate(context);
            lock (state.Gate)
            {
                if (!state.ValidRoom(roomId)) return Results.NotFound();
                if (user == null || !state.IsActiveMember(user.Id)) return MemberRequired();
                if (!state.ResourcesReady) return Error(409, "resources_pending", "Resources are pending.");
                return Results.Json(state.ResourceManifest(), JsonOptions);
            }
        });
        app.MapGet("/api/rooms/{roomId:guid}/resources/files/{sha256}",
            async (HttpContext context, Guid roomId, string sha256) =>
            {
                var user = state.Authenticate(context);
                byte[] bytes;
                HarnessResourceDownloadFaultDecision fault;
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId))
                    {
                        context.Response.StatusCode = StatusCodes.Status404NotFound;
                        return;
                    }
                    if (user == null || !state.IsActiveMember(user.Id))
                    {
                        context.Response.StatusCode = StatusCodes.Status403Forbidden;
                        return;
                    }
                    if (!state.Blobs.TryGetValue(sha256, out var storedBytes))
                    {
                        context.Response.StatusCode = StatusCodes.Status404NotFound;
                        return;
                    }
                    bytes = storedBytes.ToArray();
                    state.DownloadedBlobCount++;
                    fault = state.RecordResourceDownloadAttempt(sha256, bytes.LongLength);
                    state.WriteState();
                }

                if (fault.DelayMilliseconds > 0)
                {
                    await Task.Delay(
                            fault.DelayMilliseconds,
                            CancellationToken.None)
                        .ConfigureAwait(false);
                }
                context.Response.StatusCode = StatusCodes.Status200OK;
                context.Response.ContentType = "application/octet-stream";
                context.Response.ContentLength = bytes.LongLength;
                if (fault.DisconnectResponse)
                {
                    var partialLength = Math.Max(1, bytes.Length / 2);
                    await context.Response.Body.WriteAsync(
                            bytes.AsMemory(0, partialLength),
                            context.RequestAborted)
                        .ConfigureAwait(false);
                    await context.Response.Body.FlushAsync(context.RequestAborted)
                        .ConfigureAwait(false);
                    context.Abort();
                    return;
                }

                if (fault.CorruptResponse)
                {
                    if (bytes.Length == 0)
                        throw new InvalidOperationException("Cannot corrupt an empty resource response.");
                    bytes[bytes.Length / 2] ^= 0x5a;
                }
                await context.Response.Body.WriteAsync(bytes, context.RequestAborted)
                    .ConfigureAwait(false);
            });

        app.MapPut("/api/rooms/{roomId:guid}/chart", async (HttpContext context, Guid roomId) =>
        {
            var user = state.Authenticate(context);
            var request = await context.Request.ReadFromJsonAsync<InitializeOnlineChartRequest>(JsonOptions)
                .ConfigureAwait(false);
            lock (state.Gate)
            {
                if (!state.ValidRoom(roomId)) return Results.NotFound();
                if (user?.Id != HarnessState.OwnerId || request == null) return Results.StatusCode(403);
                state.InitializeChart(request, user.Id);
                state.WriteState();
                return Results.Json(state.Chart, JsonOptions);
            }
        });
        app.MapGet("/api/rooms/{roomId:guid}/chart", (HttpContext context, Guid roomId) =>
            RequireActiveRoom(context, state, roomId, _ =>
                state.Chart == null
                    ? Error(409, "chart_pending", "Chart is pending.")
                    : Results.Json(state.Snapshot(), JsonOptions)));
        app.MapGet("/api/rooms/{roomId:guid}/chart/delta", (HttpContext context, Guid roomId, long? after) =>
        {
            var user = state.Authenticate(context);
            lock (state.Gate)
            {
                if (!state.ValidRoom(roomId)) return Results.NotFound();
                if (user == null || !state.IsActiveMember(user.Id)) return MemberRequired();
                if (state.Chart == null) return Error(409, "chart_pending", "Chart is pending.");
                state.RenewRoomPresence(user.Id);
                var afterRevision = Math.Max(0, after ?? 0);
                if (state.ConsumeChartDeltaFailure())
                {
                    state.RecordChartDeltaAttempt(
                        user.Id,
                        afterRevision,
                        state.Revision,
                        returnedOperationCount: 0,
                        failed: true);
                    state.WriteState();
                    context.Response.Headers.RetryAfter = "2";
                    return Error(
                        StatusCodes.Status503ServiceUnavailable,
                        "harness_delta_unavailable",
                        "Injected chart delta outage.");
                }
                if (state.ConsumeMalformedChartDeltaResponse())
                {
                    state.RecordChartDeltaAttempt(
                        user.Id,
                        afterRevision,
                        state.Revision,
                        returnedOperationCount: 0,
                        failed: true);
                    state.WriteState();
                    return Results.Text(
                        "{\"fromRevision\":0,\"currentRevision\":",
                        "application/json",
                        Encoding.UTF8,
                        StatusCodes.Status200OK);
                }
                var delta = state.Delta(afterRevision);
                state.RecordChartDeltaAttempt(
                    user.Id,
                    afterRevision,
                    delta.CurrentRevision,
                    delta.Operations.Count,
                    failed: false);
                state.WriteState();
                return Results.Json(delta, JsonOptions);
            }
        });
        app.MapPost("/api/rooms/{roomId:guid}/chart/operations/delta",
            async (HttpContext context, Guid roomId) =>
            {
                var user = state.Authenticate(context);
                var request = await context.Request.ReadFromJsonAsync<OnlineChartOperationBatch>(JsonOptions)
                    .ConfigureAwait(false);
                OnlineChartDelta response;
                HarnessChartOperationFaultDecision fault;
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (user == null || !state.IsActiveMember(user.Id)) return MemberRequired();
                    if (request == null || state.Chart == null) return Results.BadRequest();
                    var member = state.Members[user.Id];
                    if ((request.UpsertNotes.Count > 0 || request.DeleteNoteIds.Count > 0) &&
                        user.Id != HarnessState.OwnerId && !member.CanEditNotes)
                        return Error(403, "note_access_denied", "Note access denied.");
                    if ((request.UpsertTiming.Count > 0 || request.DeleteTimingIds.Count > 0) &&
                        user.Id != HarnessState.OwnerId && !member.CanEditTiming)
                        return Error(403, "timing_access_denied", "Timing access denied.");
                    if ((request.Metadata != null || request.KeyCount.HasValue) &&
                        user.Id != HarnessState.OwnerId && !member.CanEditMetadata)
                        return Error(403, "metadata_access_denied", "Metadata access denied.");
                    var duplicateReceipt = request.OperationId != Guid.Empty &&
                                           state.OperationReceipts.ContainsKey(request.OperationId);
                    state.Apply(request, user.Id);
                    fault = state.RecordChartOperationAttempt(request, duplicateReceipt);
                    response = state.Delta(request.BaseRevision);
                    state.WriteState();
                }
                if (fault.DelayMilliseconds > 0)
                    await Task.Delay(fault.DelayMilliseconds, CancellationToken.None).ConfigureAwait(false);
                lock (state.Gate)
                {
                    state.RecordChartOperationResponseCompletion(
                        request.OperationId,
                        response.CurrentRevision,
                        state.Revision,
                        fault.DropResponse);
                    state.WriteState();
                }
                if (fault.DropResponse)
                {
                    context.Abort();
                    return Results.Empty;
                }
                return Results.Json(response, JsonOptions);
            });
        app.MapGet("/api/rooms/{roomId:guid}/chart/events", async (HttpContext context, Guid roomId) =>
        {
            var user = state.Authenticate(context);
            lock (state.Gate)
            {
                if (!state.ValidRoom(roomId) || user == null || !state.IsActiveMember(user.Id))
                {
                    context.Response.StatusCode = StatusCodes.Status403Forbidden;
                    return;
                }
                state.SseConnectionCount++;
                if (state.ConsumeSseDisconnect())
                {
                    state.WriteState();
                    context.Abort();
                    return;
                }
            }
            context.Response.StatusCode = StatusCodes.Status200OK;
            context.Response.ContentType = "text/event-stream";
            context.Response.Headers.CacheControl = "no-cache";
            long last = -1;
            long lastChangeSequence = -1;
            try
            {
                while (!context.RequestAborted.IsCancellationRequested)
                {
                    long revision;
                    long changeSequence;
                    bool active;
                    lock (state.Gate)
                    {
                        revision = state.Revision;
                        changeSequence = state.ChartChangeSequence;
                        active = state.IsActiveMember(user.Id) &&
                                 !state.IsTransportBlocked(user.Id);
                    }
                    if (!active) return;
                    if (revision != last || changeSequence != lastChangeSequence)
                    {
                        await context.Response.WriteAsync($"data: {revision}\n\n", context.RequestAborted)
                            .ConfigureAwait(false);
                        await context.Response.Body.FlushAsync(context.RequestAborted).ConfigureAwait(false);
                        last = revision;
                        lastChangeSequence = changeSequence;
                    }
                    await Task.Delay(200, context.RequestAborted).ConfigureAwait(false);
                }
            }
            catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
            {
            }
        });
        app.MapPost("/api/rooms/{roomId:guid}/chart/locks/toggle-selection",
            async (HttpContext context, Guid roomId) =>
            {
                var user = state.Authenticate(context);
                var request = await context.Request
                    .ReadFromJsonAsync<OnlineToggleChartLockSelectionRequest>(JsonOptions)
                    .ConfigureAwait(false);
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (user?.Id != HarnessState.OwnerId || request == null) return Results.StatusCode(403);
                    var result = state.ToggleLocks(request.Ranges, user.Id);
                    state.LockSelectionToggles.Add(new HarnessLockSelectionToggle(
                        state.LockSelectionToggles.Count + 1,
                        user.Id,
                        request.Ranges.ToArray(),
                        result.IsUnlock,
                        result.Locks.ToArray(),
                        DateTimeOffset.UtcNow));
                    state.WriteState();
                    return Results.Json(result, JsonOptions);
                }
            });
        app.MapGet("/api/rooms/{roomId:guid}/chart/snapshots", (HttpContext context, Guid roomId) =>
            RequireActiveRoom(context, state, roomId, _ => Results.Json(
                state.SavedSnapshots.Select(snapshot => snapshot.Info).ToArray(), JsonOptions)));
        app.MapPost("/api/rooms/{roomId:guid}/chart/snapshots",
            async (HttpContext context, Guid roomId) =>
            {
                var user = state.Authenticate(context);
                var request = await context.Request
                    .ReadFromJsonAsync<OnlineCreateChartSnapshotRequest>(JsonOptions)
                    .ConfigureAwait(false);
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (user?.Id != HarnessState.OwnerId || state.Chart == null)
                        return Results.StatusCode(403);
                    var saved = state.CreateSavedSnapshot(request?.Name, user.Id, automatic: false);
                    state.WriteState();
                    return Results.Json(saved.Info, JsonOptions, statusCode: StatusCodes.Status201Created);
                }
            });
        app.MapPost("/api/rooms/{roomId:guid}/chart/snapshots/{snapshotId:guid}/rollback",
            async (HttpContext context, Guid roomId, Guid snapshotId) =>
            {
                var user = state.Authenticate(context);
                _ = await context.Request
                    .ReadFromJsonAsync<OnlineRollbackChartSnapshotRequest>(JsonOptions)
                    .ConfigureAwait(false);
                lock (state.Gate)
                {
                    if (!state.ValidRoom(roomId)) return Results.NotFound();
                    if (user?.Id != HarnessState.OwnerId || state.Chart == null)
                        return Results.StatusCode(403);
                    var restored = state.SavedSnapshots.FirstOrDefault(item => item.Info.Id == snapshotId);
                    if (restored == null) return Results.NotFound();
                    var safety = state.CreateSavedSnapshot(null, user.Id, automatic: true);
                    state.Restore(restored.Snapshot);
                    state.WriteState();
                    return Results.Json(new OnlineChartRollbackResult(
                        state.Snapshot(), restored.Info, safety.Info.Id), JsonOptions);
                }
            });
    }

    private static IResult RequireActiveRoom(
        HttpContext context,
        HarnessState state,
        Guid roomId,
        Func<HarnessUser, IResult> action)
    {
        var user = state.Authenticate(context);
        if (user == null) return Results.Unauthorized();
        lock (state.Gate)
        {
            if (!state.ValidRoom(roomId)) return Results.NotFound();
            return state.IsActiveMember(user.Id) ? action(user) : MemberRequired();
        }
    }

    private static IResult MemberRequired() =>
        Error(StatusCodes.Status403Forbidden, "member_required", "Room membership is required.");

    private static IResult Error(int status, string code, string message) =>
        Results.Json(new { code, message }, JsonOptions, statusCode: status);

    private static string? Argument(IReadOnlyList<string> args, string name)
    {
        for (var index = 0; index + 1 < args.Count; index++)
            if (args[index].Equals(name, StringComparison.OrdinalIgnoreCase)) return args[index + 1];
        return null;
    }
}

internal sealed class HarnessState
{
    private static readonly TimeSpan PresenceRefreshInterval = TimeSpan.FromSeconds(15);
    private static readonly TimeSpan OnlineDisplayWindow = TimeSpan.FromSeconds(45);
    private static readonly TimeSpan MemberAbsenceGracePeriod = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan OwnerClosureGracePeriod = TimeSpan.FromMinutes(15);

    public const string OwnerToken = "windows-avalonia-gui-owner-token";
    public const string MemberToken = "windows-avalonia-gui-member-token";
    public const long OwnerId = 4101;
    public const long MemberId = 4202;
    public const long RoomNumber = 7654321;
    public static readonly Guid RoomId = Guid.Parse("a1a11111-2222-4333-8444-555555555555");
    public static readonly Guid InvitationId = Guid.Parse("b2b22222-3333-4444-8555-666666666666");

    private readonly string? statePath;
    private readonly string? checkpointPath;
    private readonly Dictionary<string, HarnessUser> users = new(StringComparer.Ordinal)
    {
        [OwnerToken] = new HarnessUser(
            OwnerId,
            "avalonia-owner",
            "Avalonia 房主",
            "owner",
            chartingSeconds: 23456),
        [MemberToken] = new HarnessUser(
            MemberId,
            "avalonia-member",
            "Avalonia 成员",
            chartingSeconds: 12345)
    };
    private readonly HashSet<(long FollowerId, long TargetId)> follows =
    [
        (OwnerId, MemberId),
        (MemberId, OwnerId)
    ];
    private readonly HashSet<long> transportBlackoutUserIds = [];
    private readonly Dictionary<long, int> transportAbortCounts = [];

    public HarnessState(
        string? statePath,
        string? checkpointPath,
        int processGeneration,
        OnlineAppConfigurationDto appConfiguration)
    {
        this.statePath = string.IsNullOrWhiteSpace(statePath) ? null : Path.GetFullPath(statePath);
        this.checkpointPath = string.IsNullOrWhiteSpace(checkpointPath)
            ? null
            : Path.GetFullPath(checkpointPath);
        ProcessGeneration = Math.Max(1, processGeneration);
        AppConfiguration = appConfiguration ??
                           throw new ArgumentNullException(nameof(appConfiguration));
        RestoreCheckpoint();
    }

    public object Gate { get; } = new();
    public int ProcessGeneration { get; }
    public bool RestoredFromCheckpoint { get; private set; }
    public ConcurrentQueue<string> Requests { get; } = new();
    public Dictionary<long, HarnessMember> Members { get; } = [];
    public Dictionary<string, byte[]> Blobs { get; } = new(StringComparer.OrdinalIgnoreCase);
    public List<OnlineRoomChatMessageDto> Messages { get; } = [];
    public List<AppliedOnlineChartOperation> Operations { get; } = [];
    public List<AppliedOnlineChartOperation> AcceptedOperationHistory { get; } = [];
    public List<OnlineChartLock> Locks { get; } = [];
    public List<HarnessSavedSnapshot> SavedSnapshots { get; } = [];
    public Dictionary<Guid, long> OperationReceipts { get; } = [];
    public List<string> InvitationResponseActions { get; } = [];
    public List<HarnessRoomLifecycleEvent> RoomLifecycleEvents { get; } = [];
    public List<HarnessLockSelectionToggle> LockSelectionToggles { get; } = [];
    public List<HarnessChartOperationAttempt> ChartOperationAttempts { get; } = [];
    public List<HarnessChartDeltaAttempt> ChartDeltaAttempts { get; } = [];
    public List<HarnessChartOperationResponseCompletion> ChartOperationResponseCompletions { get; } = [];
    public List<HarnessResourceDownloadAttempt> ResourceDownloadAttempts { get; } = [];
    public List<HarnessUserNotification> Notifications { get; } = [];
    public OnlineRoomInvitationDto? PendingInvitation { get; set; }
    public long PendingInvitationInviteeUserId { get; set; }
    public bool RoomCreated { get; private set; }
    public Guid CurrentRoomId { get; private set; } = RoomId;
    public long CurrentRoomNumber { get; private set; } = RoomNumber;
    public string RoomName { get; private set; } = "Windows Avalonia 双客户端房间";
    public bool RoomPrivate { get; private set; }
    public bool RoomHidden { get; private set; }
    public string? RoomPassword { get; private set; }
    public bool ResourcesReady { get; set; }
    public OnlineRoomResourceEntryDto[] PlannedEntries { get; set; } = [];
    public OnlineRoomResourceEntryDto[] ResourceEntries { get; set; } = [];
    public OnlineChartSnapshot? Chart { get; private set; }
    public long Revision { get; private set; }
    public long ChartChangeSequence { get; private set; }
    public long? AuthoritativeBaselineRevision { get; private set; }
    public int UploadedBlobCount { get; set; }
    public int DownloadedBlobCount { get; set; }
    public int AvatarDownloadCount { get; set; }
    public List<string> AvatarDownloadKeys { get; } = [];
    public OnlineAppConfigurationDto AppConfiguration { get; set; }
    public int AdminConfigurationUpdateCount { get; set; }
    public int AdminUserReadCount { get; set; }
    public int AdminUserUpdateCount { get; set; }
    public int AdminUserLabelUpdateCount { get; set; }
    public int AdminUserAvatarUploadCount { get; set; }
    public int AdminUserAvatarResetCount { get; set; }
    public long AdminUserAvatarUploadBytes { get; set; }
    public int ResourceCommitCount { get; set; }
    public int SseConnectionCount { get; set; }
    public int InvitationCreateCount { get; set; }
    public int InvitationFetchCount { get; set; }
    public int InvitationJoinCount { get; set; }
    public int NotificationFetchCount { get; set; }
    public int NotificationInjectionCount { get; set; }
    public int FollowRequestCount { get; private set; }
    public int FollowMutationCount { get; private set; }
    public int FollowNotificationCount { get; private set; }
    public int MemberNormalJoinRequestCount { get; set; }
    public int MemberJoinPasswordSubmissionCount { get; set; }
    public int RoomCreateCount { get; private set; }
    public int OwnerCloseCount { get; private set; }
    public int PendingChartDeltaFailures { get; private set; }
    public int PendingMalformedChartDeltaResponses { get; private set; }
    public int PendingSseDisconnects { get; private set; }
    public int PendingDroppedChartOperationResponses { get; private set; }
    public int PendingDelayedChartOperationResponseMilliseconds { get; private set; }
    public int PendingDelayedResourceDownloadMilliseconds { get; private set; }
    public int PendingDisconnectedResourceDownloads { get; private set; }
    public int PendingCorruptedResourceDownloads { get; private set; }
    public int InjectedChartDeltaFailureCount { get; private set; }
    public int InjectedMalformedChartDeltaResponseCount { get; private set; }
    public int InjectedSseDisconnectCount { get; private set; }
    public int InjectedDroppedChartOperationResponseCount { get; private set; }
    public int InjectedDelayedChartOperationResponseCount { get; private set; }
    public int InjectedDelayedResourceDownloadCount { get; private set; }
    public int InjectedDisconnectedResourceDownloadCount { get; private set; }
    public int InjectedCorruptedResourceDownloadCount { get; private set; }
    public TimeSpan LeaseClockOffset { get; private set; }
    public DateTimeOffset OwnerLastHeartbeatAt { get; private set; }
    public int LeaseCleanupCount { get; private set; }
    public int TransportAbortCount { get; private set; }

    public HarnessUser? Authenticate(HttpContext context)
    {
        var header = context.Request.Headers.Authorization.ToString();
        const string prefix = "Bearer ";
        return header.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) &&
               users.TryGetValue(header[prefix.Length..], out var user)
            ? user
            : null;
    }

    public bool TryRecordTransportAbort(HttpContext context)
    {
        var user = Authenticate(context);
        if (user == null) return false;
        lock (Gate)
        {
            if (!transportBlackoutUserIds.Contains(user.Id)) return false;
            TransportAbortCount++;
            transportAbortCounts[user.Id] =
                transportAbortCounts.GetValueOrDefault(user.Id) + 1;
            return true;
        }
    }

    public bool ConfigureNetworkBlackout(long userId, bool enabled)
    {
        if (FindUser(userId) == null) return false;
        if (enabled)
            transportBlackoutUserIds.Add(userId);
        else
            transportBlackoutUserIds.Remove(userId);
        return true;
    }

    public bool IsTransportBlocked(long userId) =>
        transportBlackoutUserIds.Contains(userId);

    public void AdvanceLeaseClock(TimeSpan amount)
    {
        if (amount < TimeSpan.Zero || amount > TimeSpan.FromHours(1))
            throw new ArgumentOutOfRangeException(nameof(amount));
        LeaseClockOffset += amount;
    }

    public void RenewRoomPresence(long userId)
    {
        if (!RoomCreated ||
            !Members.TryGetValue(userId, out var member) ||
            !member.Active)
            return;
        var observedAt = LeaseNow;
        if (member.LastSeenAt < observedAt - PresenceRefreshInterval)
            member.LastSeenAt = observedAt;
        if (userId == OwnerId &&
            OwnerLastHeartbeatAt < observedAt - PresenceRefreshInterval)
            OwnerLastHeartbeatAt = observedAt;
    }

    public void ApplyLeaseCleanup()
    {
        if (!RoomCreated) return;
        var observedAt = LeaseNow;
        if (OwnerLastHeartbeatAt < observedAt - OwnerClosureGracePeriod)
        {
            foreach (var member in Members.Values)
            {
                member.Active = false;
                member.Online = false;
            }
            RoomCreated = false;
            LeaseCleanupCount++;
            RecordRoomLifecycleEvent("owner-lease-expired", OwnerId);
            return;
        }

        foreach (var member in Members.Values.Where(member =>
                     member.Active &&
                     member.LastSeenAt < observedAt - MemberAbsenceGracePeriod))
        {
            member.Active = false;
            member.Online = false;
            LeaseCleanupCount++;
            RecordRoomLifecycleEvent("member-lease-expired", member.UserId);
        }
    }

    public object LeaseEvidence()
    {
        ApplyLeaseCleanup();
        var observedAt = LeaseNow;
        return new
        {
            observedAt,
            clockOffsetSeconds = LeaseClockOffset.TotalSeconds,
            presenceRefreshSeconds = PresenceRefreshInterval.TotalSeconds,
            onlineDisplaySeconds = OnlineDisplayWindow.TotalSeconds,
            memberGraceSeconds = MemberAbsenceGracePeriod.TotalSeconds,
            ownerGraceSeconds = OwnerClosureGracePeriod.TotalSeconds,
            roomCreated = RoomCreated,
            ownerLastHeartbeatAt = OwnerLastHeartbeatAt,
            ownerHeartbeatAgeSeconds = Math.Max(
                0,
                (observedAt - OwnerLastHeartbeatAt).TotalSeconds),
            cleanupCount = LeaseCleanupCount,
            blockedUserIds = transportBlackoutUserIds.Order().ToArray(),
            transportAbortCount = TransportAbortCount,
            transportAbortCounts = transportAbortCounts
                .OrderBy(pair => pair.Key)
                .ToDictionary(pair => pair.Key, pair => pair.Value),
            members = Members.Values
                .OrderBy(member => member.UserId)
                .Select(member => new
                {
                    member.UserId,
                    member.Active,
                    online = IsDisplayedOnline(member, observedAt),
                    member.LastSeenAt,
                    lastSeenAgeSeconds = Math.Max(
                        0,
                        (observedAt - member.LastSeenAt).TotalSeconds)
                })
                .ToArray()
        };
    }

    private DateTimeOffset LeaseNow => DateTimeOffset.UtcNow + LeaseClockOffset;

    private static bool IsDisplayedOnline(
        HarnessMember member,
        DateTimeOffset observedAt) =>
        member.Active && member.Online &&
        member.LastSeenAt >= observedAt - OnlineDisplayWindow;

    public HarnessUser OtherUser(long userId) =>
        users.Values.Single(user => user.Id != userId);

    public IReadOnlyList<HarnessUser> AllUsers() =>
        users.Values.OrderBy(user => user.Id).ToArray();

    public IReadOnlyList<HarnessUser> SearchUsers(string query)
    {
        if (string.IsNullOrWhiteSpace(query)) return AllUsers();
        var normalized = query.Trim();
        return users.Values
            .Where(user =>
                user.Id.ToString(System.Globalization.CultureInfo.InvariantCulture)
                    .Contains(normalized, StringComparison.OrdinalIgnoreCase) ||
                user.Username.Contains(normalized, StringComparison.OrdinalIgnoreCase) ||
                user.DisplayName.Contains(normalized, StringComparison.OrdinalIgnoreCase))
            .OrderBy(user => user.Id)
            .ToArray();
    }

    public IReadOnlyList<HarnessUser> FollowingUsers(long userId) =>
        follows
            .Where(relation => relation.FollowerId == userId)
            .Select(relation => FindUser(relation.TargetId))
            .Where(user => user != null)
            .Cast<HarnessUser>()
            .OrderBy(user => user.Id)
            .ToArray();

    public IReadOnlyList<HarnessUser> FollowerUsers(long userId) =>
        follows
            .Where(relation => relation.TargetId == userId)
            .Select(relation => FindUser(relation.FollowerId))
            .Where(user => user != null)
            .Cast<HarnessUser>()
            .OrderBy(user => user.Id)
            .ToArray();

    public IReadOnlyList<HarnessUser> FriendUsers(long userId) =>
        FollowingUsers(userId)
            .Where(user => follows.Contains((user.Id, userId)))
            .ToArray();

    public OnlineUserProfileDto UserProfile(HarnessUser user) => new(
        user.Id,
        user.Username,
        user.DisplayName,
        user.Role,
        user.AvatarKey,
        user.CreatedAt,
        user.ChartingSeconds,
        user.Bio,
        FollowingCount: FollowingUsers(user.Id).Count,
        FollowerCount: FollowerUsers(user.Id).Count,
        CustomLabel: user.CustomLabel,
        Tags: user.Tags,
        Email: $"{user.Username}@example.invalid");

    public OnlinePlayerProfileDto PlayerProfile(long viewerUserId, HarnessUser user)
    {
        var isFollowing = viewerUserId != user.Id &&
                          follows.Contains((viewerUserId, user.Id));
        var isMutual = isFollowing &&
                       follows.Contains((user.Id, viewerUserId));
        return new OnlinePlayerProfileDto(
            user.Id,
            user.DisplayName,
            user.AvatarKey,
            user.Bio,
            user.ChartingSeconds,
            FollowingUsers(user.Id).Count,
            FollowerUsers(user.Id).Count,
            isFollowing,
            isMutual,
            user.IsOnline,
            IsNameHidden: false,
            IsAvatarHidden: false,
            CustomLabel: user.CustomLabel,
            Tags: user.Tags);
    }

    public OnlinePlayerDirectoryDto PlayerDirectory(
        long viewerUserId,
        IEnumerable<HarnessUser> candidates,
        int page,
        bool paginate = true)
    {
        const int pageSize = 100;
        var all = candidates.DistinctBy(user => user.Id).ToArray();
        var normalizedPage = Math.Max(1, page);
        var selected = paginate
            ? all.Skip((normalizedPage - 1) * pageSize).Take(pageSize).ToArray()
            : all;
        return new OnlinePlayerDirectoryDto(
            selected.Count(user => user.IsOnline),
            selected.Select(user => PlayerProfile(viewerUserId, user)).ToArray(),
            paginate ? normalizedPage : 1,
            paginate ? pageSize : Math.Max(1, all.Length),
            all.Length);
    }

    public OnlineUserProfileDto? SetFollow(
        HarnessUser actor,
        long targetUserId,
        bool follow)
    {
        FollowRequestCount++;
        var target = FindUser(targetUserId);
        if (target == null || target.Id == actor.Id) return null;

        var relation = (FollowerId: actor.Id, TargetId: target.Id);
        var changed = follow ? follows.Add(relation) : follows.Remove(relation);
        if (changed)
        {
            FollowMutationCount++;
            if (follow)
            {
                var nextId = Notifications.Count == 0
                    ? 1
                    : checked(Notifications.Max(item => item.Notification.Id) + 1);
                Notifications.Add(new HarnessUserNotification(
                    target.Id,
                    new OnlineUserNotificationDto(
                        nextId,
                        "follow",
                        actor.Id,
                        actor.DisplayName,
                        DateTimeOffset.UtcNow)));
                FollowNotificationCount++;
            }
        }
        return UserProfile(actor);
    }

    public HarnessUser? FindUser(long userId) =>
        users.Values.SingleOrDefault(user => user.Id == userId);

    public OnlineUserNotificationDto AddNotification(
        HarnessNotificationInjectionRequest request)
    {
        if (FindUser(request.TargetUserId) == null)
            throw new ArgumentException("Notification target user does not exist.");
        if (request.ActorUserId < 1)
            throw new ArgumentException("Notification actor user id must be positive.");
        var type = string.IsNullOrWhiteSpace(request.Type)
            ? "follow"
            : request.Type.Trim();
        var actor = request.ActorDisplayName?.Trim() ?? string.Empty;
        var nextId = Notifications.Count == 0
            ? 1
            : checked(Notifications.Max(item => item.Notification.Id) + 1);
        var notification = new OnlineUserNotificationDto(
            nextId,
            type,
            request.ActorUserId,
            actor,
            DateTimeOffset.UtcNow);
        Notifications.Add(new HarnessUserNotification(
            request.TargetUserId,
            notification));
        NotificationInjectionCount++;
        return notification;
    }

    public OnlineUserNotificationPageDto NotificationPage(
        long userId,
        long? after,
        int limit)
    {
        var all = Notifications
            .Where(item => item.TargetUserId == userId)
            .Select(item => item.Notification)
            .OrderBy(item => item.Id)
            .ToArray();
        if (!after.HasValue)
        {
            return new OnlineUserNotificationPageDto(
                all.LastOrDefault()?.Id ?? 0,
                false,
                all.TakeLast(limit).ToArray());
        }

        var pending = all.Where(item => item.Id > after.Value).ToArray();
        var page = pending.Take(limit).ToArray();
        var nextCursor = page.LastOrDefault()?.Id ?? after.Value;
        return new OnlineUserNotificationPageDto(
            nextCursor,
            pending.Length > page.Length,
            page);
    }

    public OnlineRoomInvitationDto CreateInvitation(long inviterUserId, long inviteeUserId)
    {
        var inviter = users.Values.Single(user => user.Id == inviterUserId);
        PendingInvitationInviteeUserId = inviteeUserId;
        PendingInvitation = new OnlineRoomInvitationDto(
            InvitationId,
            CurrentRoomId,
            RoomName,
            inviter.Id,
            inviter.DisplayName,
            "default",
            DateTimeOffset.UtcNow.AddSeconds(90));
        InvitationCreateCount++;
        return PendingInvitation;
    }

    public void ResetRoom(OnlineCreateRoomRequestDto request)
    {
        RoomCreateCount++;
        CurrentRoomId = RoomCreateCount == 1 ? RoomId : Guid.NewGuid();
        CurrentRoomNumber = checked(RoomNumber + RoomCreateCount - 1L);
        RoomCreated = true;
        RoomName = request.Name;
        RoomPrivate = request.IsPrivate;
        RoomHidden = request.IsHidden;
        RoomPassword = request.Password;
        ResourcesReady = false;
        PlannedEntries = [];
        ResourceEntries = [];
        Blobs.Clear();
        Messages.Clear();
        Operations.Clear();
        AcceptedOperationHistory.Clear();
        Locks.Clear();
        SavedSnapshots.Clear();
        OperationReceipts.Clear();
        InvitationResponseActions.Clear();
        PendingInvitation = null;
        PendingInvitationInviteeUserId = 0;
        Members.Clear();
        Revision = 0;
        AuthoritativeBaselineRevision = null;
        Chart = null;
        UploadedBlobCount = 0;
        DownloadedBlobCount = 0;
        AvatarDownloadCount = 0;
        AvatarDownloadKeys.Clear();
        ResourceCommitCount = 0;
        InvitationCreateCount = 0;
        InvitationFetchCount = 0;
        InvitationJoinCount = 0;
        MemberNormalJoinRequestCount = 0;
        MemberJoinPasswordSubmissionCount = 0;
        ChartOperationAttempts.Clear();
        ChartDeltaAttempts.Clear();
        ChartOperationResponseCompletions.Clear();
        ResourceDownloadAttempts.Clear();
        ConfigureFaults(new HarnessFaultInjectionRequest());
        InjectedChartDeltaFailureCount = 0;
        InjectedMalformedChartDeltaResponseCount = 0;
        InjectedSseDisconnectCount = 0;
        InjectedDroppedChartOperationResponseCount = 0;
        InjectedDelayedChartOperationResponseCount = 0;
        InjectedDelayedResourceDownloadCount = 0;
        InjectedDisconnectedResourceDownloadCount = 0;
        InjectedCorruptedResourceDownloadCount = 0;
        transportBlackoutUserIds.Clear();
        transportAbortCounts.Clear();
        TransportAbortCount = 0;
        LeaseCleanupCount = 0;
        OwnerLastHeartbeatAt = LeaseNow;
        InstallMember(OwnerId, "owner");
        RecordRoomLifecycleEvent("created", OwnerId);
    }

    public void LeaveRoom(long userId, HarnessMember member)
    {
        if (userId == OwnerId)
        {
            RecordRoomLifecycleEvent("owner-closed", userId);
            OwnerCloseCount++;
            foreach (var current in Members.Values)
            {
                current.Active = false;
                current.Online = false;
            }
            RoomCreated = false;
            return;
        }

        RecordRoomLifecycleEvent("member-left", userId);
        member.Active = false;
        member.Online = false;
    }

    private void RecordRoomLifecycleEvent(string action, long actorUserId)
    {
        RoomLifecycleEvents.Add(new HarnessRoomLifecycleEvent(
            RoomLifecycleEvents.Count + 1,
            action,
            RoomCreateCount,
            CurrentRoomId,
            CurrentRoomNumber,
            RoomName,
            actorUserId,
            Revision,
            Chart?.Notes.Count ?? 0,
            Chart?.Timing.Count ?? 0,
            AcceptedOperationHistory.Count,
            Members.Values.Where(current => current.Active).Select(current => current.UserId).ToArray(),
            LeaseNow));
    }

    public void ConfigureFaults(HarnessFaultInjectionRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);
        ValidateFaultCount(request.FailNextChartDeltaRequests, nameof(request.FailNextChartDeltaRequests));
        ValidateFaultCount(
            request.MalformedNextChartDeltaResponses,
            nameof(request.MalformedNextChartDeltaResponses));
        ValidateFaultCount(request.DisconnectNextSseConnections, nameof(request.DisconnectNextSseConnections));
        ValidateFaultCount(
            request.DropNextChartOperationResponsesAfterCommit,
            nameof(request.DropNextChartOperationResponsesAfterCommit));
        ValidateFaultCount(
            request.DisconnectNextResourceDownloads,
            nameof(request.DisconnectNextResourceDownloads));
        ValidateFaultCount(
            request.CorruptNextResourceDownloads,
            nameof(request.CorruptNextResourceDownloads));
        if (request.DelayNextChartOperationResponseMilliseconds is < 0 or > 30_000)
            throw new ArgumentOutOfRangeException(
                nameof(request.DelayNextChartOperationResponseMilliseconds),
                "The injected chart operation delay must be between 0 and 30000 milliseconds.");
        if (request.DelayNextResourceDownloadMilliseconds is < 0 or > 30_000)
            throw new ArgumentOutOfRangeException(
                nameof(request.DelayNextResourceDownloadMilliseconds),
                "The injected resource download delay must be between 0 and 30000 milliseconds.");

        PendingChartDeltaFailures = request.FailNextChartDeltaRequests;
        PendingMalformedChartDeltaResponses = request.MalformedNextChartDeltaResponses;
        PendingSseDisconnects = request.DisconnectNextSseConnections;
        PendingDroppedChartOperationResponses = request.DropNextChartOperationResponsesAfterCommit;
        PendingDelayedChartOperationResponseMilliseconds =
            request.DelayNextChartOperationResponseMilliseconds;
        PendingDelayedResourceDownloadMilliseconds =
            request.DelayNextResourceDownloadMilliseconds;
        PendingDisconnectedResourceDownloads = request.DisconnectNextResourceDownloads;
        PendingCorruptedResourceDownloads = request.CorruptNextResourceDownloads;
    }

    public bool ConsumeChartDeltaFailure()
    {
        if (PendingChartDeltaFailures <= 0) return false;
        PendingChartDeltaFailures--;
        InjectedChartDeltaFailureCount++;
        return true;
    }

    public bool ConsumeMalformedChartDeltaResponse()
    {
        if (PendingMalformedChartDeltaResponses <= 0) return false;
        PendingMalformedChartDeltaResponses--;
        InjectedMalformedChartDeltaResponseCount++;
        return true;
    }

    public bool ConsumeSseDisconnect()
    {
        if (PendingSseDisconnects <= 0) return false;
        PendingSseDisconnects--;
        InjectedSseDisconnectCount++;
        return true;
    }

    public HarnessChartOperationFaultDecision RecordChartOperationAttempt(
        OnlineChartOperationBatch request,
        bool duplicateReceipt)
    {
        var dropResponse = PendingDroppedChartOperationResponses > 0;
        if (dropResponse)
        {
            PendingDroppedChartOperationResponses--;
            InjectedDroppedChartOperationResponseCount++;
        }

        var delayMilliseconds = PendingDelayedChartOperationResponseMilliseconds;
        if (delayMilliseconds > 0)
        {
            PendingDelayedChartOperationResponseMilliseconds = 0;
            InjectedDelayedChartOperationResponseCount++;
        }

        var canonicalRequest = JsonSerializer.SerializeToUtf8Bytes(
            request,
            new JsonSerializerOptions(JsonSerializerDefaults.Web));
        ChartOperationAttempts.Add(new HarnessChartOperationAttempt(
            ChartOperationAttempts.Count + 1,
            request.OperationId,
            request.BaseRevision,
            Convert.ToHexString(SHA256.HashData(canonicalRequest)),
            duplicateReceipt,
            dropResponse,
            delayMilliseconds,
            DateTimeOffset.UtcNow));
        return new HarnessChartOperationFaultDecision(dropResponse, delayMilliseconds);
    }

    public void RecordChartDeltaAttempt(
        long userId,
        long afterRevision,
        long currentRevision,
        int returnedOperationCount,
        bool failed)
    {
        ChartDeltaAttempts.Add(new HarnessChartDeltaAttempt(
            ChartDeltaAttempts.Count + 1,
            userId,
            afterRevision,
            currentRevision,
            returnedOperationCount,
            failed,
            DateTimeOffset.UtcNow));
    }

    public void RecordChartOperationResponseCompletion(
        Guid operationId,
        long responseRevision,
        long serverRevisionAtCompletion,
        bool dropped)
    {
        ChartOperationResponseCompletions.Add(new HarnessChartOperationResponseCompletion(
            operationId,
            responseRevision,
            serverRevisionAtCompletion,
            dropped,
            DateTimeOffset.UtcNow));
    }

    public HarnessResourceDownloadFaultDecision RecordResourceDownloadAttempt(
        string sha256,
        long declaredLength)
    {
        var delayMilliseconds = PendingDelayedResourceDownloadMilliseconds;
        if (delayMilliseconds > 0)
        {
            PendingDelayedResourceDownloadMilliseconds = 0;
            InjectedDelayedResourceDownloadCount++;
        }
        var disconnectResponse = PendingDisconnectedResourceDownloads > 0;
        if (disconnectResponse)
        {
            PendingDisconnectedResourceDownloads--;
            InjectedDisconnectedResourceDownloadCount++;
        }

        var corruptResponse = !disconnectResponse && PendingCorruptedResourceDownloads > 0;
        if (corruptResponse)
        {
            PendingCorruptedResourceDownloads--;
            InjectedCorruptedResourceDownloadCount++;
        }

        ResourceDownloadAttempts.Add(new HarnessResourceDownloadAttempt(
            ResourceDownloadAttempts.Count + 1,
            sha256,
            declaredLength,
            disconnectResponse,
            corruptResponse,
            delayMilliseconds,
            DateTimeOffset.UtcNow));
        return new HarnessResourceDownloadFaultDecision(
            disconnectResponse,
            corruptResponse,
            delayMilliseconds);
    }

    public object FaultEvidence() => new
    {
        pendingChartDeltaFailures = PendingChartDeltaFailures,
        pendingMalformedChartDeltaResponses = PendingMalformedChartDeltaResponses,
        pendingSseDisconnects = PendingSseDisconnects,
        pendingDroppedChartOperationResponses = PendingDroppedChartOperationResponses,
        pendingDelayedChartOperationResponseMilliseconds =
            PendingDelayedChartOperationResponseMilliseconds,
        pendingDelayedResourceDownloadMilliseconds =
            PendingDelayedResourceDownloadMilliseconds,
        pendingDisconnectedResourceDownloads = PendingDisconnectedResourceDownloads,
        pendingCorruptedResourceDownloads = PendingCorruptedResourceDownloads,
        injectedChartDeltaFailureCount = InjectedChartDeltaFailureCount,
        injectedMalformedChartDeltaResponseCount = InjectedMalformedChartDeltaResponseCount,
        injectedSseDisconnectCount = InjectedSseDisconnectCount,
        injectedDroppedChartOperationResponseCount = InjectedDroppedChartOperationResponseCount,
        injectedDelayedChartOperationResponseCount = InjectedDelayedChartOperationResponseCount,
        injectedDelayedResourceDownloadCount = InjectedDelayedResourceDownloadCount,
        injectedDisconnectedResourceDownloadCount = InjectedDisconnectedResourceDownloadCount,
        injectedCorruptedResourceDownloadCount = InjectedCorruptedResourceDownloadCount,
        chartOperationAttempts = ChartOperationAttempts.ToArray(),
        chartDeltaAttempts = ChartDeltaAttempts.ToArray(),
        chartOperationResponseCompletions = ChartOperationResponseCompletions.ToArray(),
        resourceDownloadAttempts = ResourceDownloadAttempts.ToArray()
    };

    private static void ValidateFaultCount(int value, string parameterName)
    {
        if (value is < 0 or > 100)
            throw new ArgumentOutOfRangeException(
                parameterName,
                "An injected fault count must be between 0 and 100.");
    }

    public bool ValidRoom(Guid roomId)
    {
        ApplyLeaseCleanup();
        return RoomCreated && roomId == CurrentRoomId;
    }
    public bool IsActiveMember(long userId) =>
        Members.TryGetValue(userId, out var member) && member.Active;

    public void InstallMember(long userId, string role)
    {
        var normalized = userId == OwnerId ? "owner" : role == "viewer" ? "viewer" : "editor";
        if (!Members.TryGetValue(userId, out var member))
        {
            member = new HarnessMember(userId, normalized);
            Members[userId] = member;
        }
        member.Role = normalized;
        member.Active = true;
        member.Online = true;
        member.LastSeenAt = LeaseNow;
        member.CanEditMetadata = userId == OwnerId;
        member.CanEditTiming = userId == OwnerId;
        member.CanEditNotes = normalized != "viewer";
        if (userId == OwnerId) OwnerLastHeartbeatAt = LeaseNow;
    }

    public OnlineRoomSummaryDto RoomSummary() => new(
        CurrentRoomId,
        CurrentRoomNumber,
        RoomName,
        OwnerId,
        users[OwnerToken].DisplayName,
        Members.Values.Count(member => member.Active),
        8,
        RoomPrivate,
        RoomHidden,
        ResourcesReady,
        ResourceEntries.Sum(entry => entry.Length),
        DateTimeOffset.Parse("2026-07-23T15:00:00Z"));

    public OnlineRoomMemberDto MemberDto(HarnessMember member)
    {
        var user = users.Values.Single(item => item.Id == member.UserId);
        return new OnlineRoomMemberDto(
            user.Id,
            user.Username,
            user.DisplayName,
            member.UserId == OwnerId ? "owner-avatar-v1" : "member-avatar-v1",
            member.Role,
            member.JoinedAt,
            IsDisplayedOnline(member, LeaseNow),
            Tags: [],
            CanEditMetadata: member.CanEditMetadata,
            CanEditTiming: member.CanEditTiming,
            CanEditNotes: member.CanEditNotes);
    }

    public OnlineRoomResourceManifestDto ResourceManifest()
    {
        var chartEntry = ResourceEntries.FirstOrDefault(entry =>
                entry.Path.Equals("working.mc", StringComparison.OrdinalIgnoreCase))?.Path
            ?? ResourceEntries.FirstOrDefault(entry =>
                entry.Path.EndsWith(".mc", StringComparison.OrdinalIgnoreCase))?.Path
            ?? "working.mc";
        var canonical = string.Join("\n", ResourceEntries
            .OrderBy(entry => entry.Path, StringComparer.Ordinal)
            .Select(entry => $"{entry.Path}|{entry.Length}|{entry.Sha256.ToLowerInvariant()}"));
        var manifestHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)))
            .ToLowerInvariant();
        return new OnlineRoomResourceManifestDto(
            ResourceEntries.Sum(entry => entry.Length),
            manifestHash,
            chartEntry,
            ResourceEntries);
    }

    public void InitializeChart(InitializeOnlineChartRequest request, long actorId)
    {
        Revision = 1;
        AuthoritativeBaselineRevision = null;
        Operations.Clear();
        OperationReceipts.Clear();
        Locks.Clear();
        if (request.InitialLocks != null)
        {
            Locks.AddRange(request.InitialLocks.Select(range => new OnlineChartLock(
                Guid.NewGuid(), range.StartBeat, range.EndBeat, -64, 81, actorId)));
        }
        Chart = new OnlineChartSnapshot(
            Revision,
            request.KeyCount,
            request.Notes.Select(note => note with { CreatorUserId = actorId }).ToArray(),
            request.Timing.Select(timing => timing with { CreatorUserId = actorId }).ToArray(),
            Locks.ToArray(),
            request.Metadata);
    }

    public OnlineChartSnapshot Snapshot()
    {
        var chart = Chart ?? throw new InvalidOperationException("The chart is not initialized.");
        return new OnlineChartSnapshot(
            Revision,
            chart.KeyCount,
            chart.Notes.ToArray(),
            chart.Timing.ToArray(),
            Locks.ToArray(),
            chart.Metadata);
    }

    public OnlineChartDelta Delta(long after)
    {
        if (AuthoritativeBaselineRevision is { } baseline && after < baseline)
            return new OnlineChartDelta(
                Revision, [], Locks.ToArray(), false, baseline, RequiresFullSnapshot: true);
        return new OnlineChartDelta(
            Revision,
            Operations.Where(operation => operation.Revision > after).ToArray(),
            Locks.ToArray(),
            false,
            AuthoritativeBaselineRevision,
            false);
    }

    public void Apply(OnlineChartOperationBatch request, long actorId)
    {
        if (request.OperationId != Guid.Empty && OperationReceipts.ContainsKey(request.OperationId)) return;
        var chart = Chart ?? throw new InvalidOperationException("The chart is not initialized.");
        var notes = chart.Notes.ToDictionary(note => note.Id);
        foreach (var id in request.DeleteNoteIds) notes.Remove(id);
        var authoredNotes = request.UpsertNotes
            .Select(note => note with { CreatorUserId = note.CreatorUserId == 0 ? actorId : note.CreatorUserId })
            .ToArray();
        foreach (var note in authoredNotes) notes[note.Id] = note;
        var timing = chart.Timing.ToDictionary(item => item.Id);
        foreach (var id in request.DeleteTimingIds) timing.Remove(id);
        var authoredTiming = request.UpsertTiming
            .Select(item => item with { CreatorUserId = item.CreatorUserId == 0 ? actorId : item.CreatorUserId })
            .ToArray();
        foreach (var item in authoredTiming) timing[item.Id] = item;

        Revision++;
        var accepted = request with
        {
            UpsertNotes = authoredNotes,
            UpsertTiming = authoredTiming
        };
        var operation = new AppliedOnlineChartOperation(Revision, actorId, accepted, DateTimeOffset.UtcNow);
        Operations.Add(operation);
        AcceptedOperationHistory.Add(operation);
        if (request.OperationId != Guid.Empty) OperationReceipts[request.OperationId] = Revision;
        Chart = new OnlineChartSnapshot(
            Revision,
            request.KeyCount ?? chart.KeyCount,
            notes.Values.OrderBy(note => BeatValue(note.Beat)).ThenBy(note => note.Lane).ThenBy(note => note.Id).ToArray(),
            timing.Values.OrderBy(item => BeatValue(item.Beat)).ThenBy(item => item.Id).ToArray(),
            Locks.ToArray(),
            request.Metadata ?? chart.Metadata);
    }

    public OnlineToggleChartLockSelectionResult ToggleLocks(
        IReadOnlyList<OnlineChartLockRange> ranges,
        long actorId)
    {
        if (ranges.Count == 0)
            throw new ArgumentException("锁定选区至少需要一个非空范围。", nameof(ranges));
        var selection = BuildDisjointLockRanges(ranges, validate: true);
        var existing = BuildDisjointLockRanges(
            Locks.Select(item => new OnlineChartLockRange(item.StartBeat, item.EndBeat)),
            validate: true);
        var unlock = IsFullyCovered(selection, existing);
        var finalRanges = unlock
            ? SubtractLockRanges(existing, selection)
            : BuildDisjointLockRanges(existing.Concat(selection), validate: false);
        Locks.Clear();
        Locks.AddRange(finalRanges.Select(range => new OnlineChartLock(
            Guid.NewGuid(), range.StartBeat, range.EndBeat, -64, 81, actorId)));
        if (Chart != null) Chart = Snapshot();
        ChartChangeSequence = checked(ChartChangeSequence + 1);
        return new OnlineToggleChartLockSelectionResult(unlock, Locks.ToArray());
    }

    private static IReadOnlyList<OnlineChartLockRange> BuildDisjointLockRanges(
        IEnumerable<OnlineChartLockRange> ranges,
        bool validate)
    {
        var normalized = new List<OnlineChartLockRange>();
        foreach (var range in ranges)
        {
            var start = range.StartBeat;
            var end = range.EndBeat;
            if (validate)
            {
                ValidateBeat(start);
                ValidateBeat(end);
                if (Compare(start, end) > 0) (start, end) = (end, start);
                if (Compare(start, end) == 0)
                    throw new ArgumentException("锁定选区必须包含非空 Beat 范围。", nameof(ranges));
            }
            normalized.Add(new OnlineChartLockRange(start, end));
        }
        normalized.Sort((left, right) =>
        {
            var start = Compare(left.StartBeat, right.StartBeat);
            return start != 0 ? start : Compare(left.EndBeat, right.EndBeat);
        });
        if (normalized.Count == 0) return [];

        var result = new List<OnlineChartLockRange>(normalized.Count) { normalized[0] };
        foreach (var next in normalized.Skip(1))
        {
            var current = result[^1];
            if (Compare(next.StartBeat, current.EndBeat) <= 0)
            {
                if (Compare(next.EndBeat, current.EndBeat) > 0)
                    result[^1] = current with { EndBeat = next.EndBeat };
                continue;
            }
            result.Add(next);
        }
        return result;
    }

    private static bool IsFullyCovered(
        IReadOnlyList<OnlineChartLockRange> selection,
        IReadOnlyList<OnlineChartLockRange> existing)
    {
        var existingIndex = 0;
        foreach (var selected in selection)
        {
            while (existingIndex < existing.Count &&
                   Compare(existing[existingIndex].EndBeat, selected.StartBeat) <= 0)
                existingIndex++;
            if (existingIndex >= existing.Count ||
                Compare(existing[existingIndex].StartBeat, selected.StartBeat) > 0 ||
                Compare(existing[existingIndex].EndBeat, selected.EndBeat) < 0)
                return false;
        }
        return true;
    }

    private static IReadOnlyList<OnlineChartLockRange> SubtractLockRanges(
        IReadOnlyList<OnlineChartLockRange> existing,
        IReadOnlyList<OnlineChartLockRange> selection)
    {
        var result = new List<OnlineChartLockRange>(existing.Count + selection.Count);
        var selectionIndex = 0;
        foreach (var current in existing)
        {
            while (selectionIndex < selection.Count &&
                   Compare(selection[selectionIndex].EndBeat, current.StartBeat) <= 0)
                selectionIndex++;

            var cursor = current.StartBeat;
            var index = selectionIndex;
            while (index < selection.Count &&
                   Compare(selection[index].StartBeat, current.EndBeat) < 0)
            {
                var removed = selection[index];
                if (Compare(removed.StartBeat, cursor) > 0)
                    result.Add(new OnlineChartLockRange(cursor, removed.StartBeat));
                if (Compare(removed.EndBeat, cursor) > 0) cursor = removed.EndBeat;
                if (Compare(cursor, current.EndBeat) >= 0) break;
                index++;
            }
            if (Compare(cursor, current.EndBeat) < 0)
                result.Add(new OnlineChartLockRange(cursor, current.EndBeat));
        }
        return result;
    }

    public HarnessSavedSnapshot CreateSavedSnapshot(string? name, long actorId, bool automatic)
    {
        var snapshot = Snapshot();
        var info = new OnlineChartSavedSnapshot(
            Guid.NewGuid(),
            string.IsNullOrWhiteSpace(name)
                ? automatic ? $"回滚前自动保护 {DateTimeOffset.Now:MM-dd HH:mm:ss}" : "Windows Avalonia GUI 快照"
                : name,
            Revision,
            actorId,
            users.Values.Single(user => user.Id == actorId).DisplayName,
            snapshot.Notes.Count,
            snapshot.Timing.Count,
            automatic,
            DateTimeOffset.UtcNow);
        var saved = new HarnessSavedSnapshot(info, snapshot);
        SavedSnapshots.Insert(0, saved);
        return saved;
    }

    public void Restore(OnlineChartSnapshot saved)
    {
        Revision++;
        AuthoritativeBaselineRevision = Revision;
        Locks.Clear();
        Locks.AddRange(saved.Locks);
        Operations.Clear();
        OperationReceipts.Clear();
        Chart = new OnlineChartSnapshot(
            Revision,
            saved.KeyCount,
            saved.Notes.ToArray(),
            saved.Timing.ToArray(),
            Locks.ToArray(),
            saved.Metadata);
    }

    public object Evidence()
    {
        ApplyLeaseCleanup();
        return new
        {
        schema = "lumachart.windows.avalonia.two-client-loopback-state.v1",
        processGeneration = ProcessGeneration,
        restoredFromCheckpoint = RestoredFromCheckpoint,
        roomCreated = RoomCreated,
        roomCreateCount = RoomCreateCount,
        ownerCloseCount = OwnerCloseCount,
        roomLifecycleEvents = RoomLifecycleEvents.ToArray(),
        room = RoomCreated ? RoomSummary() : null,
        activeMemberIds = Members.Values.Where(member => member.Active).Select(member => member.UserId).ToArray(),
        offlineSeatIds = Members.Values.Where(member => !member.Active).Select(member => member.UserId).ToArray(),
        members = Members.Values.OrderBy(member => member.UserId).Select(MemberDto).ToArray(),
        revision = Revision,
        chartChangeSequence = ChartChangeSequence,
        chart = Chart == null ? null : new
        {
            Chart.KeyCount,
            noteCount = Chart.Notes.Count,
            timingCount = Chart.Timing.Count,
            notes = Chart.Notes.Take(32).ToArray(),
            Chart.Metadata
        },
        lockCount = Locks.Count,
        locks = Locks.ToArray(),
        lockSelectionToggleCount = LockSelectionToggles.Count,
        lockSelectionToggles = LockSelectionToggles.ToArray(),
        savedSnapshotCount = SavedSnapshots.Count,
        chatCount = Messages.Count,
        messages = Messages.ToArray(),
        resourceEntryCount = ResourceEntries.Length,
        resourceEntries = ResourceEntries.ToArray(),
        resourceBytes = ResourceEntries.Sum(entry => entry.Length),
        uploadedBlobCount = UploadedBlobCount,
        downloadedBlobCount = DownloadedBlobCount,
        avatarDownloadCount = AvatarDownloadCount,
        avatarDownloadKeys = AvatarDownloadKeys.ToArray(),
        appConfiguration = AppConfiguration,
        adminConfigurationUpdateCount = AdminConfigurationUpdateCount,
        adminUserReadCount = AdminUserReadCount,
        adminUserUpdateCount = AdminUserUpdateCount,
        adminUserLabelUpdateCount = AdminUserLabelUpdateCount,
        adminUserAvatarUploadCount = AdminUserAvatarUploadCount,
        adminUserAvatarResetCount = AdminUserAvatarResetCount,
        adminUserAvatarUploadBytes = AdminUserAvatarUploadBytes,
        adminUsers = users.Values
            .OrderBy(user => user.Id)
            .Select(UserProfile)
            .ToArray(),
        resourceCommitCount = ResourceCommitCount,
        sseConnectionCount = SseConnectionCount,
        invitationCreateCount = InvitationCreateCount,
        invitationFetchCount = InvitationFetchCount,
        invitationJoinCount = InvitationJoinCount,
        notificationFetchCount = NotificationFetchCount,
        notificationInjectionCount = NotificationInjectionCount,
        followRequestCount = FollowRequestCount,
        followMutationCount = FollowMutationCount,
        followNotificationCount = FollowNotificationCount,
        follows = follows
            .OrderBy(relation => relation.FollowerId)
            .ThenBy(relation => relation.TargetId)
            .Select(relation => new
            {
                relation.FollowerId,
                relation.TargetId
            })
            .ToArray(),
        notifications = Notifications.ToArray(),
        invitationResponseActions = InvitationResponseActions.ToArray(),
        pendingInvitationCount = PendingInvitation == null ? 0 : 1,
        memberNormalJoinRequestCount = MemberNormalJoinRequestCount,
        memberJoinPasswordSubmissionCount = MemberJoinPasswordSubmissionCount,
        faults = FaultEvidence(),
        lease = LeaseEvidence(),
        deltaWindowOperationCount = Operations.Count,
        acceptedOperationCount = AcceptedOperationHistory.Count,
        acceptedOperations = AcceptedOperationHistory.Select(operation => new
        {
            operation.Revision,
            operation.ActorUserId,
            operation.Batch.OperationId,
            operation.CreatedAt,
            upsertNoteCount = operation.Batch.UpsertNotes.Count,
            upsertNotes = operation.Batch.UpsertNotes.ToArray(),
            deleteNoteCount = operation.Batch.DeleteNoteIds.Count,
            deleteNoteIds = operation.Batch.DeleteNoteIds.ToArray(),
            upsertTimingCount = operation.Batch.UpsertTiming.Count,
            upsertTiming = operation.Batch.UpsertTiming.ToArray(),
            deleteTimingCount = operation.Batch.DeleteTimingIds.Count,
            deleteTimingIds = operation.Batch.DeleteTimingIds.ToArray(),
            operation.Batch.KeyCount,
            operation.Batch.Metadata
        }).ToArray(),
        requests = Requests.ToArray()
        };
    }

    public void WriteState()
    {
        if (statePath != null)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(statePath)
                ?? throw new InvalidOperationException("The state file has no parent directory."));
            var temporary = statePath + ".tmp";
            File.WriteAllText(temporary, JsonSerializer.Serialize(Evidence(), new JsonSerializerOptions(JsonSerializerDefaults.Web)
            {
                WriteIndented = true
            }));
            File.Move(temporary, statePath, overwrite: true);
        }
        WriteCheckpoint();
    }

    private void RestoreCheckpoint()
    {
        if (checkpointPath == null || !File.Exists(checkpointPath)) return;
        var checkpoint = JsonSerializer.Deserialize<HarnessRestartCheckpoint>(
            File.ReadAllText(checkpointPath),
            RestartJsonOptions) ?? throw new InvalidDataException(
            "The loopback restart checkpoint was empty.");
        if (checkpoint.SchemaVersion is not (1 or 2))
            throw new InvalidDataException(
                $"Unsupported loopback restart checkpoint version {checkpoint.SchemaVersion}.");
        if (checkpoint.RoomCreated && checkpoint.Chart == null)
            throw new InvalidDataException(
                "A created room restart checkpoint must include the full chart.");

        RoomCreated = checkpoint.RoomCreated;
        RoomCreateCount = checkpoint.RoomCreateCount;
        OwnerCloseCount = checkpoint.OwnerCloseCount;
        CurrentRoomId = checkpoint.CurrentRoomId;
        CurrentRoomNumber = checkpoint.CurrentRoomNumber;
        RoomName = checkpoint.RoomName;
        RoomPrivate = checkpoint.RoomPrivate;
        RoomHidden = checkpoint.RoomHidden;
        RoomPassword = checkpoint.RoomPassword;
        ResourcesReady = checkpoint.ResourcesReady;
        PlannedEntries = checkpoint.PlannedEntries;
        ResourceEntries = checkpoint.ResourceEntries;
        Chart = checkpoint.Chart;
        Revision = checkpoint.Revision;
        ChartChangeSequence = checkpoint.ChartChangeSequence;
        AuthoritativeBaselineRevision = checkpoint.AuthoritativeBaselineRevision;
        UploadedBlobCount = checkpoint.UploadedBlobCount;
        DownloadedBlobCount = checkpoint.DownloadedBlobCount;
        ResourceCommitCount = checkpoint.ResourceCommitCount;
        SseConnectionCount = checkpoint.SseConnectionCount;
        OwnerLastHeartbeatAt = checkpoint.OwnerLastHeartbeatAt == default
            ? DateTimeOffset.UtcNow
            : checkpoint.OwnerLastHeartbeatAt;
        LeaseClockOffset = TimeSpan.FromSeconds(checkpoint.LeaseClockOffsetSeconds);
        LeaseCleanupCount = checkpoint.LeaseCleanupCount;
        TransportAbortCount = checkpoint.TransportAbortCount;

        Blobs.Clear();
        foreach (var pair in checkpoint.Blobs) Blobs[pair.Key] = pair.Value;
        Members.Clear();
        foreach (var saved in checkpoint.Members)
        {
            var member = new HarnessMember(saved.UserId, saved.Role, saved.JoinedAt)
            {
                Active = saved.Active,
                Online = saved.Online,
                CanEditMetadata = saved.CanEditMetadata,
                CanEditTiming = saved.CanEditTiming,
                CanEditNotes = saved.CanEditNotes,
                LastSeenAt = saved.LastSeenAt == default
                    ? saved.JoinedAt
                    : saved.LastSeenAt
            };
            Members[member.UserId] = member;
        }
        Messages.Clear();
        Messages.AddRange(checkpoint.Messages);
        Operations.Clear();
        Operations.AddRange(checkpoint.Operations);
        AcceptedOperationHistory.Clear();
        AcceptedOperationHistory.AddRange(checkpoint.AcceptedOperationHistory);
        Locks.Clear();
        Locks.AddRange(checkpoint.Locks);
        SavedSnapshots.Clear();
        SavedSnapshots.AddRange(checkpoint.SavedSnapshots);
        OperationReceipts.Clear();
        foreach (var pair in checkpoint.OperationReceipts)
            OperationReceipts[pair.Key] = pair.Value;
        RoomLifecycleEvents.Clear();
        RoomLifecycleEvents.AddRange(checkpoint.RoomLifecycleEvents);
        LockSelectionToggles.Clear();
        LockSelectionToggles.AddRange(checkpoint.LockSelectionToggles);
        ChartOperationAttempts.Clear();
        ChartOperationAttempts.AddRange(checkpoint.ChartOperationAttempts);
        ChartDeltaAttempts.Clear();
        ChartDeltaAttempts.AddRange(checkpoint.ChartDeltaAttempts);
        ChartOperationResponseCompletions.Clear();
        ChartOperationResponseCompletions.AddRange(
            checkpoint.ChartOperationResponseCompletions);
        RestoredFromCheckpoint = true;
    }

    private void WriteCheckpoint()
    {
        if (checkpointPath == null) return;
        Directory.CreateDirectory(Path.GetDirectoryName(checkpointPath)
            ?? throw new InvalidOperationException(
                "The checkpoint file has no parent directory."));
        var checkpoint = new HarnessRestartCheckpoint(
            2,
            RoomCreated,
            RoomCreateCount,
            OwnerCloseCount,
            CurrentRoomId,
            CurrentRoomNumber,
            RoomName,
            RoomPrivate,
            RoomHidden,
            RoomPassword,
            ResourcesReady,
            PlannedEntries,
            ResourceEntries,
            Blobs.ToDictionary(pair => pair.Key, pair => pair.Value,
                StringComparer.OrdinalIgnoreCase),
            Members.Values.Select(member => new HarnessRestartMember(
                member.UserId,
                member.Role,
                member.JoinedAt,
                member.Active,
                member.Online,
                member.CanEditMetadata,
                member.CanEditTiming,
                member.CanEditNotes,
                member.LastSeenAt)).ToArray(),
            Chart,
            Revision,
            ChartChangeSequence,
            AuthoritativeBaselineRevision,
            Operations.ToArray(),
            AcceptedOperationHistory.ToArray(),
            Locks.ToArray(),
            SavedSnapshots.ToArray(),
            new Dictionary<Guid, long>(OperationReceipts),
            Messages.ToArray(),
            RoomLifecycleEvents.ToArray(),
            LockSelectionToggles.ToArray(),
            ChartOperationAttempts.ToArray(),
            ChartDeltaAttempts.ToArray(),
            ChartOperationResponseCompletions.ToArray(),
            UploadedBlobCount,
            DownloadedBlobCount,
            ResourceCommitCount,
            SseConnectionCount,
            OwnerLastHeartbeatAt,
            LeaseClockOffset.TotalSeconds,
            LeaseCleanupCount,
            TransportAbortCount);
        var temporary = checkpointPath + ".tmp";
        File.WriteAllText(
            temporary,
            JsonSerializer.Serialize(checkpoint, RestartJsonOptions));
        File.Move(temporary, checkpointPath, overwrite: true);
    }

    private static readonly JsonSerializerOptions RestartJsonOptions =
        new(JsonSerializerDefaults.Web)
        {
            WriteIndented = false
        };

    private static double BeatValue(OnlineSyncBeat beat) =>
        beat.Bar + (double)beat.Numerator / Math.Max(1, beat.Denominator);

    private static int Compare(OnlineSyncBeat left, OnlineSyncBeat right)
    {
        var leftWhole = (BigInteger)left.Bar * left.Denominator + left.Numerator;
        var rightWhole = (BigInteger)right.Bar * right.Denominator + right.Numerator;
        return (leftWhole * right.Denominator).CompareTo(rightWhole * left.Denominator);
    }

    private static void ValidateBeat(OnlineSyncBeat beat)
    {
        if (beat.Bar < 0 || beat.Numerator < 0 || beat.Denominator < 1 ||
            beat.Numerator >= beat.Denominator)
            throw new ArgumentException("Beat 位置无效。");
    }
}

internal sealed record HarnessNotificationInjectionRequest(
    long TargetUserId,
    long ActorUserId,
    string? ActorDisplayName,
    string? Type = "follow");

internal sealed record HarnessNetworkBlackoutRequest(long UserId, bool Enabled);

internal sealed record HarnessLeaseAdvanceRequest(double Seconds);

internal sealed record HarnessUserNotification(
    long TargetUserId,
    OnlineUserNotificationDto Notification);

internal sealed class HarnessUser
{
    public HarnessUser(
        long id,
        string username,
        string displayName,
        string role = "user",
        long chartingSeconds = 12345)
    {
        Id = id;
        Username = username;
        DisplayName = displayName;
        Role = role;
        ChartingSeconds = chartingSeconds;
    }

    public long Id { get; }
    public string Username { get; set; }
    public string DisplayName { get; set; }
    public string Role { get; }
    public DateTimeOffset CreatedAt { get; } =
        DateTimeOffset.Parse("2025-01-02T03:04:05Z");
    public long ChartingSeconds { get; }
    public bool IsOnline { get; set; } = true;
    public string AvatarKey { get; set; } = "default";
    public string Bio { get; set; } = "Windows Avalonia 双客户端联机 GUI 验收账号。";
    public string CustomLabel { get; set; } = string.Empty;
    public IReadOnlyList<OnlineUserTagDto> Tags { get; set; } =
        [new OnlineUserTagDto("验收", "#79B8BD")];
}

internal sealed class HarnessMember(
    long userId,
    string role,
    DateTimeOffset? joinedAt = null)
{
    public long UserId { get; } = userId;
    public string Role { get; set; } = role;
    public DateTimeOffset JoinedAt { get; } = joinedAt ?? DateTimeOffset.UtcNow;
    public DateTimeOffset LastSeenAt { get; set; } = joinedAt ?? DateTimeOffset.UtcNow;
    public bool Active { get; set; } = true;
    public bool Online { get; set; } = true;
    public bool CanEditMetadata { get; set; }
    public bool CanEditTiming { get; set; }
    public bool CanEditNotes { get; set; } = true;
}

internal sealed record HarnessSavedSnapshot(
    OnlineChartSavedSnapshot Info,
    OnlineChartSnapshot Snapshot);

internal sealed record HarnessRestartMember(
    long UserId,
    string Role,
    DateTimeOffset JoinedAt,
    bool Active,
    bool Online,
    bool CanEditMetadata,
    bool CanEditTiming,
    bool CanEditNotes,
    DateTimeOffset LastSeenAt);

internal sealed record HarnessRestartCheckpoint(
    int SchemaVersion,
    bool RoomCreated,
    int RoomCreateCount,
    int OwnerCloseCount,
    Guid CurrentRoomId,
    long CurrentRoomNumber,
    string RoomName,
    bool RoomPrivate,
    bool RoomHidden,
    string? RoomPassword,
    bool ResourcesReady,
    OnlineRoomResourceEntryDto[] PlannedEntries,
    OnlineRoomResourceEntryDto[] ResourceEntries,
    Dictionary<string, byte[]> Blobs,
    HarnessRestartMember[] Members,
    OnlineChartSnapshot? Chart,
    long Revision,
    long ChartChangeSequence,
    long? AuthoritativeBaselineRevision,
    AppliedOnlineChartOperation[] Operations,
    AppliedOnlineChartOperation[] AcceptedOperationHistory,
    OnlineChartLock[] Locks,
    HarnessSavedSnapshot[] SavedSnapshots,
    Dictionary<Guid, long> OperationReceipts,
    OnlineRoomChatMessageDto[] Messages,
    HarnessRoomLifecycleEvent[] RoomLifecycleEvents,
    HarnessLockSelectionToggle[] LockSelectionToggles,
    HarnessChartOperationAttempt[] ChartOperationAttempts,
    HarnessChartDeltaAttempt[] ChartDeltaAttempts,
    HarnessChartOperationResponseCompletion[] ChartOperationResponseCompletions,
    int UploadedBlobCount,
    int DownloadedBlobCount,
    int ResourceCommitCount,
    int SseConnectionCount,
    DateTimeOffset OwnerLastHeartbeatAt,
    double LeaseClockOffsetSeconds,
    int LeaseCleanupCount,
    int TransportAbortCount);

internal sealed record HarnessRoomLifecycleEvent(
    int Sequence,
    string Action,
    int Generation,
    Guid RoomId,
    long RoomNumber,
    string RoomName,
    long ActorUserId,
    long Revision,
    int NoteCount,
    int TimingCount,
    int AcceptedOperationCount,
    IReadOnlyList<long> ActiveMemberIds,
    DateTimeOffset OccurredAt);

internal sealed record HarnessLockSelectionToggle(
    int Sequence,
    long ActorUserId,
    IReadOnlyList<OnlineChartLockRange> RequestedRanges,
    bool IsUnlock,
    IReadOnlyList<OnlineChartLock> ResultingLocks,
    DateTimeOffset OccurredAt);

internal sealed record HarnessFaultInjectionRequest(
    int FailNextChartDeltaRequests = 0,
    int MalformedNextChartDeltaResponses = 0,
    int DisconnectNextSseConnections = 0,
    int DropNextChartOperationResponsesAfterCommit = 0,
    int DelayNextChartOperationResponseMilliseconds = 0,
    int DelayNextResourceDownloadMilliseconds = 0,
    int DisconnectNextResourceDownloads = 0,
    int CorruptNextResourceDownloads = 0);

internal sealed record HarnessChartOperationFaultDecision(
    bool DropResponse,
    int DelayMilliseconds);

internal sealed record HarnessResourceDownloadFaultDecision(
    bool DisconnectResponse,
    bool CorruptResponse,
    int DelayMilliseconds);

internal sealed record HarnessChartOperationAttempt(
    int Attempt,
    Guid OperationId,
    long BaseRevision,
    string CanonicalRequestSha256,
    bool DuplicateReceipt,
    bool ResponseDropped,
    int ResponseDelayMilliseconds,
    DateTimeOffset ReceivedAt);

internal sealed record HarnessChartDeltaAttempt(
    int Attempt,
    long UserId,
    long AfterRevision,
    long CurrentRevision,
    int ReturnedOperationCount,
    bool Failed,
    DateTimeOffset ReceivedAt);

internal sealed record HarnessChartOperationResponseCompletion(
    Guid OperationId,
    long ResponseRevision,
    long ServerRevisionAtCompletion,
    bool Dropped,
    DateTimeOffset CompletedAt);

internal sealed record HarnessResourceDownloadAttempt(
    int Attempt,
    string Sha256,
    long DeclaredLength,
    bool ResponseDisconnected,
    bool ResponseCorrupted,
    int ResponseDelayMilliseconds,
    DateTimeOffset ReceivedAt);
