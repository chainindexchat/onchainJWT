import {
  Lucid,
  Constr,
  MintingPolicy,
  SpendingValidator,
  UTxO,
  Data,
  fromText,
} from "https://deno.land/x/lucid@0.10.7/mod.ts";
import {
  awaitTxConfirms,
  decodeBase64,
  filterUTXOsByTxHash,
  FIXED_MIN_ADA,
  getFormattedTxDetails,
  getWalletBalanceLovelace,
  setupMintingPolicy,
  setupValidator,
} from "../../tests/utils.ts";
import { createJwtConsumerDatum, JwtConsumerRedeemer } from "./types.ts";
import blueprint from "../plutus.json" with { type: "json" };
import {
  failTest,
  failTests,
  passAllTests,
  passTest,
  submitSolutionRecord,
} from "../../tests/test_utils.ts";


export type Validators = {
  jwtConsumer: SpendingValidator;
  jwtProducer: MintingPolicy;
  stateThread: MintingPolicy;
};
export type GameData = {
  validators: Validators;
};
export type TestData = void;
export const JWT_PRICE = 500000n;
export const NUM_JWT_TOKENS = 2n;
export const EXPECTED_FEES = 306852n + 739203n + (724046n * NUM_JWT_TOKENS) + 808906n
function readValidators(lucid: Lucid, ownAddress: string): Validators {

  const stateThread = setupMintingPolicy(
    lucid,
    blueprint,
    "state_thread.state_thread",
  );


  const serverAddrBytes = new Constr(0, [
    new Constr(0, [lucid.utils.getAddressDetails(ownAddress).paymentCredential.hash]),
    // TODO add staking credential to server address
    // new Constr(0, [lucid.utils.getAddressDetails(SERVER_ADDR).stakeCredential.hash]),
  ]
  );
  console.log("serverAddrBytes", serverAddrBytes)
  console.log("ownAddress", ownAddress);
  console.log("lucid.utils.getAddressDetails(ownAddress).paymentCredential.hash", lucid.utils.getAddressDetails(ownAddress).paymentCredential.hash);
  const jwtProducer = setupMintingPolicy(
    lucid,
    blueprint,
    "jwt_producer.jwt_producer",
    [
      stateThread.policyId,
      serverAddrBytes,
      JWT_PRICE
    ]
  );
  const jwtConsumer = setupValidator(lucid, blueprint, "jwt_consumer.jwt_consumer", [
    stateThread.policyId,
    jwtProducer.policyId,
    serverAddrBytes,
  ]);

  return {
    stateThread,
    jwtProducer,
    jwtConsumer,
  };
}

export async function setup(lucid: Lucid) {
  console.log(`=== SETUP IN PROGRESS ===`);

  // TODO setup script environment with separate addresses for client & server
  const ownAddress = "addr_test1vzeahxrjjfxmg862fzz7xk3cqt09cwjn0lp9h5qfn4p2sssjg53fm"
  // const ownAddress = await lucid.wallet.address();

  const validators = readValidators(lucid, ownAddress);

  // const jwtProducerScriptHash = lucid.utils.validatorToScriptHash(
  //   validators.jwtProducer.validator,
  // );
  const jwtConsumerScriptHash = lucid.utils.validatorToScriptHash(
    validators.jwtConsumer.validator,
  );
  const validationAsset =
    `${validators.stateThread.policyId}${jwtConsumerScriptHash}`;
  console.log("validators.jwtProducer.policyId", validators.jwtProducer.policyId);
  console.log("jwtConsumerScriptHash", jwtConsumerScriptHash);
  console.log("validators.jwtConsumer.address", validators.jwtConsumer.address);
  console.log("validators.stateThread.policyId", validators.stateThread.policyId);
  const createRawJwtconsumer = await lucid
    .newTx()
    .attachMintingPolicy(validators.stateThread.policy)
    .mintAssets(
      { [validationAsset]: BigInt(1) },
      Data.void(),
    )
    .payToContract(validators.jwtConsumer.address, {
      inline: createJwtConsumerDatum(
        0n,
        lucid,
      ),
    }, {
      [validationAsset]: BigInt(1),
      // TODO: add fees to the input lovelace
      lovelace: FIXED_MIN_ADA + (JWT_PRICE * NUM_JWT_TOKENS) + EXPECTED_FEES
    })
    .addSigner(ownAddress)
    .complete();


  const signedCreateRawJwtConsumerTx = await createRawJwtconsumer.sign().complete();
  const submittedCreateRawJwtConsumerTx = await signedCreateRawJwtConsumerTx.submit();
  console.log(
    `Transaction creating jwtConsumer with a validation token was submitted${getFormattedTxDetails(submittedCreateRawJwtConsumerTx, lucid)
    }`,
  );
  await awaitTxConfirms(lucid, submittedCreateRawJwtConsumerTx);

  const rawJwtConsumerUtxo = filterUTXOsByTxHash(
    await lucid.utxosAt(validators!.jwtConsumer.address),
    submittedCreateRawJwtConsumerTx,
  );
  console.log("jwtConsumerUtxo", rawJwtConsumerUtxo)

  const createSignedJwtConsumerTx = await lucid
    .newTx()
    .collectFrom(rawJwtConsumerUtxo, Data.to("Sign", JwtConsumerRedeemer))
    .attachMintingPolicy(validators.jwtProducer.policy)
    .mintAssets({
      [`${validators.jwtProducer.policyId}${fromText("jwt1")}`]: BigInt(1),
      [`${validators.jwtProducer.policyId}${fromText("jwt2")}`]: BigInt(1),
    },
      Data.void(),
    )
    .attachSpendingValidator(validators.jwtConsumer.validator)
    .payToContract(validators.jwtConsumer.address, {
      inline: createJwtConsumerDatum(
        1n,
        lucid,
      ),
    }, {
      lovelace: FIXED_MIN_ADA,
      [validationAsset]: BigInt(1),
      [`${validators.jwtProducer.policyId}${fromText("jwt1")}`]: BigInt(1),
      [`${validators.jwtProducer.policyId}${fromText("jwt2")}`]: BigInt(1),
    })
    .addSigner(ownAddress)
    .payToAddress(ownAddress, { lovelace: (JWT_PRICE * NUM_JWT_TOKENS) + EXPECTED_FEES }, Data.void())
    .complete();

  const createSignedSignedJwtConsumerTx = await createSignedJwtConsumerTx.sign().complete();
  const submittedCreateSignedJwtConsumerTx = await createSignedSignedJwtConsumerTx.submit();

  console.log(
    `Transaction creating signedJwtConsumer with a validation token was submitted${getFormattedTxDetails(submittedCreateSignedJwtConsumerTx, lucid)
    }`,
  );
  await awaitTxConfirms(lucid, submittedCreateSignedJwtConsumerTx);

  const signedJwtConsumerUtxo = filterUTXOsByTxHash(
    await lucid.utxosAt(validators!.jwtConsumer.address),
    submittedCreateSignedJwtConsumerTx,
  );




  const createSpendJwtConsumerTx = await lucid
    .newTx()
    .collectFrom(signedJwtConsumerUtxo, Data.to("Spend", JwtConsumerRedeemer))
    .attachMintingPolicy(validators.jwtProducer.policy)
    .mintAssets({
      [`${validators.jwtProducer.policyId}${fromText("jwt2")}`]: BigInt(-1),
    },
      Data.void(),
    )
    .attachSpendingValidator(validators.jwtConsumer.validator)
    .payToContract(validators.jwtConsumer.address, {
      inline: createJwtConsumerDatum(
        1n,
        lucid,
      ),
    }, {
      lovelace: FIXED_MIN_ADA,
      [validationAsset]: BigInt(1),
      [`${validators.jwtProducer.policyId}${fromText("jwt1")}`]: BigInt(1),
    })
    .addSigner(ownAddress)
    .complete();


  const createSignedSpendJwtConsumerTx = await createSpendJwtConsumerTx.sign().complete();
  const submittedCreateSpendJwtConsumerTx = await createSignedSpendJwtConsumerTx.submit();
  console.log(
    `Transaction creating spendJtConsumer with a validation token was submitted${getFormattedTxDetails(submittedCreateSpendJwtConsumerTx, lucid)
    }`,
  );
  await awaitTxConfirms(lucid, submittedCreateSpendJwtConsumerTx);

  const spendJwtConsumerUtxo = filterUTXOsByTxHash(
    await lucid.utxosAt(validators!.jwtConsumer.address),
    submittedCreateSpendJwtConsumerTx,
  );
  console.log("spendJwtConsumerUtxo", spendJwtConsumerUtxo)







  const createSpend2JwtConsumerTx = await lucid
    .newTx()
    .collectFrom(spendJwtConsumerUtxo, Data.to("Spend", JwtConsumerRedeemer))
    .attachMintingPolicy(validators.jwtProducer.policy)
    .mintAssets({
      [`${validators.jwtProducer.policyId}${fromText("jwt1")}`]: BigInt(-1),
    },
      Data.void(),
    )
    .attachMintingPolicy(validators.stateThread.policy)
    .mintAssets(
      { [validationAsset]: BigInt(-1) },
      Data.void(),
    )
    .attachSpendingValidator(validators.jwtConsumer.validator)
    .addSigner(ownAddress)
    .complete();


  const createSignedSpend2JwtConsumerTx = await createSpend2JwtConsumerTx.sign().complete();
  const submittedCreateSpend2JwtConsumerTx = await createSignedSpend2JwtConsumerTx.submit();
  console.log(
    `Transaction creating spend2JwtConsumer with a validation token was submitted${getFormattedTxDetails(submittedCreateSpend2JwtConsumerTx, lucid)
    }`,
  );
  await awaitTxConfirms(lucid, submittedCreateSpend2JwtConsumerTx);

  const spend2JwtConsumerUtxo = filterUTXOsByTxHash(
    await lucid.utxosAt(validators!.jwtConsumer.address),
    submittedCreateSpend2JwtConsumerTx,
  );
  console.log("spend2JwtConsumerUtxo", spend2JwtConsumerUtxo)

  console.log(`=== SETUP WAS SUCCESSFUL ===`);

  return {
    validators,
  };
}

export async function test(
  lucid: Lucid,
  // gameData: GameData,
  _testData: TestData,
): Promise<boolean> {
  let passed = true;
  console.log("================TESTS==================");

  // const endBalance = await getWalletBalanceLovelace(lucid);
  if (true) {
    // if (endBalance < gameData.originalBalance) {
    //   failTest(
    //     "TEST 1 FAILED -- you spent more ADA than you obtained from the exploit",
    //   );
    //   passed = false;
    // } else {
    //   passTest("TEST 1 PASSED", lucid);
    // }

    // const treasuryUtxos = filterUTXOsByTxHash(
    //   await lucid.utxosAt(gameData.validators.treasuryAddress),
    //   gameData.treasuryUTxO.txHash,
    // );
    // if (treasuryUtxos.length != 0) {
    //   failTest("TEST 2 FAILED -- the treasury UTxO was not spent");
    //   passed = false;
    // } else {
    //   passTest("TEST 2 PASSED", lucid);
    // }

    // if (passed) {
    //   await submitSolutionRecord(lucid, 9n);

    //   const encodedBlogURL =
    //     "aHR0cHM6Ly9tZWRpdW0uY29tL0B2YWN1dW1sYWJzX2F1ZGl0aW5nL2NhcmRhbm8tY3RmLWhpbnRzLWFuZC1zb2x1dGlvbnMtZTM5OTFjZTZhOTQ0";

    //   passAllTests(
    //     "\nCongratulations on the successful completion of the Level 09: Multisig Treasury v3\n" +
    //     `You can compare your solution with ours by reading this blog post: ${decodeBase64(encodedBlogURL)
    //     }` + "\nGood luck with the next level.",
    //     lucid,
    //   );

    return true;
  } else {
    failTests();
    return false;
  }
}
