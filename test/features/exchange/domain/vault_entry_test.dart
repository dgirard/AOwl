import 'package:aowl/features/exchange/domain/vault_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VaultEntry', () {
    group('create', () {
      test('creates entry with generated UUID', () {
        final entry = VaultEntry.create(
          type: EntryType.text,
          label: 'Test note',
          sizeBytes: 1024,
        );

        expect(entry.id, isNotEmpty);
        expect(entry.id.length, equals(36)); // UUID v4 format
        expect(entry.filename, equals('${entry.id}.enc'));
        expect(entry.type, equals(EntryType.text));
        expect(entry.label, equals('Test note'));
        expect(entry.sizeBytes, equals(1024));
        expect(entry.sha, isNull);
      });

      test('creates image entry with mime type', () {
        final entry = VaultEntry.create(
          type: EntryType.image,
          label: 'Photo',
          mimeType: 'image/jpeg',
          sizeBytes: 50000,
        );

        expect(entry.type, equals(EntryType.image));
        expect(entry.mimeType, equals('image/jpeg'));
        expect(entry.isImage, isTrue);
        expect(entry.isText, isFalse);
      });

      test('sets timestamps to current UTC time', () {
        final before = DateTime.now().toUtc();
        final entry = VaultEntry.create(
          type: EntryType.text,
          label: 'Test',
          sizeBytes: 100,
        );
        final after = DateTime.now().toUtc();

        expect(entry.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(entry.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
        expect(entry.updatedAt, equals(entry.createdAt));
      });
    });

    group('JSON serialization', () {
      test('round-trips through JSON', () {
        final original = VaultEntry(
          id: 'test-uuid-1234',
          filename: 'test-uuid-1234.enc',
          type: EntryType.image,
          label: 'Test image',
          mimeType: 'image/png',
          createdAt: DateTime.utc(2024, 1, 15, 10, 30),
          updatedAt: DateTime.utc(2024, 1, 15, 11, 45),
          sizeBytes: 12345,
          sha: 'abc123def',
        );

        final json = original.toJson();
        final restored = VaultEntry.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.filename, equals(original.filename));
        expect(restored.type, equals(original.type));
        expect(restored.label, equals(original.label));
        expect(restored.mimeType, equals(original.mimeType));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.updatedAt, equals(original.updatedAt));
        expect(restored.sizeBytes, equals(original.sizeBytes));
        expect(restored.sha, equals(original.sha));
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'test-id',
          'filename': 'test.enc',
          'type': 'text',
          'label': 'Test',
          'created_at': '2024-01-15T10:00:00.000Z',
          'updated_at': '2024-01-15T10:00:00.000Z',
          'size_bytes': 100,
        };

        final entry = VaultEntry.fromJson(json);

        expect(entry.mimeType, isNull);
        expect(entry.sha, isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = VaultEntry.create(
          type: EntryType.text,
          label: 'Original',
          sizeBytes: 100,
        );

        final copy = original.copyWith(
          label: 'Updated',
          sha: 'new-sha',
        );

        expect(copy.id, equals(original.id));
        expect(copy.label, equals('Updated'));
        expect(copy.sha, equals('new-sha'));
        expect(copy.sizeBytes, equals(original.sizeBytes));
      });

      test('withSha updates SHA and timestamp', () {
        final original = VaultEntry.create(
          type: EntryType.text,
          label: 'Test',
          sizeBytes: 100,
        );

        final updated = original.withSha('new-sha-value');

        expect(updated.sha, equals('new-sha-value'));
        expect(updated.updatedAt.isAfter(original.createdAt), isTrue);
      });
    });

    group('formattedSize', () {
      test('formats bytes', () {
        final entry = VaultEntry.create(
          type: EntryType.text,
          label: 'Test',
          sizeBytes: 512,
        );
        expect(entry.formattedSize, equals('512 B'));
      });

      test('formats kilobytes', () {
        final entry = VaultEntry.create(
          type: EntryType.text,
          label: 'Test',
          sizeBytes: 2048,
        );
        expect(entry.formattedSize, equals('2.0 KB'));
      });

      test('formats megabytes', () {
        final entry = VaultEntry.create(
          type: EntryType.text,
          label: 'Test',
          sizeBytes: 1572864,
        );
        expect(entry.formattedSize, equals('1.5 MB'));
      });
    });

    group('equality', () {
      test('entries with same ID are equal', () {
        final entry1 = VaultEntry(
          id: 'same-id',
          filename: 'same-id.enc',
          type: EntryType.text,
          label: 'One',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          sizeBytes: 100,
        );

        final entry2 = VaultEntry(
          id: 'same-id',
          filename: 'same-id.enc',
          type: EntryType.image,
          label: 'Two',
          createdAt: DateTime.now().add(const Duration(hours: 1)),
          updatedAt: DateTime.now().add(const Duration(hours: 1)),
          sizeBytes: 200,
        );

        expect(entry1, equals(entry2));
        expect(entry1.hashCode, equals(entry2.hashCode));
      });

      test('entries with different IDs are not equal', () {
        final entry1 = VaultEntry.create(
          type: EntryType.text,
          label: 'Same label',
          sizeBytes: 100,
        );

        final entry2 = VaultEntry.create(
          type: EntryType.text,
          label: 'Same label',
          sizeBytes: 100,
        );

        expect(entry1, isNot(equals(entry2)));
      });
    });
  });

  group('EntryType', () {
    test('serializes to JSON', () {
      expect(EntryType.text.toJson(), equals('text'));
      expect(EntryType.image.toJson(), equals('image'));
    });

    test('deserializes from JSON', () {
      expect(EntryType.fromJson('text'), equals(EntryType.text));
      expect(EntryType.fromJson('image'), equals(EntryType.image));
    });

    test('defaults to text for unknown type', () {
      expect(EntryType.fromJson('unknown'), equals(EntryType.text));
    });
  });
}
