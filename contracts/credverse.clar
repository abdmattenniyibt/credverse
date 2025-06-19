;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CredVerse Protocol - AI-Driven DAO Credit Identity & Governance ;;
;; Reputation-based Lending, NFT Identity, and DAO Voting Layer     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; CreditScore, Config, and Proposal are represented as tuples in Clarity.

;; CreditScore: (tuple (repayment uint) (staking uint) (nft uint) (dao uint) (total uint) (last-updated uint))
;; Config: (tuple (repayment-weight uint) (staking-weight uint) (nft-weight uint) (dao-weight uint))
;; Proposal: (tuple (id uint) (creator principal) (type (string-ascii 20)) (params (string-ascii 200)) (votes-for uint) (votes-against uint) (executed bool))

(define-map credit-scores principal
  (tuple (repayment uint) (staking uint) (nft uint) (dao uint) (total uint) (last-updated uint))
)
(define-data-var config (tuple (repayment-weight uint) (staking-weight uint) (nft-weight uint) (dao-weight uint)) (tuple
  (repayment-weight u25)
  (staking-weight u25)
  (nft-weight u25)
  (dao-weight u25)))

(define-data-var admin principal tx-sender)
(define-data-var proposal-count uint u0)

(define-map loan-history principal (list 100 uint))
(define-map score-nfts principal bool)
(define-map proposals uint
  (tuple (id uint) (creator principal) (type (string-ascii 20)) (params (string-ascii 200)) (votes-for uint) (votes-against uint) (executed bool))
)
(define-map has-voted
  (tuple (proposal-id uint) (voter principal))
  bool
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Score Calculation Engine                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-private (calculate-total-score (score (tuple (repayment uint) (staking uint) (nft uint) (dao uint) (total uint) (last-updated uint))))
  (let (
    (cfg (var-get config))
    (r (* (get repayment score) (get repayment-weight cfg)))
    (s (* (get staking score) (get staking-weight cfg)))
    (n (* (get nft score) (get nft-weight cfg)))
    (d (* (get dao score) (get dao-weight cfg)))
  )
    (+ r (+ s (+ n d)))
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Score Updating & NFT Identity Minting   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-public (update-score (user principal) (repayment uint) (staking uint) (nft uint) (dao uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (let (
      (existing (default-to (tuple (repayment u0) (staking u0) (nft u0) (dao u0) (total u0) (last-updated stacks-block-height)) (map-get? credit-scores user)))
(updated (tuple
  (repayment (+ (get repayment existing) repayment))
  (staking (+ (get staking existing) staking))
  (nft (+ (get nft existing) nft))
  (dao (+ (get dao existing) dao))
  (total u0)
  (last-updated stacks-block-height)
))
      (new-total (calculate-total-score updated))
    )
      (map-set credit-scores user (merge updated { total: new-total }))
      (ok new-total)
    )
  )
)

(define-public (mint-score-nft)
  (begin
    (asserts! (not (default-to false (map-get? score-nfts tx-sender))) (err u409))
    (map-set score-nfts tx-sender true)
    (ok "Score NFT minted")
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read-only Queries                      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-read-only (get-user-score (user principal))
  (ok (map-get? credit-scores user))
)

(define-read-only (get-score-tier (user principal))
  (match (map-get? credit-scores user)
    score
      (let ((t (get total score)))
        (if (>= t u1000)
          (ok "Platinum")
          (if (>= t u750)
            (ok "Gold")
            (if (>= t u500)
              (ok "Silver")
              (ok "Bronze")))))
    (err u404))
)

(define-read-only (snapshot-score (user principal))
  (match (map-get? credit-scores user)
    score
      (ok (get total score))
    (err u404))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Admin Controls                         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-public (update-weights (repayment-weight uint) (staking-weight uint) (nft-weight uint) (dao-weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set config (tuple
      (repayment-weight repayment-weight)
      (staking-weight staking-weight)
      (nft-weight nft-weight)
      (dao-weight dao-weight)))
    (ok "Weights updated")
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok "Admin transferred")
  )
)

(define-public (reset-score (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (map-delete credit-scores user)
    (map-delete score-nfts user)
    (ok "Score reset")
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DAO Voting System                      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-public (create-proposal (type (string-ascii 20)) (params (string-ascii 200)))
  (let ((pid (var-get proposal-count)))
    (begin
      (map-set proposals pid (tuple
        (id pid)
        (creator tx-sender)
        (type type)
        (params params)
        (votes-for u0)
        (votes-against u0)
        (executed false)
      ))
      (var-set proposal-count (+ pid u1))
      (ok pid)
    )
  )
)

(define-public (vote (proposal-id uint) (support bool))
  (begin
    (asserts! (not (default-to false (map-get? has-voted (tuple (proposal-id proposal-id) (voter tx-sender))))) (err u401))
    (match (map-get? proposals proposal-id)
      proposal
        (begin
          (map-set has-voted (tuple (proposal-id proposal-id) (voter tx-sender)) true)
          (let (
            (score
              (match (map-get? credit-scores tx-sender)
                user-score (get total user-score)
                u0
              )
            )
          )
            (if support
              (map-set proposals proposal-id (merge proposal {votes-for: (+ (get votes-for proposal) score)}))
              (map-set proposals proposal-id (merge proposal {votes-against: (+ (get votes-against proposal) score)}))
            )
            (ok "Vote submitted")
          )
        )
      (err u404)
    )
  )
)

(define-public (execute-proposal (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
      (begin
        (asserts! (not (get executed proposal)) (err u410))
        (let ((for (get votes-for proposal)) (against (get votes-against proposal)))
          (if (> for against)
            (begin
              ;; NOTE: actual execution depends on parsing `params`
              ;; You can integrate parse-weight or parse-principal helpers here.
              (map-set proposals proposal-id (merge proposal {executed: true}))
              (ok "Proposal executed")
            )
            (err u405)
          )
        )
      )
    (err u404)
  )
)
