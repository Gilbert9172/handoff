# handoff — 세션 간 작업 인계 플러그인

대화 세션이 끝나도 작업의 맥락이 끊기지 않게 해주는 Claude Code 플러그인입니다.
"무엇을 하려 했고, 어디까지 했고, 다음에 뭘 해야 하는지"를 **프로젝트별 개인 노트**로 남겼다가, 새 대화에서 그대로 이어받습니다.

> 이 플러그인은 [Gilbert9172/handoff](https://github.com/Gilbert9172/handoff) 저장소를 마켓플레이스로 등록해 설치합니다. 아래 순서대로 따라 하면 됩니다.

---

## 왜 쓰나

- 대화가 길어져 컨텍스트가 잘리거나, 며칠 뒤 새 세션에서 같은 작업을 이어갈 때 **처음부터 다시 설명하지 않아도** 됩니다.
- "이미 시도했다가 안 됐던 방법"을 기록해두면 다음 세션(또는 다음 사람)이 **같은 삽질을 반복하지 않습니다.**
- 노트는 저장소가 아니라 **홈 디렉토리**에 저장되는 개인 메모라, 커밋·리뷰 부담이 없습니다.

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

handoff는 저장소가 아니라 홈 디렉토리의 프로젝트별 폴더에 저장됩니다 (Claude Code가 프로젝트 메모리를 두는 곳과 동일):

```
~/.claude/projects/<프로젝트-슬러그>/handoffs/HANDOFF-<슬러그>.md
```

`<프로젝트-슬러그>`는 **git 루트 경로**의 `/`를 `-`로 바꾼 값입니다(git 저장소가 아니면 현재 디렉토리 기준). git 루트를 쓰므로 하위 디렉토리에서 세션을 시작해도 이전 handoff를 찾습니다.

예) `handoff` 저장소(`/Users/<you>/project/handoff`)라면:

```
~/.claude/projects/-Users-<you>-project-handoff/handoffs/
├── HANDOFF-auth-jwt-migration.md
└── HANDOFF-pages-ci-setup.md
```

필요하면 이 파일들을 에디터로 직접 열어 수정해도 됩니다.

---

## 워크플로우 예시

**첫 세션 — 작업하다 마무리**

```shell
/handoff:save auth-migration
```
```markdown
# Goal
세션 기반 인증을 JWT로 마이그레이션

# Current Progress
- 사용자 모델에 JWT 필드 추가
- 토큰 생성/검증 함수 구현

# What Worked
- jsonwebtoken 라이브러리 채택

# What Didn't Work
- RSA 키 방식은 운영 복잡 → HS256으로 변경

# Next Steps
- 기존 세션을 JWT로 옮기는 마이그레이션 스크립트 작성
- 로그인/로그아웃 엔드포인트 수정 후 테스트
```

**다음 세션 — 그대로 이어받기**

```shell
/handoff:list                    # auth-migration 확인
/handoff:resume auth-migration   # Goal·Next Steps 확인 후 이어서 진행
# ... 작업 ...
/handoff:save auth-migration     # 진행 상황 갱신 (다음 세션을 위해)
# ... 완료되면 ...
/handoff:delete auth-migration   # 정리
```

---

## 베스트 프랙티스

**이렇게 쓰세요**
- **Goal은 명확하게** — 다음 세션이 한눈에 목표를 파악하도록.
- **Next Steps는 구체적으로** — "테스트 더 하기"❌ → "POST /api/auth 엔드포인트 테스트, `tests/auth.test.ts`"✅
- **실패도 이유까지** — What Didn't Work는 시간 절약 장치입니다.
- **끝난 건 지우기** — `/handoff:delete`로 목록을 깔끔하게.

**피하세요**
- 너무 짧은 진행 기록(다음 세션에 코드를 다시 읽어야 하면 가치가 줄어듭니다).
- 오래된 정보 방치(업데이트 시 Progress·Next Steps는 최신으로).

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
→ 다른 git 루트에서 저장했을 수 있습니다. `git rev-parse --show-toplevel`로 현재 루트를 확인하고, `~/.claude/projects/` 아래 해당 슬러그 폴더가 맞는지 보세요.

**저장이 안 됨**
→ `~/.claude/projects/`에 쓰기 권한이 있는지 확인하세요. 폴더는 첫 저장 시 자동 생성됩니다.

---

## 동작 원리 (참고)

네 커맨드는 공통 스크립트 하나(`scripts/handoffs.sh`)를 공유해 경로·스캔 로직을 동일하게 씁니다.

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" dir    # 이 프로젝트의 handoff 디렉토리
sh "${CLAUDE_PLUGIN_ROOT}/scripts/handoffs.sh" scan   # 노트별: 슬러그 · 수정일 · Goal 첫 문단
```

`${CLAUDE_PLUGIN_ROOT}`는 플러그인 설치 경로로 자동 주입됩니다. 별도 인덱스 파일 없이 `scan`이 매번 디렉토리를 훑으므로, 목록이 실제 파일과 어긋날 일이 없습니다.

---

🚀 **작업이 끊기지 않게, 세션 끝에 한 번씩 `/handoff:save`.**
