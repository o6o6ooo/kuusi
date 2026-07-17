# Kuusi Release Notes

初回 App Store リリース以降の TestFlight ビルドと正式リリースの変更記録です。正式リリースには 🌟 を付け、App Store Connect のリリースノートを併記します。

### 1.3 (18) - 3 Jul 2026 🌟  
* App Store の共有リンクを正式な Kuusi ページに更新  
* 主要ボタン、フィード操作、設定カード、プロフィールアバター、色スウォッチなどを glassEffect ベースのスタイルに整理  
* ボタンの無効状態、ローディング状態、サイズ、文字色を統一  
* 初回サインイン後に表示するオンボーディングを追加  
* 空のフィード、プロフィール設定、グループ作成/参加、アップロードの流れを4ページのスライドで案内  
* オンボーディング画像にポイント表示とメニュー表示のループ切り替えを追加し、操作箇所が分かりやすくなるよう調整  
* オンボーディングのページインジケーターとボタンをガラススタイルに合わせて調整  
* 設定画面からオンボーディングをもう一度見られるボタンを追加  
* 再インストール後はサインイン画面から始まるように認証状態をリセット  
* Crashlytics に画面名や主要操作のカスタムキーを追加し、クラッシュ調査に必要な情報を改善  
* Debug ビルドでも dSYM を生成するようにして、クラッシュログのシンボリケーションを改善  
  
**App Store Connect Release Notes - English UK**  
```
This update introduces a first-launch onboarding flow after sign-in, helping new and returning users set up their profile, create or join a group, and start uploading photos.
It also refines the app’s glass-style interface across buttons, feed controls, settings cards, avatars, colour swatches, and loading states for a more consistent experience.
Reinstalling the app now starts from the sign-in screen again, and this release includes Crashlytics and debug symbol improvements to help investigate issues more reliably.

```
  
**App Store Connect Release Notes - Japanese**  
```
サインイン後に表示される初回オンボーディングを追加し、プロフィール設定、グループの作成または参加、写真のアップロードまでの流れを分かりやすく案内するようにしました。
ボタン、フィード操作、設定カード、アバター、色スウォッチ、ローディング状態などのガラス風UIも見直し、アプリ全体の見た目と操作感をより統一しています。
再インストール後はサインイン画面から始まるように調整し、問題調査のためのCrashlytics情報とデバッグシンボル生成も改善しました。

```
  
### 1.3 (17) - 28 Jun 2026  
* App Store の共有リンクを正式な Kuusi ページに更新  
* 主要なカプセルボタンを標準の glassEffect ベースのスタイルに整理  
* 主要ボタンの無効状態とローディング状態の見た目を統一  
* フィード上部・下部の丸ボタンと閉じるボタンのガラススタイルを整理  
* 設定画面のアイコンボタンサイズを調整  
* グループカード、設定ローディング表示、プランカードを標準のガラスカードスタイルに変更  
* ストレージ使用量バーをガラススタイルに変更  
* プロフィール、グループメンバー、フィード上のプロフィールバッジをガラススタイルのアバター表示に変更  
* 背景色ピッカーのスウォッチをガラススタイルに変更し、選択状態をチェックマークで分かりやすく表示  
* 招待QRコードの読み取りをiPhoneのカメラでも可能に  
  
### 1.2 (16) - 21 Jun 2026 🌟  
* アップロードオーバーレイにヘッダーと閉じるボタンを追加  
* アップロードボタンをヘッダー右上に移動  
* アップロードシートを large detent に変更  
* 選択写真の削除ボタンをガラススタイルに調整  
* 編集オーバーレイにヘッダー、閉じるボタン、保存ボタンを追加  
* 編集オーバーレイに写真プレビューを表示するように変更  
* フィード設定ボタンの境界線と影を調整  
* 主要ボタンを glassEffect ベースのスタイルに変更  
  
**App Store Connect Release Notes - English UK**  
```
Added captions to photo metadata and improved photo previews with clearer metadata and author icons.
This update also refines the upload and edit screens with clearer headers, larger sheets, updated glass-style controls, and a photo preview while editing.
It includes reliability, localisation, and test coverage improvements as well.

```
  
**App Store Connect Release Notes - Japanese**  
```
写真のメタデータにキャプションを追加し、写真プレビューでメタデータや投稿者アイコンをより分かりやすく表示するよう改善しました。
アップロード画面と編集画面も見直し、ヘッダー、シート、ガラス風コントロール、編集中の写真プレビューを改善しています。
そのほか、安定性、ローカライズ、テストカバレッジも向上しました。

```
  
### 1.2 (15) - 20 Jun 2026  
* 写真メタデータにキャプションを追加  
* 写真プレビューのメタデータ表示を調整  
* 写真プレビューに投稿者アイコンを表示するように変更  
* 写真プレビュー内の投稿者アイコンサイズを調整  
* caption まわりの Swift concurrency warning を解消  
* missing localisability checks を有効化  
* UI テストを現行の FeedView / Settings sheet 構成に合わせて更新  
* UI テスト用の signed-in fixture を追加  
* GroupStore、AppState、SettingsProfileViewModel、Feed inline ad のテストを追加・補強  
###   
### 1.1 (14) - 19 Jun 2026 🌟  
* 起動時にサインイン状態を確認するローディング画面を追加  
* サインイン済みユーザーが起動時に一瞬サインイン画面へ遷移する表示を改善  
* 無効状態のボタンのコントラストを調整  
* AdMob の SKAdNetwork identifiers を追加  
* 未使用の Localizable 文字列を削除  
* **App Store Connect Release Notes**  
```
Added a loading screen while Kuusi checks your sign-in state, making launch transitions feel smoother.
Refined some button styling and updated internal ad configuration.

```
  
### 1.0 (13) - 18 Jun 2026 🌟  
* 初回リリース  
* サブスクリプション画面に Terms of Use (EULA) と Privacy Policy へのリンクを追加  
* サブスクリプションが年単位で自動更新される旨を英語・日本語で表示するように変更  
