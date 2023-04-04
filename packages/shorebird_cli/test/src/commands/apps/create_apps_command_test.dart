import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shorebird_cli/src/auth/auth.dart';
import 'package:shorebird_cli/src/commands/commands.dart';
import 'package:shorebird_code_push_client/shorebird_code_push_client.dart';
import 'package:test/test.dart';

class _MockArgResults extends Mock implements ArgResults {}

class _MockHttpClient extends Mock implements http.Client {}

class _MockAuth extends Mock implements Auth {}

class _MockCodePushClient extends Mock implements CodePushClient {}

class _MockLogger extends Mock implements Logger {}

class _MockAccessCredentials extends Mock implements AccessCredentials {}

void main() {
  group('create', () {
    const appId = 'app-id';
    const displayName = 'Example App';
    final credentials = _MockAccessCredentials();

    late ArgResults argResults;
    late http.Client httpClient;
    late Auth auth;
    late Logger logger;
    late CodePushClient codePushClient;
    late CreateAppCommand command;

    setUp(() {
      argResults = _MockArgResults();
      httpClient = _MockHttpClient();
      auth = _MockAuth();
      logger = _MockLogger();
      codePushClient = _MockCodePushClient();
      command = CreateAppCommand(
        auth: auth,
        buildCodePushClient: ({
          required http.Client httpClient,
          Uri? hostedUri,
        }) {
          return codePushClient;
        },
        logger: logger,
      )..testArgResults = argResults;

      when(() => auth.credentials).thenReturn(credentials);
      when(() => auth.client).thenReturn(httpClient);
    });

    test('returns correct description', () {
      expect(command.description, equals('Create a new app on Shorebird.'));
    });

    test('returns no user error when not logged in', () async {
      when(() => auth.credentials).thenReturn(null);
      final result = await command.run();
      expect(result, ExitCode.noUser.code);
    });

    test('prompts for app name when not provided', () async {
      when(
        () => logger.prompt(any(), defaultValue: any(named: 'defaultValue')),
      ).thenReturn(displayName);
      await command.run();
      verify(
        () => logger.prompt(any(), defaultValue: any(named: 'defaultValue')),
      ).called(1);
      verify(
        () => codePushClient.createApp(displayName: displayName),
      ).called(1);
    });

    test('uses provided app name when provided', () async {
      when(() => argResults['app-name']).thenReturn(displayName);
      await command.run();
      verifyNever(() => logger.prompt(any()));
      verify(
        () => codePushClient.createApp(displayName: displayName),
      ).called(1);
    });

    test('returns success when app is created', () async {
      when(() => argResults['app-name']).thenReturn(displayName);
      when(
        () => codePushClient.createApp(displayName: displayName),
      ).thenAnswer((_) async => const App(id: appId, displayName: displayName));
      final result = await command.run();
      expect(result, ExitCode.success.code);
    });

    test('returns software error when app creation fails', () async {
      final error = Exception('oops');
      when(() => argResults['app-name']).thenReturn(displayName);
      when(
        () => codePushClient.createApp(displayName: displayName),
      ).thenThrow(error);
      final result = await command.run();
      expect(result, ExitCode.software.code);
      verify(() => logger.err('$error')).called(1);
    });
  });
}
