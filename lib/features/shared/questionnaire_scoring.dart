/// Score questionnaire answers: Yes=2, Sometimes=1, No/other=0.
int scoreQuestionnaireAnswers(dynamic answers) {
  if (answers is! Map) return 0;
  var score = 0;
  for (final v in answers.values) {
    if (v == 'Yes') {
      score += 2;
    } else if (v == 'Sometimes') {
      score += 1;
    }
  }
  return score;
}

String formatSubmittedDate(String? iso) {
  if (iso == null || iso.length < 10) return '';
  return iso.substring(0, 10);
}
