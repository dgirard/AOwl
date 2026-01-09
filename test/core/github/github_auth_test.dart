import 'package:ashare/core/github/github_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GitHubAuth', () {
    test('creates from owner, repo, and token', () {
      final auth = GitHubAuth(
        owner: 'testuser',
        repo: 'testrepo',
        token: 'ghp_test123',
      );

      expect(auth.owner, equals('testuser'));
      expect(auth.repo, equals('testrepo'));
      expect(auth.token, equals('ghp_test123'));
      expect(auth.baseUrl, equals('https://api.github.com'));
    });

    group('parseRepoUrl', () {
      test('parses https URL', () {
        final result = GitHubAuth.parseRepoUrl(
          'https://github.com/owner/repo',
        );
        expect(result, equals(('owner', 'repo')));
      });

      test('parses https URL with .git suffix', () {
        final result = GitHubAuth.parseRepoUrl(
          'https://github.com/owner/repo.git',
        );
        expect(result, equals(('owner', 'repo')));
      });

      test('parses URL without protocol', () {
        final result = GitHubAuth.parseRepoUrl('github.com/owner/repo');
        expect(result, equals(('owner', 'repo')));
      });

      test('parses URL with www', () {
        final result = GitHubAuth.parseRepoUrl(
          'https://www.github.com/owner/repo',
        );
        expect(result, equals(('owner', 'repo')));
      });

      test('returns null for invalid URL', () {
        expect(GitHubAuth.parseRepoUrl('not-a-url'), isNull);
        expect(GitHubAuth.parseRepoUrl('https://gitlab.com/owner/repo'), isNull);
        expect(GitHubAuth.parseRepoUrl('github.com/owner'), isNull);
        expect(GitHubAuth.parseRepoUrl('github.com/'), isNull);
      });
    });

    group('fromUrl', () {
      test('creates auth from valid URL', () {
        final auth = GitHubAuth.fromUrl(
          repoUrl: 'https://github.com/testowner/testrepo',
          token: 'ghp_test',
        );

        expect(auth.owner, equals('testowner'));
        expect(auth.repo, equals('testrepo'));
        expect(auth.token, equals('ghp_test'));
      });

      test('throws for invalid URL', () {
        expect(
          () => GitHubAuth.fromUrl(
            repoUrl: 'invalid-url',
            token: 'ghp_test',
          ),
          throwsArgumentError,
        );
      });
    });

    group('paths', () {
      late GitHubAuth auth;

      setUp(() {
        auth = GitHubAuth(
          owner: 'owner',
          repo: 'repo',
          token: 'token',
        );
      });

      test('repoPath returns correct path', () {
        expect(auth.repoPath, equals('/repos/owner/repo'));
      });

      test('contentsPath handles path with leading slash', () {
        expect(
          auth.contentsPath('/path/to/file.txt'),
          equals('/repos/owner/repo/contents/path/to/file.txt'),
        );
      });

      test('contentsPath handles path without leading slash', () {
        expect(
          auth.contentsPath('path/to/file.txt'),
          equals('/repos/owner/repo/contents/path/to/file.txt'),
        );
      });
    });

    group('headers', () {
      test('includes authorization bearer token', () {
        final auth = GitHubAuth(
          owner: 'owner',
          repo: 'repo',
          token: 'my_token',
        );

        expect(auth.headers['Authorization'], equals('Bearer my_token'));
      });

      test('includes GitHub API version', () {
        final auth = GitHubAuth(
          owner: 'owner',
          repo: 'repo',
          token: 'token',
        );

        expect(auth.headers['X-GitHub-Api-Version'], equals('2022-11-28'));
        expect(auth.headers['Accept'], equals('application/vnd.github+json'));
      });
    });
  });
}
