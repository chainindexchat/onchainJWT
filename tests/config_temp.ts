// By default, both the emulator and the testnet are enabled
// The tests will first run in the Lucid emulator and only if they pass, they will be run on the testnet
// To force the testnet even when emulator tests fail, turn USE_EMULATOR to false
export const USE_EMULATOR = true;
export const USE_TESTNET = true;

// The settings for testnet.
export const PRIVATE_KEY = "";
export const BLOCKFROST_API_KEY = "";
export const MAESTRO_API_KEY = "";
export const BLOCKFROST_URL = "https://cardano-preview.blockfrost.io/api/v0";
export const CONFIRMS_WAIT = 5;

export const SERVER_ADDR = ""
export const SERVER_PRIVATE_KEY = ""
export const JWT_PRICE = 500000n;
export const NUM_JWT_TOKENS = 2n;
export const EXPECTED_FEES = 306852n + 739203n + (724046n * NUM_JWT_TOKENS) + 808906n