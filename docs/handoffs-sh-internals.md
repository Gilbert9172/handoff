# handoffs.sh 동작 원리

`scripts/handoffs.sh`는 handoff 플러그인의 유일한 실행 코드다. 네 개 skill(`save`, `list`, `resume`, `delete`)과 `UserPromptSubmit` 훅이 모두 이 스크립트 하나를 호출하므로, 저장 경로를 정하는 방식과 컨텍스트 사용량을 계산하는 방식이 호출 지점마다 갈라지지 않는다. 이 문서는 그 세 서브커맨드가 각각 무엇을 어떻게 계산하는지, 특히 컨텍스트 사용량(`used`)을 Claude와 Codex 두 포맷에서 어떻게 구하는지 설명한다.

읽고 나면 다음을 알 수 있다.

- handoff 문서가 어느 디렉토리에 저장되고 그 경로가 어떻게 결정되는지
- `scan`이 문서에서 Goal 문단만 뽑아내는 방식
- `context-check`가 transcript에서 `used`를 구하는 두 가지 계산식과, 두 식이 왜 다르게 생겼는데도 같은 값을 뜻하는지
- 훅이 조용히 종료(exit 0)하는 지점과 그 이유

전제 지식은 POSIX sh, `awk`, `sed` 수준이면 충분하다. 설계 배경은 `docs/provider-neutral-handoff-design.md`에 있고, 이 문서는 그 설계가 코드로 어떻게 내려앉았는지를 다룬다.

## 실행 계약

스크립트는 POSIX sh로 작성했고(`#!/bin/sh`), 첫 줄에서 `set -eu`로 미정의 변수와 실패한 명령을 차단한다. 외부 의존성은 `git`, `stat`, `awk`, `sed`, `grep`, `tail` 뿐이며 `jq` 같은 JSON 파서는 쓰지 않는다. 훅은 사용자의 모든 프롬프트마다 실행되므로 설치 부담과 실행 지연을 최소화한 선택이다.

| 서브커맨드 | 호출 지점 | 출력 | 종료 코드 |
| --- | --- | --- | --- |
| `dir` | `save`, `resume`, `delete` skill | handoff 디렉토리 절대경로 1줄 | 0 |
| `scan` | `list`, `save`, `resume`, `delete` skill | handoff 1개당 TSV 1줄 | 0 |
| `context-check` | `UserPromptSubmit` 훅 | 훅 JSON 1줄 또는 무출력 | 0 |
| 그 외 | — | usage(stderr) | 2 |

훅 등록은 `hooks/hooks.json` 한 곳에서 하며, 타임아웃 10초를 준다.

```json
"command": "sh \"${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh\" context-check"
```

## 저장 경로 결정

세 서브커맨드가 공유하는 상단 3줄(`scripts/handoffs.sh:8-10`)이 이 프로젝트의 handoff 디렉토리를 계산한다.

```sh
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
slug=$(printf '%s' "$root" | tr '/' '-')
dir="$HOME/.handoffs/$slug"
```

기준점은 git 저장소 루트다. `git rev-parse`가 실패하면(저장소가 아니면) 현재 디렉토리로 떨어진다. 저장소 안에서는 하위 디렉토리 어디서 호출하든 같은 `dir`이 나오므로, 같은 프로젝트의 handoff가 작업 위치에 따라 흩어지지 않는다.

프로젝트 식별자는 절대경로의 `/`를 `-`로 치환해 만든다. `/Users/gilbert/gilbert/handoff`는 선행 슬래시까지 치환돼 `-Users-gilbert-gilbert-handoff`가 된다. 이 slug 알고리즘 자체는 Claude Code가 `~/.claude/projects/`를 만드는 규칙과 같지만, 저장 위치는 그 디렉토리 **아래가 아니다** — `~/.handoffs/`는 host 중립 최상위 디렉토리로 분리돼 있어, Claude든 Codex든 같은 스크립트가 같은 slug를 계산해 같은 폴더를 본다. 우연히 같은 알고리즘을 쓸 뿐, Claude의 메모리 디렉토리에 얹혀가는 구조가 아니다.

이 규칙에는 대가가 있다. 프로젝트를 다른 경로로 옮기면(또는 서로 다른 절대경로에 clone/worktree를 두면) slug가 바뀌고, 이전 handoff는 옛 slug 아래에 남아 조회되지 않는다. 이 한계는 host를 가리지 않고 동일하게 적용되며, 자동으로 해소하지 않고 사용자가 수동으로 처리하는 것으로 남겨둔다.

**이전 위치와의 호환은 아직 없다.** `~/.claude/projects/<slug>/handoffs/`에 저장된 기존 문서는 이 경로 변경만으로는 보이지 않는다. 별도의 `migrate` 동작(계획 중, 미구현)이 이 이동을 명시적으로 처리할 예정이다.

## scan: Goal 문단 추출

`scan`은 `HANDOFF-*.md` 파일마다 한 줄씩, 탭으로 구분된 세 필드를 출력한다.

```
multi-platform-handoff-plugin	2026-08-28	`handoff` 플러그인(현재 v1.3.2, ...)을 provider-neutral 플러그인으로 재구성한다.
```

slug는 파일명에서 `HANDOFF-` 접두사와 `.md` 확장자를 벗겨 얻는다. 수정일은 `stat`의 플랫폼 차이를 두 번 시도로 흡수한다.

```sh
updated=$(stat -c '%y' "$f" 2>/dev/null | cut -d' ' -f1)
[ -n "$updated" ] || updated=$(stat -f '%Sm' -t '%Y-%m-%d' "$f")
```

앞 줄은 GNU coreutils(Linux), 뒷 줄은 BSD(macOS) 문법이다. macOS에서는 첫 시도가 실패해 빈 문자열이 되고 두 번째 줄이 값을 채운다.

세 번째 필드가 이 서브커맨드의 핵심이다. `awk` 상태 기계로 `# Goal` 헤딩 다음의 **첫 문단만** 뽑는다.

```awk
/^#+ *Goal/{g=1; next}                                  # Goal 헤딩을 만나면 수집 시작
g && /^#/{exit}                                         # 다음 헤딩을 만나면 중단
g && !NF{if(got) exit; next}                            # 빈 줄: 이미 모았으면 중단, 아니면 무시
g {sub(/^ +/,""); gsub(/\t/," "); out=out (got?" ":"") $0; got=1}
END{print out}
```

`got` 플래그가 "헤딩 바로 아래 빈 줄"과 "문단이 끝난 빈 줄"을 구분한다. 아직 아무것도 모으지 않았으면 빈 줄을 건너뛰고, 한 줄이라도 모았으면 그 빈 줄에서 멈춘다. 여러 줄에 걸친 문단은 공백 하나로 이어 붙여 한 줄로 만든다.

`gsub(/\t/," ")`는 장식이 아니라 출력 포맷을 지키는 장치다. 출력이 탭 구분 형식이므로 본문에 탭이 남으면 필드 경계가 깨진다. 헤딩 매칭이 `/^#+ *Goal/`인 덕분에 `# Goal`과 `## Goal` 모두 잡히고, Goal 섹션이 없는 문서는 세 번째 필드가 빈 채로 출력된다.

## context-check: 컨텍스트 압력 감지

`context-check`는 프롬프트를 보낼 때마다 실행되며, 컨텍스트 사용률이 임계치를 넘으면 `/handoff:save`를 제안한다. **제안만 하고 아무것도 저장하지 않는다.** 저장은 항상 사용자가 명령해야 일어난다.

전체 흐름은 다음과 같다.

```
stdin(훅 payload JSON)
   ↓ sed로 transcript_path, session_id 추출
   ↓ transcript 파일 없으면 exit 0
   ↓ tail -n 200 으로 꼬리 조각 확보
   ↓ 포맷 판별: "model_context_window" 존재 여부
   ├── 있음 → Codex 경로: last_token_usage.input_tokens
   └── 없음 → Claude 경로: input + cache_read + cache_creation
   ↓ used 검증 (비수치·0 이하면 exit 0)
   ↓ pct = used * 100 / limit → 밴드 판정 (35/50/75)
   ↓ marker 파일과 비교, 같거나 낮은 밴드면 exit 0
   ↓ 훅 JSON 1줄 출력
```

### 입력 파싱

payload는 `jq` 없이 `sed` 정규식 두 개로 읽는다.

```sh
input=$(cat 2>/dev/null || true)
transcript=$(printf '%s' "$input" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
session=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then exit 0; fi
```

이 방식은 키가 payload에 한 번만 등장하고 키와 값이 같은 줄에 있다는 전제에 기댄다. 훅 payload는 한 줄 JSON이므로 실제로 성립하지만, 중첩 객체가 같은 키를 또 쓰면 `.*`가 탐욕적으로 매칭해 마지막 것을 집는다. 이 취약함을 감수하는 대신, 파싱이 어긋나면 경로가 비거나 존재하지 않는 파일이 되어 곧바로 `exit 0`으로 빠진다.

### 두 transcript 포맷을 가르는 기준

Claude와 Codex는 같은 값을 서로 다른 모양으로 기록한다. 스크립트는 필드 하나로 둘을 구분한다. Codex rollout에는 `model_context_window`가 있고 Claude transcript에는 없다.

```sh
tail_chunk=$(tail -n 200 "$transcript" 2>/dev/null || true)

if printf '%s' "$tail_chunk" | grep -q '"model_context_window"'; then
  codex_chunk="$tail_chunk"
elif grep -q '"model_context_window"' "$transcript" 2>/dev/null; then
  codex_chunk=$(cat "$transcript")
else
  codex_chunk=""
fi
```

기본 작업 단위를 꼬리 200줄로 잡은 이유는 비용이다. 훅은 매 프롬프트마다 돌고 transcript는 세션이 길어질수록 커지므로, 전체 파일을 읽는 경로는 꼬리에서 판별에 실패했을 때만 쓴다. 위 분기가 판별과 fallback을 한 번에 처리하는 구조다.

### used 계산 (1) Claude 경로

Claude transcript의 `usage` 객체는 이렇게 생겼다.

```json
"usage":{"input_tokens":2,"cache_creation_input_tokens":2600,"cache_read_input_tokens":53543,"output_tokens":246}
```

`input_tokens`가 2라는 점이 중요하다. Claude는 캐시된 토큰을 `input_tokens`에서 **제외**하고 별도 필드에 기록한다. 실제 컨텍스트에 올라간 양은 세 값을 더해야 나온다.

```awk
/"input_tokens"/ {
  i=r=c=0
  if (match($0, /"input_tokens":[0-9]+/))                i=substr($0, RSTART+15, RLENGTH-15)
  if (match($0, /"cache_read_input_tokens":[0-9]+/))     r=substr($0, RSTART+26, RLENGTH-26)
  if (match($0, /"cache_creation_input_tokens":[0-9]+/)) c=substr($0, RSTART+30, RLENGTH-30)
  last=i+r+c
}
END { print last+0 }
```

`match`가 잡은 위치에서 키 이름 길이만큼 건너뛰어 숫자만 잘라낸다. 오프셋 15/26/30은 각각 `"input_tokens":`, `"cache_read_input_tokens":`, `"cache_creation_input_tokens":`의 문자 수(따옴표 2개와 콜론 포함)다.

여기서 `"input_tokens":` 패턴이 `"cache_read_input_tokens":`를 잘못 잡지 않는 이유는 패턴 맨 앞의 따옴표다. 캐시 필드에서 `input_tokens` 앞에 오는 문자는 `_`이므로 매칭되지 않는다.

`last`는 매 줄 덮어써지고 `END`에서 마지막 값만 출력한다. 즉 **스캔한 범위에서 가장 마지막 usage 기록**이 현재 컨텍스트 크기다. 누적 합이 아니라 마지막 값인 이유는, Claude가 매 요청마다 그 시점의 전체 컨텍스트를 다시 보고하기 때문이다.

```sh
used=$(printf '%s\n' "$tail_chunk" | awk "$usage_awk")
[ "${used:-0}" -le 0 ] 2>/dev/null && used=$(awk "$usage_awk" "$transcript")
```

꼬리 200줄에 usage 기록이 없으면(툴 결과가 길게 이어진 경우 발생할 수 있다) 전체 파일을 다시 스캔한다. 참고로 뒷줄의 `&&`는 `set -e` 아래에서도 안전하다. POSIX는 AND-OR 리스트의 마지막이 아닌 명령의 실패에는 `-e`를 적용하지 않으므로, 조건이 거짓이면 스크립트가 종료되지 않고 그대로 진행한다.

### used 계산 (2) Codex 경로

Codex rollout은 `token_count` 이벤트에 사용량을 담는다.

```sh
last_line=$(printf '%s\n' "$codex_chunk" | grep '"type":"token_count"' | tail -n 1)
inner=$(printf '%s' "$last_line" | sed -n 's/.*"last_token_usage":{\([^}]*\)}.*/\1/p')
used=$(printf '%s' "$inner" | sed -n 's/.*"input_tokens":\([0-9]*\).*/\1/p')
codex_limit=$(printf '%s' "$last_line" | sed -n 's/.*"model_context_window":\([0-9]*\).*/\1/p')
[ -n "$codex_limit" ] && limit="$codex_limit"
```

두 단계로 나눈 이유가 이 코드의 핵심이다. 같은 줄에 `total_token_usage`(세션 누적)와 `last_token_usage`(현재 턴)가 함께 들어 있어서, `input_tokens`를 줄 전체에서 찾으면 누적값을 집을 위험이 있다. 그래서 먼저 `last_token_usage`의 중괄호 안쪽만 `inner`로 잘라내고, 그 안에서만 `input_tokens`를 읽는다. 설계 문서 §12 단계 4의 실측 기록에 따르면 실제 rollout에서 두 값은 20017과 59147로 크게 달랐다.

Codex 경로에서는 한도도 실제 값을 쓴다. `model_context_window`가 있으면 기본값 대신 그 값으로 `limit`을 덮어쓰므로, 사용률이 세션의 실제 모델 한도 기준으로 계산된다.

### 두 계산식이 같은 값인 이유

두 경로의 식은 이렇게 다르다.

| 호스트 | 계산식 | 캐시 토큰 처리 |
| --- | --- | --- |
| Claude | `input_tokens + cache_read + cache_creation` | `input_tokens`에 **미포함** → 더해야 전체 |
| Codex | `last_token_usage.input_tokens` | `input_tokens`에 **이미 포함** → 더하면 이중 계산 |

모양이 다를 뿐 두 식 모두 "지금 컨텍스트에 올라와 있는 전체 토큰"을 구한다. 이 등가성이 두 호스트가 같은 임계 밴드(35/50/75)를 공유할 수 있는 근거다.

Codex 경로에 `cached_input_tokens`를 더하는 "수정"은 버그 수정이 아니라 이중 계산을 만드는 회귀다. 코드에도 같은 경고가 주석으로 남아 있다(`scripts/handoffs.sh:48-54`).

### 사용률과 밴드 판정

`used`를 얻은 뒤 세 겹으로 검증한다. 빈 값이면 0, 숫자가 아니면 0, 그리고 0 이하면 알림 없이 종료한다.

```sh
[ -n "${used:-}" ] || used=0
case "$used" in ''|*[!0-9]*) used=0;; esac
if [ "$used" -le 0 ]; then exit 0; fi

pct=$((used * 100 / limit))
```

`pct`는 셸 정수 연산이라 소수점을 버린다. 밴드 경계에서 최대 1% 낮게 나오지만 판정에는 영향이 없다.

| 밴드 | 기본 임계 | 환경변수 | 태그 | 모델에게 지시하는 강도 |
| --- | --- | --- | --- | --- |
| 1 | 35% | `HANDOFF_BAND_1` | 🟢 | 저장하기 좋은 시점임을 한 문장으로 언급 |
| 2 | 50% | `HANDOFF_BAND_2` | 🟠 | 한두 문장으로 분명하게 권장 |
| 3 | 75% | `HANDOFF_BAND_3` | 🔴 | 강하게 권고, 예/아니오 질문 금지, 직접 저장 금지 |

한도는 `HANDOFF_CONTEXT_LIMIT`로 조정하며 기본값은 1000000이다. Claude 경로에서는 훅이 사용량만 읽을 수 있고 세션의 실제 한도는 알 수 없어서 이 값을 고정 가정으로 쓴다. 200K 컨텍스트 세션에서 기본값을 그대로 두면 한도를 5배로 잡은 셈이라 밴드가 훨씬 늦게 뜨므로, `HANDOFF_CONTEXT_LIMIT=200000`으로 맞춰야 한다. Codex 경로는 앞서 본 대로 `model_context_window`를 읽으므로 이 설정이 필요 없다.

### 세션당 한 번만 알리는 방법

같은 밴드를 매 프롬프트마다 반복하지 않도록 marker 파일에 지금까지 발동한 최고 밴드를 기록한다.

```sh
marker="${TMPDIR:-/tmp}/handoff-context-reminder-${session:-unknown}"
prev=$(cat "$marker" 2>/dev/null || echo 0)
case "$prev" in ''|*[!0-9]*) prev=0;; esac
if [ "$band" -le "$prev" ]; then exit 0; fi
printf '%s' "$band" > "$marker"
```

파일명에 `session_id`가 들어가므로 세션마다 독립적이다. 저장하는 값이 "발동 여부"가 아니라 "최고 밴드 번호"인 덕분에, 밴드 1을 이미 본 세션에서도 사용률이 50%를 넘으면 밴드 2가 새로 뜬다. 반대로 컨텍스트가 압축돼 사용률이 내려가도 낮은 밴드가 다시 뜨지는 않는다.

marker는 `TMPDIR` 아래에 두므로 재부팅이나 OS의 임시 파일 정리로 사라질 수 있다. 그 경우 최악의 결과는 알림이 한 번 더 뜨는 것뿐이라 별도 정리 로직을 두지 않았다.

### 출력 계약

조건을 모두 통과하면 한 줄짜리 JSON을 stdout으로 내보낸다.

```sh
printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' \
  "$banner" "$(printf '%s' "$context" | sed 's/\\/\\\\/g; s/"/\\"/g')"
```

두 필드의 독자가 다르다. `systemMessage`는 사용자가 터미널에서 보는 한 줄 배너이고, `additionalContext`는 모델의 컨텍스트에 주입되는 지시문이다. 후자에는 태그를 붙여 한 줄로 알리라는 지시와 함께 "실제로 저장하지 않았다면 저장했다고 말하지 말 것"이라는 제약이 들어간다. 밴드 3에는 직접 저장하지 말라는 문장이 추가로 붙는다.

JSON 이스케이프는 `additionalContext`에만 적용한다. `banner`는 고정 한국어 문자열과 정수만으로 조립돼 따옴표나 역슬래시가 들어갈 수 없기 때문이다. 반면 `context`는 같은 값들로 만들어지지만 향후 문구 수정에 대비해 방어적으로 이스케이프한다.

실제 출력은 이렇다.

```json
{"systemMessage":"🟠 [handoff] 컨텍스트 70% 사용 중 (700010/1000000 토큰) — /handoff:save 사용을 권장합니다","hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"[handoff plugin] 🟠 Context usage is at ~70% ..."}}
```

## 조용히 종료하는 지점

훅은 사용자의 모든 프롬프트를 거쳐 가므로, 파서가 실패해도 일반 요청을 막아서는 안 된다. `context-check`는 다음 여섯 지점에서 아무 출력 없이 `exit 0`한다.

| 지점 | 조건 |
| --- | --- |
| payload 파싱 | `transcript_path`가 없음 |
| 파일 확인 | 경로가 가리키는 파일이 없음 |
| used 추출 | 빈 파일이거나 usage 기록이 없음 |
| used 검증 | 숫자가 아니거나 0 이하 |
| 밴드 판정 | 사용률이 밴드 1 미만 |
| 중복 억제 | 이미 같거나 높은 밴드를 알림 |

`dir`과 `scan`은 실패하지 않는다. `scan`은 handoff가 하나도 없으면 `[ -e "$f" ] || continue`로 glob 미매칭 상태를 걸러 빈 출력을 낸다.

## 알아둘 한계

**Claude 경로는 서브에이전트 사용량을 구분하지 않는다.** awk는 `"input_tokens"`가 든 마지막 줄을 무조건 집는다. 서브에이전트 메시지는 같은 transcript에 `"isSidechain":true`로 기록되므로, 서브에이전트가 방금 응답한 직후에 프롬프트를 보내면 메인 세션이 아닌 서브에이전트의 컨텍스트 크기를 읽을 가능성이 있다. 현재 코드는 `isSidechain`을 보지 않는다.

**`HANDOFF_CONTEXT_LIMIT=0`은 스크립트를 죽인다.** `pct=$((used * 100 / limit))`에서 0으로 나누게 된다. 환경변수 값 검증이 없다.

**Codex 훅 배선은 아직 실측되지 않았다.** 파싱 로직 자체는 실제 rollout 파일로 검증됐지만, Codex가 이 훅을 호출해 stdin으로 `transcript_path`를 넘겨주는 전체 경로는 hook trust 게이트 때문에 확인하지 못했다. Codex는 플러그인 번들 훅을 사용자가 한 번 신뢰하기 전까지 조용히 건너뛴다.

**포맷 판별이 단일 필드에 의존한다.** Codex가 `model_context_window` 필드명을 바꾸면 Codex rollout이 Claude 경로로 잘못 흘러가고, 그 경우 `last_token_usage` 대신 줄 전체에서 첫 `input_tokens`를 읽어 누적값을 집을 수 있다. transcript 포맷은 안정적인 인터페이스가 아니므로 호스트 버전 업그레이드 때 재확인이 필요하다.

## 검증 방법

합성 transcript를 훅 payload처럼 흘려 넣으면 계산 경로를 직접 확인할 수 있다.

```sh
# Claude 포맷: (10 + 200000 + 500000) / 1000000 = 70% → 밴드 2
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":10,"cache_creation_input_tokens":200000,"cache_read_input_tokens":500000,"output_tokens":50}}}' > /tmp/claude.jsonl
printf '{"session_id":"t1","transcript_path":"/tmp/claude.jsonl"}' | sh scripts/handoffs.sh context-check

# Codex 포맷: 220000 / 272000 = 80% → 밴드 3, 누적값 20017을 집지 않는지 확인
printf '%s\n' '{"type":"token_count","info":{"total_token_usage":{"input_tokens":20017},"last_token_usage":{"input_tokens":220000,"cached_input_tokens":180000},"model_context_window":272000}}' > /tmp/codex.jsonl
printf '{"session_id":"t2","transcript_path":"/tmp/codex.jsonl"}' | sh scripts/handoffs.sh context-check

# 같은 session_id로 한 번 더 실행하면 marker에 막혀 무출력
printf '{"session_id":"t1","transcript_path":"/tmp/claude.jsonl"}' | sh scripts/handoffs.sh context-check
```

`total_token_usage`와 `last_token_usage`에 서로 다른 값을 넣는 것이 Codex 경로 검증의 핵심이다. 두 값이 같으면 파서가 잘못된 필드를 읽어도 드러나지 않는다.

## 참고

- 설계 배경과 provider-neutral 계약: `docs/provider-neutral-handoff-design.md`
- 훅 등록: `hooks/hooks.json`
- 환경변수 표와 사용자 안내: `README.md`
