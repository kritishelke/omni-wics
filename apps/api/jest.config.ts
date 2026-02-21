import type { Config } from "jest";

const config: Config = {
  preset: "ts-jest",
  testEnvironment: "node",
  setupFiles: ["<rootDir>/test/setup-env.ts"],
  roots: ["<rootDir>/test"],
  moduleNameMapper: {
    "^@omni/shared$": "<rootDir>/../../packages/shared/src/index.ts",
    "^@omni/shared/(.*)$": "<rootDir>/../../packages/shared/src/$1"
  }
};

export default config;
