# Changelog

All notable changes to EagleFlow will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0+1] - 2026-08-04

### Added
- **Core Architecture**: Offline-first repository structure with Sembast caching and resilient two-way synchronization via Supabase.
- **Authentication**: Fully functional RBAC (Admin vs Salesperson) login with persistent encrypted sessions and double-submit protections.
- **Products**: Complete product catalogue management with active/inactive toggles, image support, and search capabilities.
- **Stock Management**: Robust double-entry stock movement tracking (Stock In / Stock Out), negative-stock prevention, and detailed stock reports.
- **Quotations**: Seamless quotation generation workflow, supporting custom items, charges (shipping/VAT), automated stock deductions upon approval, and visually appealing PDF exports.
- **Reporting**: High-performance in-memory reporting layer driving dynamic Dashboard summaries and analytics for quotation statuses and product valuation.
- **Backup & Restore**: Secure, sanitized, atomic offline JSON backup and restore capabilities, preventing secret exposure and schema corruption.
- **UX Polish**: Consistent form validations, accessibility improvements, logical focus traversals, SnackBar feedback uniformity, and keyboard-driven data entry.

### Security
- **Hardening**: Stripped sensitive backend technical exceptions (`$e`) from user-facing UI messages.
- **Validation**: Strict integrity rules on stock manipulation and quotation numbering sequences.

### Fixed
- Stabilized multiple layout overflows in Quotation Previews for narrow screens (320px).
- Fixed floating-point calculation mismatches in Quotation Charges (5% VAT defaults).
- Protected internal dependencies and mock services from overlapping generic errors during load failures.
