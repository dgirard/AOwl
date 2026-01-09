import 'dart:convert';

import 'package:ashare/core/github/models/github_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GitHubFile', () {
    test('parses from JSON', () {
      final json = {
        'name': 'test.txt',
        'path': 'folder/test.txt',
        'sha': 'abc123def456',
        'size': 1234,
        'type': 'file',
        'content': base64.encode('Hello, World!'.codeUnits),
        'download_url': 'https://raw.githubusercontent.com/owner/repo/main/test.txt',
      };

      final file = GitHubFile.fromJson(json);

      expect(file.name, equals('test.txt'));
      expect(file.path, equals('folder/test.txt'));
      expect(file.sha, equals('abc123def456'));
      expect(file.size, equals(1234));
      expect(file.type, equals('file'));
      expect(file.content, isNotNull);
      expect(file.downloadUrl, isNotNull);
    });

    test('decodes base64 content', () {
      final original = 'Hello, World!';
      final json = {
        'name': 'test.txt',
        'path': 'test.txt',
        'sha': 'abc',
        'size': original.length,
        'type': 'file',
        'content': base64.encode(original.codeUnits),
      };

      final file = GitHubFile.fromJson(json);
      final decoded = file.decodedContent;

      expect(decoded, isNotNull);
      expect(String.fromCharCodes(decoded!), equals(original));
    });

    test('handles content with newlines', () {
      // GitHub often adds newlines to base64 content
      final original = 'Test content';
      final encoded = base64.encode(original.codeUnits);
      final withNewlines = '${encoded.substring(0, 5)}\n${encoded.substring(5)}';

      final json = {
        'name': 'test.txt',
        'path': 'test.txt',
        'sha': 'abc',
        'size': original.length,
        'type': 'file',
        'content': withNewlines,
      };

      final file = GitHubFile.fromJson(json);
      final decoded = file.decodedContent;

      expect(String.fromCharCodes(decoded!), equals(original));
    });

    test('returns null for missing content', () {
      final json = {
        'name': 'test.txt',
        'path': 'test.txt',
        'sha': 'abc',
        'size': 100,
        'type': 'file',
      };

      final file = GitHubFile.fromJson(json);
      expect(file.decodedContent, isNull);
    });

    test('isFile returns true for files', () {
      final file = GitHubFile(
        name: 'test.txt',
        path: 'test.txt',
        sha: 'abc',
        size: 100,
        type: 'file',
      );
      expect(file.isFile, isTrue);
      expect(file.isDirectory, isFalse);
    });

    test('isDirectory returns true for directories', () {
      final dir = GitHubFile(
        name: 'folder',
        path: 'folder',
        sha: 'abc',
        size: 0,
        type: 'dir',
      );
      expect(dir.isFile, isFalse);
      expect(dir.isDirectory, isTrue);
    });
  });

  group('CommitInfo', () {
    test('parses from JSON', () {
      final json = {
        'sha': 'abc123def456789',
        'commit': {
          'message': 'Test commit message',
          'author': {
            'name': 'Test User',
            'email': 'test@example.com',
            'date': '2024-01-15T10:30:00Z',
          },
        },
      };

      final commit = CommitInfo.fromJson(json);

      expect(commit.sha, equals('abc123def456789'));
      expect(commit.message, equals('Test commit message'));
      expect(commit.authorName, equals('Test User'));
      expect(commit.authorEmail, equals('test@example.com'));
      expect(commit.date.year, equals(2024));
      expect(commit.date.month, equals(1));
      expect(commit.date.day, equals(15));
    });
  });
}
