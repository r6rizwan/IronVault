import 'package:flutter_test/flutter_test.dart';
import 'package:ironvault/core/utils/attachment_utils.dart';

void main() {
  group('attachment utils', () {
    test('detects image attachments', () {
      expect(isImageAttachment('/tmp/photo.png'), isTrue);
      expect(isImageAttachment('/tmp/photo.jpg'), isTrue);
      expect(isImageAttachment('/tmp/document.pdf'), isFalse);
    });

    test('detects pdf attachments', () {
      expect(isPdfAttachment('/tmp/document.pdf'), isTrue);
      expect(isPdfAttachment('/tmp/document.PDF'), isTrue);
      expect(isPdfAttachment('/tmp/file.docx'), isFalse);
    });

    test('returns file extension safely', () {
      expect(getFileExtension('/tmp/report.docx'), 'docx');
      expect(getFileExtension('/tmp/noextension'), 'bin');
    });
  });
}
