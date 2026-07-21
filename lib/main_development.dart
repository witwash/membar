import 'package:membar/app/app.dart';
import 'package:membar/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
