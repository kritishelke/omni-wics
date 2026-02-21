import { Module } from "@nestjs/common";
import { AiModule } from "../ai/ai.module";
import { PlansModule } from "../plans/plans.module";
import { ProfileModule } from "../profile/profile.module";
import { SignalsController } from "./signals.controller";
import { SignalsService } from "./signals.service";

@Module({
  imports: [ProfileModule, AiModule, PlansModule],
  controllers: [SignalsController],
  providers: [SignalsService],
  exports: [SignalsService]
})
export class SignalsModule {}
