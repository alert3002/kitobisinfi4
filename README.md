# Китоби синфи 4 (Flutter)

Codemagic / iOS:

```
flutter build ipa --flavor sinf4 --release --dart-define=GRADE=4
```

Android:

```
flutter build appbundle --flavor sinf4 --release --dart-define=GRADE=4
```

Bundle ID: `com.sinfho.sinf4`

# Китобҳои мактабӣ (Flutter)

Як код, 11 барномаи алоҳида (синфи 1–11). Китобҳо аз як API/админка: https://book.1week.tj/

| Flavor | Номи барнома | Package |
| --- | --- | --- |
| sinf1 … sinf11 | Синфи 1 … Синфи 11 | com.sinfho.sinf1 … com.sinfho.sinf11 |

```powershell
cd C:\Users\ALIJOn\Desktop\sinfho\flutter

# Тест: синфи 5
.\tool\run.ps1 5

# APK барои Play Store: синфи 5
.\tool\build_apk.ps1 5

# Ҳамаи 11 APK
.\tool\build_apk.ps1 -All
```

Бе flavor кор намекунад:

```powershell
flutter run --flavor sinf1 --dart-define=GRADE=1
```
