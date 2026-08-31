# handoff

여러 작업을 오가도 **어디까지 했는지 놓치지 않게** 해주는 Claude Code 플러그인입니다.
"무엇을 하려 했고, 어디까지 했고, 다음에 뭘 해야 하는지"를 **작업별 개인 노트**로 남겨두면, 어느 작업으로 돌아오든 그 지점에서 바로 이어갑니다.

> 이 플러그인은 [Gilbert9172/handoff](https://github.com/Gilbert9172/handoff) 저장소를 마켓플레이스로 등록해 설치합니다. 아래 순서대로 따라 하면 됩니다.

---

## 왜 쓰나

- **작업을 오가도 빠르게 복귀** — 작업마다 노트가 따로 있어 `list`로 무엇이 어디까지 왔는지 한눈에 보고, `resume`이 Goal·What Worked·Next Steps를 요약해줘 **코드를 다시 읽지 않고도** 중단했던 지점으로 바로 돌아갑니다.
- **같은 실패를 반복하지 않음** — "이미 시도했다가 안 됐던 방법"을 기록해두면 다음 세션(또는 다음 사람)이 **같은 삽질을 반복하지 않습니다.**
- **세션 경계를 넘김** — 대화가 길어져 컨텍스트가 잘리거나 며칠 뒤 새 세션에서 이어갈 때 **처음부터 다시 설명하지 않아도** 됩니다.
- **커밋 걱정 없는 개인 노트** — 노트는 저장소가 아니라 **홈 디렉토리**에 저장돼 커밋·리뷰 부담이 없습니다.

### 어떻게 병렬이 되나

핵심은 **작업 하나당 노트 하나**라는 점입니다. 모든 작업을 `HANDOFF.md` 한 파일에 욱여넣는 대신, 작업마다 슬러그를 가진 별도 파일로 분리합니다:

```
~/.handoffs/<프로젝트>/
├── HANDOFF-auction-state-machine.md
├── HANDOFF-batch-php-migration.md
└── HANDOFF-settlement-interface.md
```

그래서 작업이 서로 섞이지 않고, `/handoff:list`가 이 파일들을 그대로 한 줄씩 보여줘 **"무엇이 어디까지 왔는지"가 곧 대시보드**가 됩니다. 작업을 추가해도 파일이 하나 더 늘 뿐, 기존 노트는 건드리지 않습니다.

---

## 설치

### 1) 마켓플레이스 등록 (최초 1회)

```shell
/plugin marketplace add https://github.com/Gilbert9172/handoff.git
```

이 명령은 저장소 루트의 `.claude-plugin/marketplace.json`을 읽어 `gilbert9172` 마켓플레이스로 등록합니다.

### 2) 플러그인 설치

```shell
/plugin install handoff@gilbert9172
/reload-plugins          # 현재 세션에 바로 반영
```

설치되면 `/handoff:save`, `/handoff:list`, `/handoff:resume`, `/handoff:delete` 커맨드가 생깁니다.

### 3) 확인

```shell
/handoff:list
```

처음이면 "이 프로젝트에는 아직 handoff가 없습니다"라고 나오면 정상입니다.

> 처음 5분만 보고 싶다면 [QUICKSTART.md](./QUICKSTART.md)부터 보세요.

### (선택) 프로젝트 설정으로 자동 설치

프로젝트의 `.claude/settings.json`에 아래를 넣어두면, 그 저장소에서 세션을 열 때 신뢰 확인만 거치면 마켓플레이스 등록·플러그인 설치가 자동으로 됩니다. (여러 기기에서 같은 설정을 쓰고 싶을 때 유용합니다.)

```json
{
  "extraKnownMarketplaces": {
    "gilbert9172": {
      "source": { "source": "url", "url": "https://github.com/Gilbert9172/handoff.git" }
    }
  },
  "enabledPlugins": {
    "handoff@gilbert9172": true
  }
}
```

---

## 커맨드

| 커맨드 | 용도 | 인자 |
|--------|------|------|
| `/handoff:save [제목]` | 현재 작업을 인계 노트로 저장/업데이트 | 제목(선택) |
| `/handoff:list` | 이 프로젝트의 handoff 목록 보기 | 없음 |
| `/handoff:resume [슬러그]` | 노트를 읽고 Next Steps부터 작업 재개 | 슬러그(선택) |
| `/handoff:delete [슬러그]` | 끝났거나 버린 작업의 노트 삭제 | 슬러그(선택) |

> **Codex에서는 접두사가 `$`입니다.** Codex는 skill을 `$`로 호출하므로 같은 커맨드를 `$handoff:save`, `$handoff:list`, `$handoff:resume`, `$handoff:delete`로 입력하세요. 이 문서의 나머지 표기는 Claude Code 기준(`/`)입니다.

### `/handoff:save [제목]`

세션을 마무리하거나 다른 작업으로 넘어갈 때 진행 상황을 기록합니다.

- **제목을 주면** 그 제목을 슬러그로 변환해(소문자, 공백→`-`) 해당 파일을 저장/업데이트합니다.
- **제목이 없으면** 기존 handoff를 훑어보고 *같은 작업*이면 그 파일을 갱신, *새 작업*이면 Goal에서 슬러그를 뽑아 새로 만듭니다. 애매하면 어떤 걸 쓸지 물어봅니다.
- 저장 후 **전체 파일 경로**와 **재개 명령(`/handoff:resume <슬러그>`)** 을 알려줍니다.

### `/handoff:list`

이 프로젝트의 모든 handoff를 표로 보여줍니다 — **Slug · Updated · Goal**. 읽기 전용이라 아무것도 바꾸지 않습니다.

### `/handoff:resume [슬러그]`

- **슬러그를 주면** 그 노트를 읽고, **없으면** 목록을 보여줍니다.
- **슬러그가 없을 때** — 노트가 1개면 자동 선택, 여러 개면 선택지를 물어보고, 없으면 `/handoff:save`를 제안합니다.
- 노트를 전부 읽은 뒤 **Goal · What Worked · Next Steps를 짧게 요약**해 방향을 확인하고, **Next Steps부터 실행**합니다. **What Didn't Work**에 적힌 실패 방법은 다시 시도하지 않습니다.

### `/handoff:delete [슬러그]`

- 삭제는 **되돌릴 수 없어** 삭제 전 슬러그·Goal을 보여주고 확인을 받습니다.
- 슬러그 없이 실행하면 여러 개를 골라 한 번에 정리할 수 있습니다(완료된 작업 일괄 정리용).

---

## 자동 저장 제안 (컨텍스트 훅)

`/handoff:save`를 기억에만 의존하지 않도록, 플러그인 설치 시 **UserPromptSubmit 훅**이 함께 등록됩니다. 메시지를 보낼 때마다 훅이 현재 세션 transcript에서 **실제 컨텍스트 사용량**을 읽고, 사용량에 따라 3단계로 신호를 줍니다:

| 태그 | 기준(기본값) | 동작 |
|------|-------------|------|
| 🟢 | **35%** | `/handoff:save` 사용을 가볍게 추천 |
| 🟠 | **50%** | `/handoff:save` 사용을 분명하게 권장 |
| 🔴 | **75%** | 컨텍스트 부족을 경고하고 `/handoff:save`로 관리할 것을 강하게 안내 |

- **자동으로 저장하지 않습니다.** 세 단계 모두 제안일 뿐이고, 실제 저장은 사용자가 `/handoff:save`를 실행할 때만 일어납니다.
- 각 단계는 **세션당 1회**만 발화하고, 한 번에 여러 단계를 건너뛰면 가장 높은 단계만 발화합니다.
- auto-compact를 **꺼둔 경우에도** 동일하게 동작합니다 — 컨텍스트가 한계에 닿아 작업 맥락을 잃기 전에 저장할 기회를 줍니다.

기준은 환경변수로 조정할 수 있습니다:

| 변수 | 기본값 | 의미 |
|------|--------|------|
| `HANDOFF_BAND_1` | `35` | 🟢 1단계 사용률(%) |
| `HANDOFF_BAND_2` | `50` | 🟠 2단계 사용률(%) |
| `HANDOFF_BAND_3` | `75` | 🔴 3단계 사용률(%) |
| `HANDOFF_CONTEXT_LIMIT` | 모델별 자동 감지 | 이 세션의 컨텍스트 윈도우 크기 override(토큰) |
| `HANDOFF_CMD_PREFIX` | 자동 감지 (`/` 또는 `$`) | 훅 메시지에 쓸 커맨드 접두사. transcript 형식으로 Claude Code(`/`)와 Codex(`$`)를 자동 구분하며, 이 변수를 지정하면 그 값이 우선합니다 |

> Claude transcript의 assistant message에서 모델을 읽어 1M 모델은 1,000,000으로 계산하고, 그 외 모델은 200,000으로 계산합니다. Codex는 transcript의 `model_context_window` 값을 사용합니다. 자동 감지가 맞지 않는 custom deployment에서는 `HANDOFF_CONTEXT_LIMIT`로 직접 지정할 수 있습니다.

> 훅 변경은 플러그인 업데이트(`/plugin marketplace update gilbert9172`) 후 **새 세션**부터 적용됩니다.

---

## Handoff 문서 구조

각 노트는 다음 다섯 섹션으로 구성됩니다.

```markdown
# Goal
무엇을 이루려는가 (한두 문장)

# Current Progress
지금까지 한 일

# What Worked
효과가 있었던 접근

# What Didn't Work
시도했지만 실패한 접근 (반복 방지 — 이유까지)

# Next Steps
다음에 할 구체적 작업
```

### 업데이트 시 병합 규칙 (`/handoff:save`가 자동 적용)

- **Current Progress · Next Steps** → 최신 상태로 **새로 씀**
- **What Worked · What Didn't Work** → 기존 내용에 **누적**(과거 기록을 지우지 않음)
- **Goal** → 작업 자체가 바뀌지 않는 한 그대로 둠

---

## 저장 위치

handoff는 저장소가 아니라 홈 디렉토리의 프로젝트별 폴더에 저장됩니다. Claude Code와 Codex 어느 쪽에서 저장·조회하든 같은 경로를 씁니다:

```
~/.handoffs/<프로젝트-슬러그>/HANDOFF-<슬러그>.md
```

`<프로젝트-슬러그>`는 **git 루트 경로**의 `/`를 `-`로 바꾼 값입니다(git 저장소가 아니면 현재 디렉토리 기준). git 루트를 쓰므로 하위 디렉토리에서 세션을 시작해도 이전 handoff를 찾고, Claude와 Codex가 같은 저장소를 열면 host와 무관하게 같은 슬러그·같은 폴더로 계산됩니다.

예) `handoff` 저장소(`/Users/<you>/project/handoff`)라면 경로는 이렇게 풀립니다:

```
~/.handoffs/-Users-<you>-project-handoff/HANDOFF-batch-php-migration.md
```

(같은 폴더에 작업별 노트가 나란히 쌓입니다 — 위 [어떻게 병렬이 되나](#어떻게-병렬이-되나) 참고.) 필요하면 이 파일들을 에디터로 직접 열어 수정해도 됩니다.

**이전 버전에서 저장한 handoff가 안 보인다면**, 예전에는 `~/.claude/projects/<슬러그>/handoffs/`에 저장했습니다. `/handoff:migrate`를 실행하면 같은 프로젝트(같은 슬러그)의 옛 문서를 위 새 경로로 옮겨줍니다 — 저장소를 다른 절대경로로 옮겨서 슬러그 자체가 달라진 경우는 자동으로 찾지 못하니 그때는 파일을 직접 옮기세요. 이 커맨드는 과도기용 임시 기능이라 나중 버전에서 제거될 수 있습니다.

---

## 워크플로우 예시

**여러 작업이 동시에 굴러갈 때 — 무엇이 어디까지 왔는지 한눈에**

```shell
/handoff:list
```

| Slug | Updated | Goal |
|------|---------|------|
| auction-state-machine | 2026-06-11 | 낙찰→납부 상태 전이 설계 |
| batch-php-migration | 2026-06-13 | 레거시 PHP 배치를 신규 런타임으로 이관 |
| settlement-interface | 2026-06-10 | 정산 인터페이스 초안 작성 |

```shell
/handoff:resume batch-php-migration   # 오늘은 이거 이어서
```

`resume`하면 그 작업의 Goal·What Worked·Next Steps를 요약하고 **What Didn't Work**의 실패 방법은 건너뛴 채, 중단했던 지점부터 바로 이어갑니다.

**한 작업의 라이프사이클 — 저장부터 정리까지**

```shell
/handoff:save batch-php-migration   # 진행하다 멈출 때 기록
```
```markdown
# Goal
레거시 PHP 배치를 신규 런타임으로 마이그레이션

# Current Progress
- APP_ENV 주입 방식 정리, 배치 엔트리포인트 이관

# What Worked
- 환경변수는 컨테이너 레벨에서 주입(코드 분기 제거)

# What Didn't Work
- .env 파일 동봉 방식 → 스테이징/운영 값 충돌로 폐기

# Next Steps
- IAM 권한 매핑 후 S3 접근 경로 검증
- 배치 실패 시 재시도/알림 경로 연결
```

```shell
/handoff:resume batch-php-migration   # 다음 세션에서 이어서
# ... 작업 ...
/handoff:save batch-php-migration     # 진행 상황 갱신
# ... 완료되면 ...
/handoff:delete batch-php-migration   # 정리
```

---

## 관리 (업데이트 · 제거)

```shell
/plugin marketplace update gilbert9172   # 마켓플레이스 최신화(플러그인 변경 반영)
/plugin list                             # 설치된 플러그인 확인
/plugin disable handoff@gilbert9172      # 일시 비활성화
/plugin uninstall handoff@gilbert9172    # 제거
```

플러그인 코드가 갱신되면 `/plugin marketplace update gilbert9172` 후 `/reload-plugins`로 반영합니다.

---

## 트러블슈팅

**커맨드(`/handoff:*`)가 안 보임**
→ `/plugin list`로 설치 여부 확인 → `/reload-plugins` 실행 → 그래도 없으면 마켓플레이스가 등록됐는지 `/plugin marketplace list`로 확인.

**목록에 handoff가 안 나옴**
→ 다른 git 루트에서 저장했을 수 있습니다. `git rev-parse --show-toplevel`로 현재 루트를 확인하고, `~/.handoffs/` 아래 해당 슬러그 폴더가 맞는지 보세요.

**저장이 안 됨**
→ `~/.handoffs/`에 쓰기 권한이 있는지 확인하세요. 폴더는 첫 저장 시 자동 생성됩니다.

---

## 동작 원리 (참고)

네 커맨드는 공통 스크립트 하나(`scripts/handoffs.sh`)를 공유해 경로·스캔 로직을 동일하게 씁니다.

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir    # 이 프로젝트의 handoff 디렉토리
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan   # 노트별: 슬러그 · 수정일 · Goal 첫 문단
```

`${CLAUDE_PLUGIN_ROOT}`는 플러그인 설치 경로로 자동 주입됩니다. 별도 인덱스 파일 없이 `scan`이 매번 디렉토리를 훑으므로, 목록이 실제 파일과 어긋날 일이 없습니다.

---

## 원본 대비 개선점

이 플러그인은 [ykdojo/claude-code-tips의 handoff skill](https://github.com/ykdojo/claude-code-tips/blob/main/skills/handoff/SKILL.md)에서 출발했습니다. 원본은 `HANDOFF.md` 하나를 레포 루트에 쓰는 단일 skill이었고, 여기서 다음을 재설계했습니다.

| 항목 | 원본 | 이 플러그인 |
|------|------|------------|
| 형태 | 단일 skill (저장만) | 4개 커맨드(save·list·resume·delete) — 라이프사이클 전체 |
| 파일 | `HANDOFF.md` 1개 고정 | `HANDOFF-<슬러그>.md` 작업별 N개 |
| 저장 위치 | 레포 루트 | `~/.handoffs/<슬러그>/` (홈, host 중립) |
| 스코핑 | 없음(cwd) | git 루트 기준 슬러그 |
| 목록·조회 | 없음 | `scan` 스크립트(인덱스 없이) |
| 배포 | 복사·붙여넣기 | 마켓플레이스 등록·설치 |
| 병합 | "기존 내용 보존" 한 줄 | 섹션별 차등(덮어쓰기 vs 누적) |

표의 구조적 차이(작업별 파일 · 홈 저장 · git 루트 스코핑)가 *왜* 중요한지는 위 [어떻게 병렬이 되나](#어떻게-병렬이-되나) · [저장 위치](#저장-위치)에서 다뤘습니다. 그 위에 원본에 없던 세 가지를 더했습니다.

- **resume** — 노트를 읽고 Goal·What Worked·Next Steps를 요약한 뒤 *실행 전에 멈춰* 확인을 받습니다(재개는 컨텍스트 로드이지 계획 승인이 아니므로).
- **delete** — 끝난 작업을 정리해 노트가 무한히 쌓이지 않도록 라이프사이클을 닫습니다.
- **인덱스리스** — 목록을 매번 `scan`으로 만들어, 인덱스와 실제 파일이 어긋나는 동기화 버그를 원천 차단합니다.

---
