enum QuotationStatus {
  draft,
  sent,
  approved,
  rejected,
  expired;

  String get displayName {
    switch (this) {
      case QuotationStatus.draft:
        return 'Draft';
      case QuotationStatus.sent:
        return 'Sent';
      case QuotationStatus.approved:
        return 'Approved';
      case QuotationStatus.rejected:
        return 'Rejected';
      case QuotationStatus.expired:
        return 'Expired';
    }
  }
}

enum SyncStatus { synced, pending, error }
