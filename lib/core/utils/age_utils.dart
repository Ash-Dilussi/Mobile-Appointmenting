/// Returns the completed years between [dateOfBirth] and [onDate].
///
/// February 29 birthdays advance on March 1 in non-leap years, matching the
/// ordinary month/day comparison used for all other dates.
int ageOnDate(DateTime dateOfBirth, DateTime onDate) {
  var age = onDate.year - dateOfBirth.year;
  final birthdayHasOccurred = onDate.month > dateOfBirth.month ||
      (onDate.month == dateOfBirth.month && onDate.day >= dateOfBirth.day);
  if (!birthdayHasOccurred) age--;
  return age;
}

int currentAge(DateTime dateOfBirth) => ageOnDate(dateOfBirth, DateTime.now());
