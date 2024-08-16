
use aiken/dict
use aiken/list
use aiken/transaction.{ScriptContext, Transaction}
use aiken/transaction/value
use types.{
  JWTconsumerDatum, JWTconsumerRedeemer, Sign, Spend,
}
use aiken/transaction/credential.{ScriptCredential, Address, VerificationKeyCredential}

use utils.{
  count_script_inputs, 
  count_script_outputs,
  own_input,
  max_jwt_tokens,
  min_lovelace,
  count_tokens_by_policy,
  valid_jwtc_script_output,
  price_lovelace,
  ada_sent_to_address,
  correcty_burns_state_thread,
  expected_fees_lovelace
}

validator(
  state_thread_policy: ByteArray,
  jwtp_policy: ByteArray,
  server_address: Address,
) {
  fn jwt_consumer(
    datum: JWTconsumerDatum,
    redeemer: JWTconsumerRedeemer,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    let Transaction { inputs, outputs, mint, extra_signatories, .. } = transaction

    let minted = value.minted_to_dict(mint)
    expect dict.size(minted) <= 3

    // Read server public key hash
    expect VerificationKeyCredential(server_pkh) =
         server_address.payment_credential

    // =================================================================Common assertions for Sign & Spend
    // * Tx Signed by Server only, no extra signatories
    expect list.length(extra_signatories) == 1       
    expect list.has(extra_signatories, server_pkh)
    
    let jwtc_utxo_input = own_input(purpose, inputs).output
    expect ScriptCredential(jwtc_script_hash) = jwtc_utxo_input.address.payment_credential
    expect value.quantity_of(jwtc_utxo_input.value, state_thread_policy, jwtc_script_hash) == 1
    let num_token_policies = list.length(value.policies(value.without_lovelace(jwtc_utxo_input.value)))
    let num_input_jwt = count_tokens_by_policy(jwtp_policy, jwtc_utxo_input)
    let count_output_jwt = (value.lovelace_of(jwtc_utxo_input.value)-min_lovelace-expected_fees_lovelace) / price_lovelace
   
    let num_script_inputs = count_script_inputs(inputs)
    let num_script_outputs = count_script_outputs(outputs)
    expect (num_script_inputs == 1)?
    
    when redeemer is {
      Sign -> {
        and {
          // ============================================INPUT
          list.length(inputs) == 2,
          (num_token_policies == 1)?,
          (num_input_jwt == 0)?,        
          // * JWTconsumer datum State value is 'raw'
          (datum.state == 0)?,
          // ============================================OUTPUT
          (list.length(outputs) <= 3)?,
          (num_script_outputs == 1)?,
          (valid_jwtc_script_output(outputs, jwtc_script_hash, state_thread_policy, jwtp_policy, count_output_jwt))?,
          (count_output_jwt <= max_jwt_tokens)?,
          (count_output_jwt >= 1)?,
          (ada_sent_to_address(outputs, server_address, value.lovelace_of(jwtc_utxo_input.value)-min_lovelace+expected_fees_lovelace))?
        }
      }
      Spend -> {
        and {
          // * JWTconsumer datum State value is 'signed'
          (datum.state == 1)?,
          (list.length(inputs) <= 3)?,
          (num_token_policies == 2)?,
          (num_input_jwt <= max_jwt_tokens)?,
          or {
            and{
              (num_input_jwt > 1)?,
              (num_script_outputs == 1)?,
              (valid_jwtc_script_output(outputs, jwtc_script_hash, state_thread_policy, jwtp_policy, num_input_jwt-1))?,
            },
            and{
              (num_input_jwt == 1)?,
              (list.length(outputs) == 1)?,
              (num_script_outputs == 0)?,
              (ada_sent_to_address(outputs, server_address, min_lovelace))?,
              (correcty_burns_state_thread(minted,state_thread_policy,jwtc_script_hash))?
            }
          }
        }
      }

    }
  }
}
