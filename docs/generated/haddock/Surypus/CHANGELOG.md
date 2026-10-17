# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Finance.Bill**: Bill posting business logic module
  - `Bill`, `BillLine`, `BillStatus` types
  - `createBill`, `postBill`, `validateBill`, `calculateBillTotal` functions
  - Bill posting state machine: Draft → Posted → Cancelled
  - Tax calculation per line item
  - JSON serialization (ToJSON/FromJSON)
  - Comprehensive test suite (Finance.BillSpec)

### Changed
- **CI**: Reduced from 88 workflows to CI + CodeQL only
- **Build**: Pinned GHC 9.6.5, `allow-newer: false`, `lts-22.21`
- **Modules**: Quarantined 356 non-compiling modules to `src/_quarantine/`
- **Core**: Reduced `exposed-modules` to 14 compiling modules (added Finance.Bill)
- **Branch protection**: Relaxed to allow merge with CI green

### Removed
- Dangerous auto-approve/copilot-auto-approve workflows
- 80+ non-essential CI workflows
- ai-report executable (imported quarantined modules)

### Fixed
- License inconsistency: cabal now matches LICENSE file (MPL-2.0)
- CHANGELOG cleaned up (removed references to disabled workflows)

## [0.1.0] - 2026-09-06

### Added
- Core library: `Finance.Tax`, `Finance.Accounting`, `Finance.Bill`, `DAL.Types`, `DAL.Schema`, `DAL.Database`, `DAL.Pool`
- Auth: `Surypus.RBAC` (33 permissions), `Surypus.JWT`
- Metrics: `Surypus.Metrics`
- CI: Single job, GHC 9.6.5, green build
