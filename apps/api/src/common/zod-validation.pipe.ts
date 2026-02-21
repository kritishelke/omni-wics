import { ArgumentMetadata, BadRequestException, Injectable, PipeTransform } from "@nestjs/common";
import { ZodSchema } from "zod";

interface ZodDtoLike {
  schema?: ZodSchema;
}

@Injectable()
export class ZodValidationPipe implements PipeTransform {
  transform(value: unknown, metadata: ArgumentMetadata) {
    const metatype = metadata.metatype as ZodDtoLike | undefined;
    const schema = metatype?.schema;

    if (!schema) {
      return value;
    }

    const parsed = schema.safeParse(value);
    if (!parsed.success) {
      throw new BadRequestException({
        message: "Validation failed",
        issues: parsed.error.issues
      });
    }

    return parsed.data;
  }
}
