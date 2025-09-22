;; child-development-tracking
;; Smart contract for tracking child development milestones and educational progress

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-exists (err u202))
(define-constant err-unauthorized (err u203))
(define-constant err-invalid-params (err u204))
(define-constant err-permission-denied (err u205))
(define-constant max-milestone-score u10)
(define-constant min-age-months u0)
(define-constant max-age-months u216) ;; 18 years

;; data vars
(define-data-var next-child-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var next-activity-id uint u1)
(define-data-var system-active bool true)

;; data maps
(define-map children
  { child-id: uint }
  {
    parent-wallet: principal,
    child-name: (string-ascii 50),
    birth-date: uint,
    age-months: uint,
    gender: (string-ascii 10),
    medical-notes: (string-ascii 300),
    emergency-contact: (string-ascii 100),
    registration-date: uint,
    active: bool
  }
)

(define-map authorized-caregivers
  { child-id: uint, caregiver: principal }
  {
    permission-level: (string-ascii 20),
    granted-by: principal,
    granted-date: uint,
    active: bool
  }
)

(define-map developmental-milestones
  { milestone-id: uint }
  {
    child-id: uint,
    milestone-category: (string-ascii 30),
    milestone-description: (string-ascii 200),
    achievement-date: uint,
    age-achieved-months: uint,
    achievement-score: uint,
    recorded-by: principal,
    verified: bool,
    notes: (string-ascii 250)
  }
)

(define-map educational-activities
  { activity-id: uint }
  {
    child-id: uint,
    activity-type: (string-ascii 40),
    activity-name: (string-ascii 100),
    start-date: uint,
    end-date: (optional uint),
    progress-level: uint,
    instructor: (string-ascii 50),
    outcomes: (string-ascii 200),
    active: bool
  }
)

(define-map health-records
  { child-id: uint, record-date: uint }
  {
    record-type: (string-ascii 30),
    provider-name: (string-ascii 100),
    height-cm: (optional uint),
    weight-kg: (optional uint),
    notes: (string-ascii 300),
    next-appointment: (optional uint),
    recorded-by: principal
  }
)

(define-map progress-reports
  { child-id: uint, report-date: uint }
  {
    reporting-period: (string-ascii 20),
    overall-progress: uint,
    physical-development: uint,
    cognitive-development: uint,
    social-development: uint,
    emotional-development: uint,
    strengths: (string-ascii 200),
    areas-for-improvement: (string-ascii 200),
    recommendations: (string-ascii 250),
    created-by: principal
  }
)

;; public functions

;; Register a new child in the tracking system
(define-public (register-child
  (child-name (string-ascii 50))
  (birth-date uint)
  (age-months uint)
  (gender (string-ascii 10))
  (medical-notes (string-ascii 300))
  (emergency-contact (string-ascii 100))
)
  (let (
    (child-id (var-get next-child-id))
  )
    (asserts! (var-get system-active) err-unauthorized)
    (asserts! (>= age-months min-age-months) err-invalid-params)
    (asserts! (<= age-months max-age-months) err-invalid-params)
    (asserts! (> (len child-name) u0) err-invalid-params)
    
    (map-set children
      { child-id: child-id }
      {
        parent-wallet: tx-sender,
        child-name: child-name,
        birth-date: birth-date,
        age-months: age-months,
        gender: gender,
        medical-notes: medical-notes,
        emergency-contact: emergency-contact,
        registration-date: burn-block-height,
        active: true
      }
    )
    
    (var-set next-child-id (+ child-id u1))
    (ok child-id)
  )
)

;; Record a developmental milestone
(define-public (record-milestone
  (child-id uint)
  (milestone-category (string-ascii 30))
  (milestone-description (string-ascii 200))
  (age-achieved-months uint)
  (achievement-score uint)
  (notes (string-ascii 250))
)
  (let (
    (milestone-id (var-get next-milestone-id))
    (child-data (unwrap! (map-get? children { child-id: child-id }) err-not-found))
  )
    (asserts! (or (is-eq tx-sender (get parent-wallet child-data))
                  (is-some (map-get? authorized-caregivers { child-id: child-id, caregiver: tx-sender })))
               err-unauthorized)
    (asserts! (get active child-data) err-unauthorized)
    (asserts! (<= achievement-score max-milestone-score) err-invalid-params)
    (asserts! (>= age-achieved-months min-age-months) err-invalid-params)
    
    (map-set developmental-milestones
      { milestone-id: milestone-id }
      {
        child-id: child-id,
        milestone-category: milestone-category,
        milestone-description: milestone-description,
        achievement-date: burn-block-height,
        age-achieved-months: age-achieved-months,
        achievement-score: achievement-score,
        recorded-by: tx-sender,
        verified: false,
        notes: notes
      }
    )
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

;; Add educational activity
(define-public (add-educational-activity
  (child-id uint)
  (activity-type (string-ascii 40))
  (activity-name (string-ascii 100))
  (progress-level uint)
  (instructor (string-ascii 50))
  (outcomes (string-ascii 200))
)
  (let (
    (activity-id (var-get next-activity-id))
    (child-data (unwrap! (map-get? children { child-id: child-id }) err-not-found))
  )
    (asserts! (or (is-eq tx-sender (get parent-wallet child-data))
                  (is-some (map-get? authorized-caregivers { child-id: child-id, caregiver: tx-sender })))
               err-unauthorized)
    (asserts! (get active child-data) err-unauthorized)
    (asserts! (<= progress-level u10) err-invalid-params)
    
    (map-set educational-activities
      { activity-id: activity-id }
      {
        child-id: child-id,
        activity-type: activity-type,
        activity-name: activity-name,
        start-date: burn-block-height,
        end-date: none,
        progress-level: progress-level,
        instructor: instructor,
        outcomes: outcomes,
        active: true
      }
    )
    
    (var-set next-activity-id (+ activity-id u1))
    (ok activity-id)
  )
)

;; Record health information
(define-public (record-health-data
  (child-id uint)
  (record-type (string-ascii 30))
  (provider-name (string-ascii 100))
  (height-cm (optional uint))
  (weight-kg (optional uint))
  (notes (string-ascii 300))
  (next-appointment (optional uint))
)
  (let (
    (child-data (unwrap! (map-get? children { child-id: child-id }) err-not-found))
    (record-date burn-block-height)
  )
    (asserts! (or (is-eq tx-sender (get parent-wallet child-data))
                  (is-some (map-get? authorized-caregivers { child-id: child-id, caregiver: tx-sender })))
               err-unauthorized)
    (asserts! (get active child-data) err-unauthorized)
    
    (map-set health-records
      { child-id: child-id, record-date: record-date }
      {
        record-type: record-type,
        provider-name: provider-name,
        height-cm: height-cm,
        weight-kg: weight-kg,
        notes: notes,
        next-appointment: next-appointment,
        recorded-by: tx-sender
      }
    )
    
    (ok record-date)
  )
)

;; Create progress report
(define-public (create-progress-report
  (child-id uint)
  (reporting-period (string-ascii 20))
  (overall-progress uint)
  (physical-development uint)
  (cognitive-development uint)
  (social-development uint)
  (emotional-development uint)
  (strengths (string-ascii 200))
  (areas-for-improvement (string-ascii 200))
  (recommendations (string-ascii 250))
)
  (let (
    (child-data (unwrap! (map-get? children { child-id: child-id }) err-not-found))
    (report-date burn-block-height)
  )
    (asserts! (or (is-eq tx-sender (get parent-wallet child-data))
                  (is-some (map-get? authorized-caregivers { child-id: child-id, caregiver: tx-sender })))
               err-unauthorized)
    (asserts! (get active child-data) err-unauthorized)
    (asserts! (<= overall-progress u10) err-invalid-params)
    (asserts! (<= physical-development u10) err-invalid-params)
    (asserts! (<= cognitive-development u10) err-invalid-params)
    (asserts! (<= social-development u10) err-invalid-params)
    (asserts! (<= emotional-development u10) err-invalid-params)
    
    (map-set progress-reports
      { child-id: child-id, report-date: report-date }
      {
        reporting-period: reporting-period,
        overall-progress: overall-progress,
        physical-development: physical-development,
        cognitive-development: cognitive-development,
        social-development: social-development,
        emotional-development: emotional-development,
        strengths: strengths,
        areas-for-improvement: areas-for-improvement,
        recommendations: recommendations,
        created-by: tx-sender
      }
    )
    
    (ok report-date)
  )
)

;; Authorize caregiver
(define-public (authorize-caregiver
  (child-id uint)
  (caregiver principal)
  (permission-level (string-ascii 20))
)
  (let (
    (child-data (unwrap! (map-get? children { child-id: child-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender (get parent-wallet child-data)) err-unauthorized)
    (asserts! (get active child-data) err-unauthorized)
    
    (map-set authorized-caregivers
      { child-id: child-id, caregiver: caregiver }
      {
        permission-level: permission-level,
        granted-by: tx-sender,
        granted-date: burn-block-height,
        active: true
      }
    )
    
    (ok true)
  )
)

;; Verify milestone (admin or parent only)
(define-public (verify-milestone
  (milestone-id uint)
  (verified bool)
)
  (let (
    (milestone-data (unwrap! (map-get? developmental-milestones { milestone-id: milestone-id }) err-not-found))
    (child-data (unwrap! (map-get? children { child-id: (get child-id milestone-data) }) err-not-found))
  )
    (asserts! (or (is-eq tx-sender contract-owner)
                  (is-eq tx-sender (get parent-wallet child-data)))
               err-unauthorized)
    
    (map-set developmental-milestones
      { milestone-id: milestone-id }
      (merge milestone-data { verified: verified })
    )
    
    (ok true)
  )
)

;; read only functions

;; Get child information
(define-read-only (get-child (child-id uint))
  (map-get? children { child-id: child-id })
)

;; Get milestone information
(define-read-only (get-milestone (milestone-id uint))
  (map-get? developmental-milestones { milestone-id: milestone-id })
)

;; Get educational activity
(define-read-only (get-educational-activity (activity-id uint))
  (map-get? educational-activities { activity-id: activity-id })
)

;; Get health record
(define-read-only (get-health-record (child-id uint) (record-date uint))
  (map-get? health-records { child-id: child-id, record-date: record-date })
)

;; Get progress report
(define-read-only (get-progress-report (child-id uint) (report-date uint))
  (map-get? progress-reports { child-id: child-id, report-date: report-date })
)

;; Get caregiver authorization
(define-read-only (get-caregiver-auth (child-id uint) (caregiver principal))
  (map-get? authorized-caregivers { child-id: child-id, caregiver: caregiver })
)

;; Get system statistics
(define-read-only (get-system-stats)
  {
    total-children: (- (var-get next-child-id) u1),
    total-milestones: (- (var-get next-milestone-id) u1),
    total-activities: (- (var-get next-activity-id) u1),
    system-active: (var-get system-active)
  }
)

;; private functions

;; Calculate developmental progress score
(define-private (calculate-progress-score (milestones-achieved uint) (expected-milestones uint))
  (if (is-eq expected-milestones u0)
    u0
    (let ((score (/ (* milestones-achieved u10) expected-milestones)))
      (if (<= score u10) score u10)
    )
  )
)

