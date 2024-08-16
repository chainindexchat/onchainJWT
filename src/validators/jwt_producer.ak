use aiken/dict
use aiken/list
use aiken/transaction/credential.{Address, VerificationKeyCredential, ScriptCredential}
use aiken/transaction.{Mint,Output,ScriptContext,Transaction,InlineDatum}
use aiken/transaction/value
use utils.{
  count_script_outputs, 
  count_script_inputs,
  max_jwt_tokens,
  count_tokens_by_policy,
  has_state_thread_token,
  limit_token_amounts,
  min_lovelace,
  valid_jwtc_script_output,
  ada_sent_to_address,
  correcty_burns_state_thread,
  expected_fees_lovelace
}
use types.{
  JWTconsumerDatum, 
}
validator(
  state_thread_policy: ByteArray,
  server_address: Address,
  price_lovelace: Int
) {
  fn jwt_producer(_redeemer: Void, ctx: ScriptContext) -> Bool {
    // ================================================================= Setup
    let ScriptContext { transaction, purpose } = ctx
    let Transaction { inputs, outputs, mint, extra_signatories, .. } = transaction

    let minted = value.minted_to_dict(mint)
    expect dict.size(minted) <= 3
    expect Mint(jwtp_policy) = purpose
    expect Some(jwt_assets) = dict.get(minted, jwtp_policy)
    let minted_jwt = dict.to_pairs(jwt_assets)

    // Map the inputs to their respective utxos 
    let input_utxos = list.map(inputs, fn(input){input.output})

    // Read server public key hash
    expect VerificationKeyCredential(server_pkh) =
         server_address.payment_credential

    // =================================================================Common assertions for mint & burn
    // * Tx Signed by Server only, no extra signatories
    expect list.length(extra_signatories) == 1
    expect list.has(extra_signatories, server_pkh)
    // * jwt consumer input exists and contains state thread token
    expect [jwtc_utxo_input] = list.filter(input_utxos, has_state_thread_token(state_thread_policy, _))
    expect ScriptCredential(jwtc_script_hash) = jwtc_utxo_input.address.payment_credential
    expect value.quantity_of(jwtc_utxo_input.value, state_thread_policy, jwtc_script_hash) == 1
    let num_token_policies = list.length(value.policies(value.without_lovelace(jwtc_utxo_input.value)))
    let num_input_jwt = count_tokens_by_policy(jwtp_policy, jwtc_utxo_input)
    // * Input jwt consumer datum
    expect InlineDatum(datum_data) = jwtc_utxo_input.datum
    expect input_datum: JWTconsumerDatum = datum_data
    let num_script_inputs = count_script_inputs(inputs)
    let num_script_outputs = count_script_outputs(outputs)
    
    or {
      // =============================================================== Mint the jwt token
      and {
        // =====================================================INPUTS
        // * JWTconsumer datum State value is 'raw'
        (input_datum.state == 0)?,
        (list.length(inputs) == 2)?,
        (num_script_inputs == 1)?,
        (num_token_policies == 1)?,
        (num_input_jwt == 0)?,        
        (list.length(minted_jwt) <= max_jwt_tokens)?,
        // check the user has paid for the jwt tokens with ADA
        (list.length(minted_jwt) == (value.lovelace_of(jwtc_utxo_input.value)-min_lovelace-expected_fees_lovelace) / price_lovelace)?,
        (list.all(minted_jwt, limit_token_amounts(1, _)))?,
        // * No additional tokens at JWTConsumer ScriptAddress
        // ====================================================OUTPUTS
        (num_script_outputs == 1)?,
        (valid_jwtc_script_output(outputs, jwtc_script_hash, state_thread_policy, jwtp_policy, list.length(minted_jwt)))?,
        (ada_sent_to_address(outputs, server_address, value.lovelace_of(jwtc_utxo_input.value)-min_lovelace+expected_fees_lovelace))?
      },
      // =============================================================== Burn the jwt token
      and {
        // =====================================================INPUTS
        // * JWTconsumer datum State value is 'signed'
        (input_datum.state == 1)?,
        (list.length(minted_jwt) == 1)?,
        list.all(minted_jwt, limit_token_amounts(-1, _))?,
        (list.length(inputs) == 2)?,
        (num_input_jwt <= max_jwt_tokens)?,
        (num_token_policies == 2)?,
        (num_script_inputs == 1)?,
        or {
          and {
            (num_input_jwt > 1)?,
            (num_script_outputs == 1)?,
            // expect the jwtc script output to have 1 less jwt token
            valid_jwtc_script_output(outputs, jwtc_script_hash, state_thread_policy, jwtp_policy, num_input_jwt-1)?,  
          },
          and {
            (num_input_jwt == 1)?,
            (num_script_outputs == 0)?,
            (ada_sent_to_address(outputs, server_address, min_lovelace))?,
            (correcty_burns_state_thread(minted,state_thread_policy,jwtc_script_hash))?
          }
        }
      }
    }
  }
}