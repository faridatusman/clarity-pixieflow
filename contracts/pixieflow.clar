;; PixieFlow - Fractional ownership of creative assets with NFT metadata and royalties

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-asset (err u101))
(define-constant err-unauthorized (err u102))  
(define-constant err-insufficient-shares (err u103))
(define-constant err-invalid-royalty (err u104))

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
        uri: (string-ascii 256),
        royalty-percent: uint,
        metadata: {
          description: (string-ascii 256),
          image: (string-ascii 256),
          attributes: (list 10 {
            trait: (string-ascii 32),
            value: (string-ascii 32)
          })
        }
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

(define-map royalty-payments
    uint
    {
        total-paid: uint,
        last-paid: uint
    }
)

;; Create new fractionalized asset with metadata
(define-public (create-asset 
    (name (string-ascii 64)) 
    (uri (string-ascii 256))
    (total-shares uint)
    (royalty-percent uint)
    (description (string-ascii 256))
    (image (string-ascii 256))
    (attributes (list 10 {trait: (string-ascii 32), value: (string-ascii 32)})))
    (let
        (
            (asset-id (var-get next-asset-id))
        )
        (asserts! (<= royalty-percent u100) err-invalid-royalty)
        (map-set assets asset-id {
            creator: tx-sender,
            total-shares: total-shares,
            revenue-balance: u0,
            name: name,
            uri: uri,
            royalty-percent: royalty-percent,
            metadata: {
                description: description,
                image: image, 
                attributes: attributes
            }
        })
        (map-set shares {asset-id: asset-id, owner: tx-sender} total-shares)
        (var-set next-asset-id (+ asset-id u1))
        (ok asset-id)
    )
)

;; Transfer shares between users with royalty payment
(define-public (transfer-shares (asset-id uint) (recipient principal) (amount uint) (payment uint))
    (let
        (
            (sender-shares (default-to u0 (map-get? shares {asset-id: asset-id, owner: tx-sender})))
            (asset (unwrap! (map-get? assets asset-id) err-invalid-asset))
            (royalty-amount (/ (* payment (get royalty-percent asset)) u100))
        )
        (if (<= amount sender-shares)
            (begin
                (map-set shares {asset-id: asset-id, owner: tx-sender} 
                    (- sender-shares amount))
                (map-set shares {asset-id: asset-id, owner: recipient}
                    (+ (default-to u0 (map-get? shares {asset-id: asset-id, owner: recipient})) amount))
                
                ;; Process royalty payment
                (map-set royalty-payments asset-id {
                    total-paid: (+ (default-to u0 (get total-paid (map-get? royalty-payments asset-id))) royalty-amount),
                    last-paid: block-height
                })
                (map-set assets asset-id 
                    (merge asset {revenue-balance: (+ (get revenue-balance asset) royalty-amount)}))
                
                (ok true)
            )
            err-insufficient-shares
        )
    )
)

;; Rest of contract functions remain unchanged...

;; New read-only functions for metadata and royalties
(define-read-only (get-metadata (asset-id uint))
    (get metadata (unwrap! (map-get? assets asset-id) err-invalid-asset))
)

(define-read-only (get-royalty-info (asset-id uint))
    (let
        (
            (asset (unwrap! (map-get? assets asset-id) err-invalid-asset))
            (payments (default-to {total-paid: u0, last-paid: u0} 
                (map-get? royalty-payments asset-id)))
        )
        (ok {
            royalty-percent: (get royalty-percent asset),
            total-paid: (get total-paid payments),
            last-paid: (get last-paid payments)
        })
    )
)
