# CredVerse Protocol

CredVerse is an AI-driven DAO credit identity and governance protocol for the Stacks blockchain. It enables reputation-based lending, NFT identity, and DAO voting, all powered by on-chain credit scoring.

## Features
- **Credit Scoring:** Calculates user credit scores based on repayment, staking, NFT, and DAO participation.
- **Reputation-based Lending:** Uses credit scores to enable trustless lending and borrowing.
- **NFT Identity:** Mints NFTs to represent user credit identity.
- **DAO Governance:** Allows proposal creation, voting, and execution for protocol upgrades.

## Key Contract Components
- **CreditScore:** Tuple storing user credit metrics and last update block.
- **Config:** Tuple for score weighting configuration.
- **Proposal:** Tuple for DAO proposals.
- **Maps:**
  - `credit-scores`: Maps user principal to their credit score tuple.
  - `loan-history`: Tracks user loan history.
  - `score-nfts`: Tracks NFT minting status.
  - `proposals`: Stores DAO proposals.
  - `has-voted`: Tracks voting status per proposal/user.

## Main Functions
- `update-score`: Admin-only. Updates a user's credit score.
- `mint-score-nft`: Mints a credit score NFT for the caller.
- `get-user-score`: Read-only. Returns a user's credit score.
- `create-proposal`: Allows users to create governance proposals.
- `vote`: Allows users to vote on proposals.
- `execute-proposal`: Executes a proposal if it passes.

## Usage
1. **Deploy the contract** using Clarinet or the Stacks CLI.
2. **Admin** can update user scores via `update-score`.
3. **Users** can mint their score NFT and participate in DAO governance.


