import 'package:ashare/features/exchange/domain/vault_entry.dart';
import 'package:ashare/features/exchange/domain/vault_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VaultIndex', () {
    late VaultEntry entry1;
    late VaultEntry entry2;
    late VaultEntry entry3;

    setUp(() {
      entry1 = VaultEntry(
        id: 'entry-1',
        filename: 'entry-1.enc',
        type: EntryType.text,
        label: 'Note 1',
        createdAt: DateTime.utc(2024, 1, 15, 10, 0),
        updatedAt: DateTime.utc(2024, 1, 15, 10, 0),
        sizeBytes: 100,
      );

      entry2 = VaultEntry(
        id: 'entry-2',
        filename: 'entry-2.enc',
        type: EntryType.image,
        label: 'Photo',
        mimeType: 'image/jpeg',
        createdAt: DateTime.utc(2024, 1, 15, 11, 0),
        updatedAt: DateTime.utc(2024, 1, 15, 11, 0),
        sizeBytes: 50000,
      );

      entry3 = VaultEntry(
        id: 'entry-3',
        filename: 'entry-3.enc',
        type: EntryType.text,
        label: 'Note 2',
        createdAt: DateTime.utc(2024, 1, 15, 12, 0),
        updatedAt: DateTime.utc(2024, 1, 15, 12, 0),
        sizeBytes: 200,
      );
    });

    group('empty', () {
      test('creates empty index with current version', () {
        final index = VaultIndex.empty();

        expect(index.version, equals(VaultIndex.currentVersion));
        expect(index.entries, isEmpty);
        expect(index.isEmpty, isTrue);
        expect(index.isNotEmpty, isFalse);
      });
    });

    group('JSON serialization', () {
      test('round-trips through JSON', () {
        final original = VaultIndex(
          entries: [entry1, entry2],
          updatedAt: DateTime.utc(2024, 1, 15, 12, 0),
        );

        final jsonString = original.toJsonString();
        final restored = VaultIndex.fromJsonString(jsonString);

        expect(restored.version, equals(original.version));
        expect(restored.entries.length, equals(2));
        expect(restored.entries[0].id, equals(entry1.id));
        expect(restored.entries[1].id, equals(entry2.id));
      });

      test('handles empty entries list', () {
        final json = {
          'version': 1,
          'updated_at': '2024-01-15T12:00:00.000Z',
        };

        final index = VaultIndex.fromJson(json);
        expect(index.entries, isEmpty);
      });
    });

    group('entry operations', () {
      test('getEntry returns entry by ID', () {
        final index = VaultIndex(entries: [entry1, entry2]);

        expect(index.getEntry('entry-1'), equals(entry1));
        expect(index.getEntry('entry-2'), equals(entry2));
        expect(index.getEntry('nonexistent'), isNull);
      });

      test('hasEntry checks if entry exists', () {
        final index = VaultIndex(entries: [entry1]);

        expect(index.hasEntry('entry-1'), isTrue);
        expect(index.hasEntry('entry-2'), isFalse);
      });

      test('addEntry adds new entry', () {
        final index = VaultIndex(entries: [entry1]);
        final newIndex = index.addEntry(entry2);

        expect(newIndex.entries.length, equals(2));
        expect(newIndex.hasEntry('entry-2'), isTrue);
        expect(index.entries.length, equals(1)); // Original unchanged
      });

      test('addEntry throws for duplicate ID', () {
        final index = VaultIndex(entries: [entry1]);

        expect(
          () => index.addEntry(entry1),
          throwsArgumentError,
        );
      });

      test('updateEntry updates existing entry', () {
        final index = VaultIndex(entries: [entry1]);
        final updated = entry1.copyWith(label: 'Updated label');
        final newIndex = index.updateEntry(updated);

        expect(newIndex.getEntry('entry-1')?.label, equals('Updated label'));
      });

      test('updateEntry throws for nonexistent ID', () {
        final index = VaultIndex(entries: [entry1]);

        expect(
          () => index.updateEntry(entry2),
          throwsArgumentError,
        );
      });

      test('removeEntry removes entry by ID', () {
        final index = VaultIndex(entries: [entry1, entry2]);
        final newIndex = index.removeEntry('entry-1');

        expect(newIndex.entries.length, equals(1));
        expect(newIndex.hasEntry('entry-1'), isFalse);
        expect(newIndex.hasEntry('entry-2'), isTrue);
      });

      test('upsertEntry adds new entry', () {
        final index = VaultIndex(entries: [entry1]);
        final newIndex = index.upsertEntry(entry2);

        expect(newIndex.entries.length, equals(2));
      });

      test('upsertEntry updates existing entry', () {
        final index = VaultIndex(entries: [entry1]);
        final updated = entry1.copyWith(label: 'New label');
        final newIndex = index.upsertEntry(updated);

        expect(newIndex.entries.length, equals(1));
        expect(newIndex.getEntry('entry-1')?.label, equals('New label'));
      });
    });

    group('queries', () {
      test('entriesByDate returns sorted by date descending', () {
        final index = VaultIndex(entries: [entry1, entry3, entry2]);
        final sorted = index.entriesByDate;

        expect(sorted[0].id, equals('entry-3')); // Newest
        expect(sorted[1].id, equals('entry-2'));
        expect(sorted[2].id, equals('entry-1')); // Oldest
      });

      test('entriesOfType filters by type', () {
        final index = VaultIndex(entries: [entry1, entry2, entry3]);

        final textEntries = index.entriesOfType(EntryType.text);
        expect(textEntries.length, equals(2));
        expect(textEntries.every((e) => e.type == EntryType.text), isTrue);

        final imageEntries = index.entriesOfType(EntryType.image);
        expect(imageEntries.length, equals(1));
        expect(imageEntries.first.id, equals('entry-2'));
      });

      test('count returns number of entries', () {
        final index = VaultIndex(entries: [entry1, entry2, entry3]);
        expect(index.count, equals(3));
      });

      test('totalSize sums entry sizes', () {
        final index = VaultIndex(entries: [entry1, entry2, entry3]);
        expect(index.totalSize, equals(100 + 50000 + 200));
      });
    });

    group('merge', () {
      test('merges two indexes keeping newer entries', () {
        final olderEntry = entry1.copyWith(
          updatedAt: DateTime.utc(2024, 1, 10),
        );
        final newerEntry = entry1.copyWith(
          label: 'Updated',
          updatedAt: DateTime.utc(2024, 1, 20),
        );

        final index1 = VaultIndex(entries: [olderEntry, entry2]);
        final index2 = VaultIndex(entries: [newerEntry, entry3]);

        final merged = index1.merge(index2);

        expect(merged.count, equals(3));
        expect(merged.getEntry('entry-1')?.label, equals('Updated'));
        expect(merged.hasEntry('entry-2'), isTrue);
        expect(merged.hasEntry('entry-3'), isTrue);
      });

      test('merge with empty index returns original entries', () {
        final index = VaultIndex(entries: [entry1, entry2]);
        final empty = VaultIndex.empty();

        final merged = index.merge(empty);

        expect(merged.count, equals(2));
        expect(merged.entries, containsAll([entry1, entry2]));
      });

      test('merge empty with index returns other entries', () {
        final empty = VaultIndex.empty();
        final index = VaultIndex(entries: [entry1, entry2]);

        final merged = empty.merge(index);

        expect(merged.count, equals(2));
      });
    });
  });
}
