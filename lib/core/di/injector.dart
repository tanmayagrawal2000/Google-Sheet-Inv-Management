import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/cubit/user_management_cubit.dart';
import '../../features/auth/cubit/user_session_cubit.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/auth/data/secure_token_store.dart';
import '../../features/auth/data/user_repository.dart';
import '../../features/inventory/data/catalog_repository.dart';
import '../../features/inventory/data/damage_repository.dart';
import '../../features/inventory/data/sheets_repository.dart';
import '../../features/issues/data/issue_repository.dart';
import '../../features/rooms/data/drive_repository.dart';
import '../network/google_apis.dart';
import '../theme/theme_cubit.dart';

final getIt = GetIt.instance;

/// Wires up services and repositories. Cubits are created at the widget tree
/// via BlocProvider, pulling their dependencies from here.
void configureDependencies(SharedPreferences prefs) {
  getIt
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerLazySingleton<ThemeCubit>(() => ThemeCubit(getIt()))
    ..registerLazySingleton<SecureTokenStore>(SecureTokenStore.new)
    ..registerLazySingleton<AuthService>(() => GsiAuthService(getIt()))
    ..registerLazySingleton<GoogleApis>(() => GoogleApis(getIt()))
    ..registerLazySingleton<DriveRepository>(() => DriveRepository(getIt()))
    ..registerLazySingleton<SheetsRepository>(() => SheetsRepository(getIt()))
    ..registerLazySingleton<IssueRepository>(() => IssueRepository(getIt()))
    ..registerLazySingleton<DamageRepository>(() => DamageRepository(getIt()))
    ..registerLazySingleton<CatalogRepository>(
        () => CatalogRepository(getIt(), getIt(), getIt()))
    ..registerLazySingleton<UserRepository>(
        () => UserRepository(getIt(), getIt()))
    ..registerLazySingleton<UserSessionCubit>(
        () => UserSessionCubit(getIt()))
    ..registerFactory<UserManagementCubit>(
        () => UserManagementCubit(getIt()));
}
