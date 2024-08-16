use aiken/list
use aiken/dict.{Dict}
use aiken/transaction.{InlineDatum,Input,Output,ScriptPurpose,Spend}
use aiken/transaction/credential.{Address,ScriptCredential}
use types.{JWTconsumerDatum}
use aiken/transaction/value.{PolicyId,AssetName,lovelace_of}
pub const price_lovelace = 500000
pub const max_jwt_tokens = 100
pub const min_lovelace = 2000000
pub const expected_fees_lovelace = 3303053
pub fn count_script_outputs(utxos: List<Output>) -> Int {
  list.count(utxos, is_script_output)
}
pub fn count_script_inputs(inputs: List<Input>) -> Int {
  list.count(
    inputs,
    fn(input) {
      when input.output.address.payment_credential is {
        ScriptCredential(_) -> True
        _ -> False
      }
    },
  )
}
pub fn own_input(purpose: ScriptPurpose, inputs: List<Input>) -> Input {
  expect Spend(output_reference) = purpose
  expect Some(found_input) =
    list.find(inputs, fn(input) { output_reference == input.output_reference })
  found_input
}
pub fn is_script_output(utxo: Output) -> Bool {
  when utxo.address.payment_credential is {
    ScriptCredential(_) -> True
    _ -> False
  }
}
pub fn utxo_is_script(script_hash: ByteArray, utxo: Output) -> Bool {
  when utxo.address.payment_credential is {
    ScriptCredential(hash) -> hash == script_hash
    _ -> False
  }
}
pub fn has_state_thread_token(policy_id: PolicyId, utxo: Output) -> Bool {
  when utxo.address.payment_credential is {
    ScriptCredential(hash) -> value.quantity_of(utxo.value, policy_id, hash) == 1
    _ -> False
  }
}
pub fn count_tokens_by_policy(policy: PolicyId, utxo: Output){
  utxo.value
    |> value.tokens(policy)
    |> dict.to_pairs()
    |> list.length()
}
pub fn limit_token_amounts(limit: Int, token: Pair<AssetName, Int>) -> Bool {
  let Pair(_, amount) = token
  amount == limit
}
pub fn valid_jwtc_script_output(
  outputs: List<Output>,
  jwtc_script_hash: ByteArray,
  state_thread_policy: PolicyId,
  jwtp_policy: PolicyId,
  expected_jwt_tokens: Int,

){
  // Optional jwt consumer script output, used in mint and burn when tokens > 1
  when list.find(outputs, utxo_is_script(jwtc_script_hash, _)) is {
    Some(utxo) -> {    
      expect InlineDatum(datum_data) = utxo.datum
      expect output_datum: JWTconsumerDatum = datum_data
      expect output_datum.state == 1
      // count and limit output policies
      expect (list.length(value.policies(value.without_lovelace(utxo.value))) == 2)?
      and {
        (has_state_thread_token(state_thread_policy, utxo))?,
        (count_tokens_by_policy(jwtp_policy, utxo) == expected_jwt_tokens)?,
        (lovelace_of(utxo.value) >= (min_lovelace))?,

      }
    }
    None -> False
  }
}
pub fn ada_sent_to_address(
  outputs: List<Output>,
  server_address: Address,
  lovelace_value: Int
){
  // * ADA sent to ServerAddress
  (list.any(outputs, fn(utxo) {
    and {
      utxo.address.payment_credential == server_address.payment_credential,
      value.lovelace_of(utxo.value) >= lovelace_value
    }
  }))?
}
pub fn correcty_burns_state_thread(
  minted: Dict<PolicyId, Dict<AssetName, Int>>,
  state_thread_policy: ByteArray,
  jwtc_script_hash: ByteArray
){
  when dict.get(minted, state_thread_policy) is {
    Some(state_thread_assets) -> {
      expect [Pair(asset_name, amount)] = dict.to_pairs(state_thread_assets)
      and {
        (asset_name == jwtc_script_hash)?,
        (amount == -1)?
      }
    }
    None -> (False)?
  }
}