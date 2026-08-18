import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/services/ugc_text_policy.dart';

void main() {
  test('ordinary ENM and identity discussion is not blocked', () {
    expect(
      UgcTextPolicy.violationFor(
        'I am queer, polyamorous, and looking for respectful community.',
      ),
      isNull,
    );
    expect(
      UgcTextPolicy.violationFor(
        'I am a survivor and want communication, boundaries, and safety.',
      ),
      isNull,
    );
  });

  test('direct violent threats are blocked before posting', () {
    expect(UgcTextPolicy.violationFor('I will kill you'), isNotNull);
    expect(UgcTextPolicy.violationFor('kill yourself'), isNotNull);
  });

  test('sexual solicitation involving minors is blocked before posting', () {
    expect(
        UgcTextPolicy.violationFor('looking for an underage kid'), isNotNull);
    expect(UgcTextPolicy.violationFor('send nudes from a minor'), isNotNull);
  });
}
