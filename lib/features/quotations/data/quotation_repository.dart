import '../domain/quotation.dart';

abstract class QuotationRepository {
  Future<List<Quotation>> getAllQuotations();
  Future<Quotation> saveQuotation(Quotation quotation);
  Future<void> deleteQuotation(String id);
  Future<Quotation> duplicateQuotation(Quotation sourceQuotation);
  Future<Quotation> getQuotationWithImages(Quotation quotation);
}
