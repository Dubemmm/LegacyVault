;; LegacyVault - Multigenerational NFT Archive with Custom Schedules
;; A platform for creating time-locked NFTs that can be passed down through generations

(define-non-fungible-token legacy-nft uint)

;; Define schedule types
(define-constant SCHEDULE-TYPE-FIXED u1)  ;; Fixed dates
(define-constant SCHEDULE-TYPE-INTERVAL u2)  ;; Regular intervals

;; Data Variables
(define-map nft-data
    {nft-id: uint}
    {
        owner: principal,
        creator: principal,
        metadata-url: (string-utf8 256),
        creation-time: uint,
        current-stage: uint,
        is-public: bool,
        schedule-type: uint,
        interval-blocks: (optional uint),
        total-stages: uint
    }
)

(define-map stage-schedule
    {nft-id: uint, stage: uint}
    {
        unlock-height: uint,
        recipient: (optional principal)
    }
)

;; Counter for NFT IDs
(define-data-var next-nft-id uint u1)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NFT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STAGE (err u102))
(define-constant ERR-NOT-UNLOCKED (err u103))
(define-constant ERR-INVALID-SCHEDULE (err u104))
(define-constant ERR-SCHEDULE-EXISTS (err u105))

;; Helper function to validate schedule
(define-private (validate-schedule (schedule-type uint) 
                                 (interval-blocks (optional uint))
                                 (total-stages uint))
    (if (is-eq schedule-type SCHEDULE-TYPE-INTERVAL)
        (match interval-blocks
            interval (> interval u0)
            false)
        true)
)

;; Fixed get-next-unlock-height function with consistent return type
(define-private (get-next-unlock-height (nft-id uint) (current-stage uint))
    (let ((nft-info (unwrap! (map-get? nft-data {nft-id: nft-id})
                            ERR-NFT-NOT-FOUND)))
        (if (is-eq (get schedule-type nft-info) SCHEDULE-TYPE-INTERVAL)
            (match (get interval-blocks nft-info)
                interval (ok (+ block-height interval))
                ERR-INVALID-SCHEDULE)
            (match (map-get? stage-schedule {nft-id: nft-id, stage: (+ current-stage u1)})
                schedule (ok (get unlock-height schedule))
                ERR-INVALID-SCHEDULE)
        )
    )
)

;; Create NFT with interval-based schedule
(define-public (create-interval-nft 
    (metadata-url (string-utf8 256))
    (interval-blocks uint)
    (total-stages uint)
    (is-public bool))
    (let ((nft-id (var-get next-nft-id)))
        (asserts! (> interval-blocks u0) ERR-INVALID-SCHEDULE)
        (asserts! (> total-stages u0) ERR-INVALID-SCHEDULE)
        
        (try! (nft-mint? legacy-nft nft-id tx-sender))
        (map-set nft-data
            {nft-id: nft-id}
            {
                owner: tx-sender,
                creator: tx-sender,
                metadata-url: (unwrap-panic (as-max-len? metadata-url u256)),
                creation-time: block-height,
                current-stage: u0,
                is-public: is-public,
                schedule-type: SCHEDULE-TYPE-INTERVAL,
                interval-blocks: (some interval-blocks),
                total-stages: total-stages
            }
        )
        
        ;; Set up initial stage schedule
        (map-set stage-schedule
            {nft-id: nft-id, stage: u0}
            {
                unlock-height: (+ block-height interval-blocks),
                recipient: none
            }
        )
        
        (var-set next-nft-id (+ nft-id u1))
        (ok nft-id)
    )
)

;; Create NFT with fixed schedule
(define-public (create-fixed-schedule-nft 
    (metadata-url (string-utf8 256))
    (unlock-heights (list 10 uint))
    (is-public bool))
    (let ((nft-id (var-get next-nft-id))
          (total-stages (len unlock-heights)))
        
        (asserts! (> total-stages u0) ERR-INVALID-SCHEDULE)
        (try! (nft-mint? legacy-nft nft-id tx-sender))
        
        ;; Set up NFT data
        (map-set nft-data
            {nft-id: nft-id}
            {
                owner: tx-sender,
                creator: tx-sender,
                metadata-url: (unwrap-panic (as-max-len? metadata-url u256)),
                creation-time: block-height,
                current-stage: u0,
                is-public: is-public,
                schedule-type: SCHEDULE-TYPE-FIXED,
                interval-blocks: none,
                total-stages: total-stages
            }
        )
        
        ;; Set up initial stage schedules
        (try! (setup-fixed-schedules nft-id unlock-heights))
        
        (var-set next-nft-id (+ nft-id u1))
        (ok nft-id)
    )
)

;; Helper function to set up fixed schedules
(define-private (setup-fixed-schedules (nft-id uint) (unlock-heights (list 10 uint)))
    (let ((stage u0))
        (map-set stage-schedule
            {nft-id: nft-id, stage: stage}
            {
                unlock-height: (unwrap! (element-at unlock-heights stage) ERR-INVALID-SCHEDULE),
                recipient: none
            }
        )
        (ok true)
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
        (asserts! (< stage (get total-stages nft-info))
                 ERR-INVALID-STAGE)
        
        (match (map-get? stage-schedule {nft-id: nft-id, stage: stage})
            schedule (begin
                (map-set stage-schedule
                    {nft-id: nft-id, stage: stage}
                    (merge schedule {recipient: (some recipient)})
                )
                (ok true))
            ERR-INVALID-STAGE)
    )
)

;; Advance to next stage if conditions are met
(define-public (advance-stage (nft-id uint))
    (let (
        (nft-info (unwrap! (map-get? nft-data {nft-id: nft-id}) 
                          ERR-NFT-NOT-FOUND))
        (current-stage (get current-stage nft-info))
        (current-schedule (unwrap! (map-get? stage-schedule 
                                           {nft-id: nft-id, stage: current-stage})
                                 ERR-INVALID-STAGE))
    )
        (asserts! (< current-stage (get total-stages nft-info)) 
                 ERR-INVALID-STAGE)
        (asserts! (>= block-height (get unlock-height current-schedule))
                 ERR-NOT-UNLOCKED)
        
        (let (
            (next-stage (+ current-stage u1))
            (next-recipient (get recipient current-schedule))
        )
            (asserts! (is-some next-recipient) ERR-INVALID-STAGE)
            (try! (nft-transfer? legacy-nft 
                               nft-id
                               (get owner nft-info)
                               (unwrap! next-recipient ERR-INVALID-STAGE)))
            
            ;; Update NFT data
            (map-set nft-data
                {nft-id: nft-id}
                (merge nft-info {
                    owner: (unwrap! next-recipient ERR-INVALID-STAGE),
                    current-stage: next-stage
                })
            )
            
            ;; Set up next stage schedule for interval-based NFTs
            (if (is-eq (get schedule-type nft-info) SCHEDULE-TYPE-INTERVAL)
                (begin
                    (map-set stage-schedule
                        {nft-id: nft-id, stage: next-stage}
                        {
                            unlock-height: (+ block-height 
                                (unwrap! (get interval-blocks nft-info) ERR-INVALID-SCHEDULE)),
                            recipient: none
                        }
                    )
                    (ok next-stage))
                (ok next-stage))
        )
    )
)

;; Read-only functions

;; Get NFT information
(define-read-only (get-nft-info (nft-id uint))
    (map-get? nft-data {nft-id: nft-id})
)

;; Get stage schedule
(define-read-only (get-stage-schedule (nft-id uint) (stage uint))
    (map-get? stage-schedule {nft-id: nft-id, stage: stage})
)

;; Check if NFT is ready for next stage
(define-read-only (can-advance-stage? (nft-id uint))
    (let (
        (nft-info (unwrap! (map-get? nft-data {nft-id: nft-id}) 
                          ERR-NFT-NOT-FOUND))
        (current-stage (get current-stage nft-info))
        (current-schedule (unwrap! (map-get? stage-schedule 
                                           {nft-id: nft-id, stage: current-stage})
                                 ERR-INVALID-STAGE))
    )
        (ok (and
            (< current-stage (get total-stages nft-info))
            (>= block-height (get unlock-height current-schedule))
            (is-some (get recipient current-schedule))
        ))
    )
)

;; Get time until next unlock
(define-read-only (get-blocks-until-unlock (nft-id uint))
    (let (
        (nft-info (unwrap! (map-get? nft-data {nft-id: nft-id}) 
                          ERR-NFT-NOT-FOUND))
        (current-stage (get current-stage nft-info))
        (current-schedule (unwrap! (map-get? stage-schedule 
                                           {nft-id: nft-id, stage: current-stage})
                                 ERR-INVALID-STAGE))
    )
        (ok (- (get unlock-height current-schedule) block-height))
    )
)