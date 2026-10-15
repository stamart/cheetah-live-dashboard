/// Minimal app-wide language switch — not full Flutter localization (no ARB files, no
/// system-locale integration), just a driver-toggleable PL/EN pair for the setup/wizard
/// screens, matching the reference design's language pills. The live dashboard itself
/// (gauge, tyres, pedals...) isn't translated yet — deliberately out of scope for this
/// pass, flagged as follow-up work.
enum AppLang { pl, en }

class AppStrings {
  final AppLang lang;
  const AppStrings(this.lang);

  bool get _pl => lang == AppLang.pl;
  String _t(String pl, String en) => _pl ? pl : en;

  // Setup screen
  String get demoMode => _t('Tryb demo (bez PS5)', 'Demo mode (no PS5)');
  String get ps5IpLabel => _t('Adres IP PS5 (ta sama sieć Wi-Fi)', 'PS5 IP address (same Wi-Fi network)');
  String get serverLabel => _t('Adres serwera Cheetah', 'Cheetah server address');
  String get loginWithDiscord => _t('Zaloguj przez Discord', 'Log in with Discord');
  String get loggedInAs => _t('Zalogowano jako', 'Logged in as');
  String get logout => _t('Wyloguj', 'Log out');
  String get connectFreeride => _t('Freeride', 'Freeride');
  String get orJoinEvent => _t('Albo dołącz do eventu:', 'Or join an event:');
  String get noEvents => _t('Brak dostępnych eventów.', 'No events available.');
  String get retry => _t('Spróbuj ponownie', 'Retry');
  String get missingPs5Ip => _t('Uzupełnij adres IP PS5.', 'Enter the PS5 IP address.');
  String get loginBeforeConnect => _t('Zaloguj się przez Discord przed połączeniem.', 'Log in with Discord before connecting.');

  // Waiting shell
  String get freerideSession => _t('Freeride (bez eventu)', 'Freeride (no event)');
  String get disconnect => _t('Rozłącz', 'Disconnect');
  String get driverLabel => _t('Kierowca', 'Driver');
  String get ps5 => _t('PS5', 'PS5');
  String get server => _t('Serwer', 'Server');
  String waitingForGt7(bool ps5Connected, String ps5Ip) => ps5Connected
      ? _t('Sparowano — czekam na dane z GT7...', 'Paired — waiting for GT7 data...')
      : _t('Sparowano z serwerem — łączę z PS5 pod $ps5Ip...', 'Paired with the server — connecting to PS5 at $ps5Ip...');
  String get waitingHint => _t(
        'Upewnij się, że GT7 jest uruchomione (nie tylko konsola) i telefon jest\nw tej samej sieci Wi-Fi co PS5.',
        'Make sure GT7 is actually running (not just the console) and your phone is\non the same Wi-Fi network as the PS5.',
      );

  // Session wizard
  String get wizardTitle => _t('KONFIGURACJA SESJI', 'SESSION SETUP');
  String get wizardContinent => _t('Kontynent', 'Continent');
  String get wizardTrack => _t('Tor', 'Track');
  String get wizardLayout => _t('Układ toru', 'Layout');
  String get wizardSessionType => _t('Rodzaj sesji', 'Session type');
  String get wizardRaceFormat => _t('Format wyścigu', 'Race format');
  String get wizardTyres => _t('Opony', 'Tyres');
  String get wizardSummary => _t('Podsumowanie', 'Summary');
  String get training => _t('Trening', 'Practice');
  String get qualifying => _t('Kwalifikacje', 'Qualifying');
  String get race => _t('Wyścig', 'Race');
  String get onTime => _t('Na czas', 'On time');
  String get onLaps => _t('Na okrążenia', 'On laps');
  String get raceDurationMinutes => _t('Czas wyścigu (minuty)', 'Race duration (minutes)');
  String get lapCount => _t('Liczba okrążeń', 'Number of laps');
  String get startSession => _t('Rozpocznij sesję', 'Start session');
  String get back => _t('Wstecz', 'Back');
  String get matches => _t('WYNIKÓW', 'MATCHES');
  String get searchHint => _t('Szukaj toru...', 'Search track...');
  String get del => _t('DEL', 'DEL');
  String get clr => _t('CLR', 'CLR');
}
