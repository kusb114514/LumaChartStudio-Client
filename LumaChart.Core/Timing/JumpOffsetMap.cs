using LumaChart.Core.Models;

namespace LumaChart.Core.Timing;

/// <summary>
/// Malody 的 <c>jump</c> 是事件而不是过程：它在某一拍把整条谱面的滚动坐标整体挪一段距离，
/// 然后一直保持到下一个 jump。所以它和 <see cref="ScrollSpeedMap"/> 的「速度积分」是两回事，
/// 必须分开存，最后相加。
/// </summary>
/// <remarks>
/// <para>语义（据 Malody 谱师文档《写给想写 sv 的谱师》）：<c>jump:n</c> 是「在瞬间快进谱面 n 毫秒」，
/// 而 <b>闪现距离 = 流速 × n</b>。所以先换算成拍
/// <c>Δ = n·BPM/60000</c>，再乘以该 jump 所在拍的 scroll 倍率 <c>v</c>，
/// 得到滚动坐标单位下的位移：</para>
/// <code>offset = v · j · BPM / 60000</code>
/// <para>⚠️ 那个 <c>v</c> 不能省。整张 SV 谱的卡顿写法就是
/// <c>{"scroll":0.0001}</c> 紧跟 <c>{"jump":903614.4578}</c>：
/// 前者把流速压到万分之一，于是后者 2500 拍的「快进」实际只推 0.25 拍 —— 画面一抖。
/// 不乘 v 的话它会把整段谱面推出屏幕，看起来就是「这一段完全不显示」。</para>
/// <para>⚠️ 这个位移是 <b>世界坐标</b>的一部分，note 和播放头都要用它：
/// 屏幕位置 = <c>W(note) − W(now)</c>，而 <c>W(b) = ∫v·db + Σjump(b)</c>。
/// 只给播放头加 jump 会让整张谱平移 <c>Σjump</c> 拍（例谱到 400 拍时已累积 186 拍，
/// note 全部飞出屏幕）。两边都加并不会抵消：已过去的 jump 在两侧都有、自然消掉，
/// 而 <c>(now, note]</c> 之间的 jump 只在 note 一侧 —— 那正是「谱面被快进、
/// note 在半空被判定」这个效果本身。</para>
/// </remarks>
public sealed class JumpOffsetMap
{
    private readonly Segment[] segments;

    public JumpOffsetMap(
        IEnumerable<TimingEvent> events,
        TimingMap timing,
        ScrollSpeedMap? scroll = null)
    {
        ArgumentNullException.ThrowIfNull(timing);
        // jump 和 scroll 混在一条时间线上按「拍 → 文件里的先后」走，不能分成两张表各查各的。
        // 同一拍上两者都有的时候，jump 用哪个倍率取决于谁先写：
        //   regain 297.99375 = {"jump":9999} 紧接着 {"scroll":0.75}
        //     → 这一跳必须按 1× 折 23.331 拍；若按新倍率 0.75 折 17.498 拍，
        //       就会在最密的那串交替跳中间留下 −5.833 拍的永久缺口。
        //   AX 553 = {"jump":12966.87} 紧接着 {"scroll":−33}
        //     → 同样必须按 1× 折 35.875 拍；按新倍率会折 −1183.9 拍。
        // 反过来 regain 212/216/220/224 是 {"scroll":−0.4948} 先写，jump 就该按 −0.4948 折。
        // 所以只有「按文件顺序逐个应用」这一条规则能同时满足两边。
        var timeline = events
            .Select((item, index) => (Item: item, Index: index))
            .Where(entry =>
                (entry.Item.Effect == TimingEffectKind.Jump ||
                 entry.Item.Effect == TimingEffectKind.Scroll) &&
                double.IsFinite(entry.Item.EffectValue))
            .OrderBy(entry => entry.Item.Beat)
            .ThenBy(entry => entry.Index)
            .Select(entry => entry.Item)
            .ToList();

        var floor = scroll?.MinimumMultiplier ?? double.NegativeInfinity;
        var result = new List<Segment> { new(0, 0) };
        // jump 是累积的：一条 jump 把坐标挪一段之后，那段位移一直留在坐标系里，
        // 直到下一条 jump 再叠加。"闪现距离 = 流速 × n" 说的是这一条的增量，
        // 不是该拍的总位移 —— 例谱里 384~387 那 59 条 jump 单看每条都在 ±1 拍以内，
        // 但累积后 387 那一跳把整个坐标系推了 25 拍，这就是"叠加谱面"的层从哪来。
        var cumulative = 0.0;
        var multiplier = 1.0;
        foreach (var point in timeline)
        {
            if (point.Effect == TimingEffectKind.Scroll)
            {
                multiplier = Math.Clamp(point.EffectValue, floor, ScrollSpeedMap.MaximumMultiplier);
                continue;
            }

            var beat = Math.Max(0, point.Beat.Value);
            var bpm = timing.BpmAt(point.Beat);
            var offset = bpm > 0 && double.IsFinite(bpm)
                ? point.EffectValue * bpm / 60000.0
                : point.EffectValue;
            if (scroll != null) offset *= multiplier;
            if (!double.IsFinite(offset)) continue;

            cumulative += offset;
            var previous = result[^1];
            if (Math.Abs(previous.StartBeat - beat) < 1e-9)
                result[^1] = new Segment(beat, cumulative);
            else
                result.Add(new Segment(beat, cumulative));
        }

        segments = result.ToArray();
    }

    public double OffsetAt(BeatPosition beat) => OffsetAt(beat.Value);

    public double OffsetAt(double beat)
    {
        if (!double.IsFinite(beat)) return 0;
        return segments[FindSegment(beat)].Offset;
    }

    private int FindSegment(double beat)
    {
        var low = 0;
        var high = segments.Length - 1;
        while (low < high)
        {
            var middle = (low + high + 1) / 2;
            if (segments[middle].StartBeat <= beat) low = middle;
            else high = middle - 1;
        }
        return low;
    }

    private readonly record struct Segment(double StartBeat, double Offset);
}
