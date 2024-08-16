use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{Script}

pub type ScriptHash =
  Hash<Blake2b_224, Script>

pub type JWTconsumerRedeemer {
  Sign
  Spend
}

// 0 is 'raw'
// 1 is 'signed'
pub type JWTconsumerDatum {
  state: Int
}