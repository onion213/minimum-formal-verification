# Rustの実装をLean 4で証明する最小プロジェクト

残量から使用量を引く関数を一つだけ持つRustのcrateです。RustからLeanの定義を自動生成し、**その生成された関数**について仕様を満たすことを証明します。Rust側の依存crateはありません。検証用にはhax、Charon、Aeneas、Leanとその依存ライブラリを使います。

```rust
pub fn spend(balance: u32, amount: u32) -> Option<u32> {
    if amount <= balance {
        Some(balance - amount)
    } else {
        None
    }
}
```

`spend(10, 3)`は`Some(7)`、`spend(10, 10)`は`Some(0)`、`spend(10, 11)`は`None`です。外部の状態を変更しない純粋な関数なので、残量を保存する処理や同時実行の制御は題材に含みません。

## 動かす

macOSのApple Silicon、またはLinuxのx86_64 / aarch64を想定しています。Git、Cコンパイラ、Python 3.10以上、[rustup](https://rustup.rs/)、[elan](https://github.com/leanprover/elan)を用意し、`cargo`と`lake`をPATHから実行できるようにしてください。WindowsではWSLを使います。

```sh
git clone https://github.com/onion213/minimum-formal-verification.git
cd minimum-formal-verification

# Rustはrust-toolchain.tomlの指定が自動で選ばれます。
cargo install --locked cargo-hax --version 0.4.2

# 初回のみ。Leanの指定版と、依存ライブラリのコンパイル済みファイルを取得します。
(cd proofs/lean && lake exe cache get)

# テスト → Rustから再生成 → 証明 → 公理検査 → 生成物の差分検査
bash scripts/verify.sh
```

初回はRustの解析用部品とLeanの数学ライブラリを取得するため、数GBの空き容量と時間が必要です。関数自体は小さくても、初回の環境構築は小さくありません。以後は取得済みの部品を再利用します。

検証対象を編集したときは`bash scripts/prove.sh`で再生成と証明を実行します。生成物を確認・コミットした後に`bash scripts/verify.sh`を実行してください。後者は生成物の未コミット差分も失敗として扱います。`.github/workflows/verify.yml`も同じコマンドを実行します。

## 何を証明するか

[ProofObligations.lean](proofs/lean/MinimumFormalVerification/Verification/ProofObligations.lean)が、人間が書く仕様と証明の全体です。仕様は次の関係として書きます。

```lean
def SpendSpec (balance amount : Nat) (result : core.option.Option U32) : Prop :=
  match result with
  | .Some remaining => remaining.val + amount = balance
  | .None => balance < amount
```

成功なら「返した残量と使用量の和が元の残量に等しい」、失敗なら「残量が使用量より小さい」という意味です。`.val`は32ビット整数を自然数として読む操作です。この和は上限のない自然数の和なので、整数の桁あふれで等式が偶然成立することはありません。

主定理`spend_correct`は次の形です。

```lean
theorem spend_correct (balance amount : U32) :
    ∃ result, minimum_formal_verification.spend balance amount = .ok result ∧
      SpendSpec balance.val amount.val result := by
  -- 完成した証明はリンク先のファイルにあります。
```

任意の二つの`u32`入力に対し、正常な返り値が存在し、それが仕様を満たすことを主張します。入力に追加の前提はありません。これにより、終了すること、異常終了しないこと、返り値が正しいことを同時に証明します。`Some`の場合の等式と残量の非負性から、使用量が元の残量以下であることも従います。

| 定理 | 保証する内容 |
| --- | --- |
| `spend_correct` | 全入力で正常に終了し、仕様を満たします |
| `spend_none_iff` | `None`を返すことと残量不足が同値です |
| `spend_conserves` | 成功時には残量と使用量の和が保存されます |

証明は、使用量が残量以下かどうかで場合分けします。引き算をする側では、Aeneasが証明済みの整数演算の性質を使って、範囲外の減算が起きないことと差が正しいことを導きます。もう一方では正常に`None`を返すことを確認します。`omega`は自然数・整数の加減算や不等式について、Leanが検査できる証明を構成する手続きです。

## Rustと形式モデルをどう一致させるか

`cargo hax ... into lean`が、Rustコンパイラの中間表現をCharonに渡し、AeneasでLeanの関数に変換します。haxはこの処理と依存ツールの取得をまとめる窓口です。

| ファイル | 役割 | 更新方法 |
| --- | --- | --- |
| [src/lib.rs](src/lib.rs) | 実行するRustの実装 | 編集します |
| [Extraction/Funs.lean](proofs/lean/MinimumFormalVerification/Extraction/Funs.lean) | Rustから変換した実装の形式モデル | 毎回自動生成します |
| [Verification/ProofObligations.lean](proofs/lean/MinimumFormalVerification/Verification/ProofObligations.lean) | 要求する性質と、その証明 | 編集します |
| [Verification/Audit.lean](proofs/lean/MinimumFormalVerification/Verification/Audit.lean) | 証明が依存する公理の検査 | 検証時に実行します |

生成される`spend`の型は`U32 → U32 → RustM (core.option.Option U32)`です。`RustM`には正常終了の`ok`、異常終了の`fail`、終了しない`div`があります。Rustの`None`は業務上の失敗を表す普通の返り値なので、`ok None`に対応します。主定理が`ok result`との等式を示すことで、`fail`と`div`を排除します。

検証の入口は常に現在のRustを再変換します。保存済みのLeanモデルだけを検査して、Rustの変更を見逃す構成にはしていません。さらに`verify.sh`は生成物と依存関係の固定ファイルについて、新規ファイルも含めてGitの差分を検査します。生成物を手で修正しても、次の再生成で上書きされます。

**ただし、自動生成は変換器自体の正しさの証明ではありません。** このプロジェクトでLeanが証明するのは、生成されたLean関数と仕様の関係です。その関数がRustの意味を正しく表すことは、Rustコンパイラ、Charon、Aeneas、haxの変換処理と型・演算のモデルを信頼しています。特定の変換結果ごとに、Rustの意味との一致をLeanで再証明する構成ではありません。

Rustのコンパイルと抽出は同じ`nightly-2026-08-18`を使います。対象関数には条件付きコンパイル、外部呼び出し、`unsafe`、動的メモリ確保がなく、抽出時だけ別実装になる設定もありません。将来これらを追加した場合は、この対応関係と証明範囲の見直しが必要です。生成された`Assumptions/FunsExternal.lean`は空のひな型で、この例で独自の外部関数の仮定を補ってはいません。

## 証明の検査と、残る信頼

Leanの証明を構成する手続きが誤った答えを出しても、最終的な証明項がLeanの核となる検査器を通らなければ受理されません。一方、`sorry`を使うと未完成の証明を仮定として通せるため、単に`lake build`が成功するだけでは不十分です。

このプロジェクトでは警告をエラーにし、さらに`Audit.lean`で三つの定理が**間接的に依存するものも含めて**公理を調べます。許可するのは`propext`、`Classical.choice`、`Quot.sound`だけです。`sorryAx`、独自に追加した公理、ネイティブ実行結果を公理として使う依存は拒否します。今回の三つの証明では、実際にこの標準的な三つだけが使われています。

| 段階 | このプロジェクトでの扱い |
| --- | --- |
| 欲しい振る舞い → `SpendSpec` | 人間が仕様の意味と十分さを確認します |
| Rust → 生成されたLean関数 | 版を固定した変換器を使い、毎回再生成します。変換器の実装は信頼します |
| 生成されたLean関数 → `SpendSpec` | Leanの検査器で全入力に対する証明を検査します |
| Rust → 実行ファイル → 実機での実行 | コンパイラ、実行環境、ハードウェアを信頼します。ここを形式証明してはいません |

数学的な仕様に対する証明と、機械語まで含めた全工程の証明は範囲が異なります。また、この例が証明するのは`spend`だけであり、将来追加した関数が自動的に証明済みになるわけではありません。

`tests/spend.rs`には境界値と小さな入力領域65,536組の通常のテストがあります。これは実行時の補助確認です。Leanの証明は、2^64組ある全入力を列挙せず、任意の入力についての論証として検査します。減算の範囲外計算が起きないことを示すため、Rustのdebugとreleaseでの桁あふれ時の挙動の違いも、この関数の正しい実装では問題になりません。

## 壊して確かめる

```sh
python3 scripts/check_mutations.py
```

まず元の実装で証明が通ることを確認します。その後、一時ディレクトリで`<=`を`<`に変更した版と、`balance - amount`を`balance + amount`に変更した版を作り、それぞれRustから再変換します。Rustのテストに頼らず、Leanの証明が拒否することを確認します。元のファイルは変更しません。ダウンロードや環境構築の失敗は、証明による拒否として数えません。

前者は`spend(10, 10)`が誤って`None`になる変更です。後者は`spend(10, 3)`が`Some(13)`となり、大きな入力では桁あふれも起きる変更です。どちらもRustとしてはコンパイルできますが、同じ仕様の証明は通りません。

手動で体験する場合は`src/lib.rs`の`<=`を`<`に変更し、`bash scripts/prove.sh`を実行します。比較を戻して同じコマンドを実行すれば証明が再び通ります。`lake build`だけを直接実行するとRustの再変換を省いてしまうので、この実験には必ず`prove.sh`を使ってください。

## 固定した環境と参考資料

| 部品 | 固定した版 |
| --- | --- |
| Rust / rustc | `nightly-2026-08-18` |
| cargo-hax | `0.4.2` |
| Charon | `nightly-2026.09.02` |
| Aeneas | `build-183e4f0` |
| Lean | `4.31.0` |
| hax-lean | `v0.3.30` |

Leanの依存関係は`proofs/lean/lake-manifest.json`でコミット単位に固定しています。変換ツールの指定は`hax.toml`にあります。設定を変更した場合は再生成・証明・実装を壊す検査までやり直します。

変換の入口と生成物の構成は[haxの公式手順](https://hax.cryspen.com/manual/lean/quick_start/)に、ツールの版の固定は[管理手順](https://hax.cryspen.com/manual/tools/)に説明があります。変換の考え方と対応範囲は[Aeneasの説明](https://github.com/AeneasVerif/aeneas)を参照してください。
