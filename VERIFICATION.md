# 検証記録

2026-10-24にLinux x86_64上で検証しました。使用した版はREADMEと設定ファイルに記載しています。

| 実行した確認 | 結果 |
| --- | --- |
| `cargo fmt --all -- --check` | 成功しました |
| `cargo clippy --locked --all-targets -- -D warnings` | 成功しました |
| `cargo test --locked` | 境界値・65,536組の入力・文書内の使用例が成功しました |
| `cargo test --locked --release` | 同じテストが成功しました |
| `bash scripts/prove.sh` | Rustから再生成し、三つの定理と公理の検査に成功しました |
| `bash scripts/verify.sh` | 生成物と固定ファイルに差分がないことを含め、成功しました |
| `python3 scripts/check_mutations.py` | 比較条件を壊した版と減算を加算にした版の両方で、Leanが未解決の証明目標を報告しました |

公理の検査結果は三つの定理とも`[propext, Classical.choice, Quot.sound]`でした。

この実行環境ではプロセス番号と`/proc`の対応に制約があり、Leanの実行ファイルの場所の取得がそのままでは失敗しました。実行時だけ、自分自身の実行ファイルを調べる`/proc/<自分の番号>/exe`への参照を、同じ情報を返す`/proc/self/exe`への参照に置き換えて検証しています。Leanの証明検査器、証明、依存ライブラリの内容は変更していません。この環境固有の補助処理はプロジェクトに含めていません。

GitHubの指定リポジトリは現在の接続から404となり、pushとGitHub Actions上の実行は未実施です。ワークフローはローカルで成功した同じ検証コマンドを呼び出す構成として用意しています。
