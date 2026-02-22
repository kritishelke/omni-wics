import { Injectable } from "@nestjs/common";
import { insightsTodaySchema, InsightsTodayDTO } from "@omni/shared";
import { SupabaseService } from "../supabase/supabase.service";

interface SignalRow {
  type: string;
  ts: string;
  payload: Record<string, unknown> | null;
}

@Injectable()
export class InsightsService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getToday(userId: string, date?: string): Promise<InsightsTodayDTO> {
    const targetDate = date ?? new Date().toISOString().slice(0, 10);
    const start = `${targetDate}T00:00:00.000Z`;
    const end = `${targetDate}T23:59:59.999Z`;

    const { data: signalRows, error: signalsError } = await this.supabaseService.admin
      .from("signals")
      .select("type, ts, payload")
      .eq("user_id", userId)
      .gte("ts", start)
      .lte("ts", end)
      .order("ts", { ascending: true });

    if (signalsError) {
      throw new Error(`Failed to load insights signals: ${signalsError.message}`);
    }

    const signals = (signalRows ?? []) as SignalRow[];
    const driftSignals = signals.filter((s) => s.type === "drift");
    const checkins = signals.filter((s) => s.type === "checkin");

    const driftMinutesFromDriftSignals = driftSignals.reduce((sum, signal) => {
      const payload = signal.payload ?? {};
      const minutes = Number(payload.minutes);
      return sum + (Number.isFinite(minutes) && minutes > 0 ? minutes : 5);
    }, 0);

    const driftMinutesFromCheckins = checkins.reduce((sum, signal) => {
      const payload = signal.payload ?? {};
      const minutes = Number(payload.driftMinutes);
      return sum + (Number.isFinite(minutes) && minutes > 0 ? minutes : 0);
    }, 0);

    const driftMinutesToday = Math.max(0, Math.round(driftMinutesFromDriftSignals + driftMinutesFromCheckins));

    const hourlyFocus: Record<number, number[]> = {};
    for (const signal of checkins) {
      const focus = Number((signal.payload ?? {}).focus);
      if (Number.isFinite(focus) === false) continue;

      const hour = new Date(signal.ts).getUTCHours();
      const bucket = Math.floor(hour / 2) * 2;
      if (!hourlyFocus[bucket]) {
        hourlyFocus[bucket] = [];
      }
      hourlyFocus[bucket].push(focus);
    }

    const focusBuckets = Object.entries(hourlyFocus).map(([bucketStart, values]) => ({
      bucketStart: Number(bucketStart),
      avgFocus: values.reduce((a, b) => a + b, 0) / Math.max(1, values.length)
    }));

    focusBuckets.sort((a, b) => b.avgFocus - a.avgFocus);
    const bestBucket = focusBuckets[0] ?? { bucketStart: 10, avgFocus: 7 };

    const bestFocusWindow = `${this.formatHour(bestBucket.bucketStart)} - ${this.formatHour(
      (bestBucket.bucketStart + 2) % 24
    )}`;

    const mostProductiveTimeLabel = this.timeBandLabel(bestBucket.bucketStart);
    const mostProductiveTimeRange = this.timeBandRange(bestBucket.bucketStart);

    const derailStats = new Map<string, { count: number; totalMinutes: number }>();
    for (const signal of driftSignals) {
      const payload = signal.payload ?? {};
      const reason =
        (typeof payload.derailReason === "string" && payload.derailReason.trim()) ||
        (Array.isArray(payload.apps) && typeof payload.apps[0] === "string" ? String(payload.apps[0]) : "Distraction");
      const normalizedReason = reason.trim() || "Distraction";
      const minutesRaw = Number(payload.minutes);
      const minutes = Number.isFinite(minutesRaw) && minutesRaw > 0 ? minutesRaw : 5;

      const existing = derailStats.get(normalizedReason) ?? { count: 0, totalMinutes: 0 };
      existing.count += 1;
      existing.totalMinutes += minutes;
      derailStats.set(normalizedReason, existing);
    }

    const topDerail = [...derailStats.entries()].sort((a, b) => b[1].count - a[1].count)[0];
    const mostCommonDerailLabel = topDerail?.[0] ?? "Social Media";
    const mostCommonDerailAvgMinutes = topDerail
      ? Math.round(topDerail[1].totalMinutes / Math.max(1, topDerail[1].count))
      : 15;

    const avgFocus =
      checkins.length > 0
        ? checkins.reduce((sum, signal) => sum + Number((signal.payload ?? {}).focus || 0), 0) /
          Math.max(1, checkins.length)
        : 7;

    const burnoutRiskLevel: "low" | "med" | "high" =
      driftMinutesToday > 45 || avgFocus < 4.5
        ? "high"
        : driftMinutesToday > 20 || avgFocus < 6.5
          ? "med"
          : "low";

    const burnoutExplanation =
      burnoutRiskLevel === "high"
        ? "High strain detected. Add longer recovery breaks and reduce task scope."
        : burnoutRiskLevel === "med"
          ? "Moderate strain. Keep recovery blocks and tighten context switching."
          : "Your current workload is manageable. Keep maintaining healthy study breaks.";

    const learnedBullets = [
      `You focus best in ${mostProductiveTimeLabel.toLowerCase()} windows`,
      `Most common derail today: ${mostCommonDerailLabel}`,
      driftMinutesToday > 0
        ? `Manual drift reports totaled ${driftMinutesToday} minutes`
        : "No drift reported today; keep the same pacing"
    ];

    return insightsTodaySchema.parse({
      driftMinutesToday,
      bestFocusWindow,
      mostProductiveTimeLabel,
      mostProductiveTimeRange,
      mostCommonDerailLabel,
      mostCommonDerailAvgMinutes,
      burnoutRiskLevel,
      burnoutExplanation,
      learnedBullets
    });
  }

  private formatHour(hour: number): string {
    const normalized = ((hour % 24) + 24) % 24;
    const suffix = normalized >= 12 ? "PM" : "AM";
    const display = normalized % 12 === 0 ? 12 : normalized % 12;
    return `${display} ${suffix}`;
  }

  private timeBandLabel(hour: number): string {
    const normalized = ((hour % 24) + 24) % 24;
    if (normalized >= 5 && normalized < 12) return "Morning";
    if (normalized >= 12 && normalized < 17) return "Afternoon";
    if (normalized >= 17 && normalized < 22) return "Evening";
    return "Night";
  }

  private timeBandRange(hour: number): string {
    const band = this.timeBandLabel(hour);
    switch (band) {
      case "Morning":
        return "8 AM - 12 PM";
      case "Afternoon":
        return "12 PM - 4 PM";
      case "Evening":
        return "4 PM - 8 PM";
      default:
        return "8 PM - 12 AM";
    }
  }
}
