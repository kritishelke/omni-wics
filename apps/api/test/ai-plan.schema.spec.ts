import { planSchema } from "@omni/shared";
import { AiService } from "../src/ai/ai.service";

describe("AiService.generatePlan", () => {
  it("returns a payload matching plan schema", async () => {
    const userId = "11111111-1111-1111-1111-111111111111";

    const googleService = {
      getCalendarEventsForDate: jest.fn().mockResolvedValue([]),
      getTasks: jest.fn().mockResolvedValue([
        { id: "task-1", title: "Write draft" },
        { id: "task-2", title: "Review PR" }
      ])
    };

    const plansService = {
      saveGeneratedPlan: jest.fn().mockImplementation(async (_uid: string, date: string, payload: any) => ({
        id: "22222222-2222-2222-2222-222222222222",
        userId,
        planDate: date,
        topOutcomes: payload.topOutcomes,
        shutdownSuggestion: payload.shutdownSuggestion,
        riskFlags: payload.riskFlags,
        blocks: payload.blocks.map((block: any, i: number) => ({
          ...block,
          id: `33333333-3333-3333-3333-33333333333${i}`
        }))
      }))
    };

    const profileService = {
      getProfile: jest.fn().mockResolvedValue({
        id: userId,
        coachMode: "balanced",
        checkinCadenceMinutes: 60,
        sleepTime: null,
        wakeTime: null,
        energyProfile: {},
        distractionProfile: {}
      })
    };

    const supabaseService = {
      admin: {}
    };

    const service = new AiService(
      googleService as any,
      plansService as any,
      profileService as any,
      supabaseService as any
    );

    const result = await service.generatePlan(userId, {
      date: "2026-02-21",
      energy: "med"
    });

    const parsed = planSchema.safeParse(result);
    expect(parsed.success).toBe(true);
  });
});
