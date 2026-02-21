import { Module } from "@nestjs/common";
import { GoogleModule } from "../google/google.module";
import { PlansModule } from "../plans/plans.module";
import { ProfileModule } from "../profile/profile.module";
import { AiController } from "./ai.controller";
import { AiService } from "./ai.service";

@Module({
  imports: [GoogleModule, PlansModule, ProfileModule],
  controllers: [AiController],
  providers: [AiService],
  exports: [AiService]
})
export class AiModule {}
