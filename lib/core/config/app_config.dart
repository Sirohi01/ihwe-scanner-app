class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nenita-untoured-nonhesitantly.ngrok-free.dev/api',
  );
}
