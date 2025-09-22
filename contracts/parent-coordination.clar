;; parent-coordination
;; Smart contract for managing parent participation in childcare cooperative duties

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-params (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant max-reliability-score u100)
(define-constant min-hours-per-week u8)
(define-constant max-hours-per-week u40)

;; data vars
(define-data-var next-parent-id uint u1)
(define-data-var next-duty-id uint u1)
(define-data-var total-registered-parents uint u0)
(define-data-var cooperative-active bool true)

;; data maps
(define-map parents 
  { parent-id: uint }
  {
    wallet: principal,
    name: (string-ascii 50),
    contact: (string-ascii 100),
    children-count: uint,
    availability-hours: uint,
    reliability-score: uint,
    total-hours-contributed: uint,
    registration-date: uint,
    active: bool
  }
)

(define-map parent-wallet-to-id
  { wallet: principal }
  { parent-id: uint }
)

(define-map duties
  { duty-id: uint }
  {
    assigned-parent: uint,
    duty-type: (string-ascii 30),
    scheduled-date: uint,
    start-time: uint,
    end-time: uint,
    children-assigned: uint,
    status: (string-ascii 20),
    completion-rating: (optional uint),
    notes: (string-ascii 200)
  }
)

(define-map parent-duty-history
  { parent-id: uint, duty-id: uint }
  {
    completed: bool,
    completion-date: uint,
    rating: uint,
    feedback: (string-ascii 200)
  }
)

(define-map weekly-schedules
  { parent-id: uint, week-start: uint }
  {
    available-hours: (list 7 uint),
    preferred-duties: (list 5 (string-ascii 30)),
    special-notes: (string-ascii 150)
  }
)

;; public functions

;; Register a new parent in the cooperative
(define-public (register-parent 
  (name (string-ascii 50))
  (contact (string-ascii 100))
  (children-count uint)
  (availability-hours uint)
)
  (let (
    (parent-id (var-get next-parent-id))
  )
    (asserts! (>= availability-hours min-hours-per-week) err-invalid-params)
    (asserts! (<= availability-hours max-hours-per-week) err-invalid-params)
    (asserts! (> children-count u0) err-invalid-params)
    (asserts! (is-none (map-get? parent-wallet-to-id { wallet: tx-sender })) err-already-exists)
    (asserts! (var-get cooperative-active) err-unauthorized)
    
    (map-set parents
      { parent-id: parent-id }
      {
        wallet: tx-sender,
        name: name,
        contact: contact,
        children-count: children-count,
        availability-hours: availability-hours,
        reliability-score: u100,
        total-hours-contributed: u0,
        registration-date: burn-block-height,
        active: true
      }
    )
    
    (map-set parent-wallet-to-id
      { wallet: tx-sender }
      { parent-id: parent-id }
    )
    
    (var-set next-parent-id (+ parent-id u1))
    (var-set total-registered-parents (+ (var-get total-registered-parents) u1))
    
    (ok parent-id)
  )
)

;; Assign duty to a parent
(define-public (assign-duty
  (parent-id uint)
  (duty-type (string-ascii 30))
  (scheduled-date uint)
  (start-time uint)
  (end-time uint)
  (children-assigned uint)
)
  (let (
    (duty-id (var-get next-duty-id))
    (parent-data (unwrap! (map-get? parents { parent-id: parent-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get active parent-data) err-unauthorized)
    (asserts! (< start-time end-time) err-invalid-params)
    (asserts! (> children-assigned u0) err-invalid-params)
    
    (map-set duties
      { duty-id: duty-id }
      {
        assigned-parent: parent-id,
        duty-type: duty-type,
        scheduled-date: scheduled-date,
        start-time: start-time,
        end-time: end-time,
        children-assigned: children-assigned,
        status: "scheduled",
        completion-rating: none,
        notes: ""
      }
    )
    
    (var-set next-duty-id (+ duty-id u1))
    (ok duty-id)
  )
)

;; Complete duty and update parent statistics
(define-public (complete-duty
  (duty-id uint)
  (completion-rating uint)
  (notes (string-ascii 200))
)
  (let (
    (duty-data (unwrap! (map-get? duties { duty-id: duty-id }) err-not-found))
    (parent-id (get assigned-parent duty-data))
    (parent-data (unwrap! (map-get? parents { parent-id: parent-id }) err-not-found))
    (hours-worked (- (get end-time duty-data) (get start-time duty-data)))
  )
    (asserts! (is-eq tx-sender (get wallet parent-data)) err-unauthorized)
    (asserts! (is-eq (get status duty-data) "scheduled") err-invalid-params)
    (asserts! (<= completion-rating u10) err-invalid-params)
    
    ;; Update duty status
    (map-set duties
      { duty-id: duty-id }
      (merge duty-data {
        status: "completed",
        completion-rating: (some completion-rating),
        notes: notes
      })
    )
    
    ;; Update parent history
    (map-set parent-duty-history
      { parent-id: parent-id, duty-id: duty-id }
      {
        completed: true,
        completion-date: burn-block-height,
        rating: completion-rating,
        feedback: notes
      }
    )
    
    ;; Update parent statistics
    (map-set parents
      { parent-id: parent-id }
      (merge parent-data {
        total-hours-contributed: (+ (get total-hours-contributed parent-data) hours-worked)
      })
    )
    
    (ok true)
  )
)

;; Set weekly availability schedule
(define-public (set-weekly-schedule
  (week-start uint)
  (available-hours (list 7 uint))
  (preferred-duties (list 5 (string-ascii 30)))
  (special-notes (string-ascii 150))
)
  (let (
    (parent-lookup (unwrap! (map-get? parent-wallet-to-id { wallet: tx-sender }) err-not-found))
    (parent-id (get parent-id parent-lookup))
  )
    (map-set weekly-schedules
      { parent-id: parent-id, week-start: week-start }
      {
        available-hours: available-hours,
        preferred-duties: preferred-duties,
        special-notes: special-notes
      }
    )
    
    (ok true)
  )
)

;; Update parent reliability score (admin only)
(define-public (update-reliability-score
  (parent-id uint)
  (new-score uint)
)
  (let (
    (parent-data (unwrap! (map-get? parents { parent-id: parent-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-score max-reliability-score) err-invalid-params)
    
    (map-set parents
      { parent-id: parent-id }
      (merge parent-data { reliability-score: new-score })
    )
    
    (ok true)
  )
)

;; Toggle cooperative active status (admin only)
(define-public (toggle-cooperative-status)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set cooperative-active (not (var-get cooperative-active)))
    (ok (var-get cooperative-active))
  )
)

;; read only functions

;; Get parent information by ID
(define-read-only (get-parent (parent-id uint))
  (map-get? parents { parent-id: parent-id })
)

;; Get parent ID by wallet address
(define-read-only (get-parent-id (wallet principal))
  (map-get? parent-wallet-to-id { wallet: wallet })
)

;; Get duty information
(define-read-only (get-duty (duty-id uint))
  (map-get? duties { duty-id: duty-id })
)

;; Get parent duty history
(define-read-only (get-duty-history (parent-id uint) (duty-id uint))
  (map-get? parent-duty-history { parent-id: parent-id, duty-id: duty-id })
)

;; Get weekly schedule
(define-read-only (get-weekly-schedule (parent-id uint) (week-start uint))
  (map-get? weekly-schedules { parent-id: parent-id, week-start: week-start })
)

;; Get cooperative statistics
(define-read-only (get-cooperative-stats)
  {
    total-parents: (var-get total-registered-parents),
    next-parent-id: (var-get next-parent-id),
    next-duty-id: (var-get next-duty-id),
    active: (var-get cooperative-active)
  }
)

;; private functions

;; Calculate reliability score based on completion history
(define-private (calculate-reliability-score (completed-duties uint) (total-duties uint))
  (if (is-eq total-duties u0)
    u100
    (/ (* completed-duties u100) total-duties)
  )
)

