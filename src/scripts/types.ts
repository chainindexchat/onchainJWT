import { Data, Lucid } from "https://deno.land/x/lucid@0.10.7/mod.ts";

const JwtConsumerDatumSchema = Data.Object({
  state: Data.Integer(),
});

type JwtConsumerDatum = Data.Static<typeof JwtConsumerDatumSchema>;
export const JwtConsumerDatum = JwtConsumerDatumSchema as unknown as JwtConsumerDatum;

export function createJwtConsumerDatum(
  state: bigint,
  lucid: Lucid,
): string {

  const datum: JwtConsumerDatum = {
    state,
  };
  return Data.to(datum, JwtConsumerDatum);
}

const JwtConsumerRedeemerSchema = Data.Enum([
  Data.Literal("Sign"),
  Data.Literal("Spend"),
]);

type JwtConsumerRedeemer = Data.Static<typeof JwtConsumerRedeemerSchema>;
export const JwtConsumerRedeemer =
  JwtConsumerRedeemerSchema as unknown as JwtConsumerRedeemer;
