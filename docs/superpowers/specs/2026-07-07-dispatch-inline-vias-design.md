# Dispatch Inline Vias UI Redesign

**Date:** 2026-07-07
**Area:** `src/frontend/apps/dispatch-v2`
**Decision owner:** Peter

## Goal

Replace the current modal-based VIA management flow in dispatch with an inline
route-builder on the main booking form.

This is a **UI-only** redesign:

- No booking payload changes
- No backend or quote logic changes
- No validation rule changes
- No swap-logic changes
- No feature removal

The intent is to make VIA entry materially faster for dispatchers by removing the
extra modal step while keeping all current behavior.

## Current State

Today the booking form shows:

- Pickup address row
- Swap pickup/destination button between pickup and destination
- Destination address row
- A separate `Add VIA` button

Clicking `Add VIA` opens `AddAndEditVia.jsx`, where operators can:

- Add a new via
- Edit an existing via
- Reorder vias
- Save changes back to `bookingData.vias`

This creates an unnecessary context switch because route building happens in a
separate dialog instead of where the route is entered.

## Target UX

The booking form will expose route building inline as a vertical stack:

1. Pickup row
2. Zero or more via rows
3. Destination row
4. Inline add-row action below the route stack

Initial state shows only pickup and destination. No vias are shown until the user
adds one.

When the user clicks the add-row action:

- A new VIA row is inserted between pickup and destination
- The row is immediately editable inline
- Existing pickup/destination values are unaffected

## Non-Negotiable Behavior

These rules are fixed for this redesign:

- Pickup and destination remain **non-draggable**
- VIA rows remain **draggable and reorderable among themselves**
- Hovering a VIA row reveals a right-end remove (`X`) affordance
- Removing a VIA affects only that VIA row
- Swapping addresses continues to affect **only pickup and destination**
- VIA ordering is still represented by `viaSequence`
- Existing autocomplete/manual address entry behavior must remain available
- Quote, save, passenger-count checks, and all downstream logic must continue to
  consume the same `bookingData.vias` structure

## Visual Direction

The supplied reference is inspiration only, not a copy target.

The new UI should borrow these ideas:

- A single vertical route-builder block
- Clear distinction between pickup, via, and destination rows
- Inline add action directly under the route stack
- Swap control placed in the right-side gutter between pickup and destination

The implementation must remain visually consistent with the current Red Taxi
dispatch form language rather than cloning the reference literally.

## Interaction Design

### Pickup row

- Always visible
- Non-draggable
- Uses the existing pickup address and pickup postcode controls
- Remains required

### Destination row

- Always visible
- Non-draggable
- Uses the existing destination address and destination postcode controls
- Remains required

### VIA rows

- Render between pickup and destination
- Each VIA row shows address and postcode inline
- Each VIA row is editable in place
- Each VIA row is draggable
- Each VIA row exposes a hover-state remove control on desktop
- On touch/mobile, the remove control remains visible enough to stay usable

### Add-row action

- Lives directly below the route stack
- Replaces the current full-width `Add VIA` button behavior
- Appends a new blank VIA row at the end of the VIA list, which still places it
  between pickup and destination in the rendered route

### Swap action

- Stays visually located between pickup and destination in the right-side gutter
- Retains the existing logic exactly:
  - pickup address/postcode swap with destination address/postcode
  - VIA rows remain untouched

## Data Model

No data-model change is allowed.

The redesign continues to use:

- `bookingData.pickupAddress`
- `bookingData.pickupPostCode`
- `bookingData.destinationAddress`
- `bookingData.destinationPostCode`
- `bookingData.vias`

Each VIA item continues to use:

- `address`
- `postCode`
- `viaSequence`

Reordering vias must normalize `viaSequence` exactly as the current modal flow does.

## Technical Shape

### Main booking form

The inline route-builder will live in:

- `src/frontend/apps/dispatch-v2/src/components/BookingFormV2/BookingFormView.jsx`

This component will become responsible for rendering:

- pickup row
- via rows
- destination row
- inline add-row action
- swap control positioning

### State ownership

State should remain owned by the current booking flow in:

- `src/frontend/apps/dispatch-v2/src/pages/Booking.jsx`

That file should keep responsibility for:

- existing address slot wiring
- existing swap logic
- quote triggers
- booking validation
- submit behavior

Only minimal new handlers should be introduced there for:

- add via
- edit via field
- remove via
- reorder via

### Drag and drop

The implementation should reuse the existing drag/drop approach if it can support
VIA-only movement cleanly.

Preferred outcome:

- Reuse `Dragger` for VIA rows only
- Keep pickup and destination outside the draggable collection

If `Dragger` cannot support that structure without awkward coupling, a small
route-specific wrapper may be introduced, but it must still preserve the same VIA
array shape and reorder semantics.

### Existing modal

`AddAndEditVia.jsx` should no longer be the primary route-entry surface for the
booking flow after this change.

It can either:

- be removed from this booking path entirely, or
- remain temporarily unused if removing it would create unnecessary scope

The redesign must not keep a duplicate inline-plus-modal VIA editing flow for the
same form.

## Accessibility and Responsiveness

- Inputs and buttons must remain keyboard reachable
- Drag handles and remove controls must preserve usable focus styles
- The add-row action must have a clear text label
- Required fields must remain labeled
- The layout must work on desktop and mobile
- Mobile must not depend on hover-only interaction for destructive actions

## Testing

At minimum, update or add tests to cover:

- initial render shows pickup and destination without vias
- clicking add action inserts an inline via row
- inline via removal updates the rendered rows
- inline via reorder keeps pickup/destination fixed
- swap action still changes only pickup/destination

Manual verification must confirm:

- address entry still works
- postcode entry still works
- quote flow still works
- save/update flow still works
- passenger/via warning behavior still works

## Out of Scope

- Any backend changes
- Any quote algorithm changes
- Any booking validation redesign
- Any new routing logic
- Reversing the full route when swap is clicked
- New booking features beyond the inline VIA UI

## Recommended Execution Order

1. Replace the current address section with an inline route-builder layout
2. Add inline VIA create/edit/remove behavior using existing booking state
3. Reconnect drag/drop for VIA-only reordering
4. Remove the modal entry point from the main form
5. Update tests
6. Run dispatch-v2 verification
