use aiken/dict
use aiken/list
use aiken/transaction.{InlineDatum, Output, ScriptContext, Transaction} as tx
use aiken/transaction/value.{lovelace_of,PolicyId}
use types.{JWTconsumerDatum}
use utils.{
  count_script_outputs,
  count_script_inputs,
  min_lovelace,
  price_lovelace,
  utxo_is_script,
  has_state_thread_token,
  expected_fees_lovelace
}

validator {
  fn state_thread(_redeemer: Void, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    expect tx.Mint(state_thread_policy) = purpose

    let Transaction { inputs, outputs, mint, .. } = transaction
    expect [Pair(asset_name, amount)] =
      mint
        |> value.from_minted_value
        |> value.tokens(state_thread_policy)
        |> dict.to_pairs()
    
    let num_script_inputs = count_script_inputs(inputs)
    let num_script_outputs = count_script_outputs(outputs)
    
    or {
      and {
        amount == 1,
        (num_script_inputs == 0)?,
        (num_script_outputs == 1)?,
        valid_jwtc_script_output(outputs, asset_name, state_thread_policy)?,
        True
      },
      and {
       (amount == -1)?,
       (num_script_outputs == 0)?
      }
    }
  }
}

fn valid_jwtc_script_output(outputs: List<Output>, jwtc_script_hash: ByteArray, state_thread_policy: PolicyId){
  // Optional jwt consumer script output, used in mint but not burn
  when list.find(outputs, utxo_is_script(jwtc_script_hash, _)) is {
    Some(utxo) -> { 
      expect InlineDatum(datum_data) = utxo.datum
      expect output_datum: JWTconsumerDatum = datum_data
      expect output_datum.state == 0
      // count and limit output policies
      expect (list.length(value.flatten(value.without_lovelace(utxo.value))) == 1)?
      and {
        has_state_thread_token(state_thread_policy, utxo), 
        lovelace_of(utxo.value) >= (min_lovelace + price_lovelace + expected_fees_lovelace),
      }
    }
    None -> False
  }
}
