import 'package:bookly/core/constants/auth_field_constraints.dart';
import 'package:bookly/core/error/auth_exception.dart';
import 'package:bookly/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookly/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookly/features/auth/presentation/screens/login_screen.dart';
import 'package:bookly/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;

  setUp(() {
    repository = _MockAuthRepository();
    when(() => repository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
  });

  Widget buildScreen(Widget screen) {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: screen),
    );
  }

  testWidgets('registration fields enforce account input constraints',
      (tester) async {
    await tester.pumpWidget(buildScreen(const RegisterScreen()));

    final fields =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();

    expect(fields, hasLength(4));
    expect(
      _lengthLimit(fields[0]),
      AuthFieldConstraints.fullNameMaxLength,
    );
    expect(_lengthLimit(fields[1]), AuthFieldConstraints.emailMaxLength);
    expect(fields[2].obscureText, isTrue);
    expect(fields[2].enableSuggestions, isFalse);
    expect(fields[2].autocorrect, isFalse);
    expect(fields[2].keyboardType, TextInputType.visiblePassword);
  });

  testWidgets('login limits email and uses secure password input',
      (tester) async {
    await tester.pumpWidget(buildScreen(const LoginScreen()));

    final fields =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();

    expect(fields, hasLength(2));
    expect(_lengthLimit(fields[0]), AuthFieldConstraints.emailMaxLength);
    expect(fields[1].obscureText, isTrue);
    expect(fields[1].enableSuggestions, isFalse);
    expect(fields[1].autocorrect, isFalse);
    expect(fields[1].keyboardType, TextInputType.visiblePassword);
  });

  testWidgets('Google sign-in is hidden on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(buildScreen(const LoginScreen()));

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('OR'), findsNothing);
      expect(find.text('Sign In'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Google sign-in remains available on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(buildScreen(const LoginScreen()));

      expect(find.text('Continue with Google'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('login error banner can be dismissed immediately',
      (tester) async {
    when(() => repository.authStateChanges)
        .thenAnswer((_) => Stream.value(null));
    when(
      () => repository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthException('unknown'));

    await tester.pumpWidget(buildScreen(const LoginScreen()));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsNothing);
    expect(
      find.byKey(const ValueKey('login_error_banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('login_error_dismiss')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('login_error_dismiss')));
    await tester.pump();

    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });

  testWidgets('login error banner dismisses automatically after ten seconds',
      (tester) async {
    when(() => repository.authStateChanges)
        .thenAnswer((_) => Stream.value(null));
    when(
      () => repository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthException('unknown'));

    await tester.pumpWidget(buildScreen(const LoginScreen()));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });
}

int? _lengthLimit(EditableText field) {
  return field.inputFormatters
      ?.whereType<LengthLimitingTextInputFormatter>()
      .single
      .maxLength;
}
