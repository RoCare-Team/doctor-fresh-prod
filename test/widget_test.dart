import 'package:flutter_test/flutter_test.dart';

import 'package:doctor_fresh/core/format.dart';

void main() {
  test('prices print the way the website prints them', () {
    expect(formatPrice(12499), '₹12,499');
    expect(formatPrice(645000), '₹6,45,000');
    expect(formatPrice(999), '₹999');
  });

  test('mobile numbers keep their last 10 digits', () {
    expect(normaliseMobile('+91 98765-43210'), '9876543210');
  });
}
