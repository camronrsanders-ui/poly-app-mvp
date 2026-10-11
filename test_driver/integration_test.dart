import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      final directory =
          Platform.environment['POLYCIRCLE_ACCEPTANCE_OUTPUT_DIRECTORY'] ??
              'build/simulator_acceptance';
      final file = await File(
        '$directory/$screenshotName.png',
      ).create(recursive: true);
      await file.writeAsBytes(screenshotBytes, flush: true);
      return true;
    },
  );
}
