;; PixieFlow - Fractional ownership of creative assets

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-asset (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-shares (err u103))

;; Data vars
(define-data-var next-asset-id uint u0)

;; Data maps
(define-map assets
    uint
    {
        creator: principal,
        total-shares: uint,
        revenue-balance: uint,
        name: (string-ascii 64),
        uri: (string-ascii 256)
    }
)

(define-map shares
    {asset-id: uint, owner: principal}
    uint
)

(define-map pending-votes
    uint 
    {
        proposal: (string-ascii 256),
        votes-for: uint,
        votes-against: uint,
        expires-at: uint
    }
)

;; Create new fractionalized asset
(define-public (create-asset (name (string-ascii 64)) (uri (string-ascii 256)) (total-shares uint))
    (let
        (
            (asset-id (var-get next-asset-id))
        )
        (map-set assets asset-id {
            creator: tx-sender,
            total-shares: total-shares,
            revenue-balance: u0,
            name: name,
            uri: uri
        })
        (map-set shares {asset-id: asset-id, owner: tx-sender} total-shares)
        (var-set next-asset-id (+ asset-id u1))
        (ok asset-id)
    )
)

;; Transfer shares between users
(define-public (transfer-shares (asset-id uint) (recipient principal) (amount uint))
    (let
        (
            (sender-shares (default-to u0 (map-get? shares {asset-id: asset-id, owner: tx-sender})))
        )
        (if (<= amount sender-shares)
            (begin
                (map-set shares {asset-id: asset-id, owner: tx-sender} 
                    (- sender-shares amount))
                (map-set shares {asset-id: asset-id, owner: recipient}
                    (+ (default-to u0 (map-get? shares {asset-id: asset-id, owner: recipient})) amount))
                (ok true)
            )
            err-insufficient-shares
        )
    )
)

;; Add revenue to asset
(define-public (add-revenue (asset-id uint) (amount uint))
    (let
        (
            (asset (unwrap! (map-get? assets asset-id) err-invalid-asset))
        )
        (if (is-eq tx-sender (get creator asset))
            (begin
                (map-set assets asset-id 
                    (merge asset {revenue-balance: (+ (get revenue-balance asset) amount)}))
                (ok true)
            )
            err-unauthorized
        )
    )
)

;; Claim share of revenue
(define-public (claim-revenue (asset-id uint))
    (let
        (
            (asset (unwrap! (map-get? assets asset-id) err-invalid-asset))
            (user-shares (default-to u0 (map-get? shares {asset-id: asset-id, owner: tx-sender})))
            (total-shares (get total-shares asset))
            (revenue-balance (get revenue-balance asset))
            (claim-amount (/ (* revenue-balance user-shares) total-shares))
        )
        (if (> claim-amount u0)
            (begin
                (map-set assets asset-id 
                    (merge asset {revenue-balance: (- revenue-balance claim-amount)}))
                (ok claim-amount)
            )
            (ok u0)
        )
    )
)

;; Create governance proposal
(define-public (create-proposal (asset-id uint) (proposal (string-ascii 256)) (duration uint))
    (let
        (
            (asset (unwrap! (map-get? assets asset-id) err-invalid-asset))
            (user-shares (default-to u0 (map-get? shares {asset-id: asset-id, owner: tx-sender})))
        )
        (if (> user-shares u0)
            (begin
                (map-set pending-votes asset-id {
                    proposal: proposal,
                    votes-for: u0,
                    votes-against: u0,
                    expires-at: (+ block-height duration)
                })
                (ok true)
            )
            err-unauthorized
        )
    )
)

;; Vote on proposal
(define-public (vote (asset-id uint) (vote-for bool))
    (let
        (
            (proposal (unwrap! (map-get? pending-votes asset-id) err-invalid-asset))
            (user-shares (default-to u0 (map-get? shares {asset-id: asset-id, owner: tx-sender})))
        )
        (if (> user-shares u0)
            (begin
                (map-set pending-votes asset-id
                    (if vote-for
                        (merge proposal {votes-for: (+ (get votes-for proposal) user-shares)})
                        (merge proposal {votes-against: (+ (get votes-against proposal) user-shares)})
                    ))
                (ok true)
            )
            err-unauthorized
        )
    )
)

;; Read-only functions
(define-read-only (get-asset-info (asset-id uint))
    (map-get? assets asset-id)
)

(define-read-only (get-shares (asset-id uint) (owner principal))
    (map-get? shares {asset-id: asset-id, owner: owner})
)

(define-read-only (get-proposal (asset-id uint))
    (map-get? pending-votes asset-id)
)