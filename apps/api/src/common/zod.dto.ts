import { ZodSchema } from "zod";

export function createZodDto<TSchema extends ZodSchema>(schema: TSchema) {
  class AugmentedZodDto {
    public static schema = schema;
  }

  return AugmentedZodDto as unknown as {
    new (): ReturnType<TSchema["parse"]>;
    schema: TSchema;
  };
}
