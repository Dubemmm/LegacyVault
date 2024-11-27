;; LegacyVault - Multigenerational NFT Archive
;; A platform for creating time-locked NFTs that can be passed down through generations

(define-non-fungible-token legacy-nft uint)

;; Data Variables
(define-map nft-data
    {nft-id: uint}
    {
        owner: principal,
        creator: principal,
        metadata-url: (string-utf8 256),
        creation-time: uint,
        unlock-stages: (list 10 uint),
        current-stage: uint,
        is-public: bool
    }
)

(define-map stage-recipients
    {nft-id: uint, stage: uint}
    {recipient: principal}
)

;; Counter for NFT IDs
(define-data-var next-nft-id uint u1)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NFT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STAGE (err u102))
(define-constant ERR-NOT-UNLOCKED (err u103))

;; Public functions

;; Create a new time-locked NFT
(define-public (create-nft (metadata-url (string-utf8 256)) 
                         (unlock-stages (list 10 uint))
                         (is-public bool))
    (let ((nft-id (var-get next-nft-id)))
        (try! (nft-mint? legacy-nft nft-id tx-sender))
        (map-set nft-data
            {nft-id: nft-id}
            {
                owner: tx-sender,
                creator: tx-sender,
                metadata-url: metadata-url,
                creation-time: block-height,
                unlock-stages: unlock-stages,
                current-stage: u0,
                is-public: is-public
            }
        )
        (var-set next-nft-id (+ nft-id u1))
        (ok nft-id)
    )
)

;; Set recipient for a specific stage
(define-public (set-stage-recipient (nft-id uint) 
                                  (stage uint) 
                                  (recipient principal))
    (let ((nft-info (unwrap! (map-get? nft-data {nft-id: nft-id}) 
                            ERR-NFT-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get owner nft-info)) 
                 ERR-NOT-AUTHORIZED)
        (map-set stage-recipients
            {nft-id: nft-id, stage: stage}
            {recipient: recipient}
        )
        (ok true)
    )
)

;; Advance to next stage if conditions are met
(define-public (advance-stage (nft-id uint))
    (let (
        (nft-info (unwrap! (map-get? nft-data {nft-id: nft-id}) 
                          ERR-NFT-NOT-FOUND))
        (current-stage (get current-stage nft-info))
        (unlock-stages (get unlock-stages nft-info))
    )
        (asserts! (< current-stage (len unlock-stages)) ERR-INVALID-STAGE)
        (asserts! (>= block-height (unwrap! (element-at unlock-stages current-stage) 
                                          ERR-INVALID-STAGE))
                 ERR-NOT-UNLOCKED)
        
        (let ((next-stage (+ current-stage u1))
              (stage-recipient (unwrap! (map-get? stage-recipients 
                                                {nft-id: nft-id, stage: next-stage})
                                      ERR-INVALID-STAGE)))
            (try! (nft-transfer? legacy-nft nft-id
                               (get owner nft-info)
                               (get recipient stage-recipient)))
            (map-set nft-data
                {nft-id: nft-id}
                (merge nft-info {
                    owner: (get recipient stage-recipient),
                    current-stage: next-stage
                })
            )
            (ok next-stage)
        )
    )
)

;; Read-only functions

;; Get NFT information
(define-read-only (get-nft-info (nft-id uint))
    (map-get? nft-data {nft-id: nft-id})
)

;; Get stage recipient
(define-read-only (get-stage-recipient (nft-id uint) (stage uint))
    (map-get? stage-recipients {nft-id: nft-id, stage: stage})
)

;; Check if NFT is ready for next stage - Fixed version
(define-read-only (can-advance-stage? (nft-id uint))
    (let (
        (nft-info (unwrap! (map-get? nft-data {nft-id: nft-id}) 
                          ERR-NFT-NOT-FOUND))
        (current-stage (get current-stage nft-info))
        (unlock-stages (get unlock-stages nft-info))
    )
        (if (and
            (< current-stage (len unlock-stages))
            (>= block-height (unwrap! (element-at unlock-stages current-stage) 
                                    ERR-INVALID-STAGE)))
            (ok true)
            (ok false)
        )
    )
)