# Dispatch Inline Vias Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dispatch VIA modal with an inline route-builder while keeping booking behavior and data shape unchanged.

**Architecture:** Keep `bookingData.vias` as the source of truth in `Booking.jsx`, add minimal via handlers there, and render/edit/reorder vias inline in `BookingFormView.jsx`. Reuse the current address inputs and drag/drop pattern so quoting, validation, swapping, and submission keep their existing logic.

**Tech Stack:** React, Vite, Redux, Vitest, Testing Library

## Global Constraints

- No booking payload changes
- No backend or quote logic changes
- No validation rule changes
- No swap-logic changes
- No feature removal
- Pickup and destination remain non-draggable
- VIA rows remain draggable and reorderable among themselves
- Swapping addresses continues to affect only pickup and destination

---

### Task 1: Cover Inline VIA Behavior with Tests

**Files:**
- Modify: `C:\RedTaxi\src\frontend\apps\dispatch-v2\src\components\BookingFormV2\BookingFormView.test.jsx`

**Interfaces:**
- Consumes: `CreateBookingFormView(props)`, `UpdateBookingFormView(props)`
- Produces: regression coverage for add/remove/swap-visible route-builder behavior

- [ ] **Step 1: Write failing tests for inline route-builder actions**
- [ ] **Step 2: Run the component test file and confirm the new tests fail for missing UI/actions**
- [ ] **Step 3: Keep the test names tied to user-visible behavior only**

### Task 2: Add Inline VIA State Handlers

**Files:**
- Modify: `C:\RedTaxi\src\frontend\apps\dispatch-v2\src\pages\Booking.jsx`

**Interfaces:**
- Consumes: `bookingData.vias`, `updateData(property, value)`
- Produces:
  - `addVia(): void`
  - `updateVia(index: number, patch: { address?: string; postCode?: string }): void`
  - `removeVia(index: number): void`
  - `reorderVias(nextVias: Array<{ address: string; postCode: string; viaSequence: number }>): void`

- [ ] **Step 1: Add minimal helper functions that mutate only the `vias` array shape already used today**
- [ ] **Step 2: Remove the modal-only VIA entry path from the booking form wiring**
- [ ] **Step 3: Pass the new handlers and any via row slots into the booking view props**

### Task 3: Replace the Modal UI with an Inline Route Builder

**Files:**
- Modify: `C:\RedTaxi\src\frontend\apps\dispatch-v2\src\components\BookingFormV2\BookingFormView.jsx`
- Modify: `C:\RedTaxi\src\frontend\apps\dispatch-v2\src\components\Dragger.jsx`
- Test: `C:\RedTaxi\src\frontend\apps\dispatch-v2\src\components\BookingFormV2\BookingFormView.test.jsx`

**Interfaces:**
- Consumes:
  - `addressSlots.pickupAddress`
  - `addressSlots.pickupPostCode`
  - `addressSlots.destinationAddress`
  - `addressSlots.destinationPostCode`
  - `addressSlots.vias`
  - `actions.addVia`
  - `actions.removeVia`
  - `actions.reorderVias`
  - `actions.toggleAddress`
- Produces: inline route-builder UI with fixed pickup/destination and draggable via rows

- [ ] **Step 1: Render pickup, via, and destination in one route-builder block**
- [ ] **Step 2: Place the swap button in the right-side gutter between pickup and destination**
- [ ] **Step 3: Add the inline add-row action below the route stack**
- [ ] **Step 4: Make VIA rows removable and draggable while leaving pickup/destination fixed**
- [ ] **Step 5: Keep the styling aligned with the current dispatch form rather than copying the reference literally**

### Task 4: Verify the Change End-to-End

**Files:**
- Modify: `C:\RedTaxi\src\frontend\apps\dispatch-v2\src\components\BookingFormV2\BookingFormView.test.jsx` if fixes are needed

**Interfaces:**
- Consumes: dispatch-v2 test/build commands
- Produces: fresh verification evidence for the UI-only redesign

- [ ] **Step 1: Run the updated component test file and confirm it passes**
- [ ] **Step 2: Run the dispatch-v2 build or equivalent project verification command**
- [ ] **Step 3: Report exact results, including any remaining gaps if a command fails**
