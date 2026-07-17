## Kuusi Release Notes  
  
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
###   
### 1.0 (12) - 17 Jun 2026  
* 展開中の写真プレビューで pinch zoom できるように変更  
* zoom 中の写真プレビューを drag で移動できるように変更  
* zoom 中はメタ情報 overlay と status badge を非表示にするように変更  
* 写真を閉じた時や表示画像が変わった時に zoom 状態を reset するように変更  
* zoom 中の tap で写真 tile の通常操作が走らないように調整  
###   
### 1.0 (11) - 28 May 2026  
* Premium のストレージ上限を 50GB から 30GB に変更  
* Premium storage 表示と README を 30GB に更新  
* Functions 側の Premium storage quota も 30GB に変更  
* グループの最大メンバー数を 50人 から 15人 に変更  
* Functions 側のグループ最大メンバー数も 15人 に変更  
###   
### 1.0 (10) - 21 May 2026  
* グループ退出処理を Cloud Functions に移行  
* グループオーナーが退出する場合、他のメンバーへ owner を引き継ぐように変更  
* アカウント削除前に Sign in with Apple の再認証を求めるように変更  
* アカウント削除中の loading 表示を追加  
* 新規ユーザー作成時のデフォルト名を整理  
* ユーザープロフィールに email を保存しないように変更  
* Storage rules を追加し、Firebase deploy 設定に含めるように変更  
* Premium のアップロード容量判定を client 申告ではなく server-side の verified Premium cache で確認するように変更  
* StoreKit の signed transaction と renewal info を Functions 側で検証する syncSubscription を追加  
* Premium 購入、キャンセル、期限前、期限切れの transactional email を追加  
* Legal update 用の transactional email を追加  
* Resend email template と送信ログ email_logs を追加  
* Premium 期限前・期限切れメールを送る scheduled Function を追加  
* Legal announcement 作成時に email を送る Firestore trigger を追加  
* Cloud Functions docs と Firebase schema docs を Premium / email / legal announcement に合わせて更新  
* Premium 確認に失敗した場合の upload error message を追加  
* グループ退出とアカウント削除まわりの日本語・英語文言を追加  
* Account deletion の再認証 flow に関する unit test を追加  
###   
### 1.0 (9) - 10 May 2026  
* 写真メタデータを year から編集可能な date に移行  
* フィードの並び順を created_at ではなく写真の date 基準に変更  
* アップロード時の年入力を削除し、アップロード写真には Functions 側で date と created_at を設定  
* 写真編集画面で撮影日相当の日時と hashtags を編集できるように変更  
* 既存写真向けに date = created_at を設定し、旧 year フィールドを削除する migration script を追加  
* Firestore rules と Firebase schema docs を date ベースの写真更新に合わせて更新  
* フィード写真、favourite IDs、グループ別写真件数のローカルキャッシュを追加  
* アップロード直後のフィード表示を改善し、古い写真一覧が戻らないように再読込処理を調整  
* 削除済み写真がキャッシュやアップロード後の更新で復活しないように修正  
* ディスク画像キャッシュの最終アクセス日時を更新し、古い画像キャッシュを定期削除するように変更  
* アカウント削除時にグループ、写真、プロフィール、画像の各ローカルキャッシュをクリア  
* 現在ユーザーのプロフィールをローカルキャッシュし、設定画面の初期表示を改善  
* グループ一覧とグループメンバー一覧のキャッシュを追加  
* 設定画面にグループ更新ボタンを追加  
* グループメンバー一覧に更新ボタンと読み込み状態を追加  
* 公開サイトリンクを kuusi.app に更新  
* 設定 footer の Delete account 下に Send feedback ボタンを追加し、hi@kuusi.app 宛てに件名 Kuusi Feedback のメールを開くように変更  
* アプリアイコンを更新  
* README のアップロード説明を year から date に更新  
###   
### 1.0 (8) - 4 May 2026  
* GroupStore を追加し、フィード・設定・アップロード画面でグループ一覧と選択中グループを共有  
* QRコード参加後にグループ一覧を再取得せず、参加結果のグループを即時追加  
* 既に参加済みのQR招待では専用メッセージを表示  
* フィード側で GroupStore の選択状態と PhotoCollectionViewModel を同期  
* アップロード完了後、返却された FeedPhoto をローカルフィードへ即時反映  
* お気に入り状態のキャッシュを更新・リフレッシュ時に再利用  
* 写真アップロードのFirestore書き込みと使用量更新をiOS直書きから commitPhotoUploadBatch Cloud Functionへ移行  
* iOS側は一時Storageパスへアップロードし、Functions側で最終パスへコピー、Firestore作成、usage_mb 更新、失敗時クリーンアップを実施  
* アップロードサイズ見積もりにタイムアウトとネットワーク不可メッセージを追加  
* iPadのアップロードシート高さを引き上げ  
* QRコード表示前にローディング状態を追加し、QRシートにグループ名を表示  
* Firestore Rulesを追加し、クライアントからの写真作成・削除を禁止  
* 管理通知送信失敗時に admin_notifications へ failed 状態と理由を記録  
* 管理通知の古い sent / failed データをcleanupスクリプト対象に追加  
* READMEとFirebase/Cloud Functionsドキュメントを現在の実装に合わせて更新  
###   
### 1.0 (7) - 2 May 2026  
* フィード広告まわりの安定性を改善し、広告ロード失敗時は ad tile を非表示にするよう修正  
* ネイティブ広告タイルの frame width をガードし、レイアウト崩れを防止  
* メンバー一覧オーバーレイにグループ名を表示するよう UI を改善  
* Ads SDK 導入に伴うビルド設定として module verifier を無効化  
* デバッグ用途として、写真の日付を編集できるフローを EditOverlayView / feed 編集導線に追加  
* プラン表示まわりを更新し、feature list に広告ステータスを追加、文言も調整  
* SubscriptionView のカードサイズを Dynamic Type に合わせて見直し、可読性を改善  
* GroupsSectionView の group cards をアクセシビリティ文字サイズでも崩れにくいよう拡張  
* 日本語ローカライズを追加し、画面文言を Localizable.xcstrings に集約  
* アラートやメッセージ文言も日本語対応し、AppAlert / AppMessage 周辺をローカライズ対応へ更新  
* テストでは message ID の等価性依存を避ける形にリファクタし、関連 UI / ViewModel / message tests を調整  
###   
### 1.0 (6) - 1 May 2026  
* 無料プランのストレージ上限を 1GB に引き下げ  
* フィード広告導入の土台として、無料ユーザー向けのスクエア広告表示を追加  
* 続けてネイティブ広告の読み込みと表示を実装し、FeedView / PhotoGridView 側で広告差し込みフローを整備  
* 広告設定用の AppAdConfiguration と FeedNativeAdTileView を追加  
* ネイティブ広告 UI を調整し、CTA を簡素化、アセット周辺の padding を追加してレイアウトを安定化  
* 広告配信に伴って UMP SDK を導入し、同意取得用の ConsentStore と feed ads 用 consent flow を追加  
* 設定画面・フッター周辺を更新し、広告同意フローに接続  
* グループ参加用の QR カメラスキャンを復旧し、QRCodeScannerView を追加して join flow を再接続  
* 運用系として functions/scripts/cleanup-orphaned-data.js を追加し、孤立データのクリーンアップを可能にした  
* group flow completion、consent / feed ad、QR scanner error 周辺のテストカバレッジを追加し、UI テストラベルも更新  
###   
### 1.0 (5) - 28 Apr 2026  
* フィード画像の読み込みを photoURL ベースから storagePath ベースへ移行  
* CachedRemoteImageView と PhotoTileView を更新し、Storage パスからの画像解決に対応  
* FeedPhoto と関連 ViewModel / UploadService を調整し、新しい画像参照方式を通せるようにした  
* 既存データ移行用に functions/scripts/backfill-photo-storage-paths.js を追加  
* 旧 photoURL フォールバックを削除し、関連するクリーンアップ用スクリプト functions/scripts/remove-legacy-photo-urls.js を追加  
* Cloud Functions / ドキュメントもあわせて更新し、画像参照の新フローに追従  
* フィードのページネーション読み込みを最適化し、不要な read を削減  
* フィード更新時に既存アイテムが消えないように修正し、refresh 中の表示安定性を改善  
* 上記変更にあわせて、Feed / Upload / ViewModel / Model 周辺のテストを更新  
###   
### 1.0 (4) - 25 Apr 2026  
* フィードの表示をiPhone3列/iPad4列に変更  
###   
### 1.0 (3) - 24 Apr 2026  
* info.plistでApp Uses Non-Exempt Encryption=falseを追加 追加したらApp Store Connectにアップロード後の質問入力が不要になった  
###   
### 1.0 (2) - 24 Apr 2026  
* セキュリティと安定性を強化しました  
* グループやアカウント、写真、メンバー管理まわりの処理を改善し、より安全で安定して使えるようにしました  
* グループ招待 QR コードが 24 時間で失効するようになり、招待の安全性が向上しました  
* ロック解除後のセッションを見直し、短時間で再びロックされにくくなりました  
* プッシュ通知の仕組みを強化し、お知らせがより安定して届くようになりました  
* グループの権限に応じて、フィード上で使える写真操作を適切に表示するよう改善しました  
* フィード表示まわりを最適化し、ページ送り時の表示体験を改善しました  
* ハッシュタグ表示の見た目を微調整し、よりすっきりした UI に整えました  
###   
### 1.0 (1) - 16 Apr 2026  
* TestFlight最初のリリース  
