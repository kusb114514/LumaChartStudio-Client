using LumaChart.Core.Models;
using LumaChart.Core.Timing;

namespace LumaChart.Application.Playtest;

public enum PlaytestHitGrade
{
    None,
    Best,
    Great,
    Good,
    Miss
}

public sealed class PlaytestRuntimeNote
{
    internal PlaytestRuntimeNote(
        ChartNote note,
        double startMilliseconds,
        double endMilliseconds,
        double startScrollPosition,
        double endScrollPosition)
    {
        Note = note;
        StartMilliseconds = startMilliseconds;
        EndMilliseconds = endMilliseconds;
        StartScrollPosition = startScrollPosition;
        EndScrollPosition = endScrollPosition;
    }

    public ChartNote Note { get; }
    public double StartMilliseconds { get; }
    public double EndMilliseconds { get; }
    public double StartScrollPosition { get; }
    public double EndScrollPosition { get; }
    public bool HeadJudged { get; internal set; }
    public bool Holding { get; internal set; }
    public bool Completed { get; internal set; }
    public PlaytestHitGrade Grade { get; internal set; }
}

public sealed record PlaytestJudgementEvent(
    PlaytestRuntimeNote Note,
    PlaytestHitGrade Grade,
    double OffsetMilliseconds,
    bool IsHead,
    bool Completed,
    bool PlaySound);

public readonly record struct PlaytestJudgementWindows
{
    public PlaytestJudgementWindows(
        double bestMilliseconds,
        double greatMilliseconds,
        double goodMilliseconds,
        double missMilliseconds)
    {
        BestMilliseconds = Normalize(bestMilliseconds, 45);
        GreatMilliseconds = Math.Max(
            BestMilliseconds,
            Normalize(greatMilliseconds, 85));
        GoodMilliseconds = Math.Max(
            GreatMilliseconds,
            Normalize(goodMilliseconds, 130));
        MissMilliseconds = Math.Max(
            GoodMilliseconds,
            Normalize(missMilliseconds, 170));
    }

    public static PlaytestJudgementWindows Default { get; } = new(45, 85, 130, 170);

    public double BestMilliseconds { get; }
    public double GreatMilliseconds { get; }
    public double GoodMilliseconds { get; }
    public double MissMilliseconds { get; }

    private static double Normalize(double value, double fallback) =>
        double.IsFinite(value) ? Math.Clamp(value, 1, 200) : fallback;
}

/// <summary>
/// UI-independent WPF 1.1.0 playtest judgement state machine. Windows hosts own
/// clocks, audio, keyboard routing and drawing; this type owns strict lane order,
/// judgement windows, holds, AutoPlay and score state.
/// </summary>
public sealed class PlaytestSession
{
    private static readonly IReadOnlyList<PlaytestJudgementEvent> EmptyEvents =
        Array.Empty<PlaytestJudgementEvent>();

    public const double BestWindowMilliseconds = 45;
    public const double GreatWindowMilliseconds = 85;
    public const double GoodWindowMilliseconds = 130;
    public const double MissWindowMilliseconds = 170;

    private readonly List<PlaytestRuntimeNote> notes;
    private readonly List<PlaytestRuntimeNote>[] laneQueues;
    private readonly int[] laneIndexes;
    private readonly PlaytestRuntimeNote?[] activeHolds;
    private readonly double[] autoReleaseMilliseconds;
    private int globalMissIndex;
    private int autoPlayIndex;
    private int combo;
    private int maximumCombo;
    private int judged;
    private int completed;
    private double earnedAccuracy;

    public PlaytestSession(
        ChartDocument source,
        double startBeat,
        bool autoPlay,
        PlaytestJudgementWindows? judgementWindows = null,
        // Malody accepts negative scroll; clamping at 0 turned every reverse pulse
        // into a stall, which is why "先冲过来再回去" charts looked like they merely
        // slowed down. -100 is a practical floor, not a semantic one.
        double scrollMinimumMultiplier = -100)
    {
        ArgumentNullException.ThrowIfNull(source);
        Document = source.Clone();
        TimingMap = new TimingMap(Document.Timing);
        ScrollMap = new ScrollSpeedMap(Document.Timing, scrollMinimumMultiplier);
        JumpMap = new JumpOffsetMap(Document.Timing, TimingMap, ScrollMap);
        KeyCount = Math.Clamp(Document.KeyCount, 1, 18);
        StartMilliseconds = Math.Max(
            0,
            TimingMap.BeatToMilliseconds(
                BeatPosition.FromDouble(double.IsFinite(startBeat) ? Math.Max(0, startBeat) : 0)));
        // Note 和播放头必须用同一个世界坐标（scroll 的积分 + jump 的累积位移），
        // 屏幕位置是两者相减。只给播放头加 jump 会让整张谱错位 JumpΣ 拍
        // （这张例谱到 400 拍时 JumpΣ 已经 186 拍，note 全部飞出屏幕）。
        // 两者都加不会互相抵消：抵消的只有「已经过去的 jump」，而 (now, note] 之间的
        // jump 只出现在 note 一侧 —— 那正是「谱面被快进、note 在半空被判定」的效果本身。
        //
        // 长条的**长度**也必须用世界坐标差：jump 让谱面「快进」，长条的头一旦被判定线钉住，
        // 尾巴仍然按 scroll + jump 走，所以尾巴跑得比头快，条子就被拉长 —— 这是 Malody 的实际行为。
        // 只算 scroll 积分会把长条压扁：谱面 `_song_27543` 的 287→288 那条长条横跨定格段
        // （scroll 0.0001 + 两条 0.5 拍 jump），纯积分算出来长 0.0001 拍 → 渲染成 0 长度，
        // 就是「长条变成 0 长度但颜色还是蓝的」。同谱 291.5→292 的三根应为 4.5 拍长，纯积分只给 0.5 拍。
        notes = Document.Notes
            .Where(note => !note.IsDraft)
            .Select(note => new PlaytestRuntimeNote(
                note,
                TimingMap.BeatToMilliseconds(note.Beat),
                TimingMap.BeatToMilliseconds(note.EndBeat ?? note.Beat),
                ScrollPositionAt(note.Beat),
                ScrollPositionAt(note.EndBeat ?? note.Beat)))
            .OrderBy(note => note.StartMilliseconds)
            .ThenBy(note => note.Note.Lane)
            .ToList();
        laneQueues = Enumerable.Range(0, KeyCount)
            .Select(lane => notes.Where(note => note.Note.Lane == lane).ToList())
            .ToArray();
        laneIndexes = new int[KeyCount];
        activeHolds = new PlaytestRuntimeNote?[KeyCount];
        autoReleaseMilliseconds = new double[KeyCount];
        AutoPlay = autoPlay;
        JudgementWindows = judgementWindows ?? PlaytestJudgementWindows.Default;
        Prepare();
    }

    public ChartDocument Document { get; }
    public TimingMap TimingMap { get; }
    public ScrollSpeedMap ScrollMap { get; }

    /// <summary>
    /// 世界坐标：<c>speed 的积分 + jump 的累积位移</c>。note 与播放头都用它，
    /// 屏幕位置是两者之差。只给一边加 jump 会让整张谱平移 JumpΣ 拍。
    /// </summary>
    public JumpOffsetMap JumpMap { get; }

    public double ScrollPositionAt(BeatPosition beat) =>
        ScrollMap.PositionAt(beat) + JumpMap.OffsetAt(beat);
    public IReadOnlyList<PlaytestRuntimeNote> Notes => notes;
    public int KeyCount { get; }
    public double StartMilliseconds { get; }
    public bool AutoPlay { get; private set; }
    public PlaytestJudgementWindows JudgementWindows { get; private set; }
    public int Combo => combo;
    public int MaximumCombo => maximumCombo;
    public int Judged => judged;
    public double Accuracy => judged == 0 ? 1 : earnedAccuracy / judged;
    public bool IsComplete => completed == notes.Count;

    public void Prepare()
    {
        globalMissIndex = 0;
        autoPlayIndex = 0;
        Array.Clear(laneIndexes);
        Array.Clear(activeHolds);
        Array.Clear(autoReleaseMilliseconds);
        combo = 0;
        maximumCombo = 0;
        judged = 0;
        completed = 0;
        earnedAccuracy = 0;
        foreach (var note in notes)
        {
            note.HeadJudged = false;
            note.Holding = false;
            note.Completed = false;
            note.Grade = PlaytestHitGrade.None;
            var skipBefore = AutoPlay
                ? StartMilliseconds - .5
                : StartMilliseconds - JudgementWindows.MissMilliseconds;
            if (note.StartMilliseconds >= skipBefore) continue;
            note.HeadJudged = true;
            note.Completed = true;
            completed++;
        }
        while (globalMissIndex < notes.Count && notes[globalMissIndex].Completed) globalMissIndex++;
        while (autoPlayIndex < notes.Count && notes[autoPlayIndex].Completed) autoPlayIndex++;
        for (var lane = 0; lane < laneQueues.Length; lane++)
        {
            while (laneIndexes[lane] < laneQueues[lane].Count &&
                   laneQueues[lane][laneIndexes[lane]].Completed)
                laneIndexes[lane]++;
        }
    }

    public void SetAutoPlay(bool value, double currentMilliseconds)
    {
        if (AutoPlay == value) return;
        AutoPlay = value;
        Array.Clear(autoReleaseMilliseconds);
        if (!AutoPlay) return;
        while (autoPlayIndex < notes.Count &&
               (notes[autoPlayIndex].Completed ||
                notes[autoPlayIndex].StartMilliseconds < currentMilliseconds - .5))
            autoPlayIndex++;
    }

    public void SetJudgementWindows(PlaytestJudgementWindows value) =>
        JudgementWindows = value;

    public IReadOnlyList<PlaytestJudgementEvent> PressLane(int lane, double currentMilliseconds)
    {
        if (AutoPlay || lane < 0 || lane >= laneQueues.Length || !double.IsFinite(currentMilliseconds))
            return EmptyEvents;
        var events = new List<PlaytestJudgementEvent>();
        var queue = laneQueues[lane];
        var index = laneIndexes[lane];
        while (index < queue.Count && queue[index].HeadJudged) index++;
        while (index < queue.Count &&
               currentMilliseconds - queue[index].StartMilliseconds >
               JudgementWindows.MissMilliseconds)
        {
            var stale = queue[index++];
            stale.HeadJudged = true;
            stale.Grade = PlaytestHitGrade.Miss;
            Complete(stale);
            events.Add(Event(stale, currentMilliseconds - stale.StartMilliseconds, true, false));
        }
        laneIndexes[lane] = index;
        if (index >= queue.Count) return events;
        var candidate = queue[index];
        var offset = currentMilliseconds - candidate.StartMilliseconds;
        if (offset < -JudgementWindows.MissMilliseconds ||
            offset > JudgementWindows.MissMilliseconds) return events;
        candidate.HeadJudged = true;
        candidate.Grade = Grade(offset, JudgementWindows);
        laneIndexes[lane] = index + 1;
        if (candidate.Note.IsHold)
        {
            candidate.Holding = true;
            activeHolds[lane] = candidate;
            events.Add(Event(candidate, offset, true, true));
        }
        else
        {
            Complete(candidate);
            events.Add(Event(candidate, offset, true, true));
        }
        return events;
    }

    public IReadOnlyList<PlaytestJudgementEvent> ReleaseLane(int lane, double currentMilliseconds)
    {
        if (AutoPlay || lane < 0 || lane >= activeHolds.Length || !double.IsFinite(currentMilliseconds))
            return EmptyEvents;
        var hold = activeHolds[lane];
        if (hold == null) return EmptyEvents;
        hold.Holding = false;
        var offset = currentMilliseconds - hold.EndMilliseconds;
        hold.Grade = currentMilliseconds <
                     hold.EndMilliseconds - JudgementWindows.MissMilliseconds
            ? PlaytestHitGrade.Miss
            : Worse(hold.Grade, Grade(offset, JudgementWindows));
        Complete(hold);
        return [Event(hold, offset, false, false)];
    }

    public IReadOnlyList<PlaytestJudgementEvent> Advance(double currentMilliseconds)
    {
        if (!double.IsFinite(currentMilliseconds)) return EmptyEvents;
        List<PlaytestJudgementEvent>? events = null;
        if (AutoPlay) RunAutoPlay(currentMilliseconds, ref events);
        while (globalMissIndex < notes.Count &&
               currentMilliseconds - notes[globalMissIndex].StartMilliseconds >
               JudgementWindows.MissMilliseconds)
        {
            var note = notes[globalMissIndex++];
            if (note.HeadJudged) continue;
            note.HeadJudged = true;
            note.Grade = PlaytestHitGrade.Miss;
            Complete(note);
            (events ??= []).Add(
                Event(note, currentMilliseconds - note.StartMilliseconds, true, false));
        }
        for (var lane = 0; lane < activeHolds.Length; lane++)
        {
            var note = activeHolds[lane];
            if (note is { Holding: true } && currentMilliseconds >= note.EndMilliseconds)
            {
                note.Holding = false;
                Complete(note);
                (events ??= []).Add(
                    Event(note, currentMilliseconds - note.EndMilliseconds, false, false));
            }
            if (autoReleaseMilliseconds[lane] > 0 && currentMilliseconds >= autoReleaseMilliseconds[lane])
                autoReleaseMilliseconds[lane] = 0;
        }
        return events ?? EmptyEvents;
    }

    public bool IsAutoLanePressed(int lane) =>
        lane >= 0 && lane < autoReleaseMilliseconds.Length && autoReleaseMilliseconds[lane] > 0;

    public static PlaytestHitGrade Grade(double offsetMilliseconds) =>
        Grade(offsetMilliseconds, PlaytestJudgementWindows.Default);

    public static PlaytestHitGrade Grade(
        double offsetMilliseconds,
        PlaytestJudgementWindows windows) => Math.Abs(offsetMilliseconds) switch
    {
        var offset when offset <= windows.BestMilliseconds => PlaytestHitGrade.Best,
        var offset when offset <= windows.GreatMilliseconds => PlaytestHitGrade.Great,
        var offset when offset < windows.GoodMilliseconds => PlaytestHitGrade.Good,
        _ => PlaytestHitGrade.Miss
    };

    public static string GradeText(PlaytestHitGrade grade) => grade switch
    {
        PlaytestHitGrade.Best => "BEST",
        PlaytestHitGrade.Great => "GREAT",
        PlaytestHitGrade.Good => "GOOD",
        PlaytestHitGrade.Miss => "MISS",
        _ => string.Empty
    };

    private void RunAutoPlay(
        double currentMilliseconds,
        ref List<PlaytestJudgementEvent>? events)
    {
        while (autoPlayIndex < notes.Count && notes[autoPlayIndex].StartMilliseconds <= currentMilliseconds)
        {
            var note = notes[autoPlayIndex++];
            if (note.HeadJudged || note.Completed) continue;
            note.HeadJudged = true;
            note.Grade = PlaytestHitGrade.Best;
            var lane = note.Note.Lane;
            if (lane >= 0 && lane < activeHolds.Length)
            {
                autoReleaseMilliseconds[lane] = note.Note.IsHold
                    ? note.EndMilliseconds
                    : Math.Max(autoReleaseMilliseconds[lane], currentMilliseconds + 65);
                if (note.Note.IsHold)
                {
                    note.Holding = true;
                    activeHolds[lane] = note;
                }
                else Complete(note);
            }
            else Complete(note);
            (events ??= []).Add(Event(note, 0, true, true));
        }
    }

    private void Complete(PlaytestRuntimeNote note)
    {
        if (note.Completed) return;
        var lane = note.Note.Lane;
        if (lane >= 0 && lane < activeHolds.Length && ReferenceEquals(activeHolds[lane], note))
            activeHolds[lane] = null;
        note.Completed = true;
        completed++;
        judged++;
        earnedAccuracy += note.Grade switch
        {
            PlaytestHitGrade.Best => 1,
            PlaytestHitGrade.Great => .8,
            PlaytestHitGrade.Good => .5,
            _ => 0
        };
        if (note.Grade == PlaytestHitGrade.Miss) combo = 0;
        else
        {
            combo++;
            maximumCombo = Math.Max(maximumCombo, combo);
        }
    }

    private static PlaytestJudgementEvent Event(
        PlaytestRuntimeNote note,
        double offset,
        bool isHead,
        bool playSound) => new(
        note,
        note.Grade,
        offset,
        isHead,
        note.Completed,
        playSound);

    private static PlaytestHitGrade Worse(PlaytestHitGrade left, PlaytestHitGrade right) =>
        (PlaytestHitGrade)Math.Max((int)left, (int)right);
}
