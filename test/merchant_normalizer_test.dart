import 'package:expense_manager/services/merchant_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SMS merchant fallback', () {
    test('extracts card merchant after at', () {
      expect(
        MerchantNormalizer.extractFromSms(
          'INR 450 debited from card XX1234 at BLUE TOKAI on 16-Jul.',
        ),
        'Blue Tokai',
      );
    });

    test('extracts UPI descriptor payee', () {
      expect(
        MerchantNormalizer.extractFromSms(
          'A/c debited INR 299. UPI/DR/123456789/NETFLIX/ICIC/abc@icici',
        ),
        'Netflix',
      );
    });

    test('extracts info descriptor', () {
      expect(
        MerchantNormalizer.extractFromSms(
          'Rs.120 spent on card. Info: SWIGGY BANGALORE, Avl Bal Rs.5000',
        ),
        'Swiggy',
      );
    });

    test('extracts VPA when no display name exists', () {
      expect(
        MerchantNormalizer.extractFromSms(
          'Rs 80 paid to VPA localshop@okaxis via UPI.',
        ),
        'Localshop@okaxis',
      );
    });
  });
}
