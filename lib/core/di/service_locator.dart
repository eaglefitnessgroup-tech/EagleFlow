import '../../features/quotations/data/quotation_repository.dart';
import '../../features/quotations/data/sembast_quotation_repository.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final QuotationRepository quotationRepository =
      SembastQuotationRepository();
}
