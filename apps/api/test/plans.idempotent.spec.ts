import { PlansService } from "../src/plans/plans.service";

type PlanRecord = {
  id: string;
  user_id: string;
  plan_date: string;
  top_outcomes: string[];
  shutdown_suggestion: string | null;
  risk_flags: string[];
};

type BlockRecord = {
  id: string;
  plan_id: string;
  user_id: string;
  start_at: string;
  end_at: string;
  type: "task" | "sticky" | "break";
  google_task_id: string | null;
  label: string;
  rationale: string;
  priority_score: number;
};

class FakeSupabaseAdmin {
  private readonly plans = new Map<string, PlanRecord>();
  private blocks: BlockRecord[] = [];
  private blockCounter = 1;

  from(table: string) {
    if (table === "plans") {
      return {
        upsert: (row: Omit<PlanRecord, "id">) => ({
          select: () => ({
            single: async () => {
              const key = `${row.user_id}:${row.plan_date}`;
              const existing = this.plans.get(key);
              const saved: PlanRecord = existing
                ? {
                    ...existing,
                    top_outcomes: row.top_outcomes,
                    shutdown_suggestion: row.shutdown_suggestion,
                    risk_flags: row.risk_flags
                  }
                : {
                    id: "22222222-2222-2222-2222-222222222222",
                    ...row
                  };
              this.plans.set(key, saved);
              return { data: saved, error: null };
            }
          })
        })
      };
    }

    if (table === "plan_blocks") {
      return {
        delete: () => {
          const filters: Record<string, string> = {};
          return {
            eq: (column: string, value: string) => {
              filters[column] = value;
              if (filters.plan_id && filters.user_id) {
                this.blocks = this.blocks.filter(
                  (block) => !(block.plan_id === filters.plan_id && block.user_id === filters.user_id)
                );
                return Promise.resolve({ error: null });
              }
              return {
                eq: (innerColumn: string, innerValue: string) => {
                  filters[innerColumn] = innerValue;
                  this.blocks = this.blocks.filter(
                    (block) =>
                      !(block.plan_id === filters.plan_id && block.user_id === filters.user_id)
                  );
                  return Promise.resolve({ error: null });
                }
              };
            }
          };
        },
        insert: (rows: Omit<BlockRecord, "id">[]) => ({
          select: async () => {
            const inserted = rows.map((row) => ({
              id: `33333333-3333-3333-3333-33333333333${this.blockCounter++}`,
              ...row
            }));
            this.blocks.push(...inserted);
            return { data: inserted, error: null };
          }
        })
      };
    }

    throw new Error(`Unsupported table: ${table}`);
  }

  getBlockCount() {
    return this.blocks.length;
  }
}

describe("PlansService.saveGeneratedPlan", () => {
  it("is idempotent per user/date and replaces blocks", async () => {
    const admin = new FakeSupabaseAdmin();
    const service = new PlansService({ admin } as any);

    const userId = "11111111-1111-1111-1111-111111111111";
    const date = "2026-02-21";

    const first = await service.saveGeneratedPlan(userId, date, {
      topOutcomes: ["A"],
      shutdownSuggestion: "Stop",
      riskFlags: ["Risk"],
      blocks: [
        {
          startAt: "2026-02-21T09:00:00.000Z",
          endAt: "2026-02-21T10:00:00.000Z",
          type: "task",
          googleTaskId: "task-1",
          label: "Task 1",
          rationale: "R1",
          priorityScore: 50
        }
      ]
    });

    expect(first.id).toBe("22222222-2222-2222-2222-222222222222");
    expect(admin.getBlockCount()).toBe(1);

    const second = await service.saveGeneratedPlan(userId, date, {
      topOutcomes: ["B"],
      shutdownSuggestion: "Stop again",
      riskFlags: ["Risk 2"],
      blocks: [
        {
          startAt: "2026-02-21T11:00:00.000Z",
          endAt: "2026-02-21T12:00:00.000Z",
          type: "task",
          googleTaskId: "task-2",
          label: "Task 2",
          rationale: "R2",
          priorityScore: 80
        }
      ]
    });

    expect(second.id).toBe(first.id);
    expect(admin.getBlockCount()).toBe(1);
    expect(second.blocks[0]?.label).toBe("Task 2");
  });
});
