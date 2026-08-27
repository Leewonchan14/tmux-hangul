# tmux-hangul

`tmux-hangul`은 tmux의 `prefix` key table에 등록된 영문 소문자 단축키를 두벌식 한글 자모 단축키로 자동 확장하는 TPM 플러그인입니다.

영문 binding을 변경하지 않고 한글 binding을 추가합니다.

```text
prefix + n  →  next-window
prefix + ㅜ  →  next-window
```

## 특징

- 현재 tmux `prefix` key table을 기준으로 동기화
- 두벌식 영문 소문자 26개 지원
- 기존 영문 binding 유지
- `-r` repeat flag 보존
- `command-prompt`, 중괄호 command, 따옴표, 세미콜론이 포함된 binding 처리
- 한글 key 충돌 시 기본적으로 건너뛰기
- 플러그인이 생성한 binding만 상태 파일로 추적
- 사용자가 수정한 binding은 `sync`와 `clear`에서 보존
- 초기 로드 시 자동 동기화
- 수동 동기화와 dry-run 지원

## 요구 사항

- tmux
- Bash
- 두벌식 한글 입력기

현재 tmux `3.6b`에서 검증했습니다.

## 설치

### TPM

`.tmux.conf`에 plugin을 추가합니다.

```tmux
set -g @plugin 'Leewonchan14/tmux-hangul'

set -g @hangul_prefix_auto_sync on
set -g @hangul_prefix_conflict skip
set -g @hangul_prefix_layout dubeolsik
set -g @hangul_prefix_sync_key H

run '~/.tmux/plugins/tpm/tpm'
```

자동 동기화를 사용할 때는 다른 plugin보다 `tmux-hangul`을 `@plugin` 목록의 마지막에 두는 것을 권장합니다. TPM은 plugin 디렉터리의 `*.tmux` 파일을 순서대로 실행하므로, 먼저 실행된 경우 뒤에서 추가되는 binding을 놓칠 수 있습니다.

### 로컬 경로에서 직접 로드

```tmux
run-shell '/Users/twoone14/Desktop/project/ai-projects/tmux-hangul/tmux-hangul.tmux'
```

## 사용법

설정 파일을 다시 읽은 뒤 자동 동기화합니다.

```bash
tmux source-file ~/.tmux.conf
```

자동 동기화를 기다리지 않고 직접 실행할 수도 있습니다.

```bash
~/.tmux/plugins/tmux-hangul/bin/tmux-hangul sync --dry-run
~/.tmux/plugins/tmux-hangul/bin/tmux-hangul sync
```

생성된 한글 binding을 안전하게 제거하려면 다음을 실행합니다.

```bash
~/.tmux/plugins/tmux-hangul/bin/tmux-hangul clear
```

기본 수동 동기화 키는 `prefix + H`입니다. `H`가 이미 사용 중이면 기존 binding을 덮어쓰지 않고 수동 키를 등록하지 않습니다.

## 두벌식 매핑

```text
q → ㅂ    w → ㅈ    e → ㄷ    r → ㄱ    t → ㅅ
y → ㅛ    u → ㅕ    i → ㅑ    o → ㅐ    p → ㅔ
a → ㅁ    s → ㄴ    d → ㅇ    f → ㄹ    g → ㅎ
h → ㅗ    j → ㅓ    k → ㅏ    l → ㅣ
z → ㅋ    x → ㅌ    c → ㅊ    v → ㅍ    b → ㅠ
n → ㅜ    m → ㅡ
```

현재 버전은 단일 소문자 ASCII key만 매핑합니다. 다음 key는 변환하지 않습니다.

- `C-`, `M-`, `S-` 조합
- 방향키와 Function key
- 숫자와 기호
- 대문자 및 Shift 조합
- `root`, `copy-mode`, `copy-mode-vi` 등 `prefix`가 아닌 key table

숫자, 기호, modifier key는 두벌식 한글 자모와 1:1 대응하지 않거나 터미널과 입력기 조합에 따라 전달 방식이 달라질 수 있습니다.

## 설정 옵션

| 옵션 | 기본값 | 설명 |
| --- | --- | --- |
| `@hangul_prefix_layout` | `dubeolsik` | 키보드 레이아웃. 현재 `dubeolsik`만 지원 |
| `@hangul_prefix_conflict` | `skip` | 한글 target key가 이미 사용 중일 때의 처리 |
| `@hangul_prefix_auto_sync` | `on` | plugin 로드 시 자동 동기화 |
| `@hangul_prefix_sync_key` | `H` | 수동 동기화에 사용할 prefix key |
| `@hangul_prefix_state_dir` | `~/.local/state/tmux-hangul` | 생성 binding 상태 저장 디렉터리 |

`$XDG_STATE_HOME`이 설정되어 있으면 상태 디렉터리는 `$XDG_STATE_HOME/tmux-hangul`입니다.

### 충돌 정책

- `skip`: 사용자 binding을 보존하고 해당 매핑을 건너뜁니다.
- `overwrite`: 기존 target binding을 덮어씁니다. 기존 사용자 command는 백업하지 않으므로 주의해야 합니다.
- `error`: 충돌을 출력하고 최종적으로 non-zero 상태를 반환합니다.

기본값인 `skip`을 권장합니다.

## 동작 방식

1. `tmux list-keys -T prefix`로 현재 prefix binding을 읽습니다.
2. 단일 소문자 영문 key만 선별합니다.
3. 두벌식 대응표로 한글 target key를 계산합니다.
4. `-r` flag와 command 본문을 유지한 `bind-key` 명령을 만듭니다.
5. tmux 자체 parser가 처리하도록 임시 설정 파일을 `source-file`합니다.
6. 생성한 binding의 target, repeat 여부, command를 상태 디렉터리에 기록합니다.

`list-keys`는 안정적인 JSON API가 아니므로 command를 단순히 공백으로 나누지 않습니다. command 본문은 tmux 출력에서 추출해 source-file로 다시 전달합니다.

## 안전 장치

- 영문 원본 binding을 삭제하거나 수정하지 않습니다.
- 한글 target에 사용자 binding이 있으면 기본적으로 건너뜁니다.
- 재동기화 시 상태 파일의 command와 현재 binding이 일치할 때만 plugin 소유로 판단합니다.
- 사용자가 생성된 한글 binding을 수정하면 이후 `sync`와 `clear`에서 해당 binding을 보존합니다.
- 자동 동기화 중 발생한 summary는 숨기지만, 수동 실행에서는 결과를 출력합니다.

## 테스트

테스트는 현재 tmux server를 사용하지 않고 별도의 tmux socket과 임시 상태 디렉터리를 생성합니다.

```bash
bash -n tmux-hangul.tmux bin/tmux-hangul tests/test.sh
bash tests/test.sh
```

테스트에는 다음 동작이 포함됩니다.

- dry-run 계획 출력
- 일반 binding 복제
- repeat binding 보존
- 복합 command와 quoting 보존
- 한글 binding 충돌 보호
- source command 변경 시 재동기화
- source 삭제 시 생성 binding 제거
- 사용자 수정 binding 보호
- TPM entrypoint의 수동 key와 자동 동기화

## 제한 사항

한글 입력기가 실제로 compatibility jamo를 tmux에 전달해야 한글 binding이 실행됩니다. 터미널, macOS 입력기, SSH, nested tmux 조합에 따라 동작이 달라질 수 있습니다.

자동 동기화를 사용할 때 다른 TPM plugin이 나중에 binding을 추가하면 해당 binding이 누락될 수 있습니다. 이 경우 수동으로 다시 실행합니다.

```bash
~/.tmux/plugins/tmux-hangul/bin/tmux-hangul sync
```
