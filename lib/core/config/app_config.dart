class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nenita-untoured-nonhesitantly.ngrok-free.dev/api',
  );
}

String resolveApiAssetUrl(Object? input) {
  final path = input?.toString().trim() ?? '';
  if (path.isEmpty ||
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('data:')) {
    return path;
  }
  final api = Uri.parse(AppConfig.apiBaseUrl);
  return '${api.origin}/${path.replaceFirst(RegExp(r'^/+'), '')}';
}
