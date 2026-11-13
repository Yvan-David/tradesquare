import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/api/catalog_store.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.hasSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  try {
    await CatalogStore.instance.ensureLoaded();
  } catch (_) {
    // App still launches; screens show empty states until Supabase/API is up.
  }
  runApp(const TradeSquareApp());
}
