enum AppearancePreference { system, light, dark }

/// Ceiling for historical message scanning. Kept deliberately small: real
/// inbox volume is ~250 messages/month, so a 30 day window keeps the first
/// import inside a couple of minutes while notification capture handles
/// everything arriving after setup.
const int maximumLookbackDays = 30;
const int minimumLookbackDays = 7;

/// Extraction runs one structured pass per batch and never orchestrates
/// tools, so the small fast model is the right default. Chat drives a
/// multi-tool agent loop where a stronger model reaches an answer in fewer
/// turns, which is usually faster end to end despite the larger size.
const String defaultParsingModel = 'gpt-oss:20b-cloud';
const String defaultChatModel = 'qwen3-coder:480b-cloud';

class AppPreferences {
  const AppPreferences({
    this.onboardingComplete = false,
    this.appearance = AppearancePreference.system,
    this.currency = 'INR',
    this.hideAmounts = false,
    this.lockApp = false,
    this.messageLookbackDays = maximumLookbackDays,
    this.captureNotifications = false,
    this.aiEndpoint = 'https://ollama.com',
    this.aiModel = defaultParsingModel,
    this.aiChatModel = defaultChatModel,
  });
  final bool onboardingComplete;
  final AppearancePreference appearance;
  final String currency;
  final bool hideAmounts;
  final bool lockApp;
  final int messageLookbackDays;
  final bool captureNotifications;
  final String aiEndpoint;

  /// Model used for structured SMS extraction.
  final String aiModel;

  /// Model used for the conversational agent loop.
  final String aiChatModel;

  AppPreferences copyWith({
    bool? onboardingComplete,
    AppearancePreference? appearance,
    String? currency,
    bool? hideAmounts,
    bool? lockApp,
    int? messageLookbackDays,
    bool? captureNotifications,
    String? aiEndpoint,
    String? aiModel,
    String? aiChatModel,
  }) => AppPreferences(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    appearance: appearance ?? this.appearance,
    currency: currency ?? this.currency,
    hideAmounts: hideAmounts ?? this.hideAmounts,
    lockApp: lockApp ?? this.lockApp,
    messageLookbackDays: (messageLookbackDays ?? this.messageLookbackDays)
        .clamp(minimumLookbackDays, maximumLookbackDays),
    captureNotifications: captureNotifications ?? this.captureNotifications,
    aiEndpoint: aiEndpoint ?? this.aiEndpoint,
    aiModel: aiModel ?? this.aiModel,
    aiChatModel: aiChatModel ?? this.aiChatModel,
  );
}
