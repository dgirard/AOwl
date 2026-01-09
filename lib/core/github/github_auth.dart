/// GitHub authentication configuration.
///
/// Stores the repository URL and Personal Access Token (PAT)
/// needed for GitHub API calls.
class GitHubAuth {
  /// Repository owner (username or organization).
  final String owner;

  /// Repository name.
  final String repo;

  /// Personal Access Token for authentication.
  final String token;

  /// Base URL for GitHub API.
  final String baseUrl;

  GitHubAuth({
    required this.owner,
    required this.repo,
    required this.token,
    this.baseUrl = 'https://api.github.com',
  });

  /// Creates GitHubAuth from a full repository URL.
  ///
  /// Supports formats:
  /// - https://github.com/owner/repo
  /// - https://github.com/owner/repo.git
  /// - github.com/owner/repo
  factory GitHubAuth.fromUrl({
    required String repoUrl,
    required String token,
  }) {
    final parsed = parseRepoUrl(repoUrl);
    if (parsed == null) {
      throw ArgumentError('Invalid GitHub repository URL: $repoUrl');
    }
    return GitHubAuth(
      owner: parsed.$1,
      repo: parsed.$2,
      token: token,
    );
  }

  /// Parses a GitHub repository URL and returns (owner, repo).
  ///
  /// Returns null if the URL format is invalid.
  static (String, String)? parseRepoUrl(String url) {
    // Remove trailing .git if present
    var cleaned = url.replaceAll(RegExp(r'\.git$'), '');

    // Remove protocol and www
    cleaned = cleaned.replaceFirst(RegExp(r'^https?://'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^www\.'), '');

    // Should now be: github.com/owner/repo
    final pattern = RegExp(r'^github\.com/([^/]+)/([^/]+)$');
    final match = pattern.firstMatch(cleaned);

    if (match == null) return null;

    return (match.group(1)!, match.group(2)!);
  }

  /// Returns the base path for API calls to this repository.
  String get repoPath => '/repos/$owner/$repo';

  /// Returns the contents API path for a file.
  String contentsPath(String filePath) =>
      '$repoPath/contents/${filePath.startsWith('/') ? filePath.substring(1) : filePath}';

  /// Returns HTTP headers for authenticated requests.
  Map<String, String> get headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  @override
  String toString() => 'GitHubAuth($owner/$repo)';
}
