/// Shared mood / energy display helpers.
class MoodUtils {
  static const moods = ['happy', 'neutral', 'sad', 'tired', 'sick'];

  static String emoji(String mood) {
    switch (mood) {
      case 'happy':
        return '😊';
      case 'neutral':
        return '😐';
      case 'sad':
        return '😢';
      case 'tired':
        return '😴';
      case 'sick':
        return '🤒';
      default:
        return '😐';
    }
  }

  static String label(String mood) {
    switch (mood) {
      case 'happy':
        return 'Happy';
      case 'neutral':
        return 'Okay';
      case 'sad':
        return 'Sad';
      case 'tired':
        return 'Tired';
      case 'sick':
        return 'Unwell';
      default:
        return mood;
    }
  }

  /// Numeric score for charting mood (1 = low, 5 = high wellbeing).
  static double moodScore(String mood) {
    switch (mood) {
      case 'happy':
        return 5;
      case 'neutral':
        return 3;
      case 'tired':
        return 2;
      case 'sad':
        return 1.5;
      case 'sick':
        return 1;
      default:
        return 3;
    }
  }
}
