import { Injectable } from "@nestjs/common";
import {
  rewardsClaimResponseSchema,
  rewardsWeeklySchema,
  RewardsClaimResponseDTO,
  RewardsWeeklyDTO
} from "@omni/shared";
import { SupabaseService } from "../supabase/supabase.service";

type PlanRow = {
  id: string;
  plan_date: string;
};

type BlockRow = {
  id: string;
  plan_id: string;
  start_at: string;
  type: "task" | "sticky" | "break";
  google_task_id: string | null;
};

type SignalRow = {
  type: string;
  ts: string;
  related_block_id: string | null;
  payload: Record<string, unknown> | null;
};

type DailyLogRow = {
  log_date: string;
};

type TaskRow = {
  google_task_id: string;
};

@Injectable()
export class RewardsService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getWeekly(userId: string, date?: string): Promise<RewardsWeeklyDTO> {
    const targetDate = date ?? new Date().toISOString().slice(0, 10);
    const week = this.getWeekBounds(targetDate);

    const { data: planRows, error: plansError } = await this.supabaseService.admin
      .from("plans")
      .select("id, plan_date")
      .eq("user_id", userId)
      .gte("plan_date", week.startDate)
      .lte("plan_date", week.endDate);

    if (plansError) {
      throw new Error(`Failed to fetch weekly plans: ${plansError.message}`);
    }

    const plans = (planRows ?? []) as PlanRow[];
    const planIds = plans.map((plan) => plan.id);

    let blocks: BlockRow[] = [];
    if (planIds.length > 0) {
      const { data: blockRows, error: blocksError } = await this.supabaseService.admin
        .from("plan_blocks")
        .select("id, plan_id, start_at, type, google_task_id")
        .eq("user_id", userId)
        .in("plan_id", planIds)
        .order("start_at", { ascending: true });

      if (blocksError) {
        throw new Error(`Failed to fetch weekly blocks: ${blocksError.message}`);
      }

      blocks = (blockRows ?? []) as BlockRow[];
    }

    const { data: signalRows, error: signalsError } = await this.supabaseService.admin
      .from("signals")
      .select("type, ts, related_block_id, payload")
      .eq("user_id", userId)
      .gte("ts", week.startAtIso)
      .lt("ts", week.endExclusiveIso)
      .order("ts", { ascending: true });

    if (signalsError) {
      throw new Error(`Failed to fetch weekly signals: ${signalsError.message}`);
    }

    const { data: dailyLogRows, error: logsError } = await this.supabaseService.admin
      .from("daily_logs")
      .select("log_date")
      .eq("user_id", userId)
      .gte("log_date", week.startDate)
      .lte("log_date", week.endDate);

    if (logsError) {
      throw new Error(`Failed to fetch weekly day-close logs: ${logsError.message}`);
    }

    const { data: completedTaskRows, error: tasksError } = await this.supabaseService.admin
      .from("tasks_cache")
      .select("google_task_id")
      .eq("user_id", userId)
      .eq("status", "completed")
      .gte("updated_at", week.startAtIso)
      .lt("updated_at", week.endExclusiveIso);

    if (tasksError) {
      throw new Error(`Failed to fetch weekly completed tasks: ${tasksError.message}`);
    }

    const signals = (signalRows ?? []) as SignalRow[];
    const dailyLogs = (dailyLogRows ?? []) as DailyLogRow[];
    const completedTasks = (completedTaskRows ?? []) as TaskRow[];

    const completedBlockIds = this.collectCompletedBlockIds(blocks, signals, completedTasks);
    const dailyLogSet = new Set(dailyLogs.map((row) => row.log_date));

    const blocksByDay = new Map<string, BlockRow[]>();
    for (const block of blocks) {
      const dayKey = block.start_at.slice(0, 10);
      const existing = blocksByDay.get(dayKey) ?? [];
      existing.push(block);
      blocksByDay.set(dayKey, existing);
    }

    const dayStates = week.dayKeys.map((dayKey) => {
      const dayBlocks = (blocksByDay.get(dayKey) ?? []).filter((block) => block.type !== "break");
      const completedCount = dayBlocks.filter((block) => completedBlockIds.has(block.id)).length;
      const completionRate = dayBlocks.length > 0 ? completedCount / dayBlocks.length : 0;
      return completionRate >= 0.6 || dailyLogSet.has(dayKey);
    });

    const daysCompletedThisWeek = dayStates.filter(Boolean).length;
    const todayKey = targetDate;
    const todayBlocks = (blocksByDay.get(todayKey) ?? []).filter((block) => block.type !== "break");
    const todayCompletedCount = todayBlocks.filter((block) => completedBlockIds.has(block.id)).length;
    const completionRateToday = todayBlocks.length > 0 ? todayCompletedCount / todayBlocks.length : 0;

    const checkinsToday = signals.filter((signal) => signal.type === "checkin" && signal.ts.slice(0, 10) === todayKey);
    const checkinCompliance = Math.min(1, checkinsToday.length / Math.max(1, todayBlocks.length));

    const dayCloseDoneToday = dailyLogSet.has(todayKey) ? 1 : 0;
    const driftMinutesToday = this.estimateDriftMinutes(
      signals.filter((signal) => signal.ts.slice(0, 10) === todayKey)
    );
    const driftScore = Math.max(0, 1 - driftMinutesToday / 60);

    const omniScore = Math.max(
      0,
      Math.min(
        100,
        Math.round(
          completionRateToday * 40 + checkinCompliance * 25 + dayCloseDoneToday * 15 + driftScore * 20
        )
      )
    );

    const focusSignals = signals.filter(
      (signal) => signal.type === "checkin" || signal.type === "focusSessionStart"
    );
    const focusHours = focusSignals.map((signal) => new Date(signal.ts).getUTCHours());
    const focusBeforeNoon = focusHours.filter((hour) => hour < 12).length;
    const focusAfterNight = focusHours.filter((hour) => hour >= 20).length;

    const focusRatings = signals
      .filter((signal) => signal.type === "checkin")
      .map((signal) => Number(signal.payload?.focus))
      .filter((value) => Number.isFinite(value));

    const averageFocus =
      focusRatings.length > 0
        ? focusRatings.reduce((sum, value) => sum + value, 0) / focusRatings.length
        : 0;

    const driftMinutesWeek = this.estimateDriftMinutes(signals);

    const badges = [
      { id: "7-day-streak", title: "7-Day Streak", unlocked: dayStates.every(Boolean) },
      { id: "early-bird", title: "Early Bird", unlocked: focusBeforeNoon >= 3 },
      { id: "deep-focus", title: "Deep Focus", unlocked: averageFocus >= 8 },
      { id: "night-owl", title: "Night Owl", unlocked: focusAfterNight >= 2 },
      { id: "consistency-king", title: "Consistency King", unlocked: daysCompletedThisWeek >= 5 },
      { id: "zero-drift", title: "Zero Drift", unlocked: driftMinutesWeek == 0 }
    ];

    const encouragement =
      omniScore >= 85
        ? "Strong control today. Keep this execution rhythm."
        : omniScore >= 70
          ? "Solid momentum. Tighten transitions to raise your score."
          : "You are rebuilding consistency. Start with one protected block.";

    return rewardsWeeklySchema.parse({
      omniScore,
      encouragement,
      daysCompletedThisWeek,
      dayStates,
      badges
    });
  }

  async claimWeekly(userId: string, date?: string): Promise<RewardsClaimResponseDTO> {
    const weekly = await this.getWeekly(userId, date);
    const message =
      weekly.daysCompletedThisWeek >= 3
        ? "Weekly reward claimed. Keep stacking focused days."
        : "Reward claimed. Build consistency to unlock higher tiers.";

    return rewardsClaimResponseSchema.parse({
      ok: true,
      message
    });
  }

  private collectCompletedBlockIds(
    blocks: BlockRow[],
    signals: SignalRow[],
    completedTasks: TaskRow[]
  ): Set<string> {
    const completedBlockIds = new Set<string>();

    for (const signal of signals) {
      if (signal.type !== "checkin" || !signal.related_block_id) {
        continue;
      }

      const done = signal.payload?.done === true;
      const progress = Number(signal.payload?.progress);
      if (done || (Number.isFinite(progress) && progress >= 100)) {
        completedBlockIds.add(signal.related_block_id);
      }
    }

    const completedTaskIds = new Set(completedTasks.map((task) => task.google_task_id));
    for (const block of blocks) {
      if (!block.google_task_id) continue;
      if (completedTaskIds.has(block.google_task_id)) {
        completedBlockIds.add(block.id);
      }
    }

    return completedBlockIds;
  }

  private estimateDriftMinutes(signals: SignalRow[]): number {
    let total = 0;

    for (const signal of signals) {
      if (signal.type === "drift") {
        const rawMinutes = Number(signal.payload?.minutes);
        total += Number.isFinite(rawMinutes) && rawMinutes > 0 ? rawMinutes : 5;
      }

      if (signal.type === "checkin") {
        const rawMinutes = Number(signal.payload?.driftMinutes);
        total += Number.isFinite(rawMinutes) && rawMinutes > 0 ? rawMinutes : 0;
      }
    }

    return Math.max(0, Math.round(total));
  }

  private getWeekBounds(targetDate: string) {
    const reference = new Date(`${targetDate}T12:00:00.000Z`);
    if (Number.isNaN(reference.valueOf())) {
      throw new Error("date must be YYYY-MM-DD");
    }

    const day = reference.getUTCDay();
    const mondayOffset = day === 0 ? -6 : 1 - day;

    const start = new Date(reference);
    start.setUTCDate(reference.getUTCDate() + mondayOffset);
    start.setUTCHours(0, 0, 0, 0);

    const endExclusive = new Date(start);
    endExclusive.setUTCDate(start.getUTCDate() + 7);

    const dayKeys: string[] = [];
    for (let i = 0; i < 7; i += 1) {
      const dayDate = new Date(start);
      dayDate.setUTCDate(start.getUTCDate() + i);
      dayKeys.push(dayDate.toISOString().slice(0, 10));
    }

    return {
      startDate: dayKeys[0],
      endDate: dayKeys[6],
      startAtIso: start.toISOString(),
      endExclusiveIso: endExclusive.toISOString(),
      dayKeys
    };
  }
}
