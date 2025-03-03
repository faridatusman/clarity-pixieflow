;; PixieFlow - Fractional ownership of creative assets with NFT metadata and royalties

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-asset (err u101))
(define-constant err-unauthorized (err u102))  
(define-constant err-insufficient-shares (err u103))
(define-constant err-invalid-royalty (err u104))
(define-constant err-zero-amount (err u105))
(define-constant err-zero-payment (err u106))
(define-constant err-invalid-recipient (err u107))
(define-constant err-asset-frozen (err u108))
(define-constant max-shares u1000000000) ;; 1 billion share limit

;; Data Variables
(define-data-var next-asset-id uint u0)

;; Maps
(define-map assets
    uint
    {
        creator: principal,
        total-shares: uint,
        revenue-balance: uint,
        name: (string-ascii 64),
        uri: (string-ascii 256),
        royalty-percent: uint,
        is-frozen: bool,
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

;; Enhanced Private Functions
(define-private (validate-transfer-params 
    (amount uint) 
    (payment uint) 
    (recipient principal)
    (asset-id uint)
  )
  (let
    ((asset (unwrap! (map-get? assets asset-id) err-invalid-asset)))
    (asserts! (not (get is-frozen asset)) err-asset-frozen)
    (asserts! (> amount u0) err-zero-amount)
    (asserts! (> payment u0) err-zero-payment)
    (asserts! (not (is-eq tx-sender recipient)) err-invalid-recipient)
    (ok true)
  )
)

;; New Revenue Distribution Function
(define-public (distribute-revenue (asset-id uint))
  (let
    (
      (asset (unwrap! (map-get? assets asset-id) err-invalid-asset))
      (revenue (get revenue-balance asset))
    )
    (asserts! (> revenue u0) err-zero-amount)
    (asserts! (is-eq tx-sender (get creator asset)) err-owner-only)
    
    ;; Reset revenue balance
    (map-set assets asset-id (merge asset {revenue-balance: u0}))
    
    (print {
      event: "revenue-distributed",
      asset-id: asset-id,
      amount: revenue,
      timestamp: block-height
    })
    (ok revenue)
  )
)

;; Enhanced Asset Creation
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
        (asserts! (> total-shares u0) err-zero-amount)
        (asserts! (<= total-shares max-shares) err-invalid-asset)
        (asserts! (<= royalty-percent u100) err-invalid-royalty)
        (map-set assets asset-id {
            creator: tx-sender,
            total-shares: total-shares,
            revenue-balance: u0,
            name: name,
            uri: uri,
            royalty-percent: royalty-percent,
            is-frozen: false,
            metadata: {
                description: description,
                image: image, 
                attributes: attributes
            }
        })
        (map-set shares {asset-id: asset-id, owner: tx-sender} total-shares)
        (var-set next-asset-id (+ asset-id u1))
        (print {
          event: "asset-created",
          asset-id: asset-id,
          creator: tx-sender,
          total-shares: total-shares
        })
        (ok asset-id)
    )
)

[Previous functions remain unchanged...]
