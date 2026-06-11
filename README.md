# リフティングチャレンジ

リフティングチャレンジは、サッカーの練習記録をチームやグループで管理するFlutterアプリです。
Googleログインで利用し、Firebaseにリフティング回数、動画、サッカーノート、戦術ボードを保存します。

## アプリの概要

このアプリでは、日々のリフティング回数を記録しながら、練習や試合の振り返りも一緒に残せます。
グループ単位でデータを管理するため、招待コードを使って同じチームのメンバーと記録を共有できます。

主な利用シーンは次のとおりです。

- 個人のリフティング記録と自己ベストの管理
- チーム内でのランキング確認
- 練習ノート・試合ノートの蓄積
- 戦術ボードの作成と保存
- リフティング動画や戦術ボードの見返し

## 機能一覧

- Googleアカウントでのログイン
- グループ作成と招待コードによる参加
- リフティング回数の記録
- 録画またはギャラリー選択による動画添付
- 自己ベスト表示
- 全体ランキングとフォロー中ユーザーのランキング表示
- フォロー機能
- 練習ノート・試合ノートの作成、編集、削除
- 目標、課題、よかった点、改善点の記録
- 戦術ボードの作成、編集、保存
- 保存済み戦術ボードと動画記録のアルバム表示
- プロフィール名の編集

## 使用技術

- Flutter
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Google Sign-In
- Gemini API

## 起動方法

### 1. 前提条件

以下をインストールしておきます。

- Flutter SDK
- Android Studio または VSCode
- Android Emulator、または実機端末
- Firebase CLI

Flutterのセットアップ状態は次のコマンドで確認できます。

```bash
flutter doctor
```

### 2. 依存パッケージの取得

リポジトリのルートで次を実行します。

```bash
flutter pub get
```

### 3. Firebase設定

このリポジトリにはFlutterFireの設定ファイルが含まれています。
別のFirebaseプロジェクトで動かす場合は、Firebase CLIとFlutterFire CLIで設定を作り直してください。

```bash
firebase login
flutterfire configure
```

AndroidでGoogleログインを使う場合は、Firebase ConsoleでSHA-1 / SHA-256の登録も確認してください。

### 4. アプリの起動

接続中の端末またはエミュレーターを確認します。

```bash
flutter devices
```

Androidで起動する場合は次を実行します。

```bash
flutter run
```

iOSで起動する場合は、macOS環境で次を実行します。

```bash
flutter run -d ios
```

## 開発時によく使うコマンド

```bash
# 静的解析
flutter analyze

# テスト
flutter test

# Androidビルド
flutter build apk
```

## 補足

- FirestoreとStorageを使用するため、Firebaseプロジェクト側のルール設定が必要です。
- 動画添付機能では、端末のカメラ・写真ライブラリへの権限が必要です。
- Gemini APIを利用する機能を動かす場合は、必要なAPIキーやFirebase側の設定を確認してください。
