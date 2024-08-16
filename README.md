## OnChainJWT

OnChainJWT is an on chain JWT API authentication scheme. A client initiates a transaction at the first script address (JWTproducer), depositing ADA for NFTs that represent API credits. The NFTs are sent to a second script address (JWTconsumer) where they exist in one of three states: raw, signed, and expired. The APIserver redeems the JWTconsumer twice. In the first redemption, the APIserver mutates the NFT state to "signed", and writes an encrypted signed JWT into the NFT. This JWT can only be read by the client and can be used to authenticate requests to APIserver. The client decrypts and reads the JWT, requests the APIserver using the JWT. The second redemption occurs when the APIserver validates the request by checking if the on chain NFT state is "signed", at which point the APIserver returns to the client, and mutates the NFT state to "expired".
