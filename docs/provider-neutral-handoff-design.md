# Provider-Neutral Handoff 설계

> 상태: Draft
> 작성일: 2026-08-27
> 개정일: 2026-08-31 — §7.4 정정: hook은 Claude 전용이 아니라 Codex에도 등록됨을 실측 확인, `HANDOFF_CMD_PREFIX` 기본값을 transcript 자동 감지로 교체
> 개정일: 2026-08-30 — §7.4 커맨드 표기(호출 접두사) 결정 추가
> 개정일: 2026-08-29 — §10 저장 위치 결정 확정(`~/.handoffs/<project-slug>/`, flat, 즉시 전환); §14 프로젝트 식별 방식 미결정 해소 (2026-08-27 — `skills/` 단일화 결정, 전환 검증 순서, `save` 대상 판정 및 실패 처리 반영)
> 대상: Claude Code 및 Codex 로컬 환경

## 1. 배경

현재 `handoff`는 Claude Code 플러그인으로 구현되어 있다. 네 개의 커맨드(`save`, `list`, `resume`, `delete`)와 `UserPromptSubmit` 훅을 제공하며, handoff 문서는 Claude 프로젝트 메모리 경로 아래에 저장한다.

Codex는 Claude 플러그인의 일부 구조를 호환 처리하지만 다음 요소는 동일한 계약으로 볼 수 없다.

- 플러그인 진입점 구성과 frontmatter 해석 (§7.1에서 `skills/`로 통일)
- transcript 내부의 토큰 사용량 표현
- 플러그인 manifest와 호출 방식
- 홈 디렉토리 쓰기에 대한 sandbox 및 승인 정책

개발 환경에서 현재 Claude 플러그인을 Codex에 설치했을 때 `list`, `resume`, `delete`는 임시 skill로 변환됐지만 `save`는 변환 목록에서 누락됐다. 이는 자동 호환 변환을 정식 Codex 지원 계약으로 의존하기 어렵다는 근거다.

**관찰 시점과 버전(2026-08-27, `codex-cli 0.150.0`에서 재확인):** 로컬에 실제로 설치돼 있던 `commands/` 기반 구버전 handoff 플러그인(git marketplace `gilbert9172`, revision `9927b78`)을 직접 열어 이 변환의 정체를 확인했다. Codex는 `commands/*.md`를 가진 플러그인을 설치할 때 `.codex-plugin/migrated-command-skills/source-command-<name>/SKILL.md`를 자동 생성하는데, 이 변환은 `name`과 `description`만 남기고 `model`, `effort`, `disable-model-invocation`, `allowed-tools`, `argument-hint`를 **경고 없이 전부 버린다.** `save.md`가 누락된 정확한 원인까지는 확인하지 못했지만, 이 변환 자체가 조용히 정보를 버리는 손실 압축이라는 사실은 확인됐다 — §7.1이 이 자동 변환 경로를 없애고 `skills/`를 직접 작성하기로 한 결정의 근거가 여기 있다.

## 2. 설계 목표

`handoff`를 특정 AI 제품의 커맨드 묶음이 아니라, 여러 agent host가 동일하게 구현할 수 있는 **세션 연속성 계약(session continuity contract)** 으로 재구성한다.

목표는 다음과 같다.

1. Claude에서 저장한 작업을 Codex에서 재개할 수 있다.
2. handoff 문서 구조와 병합 규칙을 host와 무관하게 유지한다.
3. Claude와 Codex의 skill 로딩, hook, 승인 정책 차이는 얇은 어댑터에서 처리한다.
4. transcript 파싱이나 특정 모델 지정처럼 불안정한 기능은 보조 기능으로만 사용하고, 이들이 실패해도 §6의 네 동작은 영향받지 않는다.
5. 기존 Claude 사용자의 문서와 사용 습관을 깨뜨리지 않고 단계적으로 전환한다.

## 3. 비목표

초기 전환 범위에는 다음을 포함하지 않는다.

- 원격 동기화 또는 팀 단위 handoff 서버
- 자동 저장
- ChatGPT 웹 환경의 로컬 파일 지원
- handoff 문서의 실시간 동시 편집
- 커맨드별 모델 라우팅을 반드시 동일하게 재현하는 것
- 기존 Markdown 형식을 데이터베이스로 교체하는 것

## 4. 핵심 개념: 세션 연속성 계약

여기서 계약은 네트워크 프로토콜이 아니라, host와 무관하게 유지해야 하는 데이터와 동작 규칙을 뜻한다.

```text
사용자 의도
   ↓
Handoff 공통 계약
   ├── save
   ├── list
   ├── resume
   └── delete
   ↓
Host adapter
   ├── Claude Code: skill + Claude hook
   └── Codex: skill + Codex hook
```

공통 계약은 다음 질문에 답해야 한다.

- 어떤 정보를 저장하는가?
- 프로젝트와 작업을 어떻게 식별하는가?
- 저장 시 어떤 항목을 교체하고 어떤 항목을 누적하는가?
- 대상이 불확실할 때 무엇을 기본값으로 삼는가?
- 저장에 실패했을 때 사용자에게 무엇을 보장하는가?
- 재개 전에 사용자에게 무엇을 보여주고 언제 확인을 받는가?
- 삭제 전에 어떤 안전 절차를 거치는가?
- 기존 문서와 새 문서를 어떻게 발견하고 마이그레이션하는가?

`/handoff:save` 또는 Codex의 skill 호출 방식, 실행 모델, transcript 위치는 이 계약의 일부가 아니라 host 구현 세부사항이다.

## 5. 공통 데이터 계약

### 5.1 문서 구조

각 작업은 독립된 Markdown 문서 하나로 표현한다.

```markdown
# Goal
달성하려는 목표

# Current Progress
현재까지 완료된 작업과 상태

# What Worked
효과가 있었던 접근과 근거

# What Didn't Work
실패한 접근, 실패 이유, 다시 시도하지 말아야 할 조건

# Next Steps
다음 세션이 바로 실행할 수 있는 구체적인 작업
```

### 5.2 문서 메타데이터

§10.2의 dual-read 기간에는 같은 slug의 문서가 두 위치에 존재할 수 있다. 파일명과 수정 시각만으로는 *같은 작업의 서로 다른 버전*과 *우연히 같은 slug를 쓴 다른 작업*을 구분할 수 없으므로, 새로 쓰는 문서에는 최소 frontmatter를 붙인다.

```markdown
---
slug: <task-slug>
updated: YYYY-MM-DD
format: 1
---
```

규칙은 다음과 같다.

- frontmatter는 **선택 사항**이다. 없는 문서도 유효한 handoff이며 읽기와 재개가 모두 동작해야 한다.
- 기존 문서를 업데이트할 때 frontmatter가 없으면 추가하되, 본문 섹션은 §5.4 병합 규칙 그대로 처리한다.
- 어떤 동작도 frontmatter의 존재를 전제로 실패해서는 안 된다. `updated`가 없으면 파일 수정 시각으로 대신한다.
- `format`은 향후 문서 구조가 바뀔 때의 판별자다. 알 수 없는 `format` 값을 만나면 읽기는 시도하되 자동 병합은 하지 않고 사용자에게 알린다.

### 5.3 파일 식별

- 작업 파일명: `HANDOFF-<task-slug>.md`
- `task-slug`: 짧은 kebab-case 식별자, 허용 문자는 `[a-z0-9-]`
- 작업 하나당 파일 하나
- 별도 인덱스 파일을 두지 않고 디렉토리를 스캔하여 목록을 생성
- slug 정규화와 검증은 모델이 아니라 `scripts/`가 담당한다

### 5.4 병합 규칙

기존 handoff를 업데이트할 때 다음 규칙을 적용한다.


| 섹션               | 업데이트 규칙             |
| ---------------- | ------------------- |
| Goal             | 작업 목표가 바뀌지 않는 한 유지  |
| Current Progress | 최신 상태로 교체           |
| What Worked      | 기존 내용에 새 발견을 누적     |
| What Didn't Work | 기존 내용에 새 실패와 이유를 누적 |
| Next Steps       | 최신 계획으로 교체          |


중복 누적을 방지하는 세부 규칙은 구현 단계에서 별도 명세한다.

## 6. 공통 동작 계약

### 6.1 `save`

**1단계 — 추출.** 현재 세션의 목표, 진행 상태, 성공·실패한 접근, 다음 단계를 추출한다.

**2단계 — 대상 판정.** 어느 문서에 쓸지는 다음 순서로만 결정한다. 이 순서는 host와 모델에 관계없이 동일해야 한다.

1. 사용자가 제목을 지정했으면 그 slug가 대상이다. 같은 slug 파일이 있으면 업데이트하고, 없으면 새로 만든다.
2. 제목이 없으면 디렉토리를 스캔해 각 문서의 Goal과 현재 세션의 목표를 비교한다.
3. 같은 작업으로 판단되는 문서가 **정확히 하나**면 그 문서를 업데이트한다.
4. 후보가 둘 이상이거나 판단이 불확실하면 **새 파일을 만들지 않고** 사용자에게 대상을 묻는다.
5. 후보가 하나도 없을 때만 새 파일을 만든다.

4번이 기본값인 이유는 두 오답의 비용이 다르기 때문이다. 잘못 병합하면 사용자가 즉시 알아채고 되돌릴 수 있지만, 불확실할 때 새 파일로 기울면 같은 작업의 handoff가 조용히 파편화되고 사용자는 `list`를 돌리기 전까지 알 수 없다.

**3단계 — 병합.** §5.4의 섹션별 규칙을 적용하고, 문서에 frontmatter가 없으면 §5.2에 따라 추가한다.

**4단계 — 실패 처리.** 대상 경로에 쓸 수 없으면(권한 거부, sandbox 차단, 디스크 오류) 실패 사실을 명시하고 **작성하려던 문서 전문을 대화에 그대로 출력한다.** `save`는 사용자가 세션을 접으려는 시점에 실행되므로 조용한 실패는 그대로 작업 내용 유실이 된다. 실패를 성공처럼 보고하거나, 권한 문제를 우회해 다른 경로에 쓰는 것은 금지한다.

**5단계 — 보고.** 저장한 전체 경로와 실제 재개 방법을 알려준다.

### 6.2 `list`

1. 현재 프로젝트의 handoff 디렉토리를 스캔한다.
2. 각 문서의 slug, 수정일, Goal 첫 문단을 반환한다.
3. 어떤 파일도 생성하거나 수정하지 않는다.

### 6.3 `resume`

1. 대상 문서를 끝까지 읽는다.
2. Goal, What Worked, Next Steps를 사용자 언어로 짧게 정리한다.
3. What Didn't Work에 기록된 실패를 명시적으로 보존한다.
4. Next Steps 실행 전에 사용자 확인을 받고 현재 턴을 종료한다.
5. 확인 후 부모 세션에서 작업을 계속한다.

### 6.4 `delete`

1. 삭제 대상의 slug와 Goal을 사용자에게 보여준다.
2. 사용자가 현재 요청에서 정확한 대상을 이미 확정한 경우를 제외하고 삭제 확인을 받는다.
3. 확인된 파일만 삭제한다.
4. 삭제한 실제 경로와 복구 가능 여부를 보고한다.

## 7. 제안 아키텍처

```text
handoff/
├── skills/
│   ├── save/
│   │   └── SKILL.md
│   ├── list/
│   │   ├── SKILL.md
│   │   └── agents/
│   │       └── openai.yaml
│   ├── resume/
│   │   └── SKILL.md
│   └── delete/
│       ├── SKILL.md
│       └── agents/
│           └── openai.yaml
├── scripts/
│   ├── handoffs.sh
│   └── context-pressure.sh
├── hooks/
│   └── hooks.json
├── .claude-plugin/
│   └── plugin.json
└── .codex-plugin/
    └── plugin.json
```

`SKILL.md`는 네 동작의 공통 본문을 담는다. `list`와 `delete`에만 있는 `agents/openai.yaml`은 해당 skill의 Codex 호출 정책을 담는 skill 부속 파일이다 — **플러그인 전체가 아니라 skill 하나에 스코프된다.** `save`와 `resume`은 자동 호출을 막을 이유가 없으므로 이 파일이 필요 없다. 즉 워크플로우는 하나로 공유하되 **host별 실행 계약은 파일을 나눈다.** 이유는 §7.1의 frontmatter 지원 현황에 있다.

이 위치는 추정이 아니라 로컬에 설치된 Codex CLI(`codex-cli 0.150.0`)로 확인한 사실이다. Codex가 스킬을 만들 때 자신이 참조하는 `skill-creator` 번들 스킬(`~/.codex/skills/.system/skill-creator/SKILL.md`, `references/openai_yaml.md`)이 `agents/openai.yaml`을 `scripts/`·`references/`·`assets/`와 같은 층위의 **skill 부속 파일**로 명시하고, `policy.allow_implicit_invocation`도 그 파일 안에 둔다. OpenAI의 `migrate-to-codex` 자료(`references/differences.md`, "Docs last checked: 2026-04-20")는 이 필드의 선언 위치를 명시하지 않았는데, `skill-creator`가 그보다 최신이고 Codex CLI 자체의 스캐폴딩 동작과 직접 일치하므로 이쪽을 근거로 채택한다.

`scripts/context-pressure.sh`는 host별 parser를 한 파일 안에서 분기한다. Claude와 Codex의 transcript 해석은 §9.2, §9.3에 따라 별도 함수로 분리하되 hook 진입점은 하나로 유지한다. 파일을 host별로 쪼개면 hook 설정도 host별로 갈라져 공통 계층이 얇아지는 이점이 사라진다.

### 7.1 결정: `skills/`만 사용

`skills/`를 워크플로우의 유일한 원본(source of truth)으로 삼고 기존 `commands/`는 제거한다.

플러그인 skill에는 command와 같은 플러그인 네임스페이스가 적용된다. 예를 들어 `handoff/skills/save/SKILL.md`는 Claude Code에서 `/handoff:save`로 호출되므로 기존 사용자 호출 방식이 유지된다.

#### frontmatter 지원 현황

현재 `commands/*.md`가 쓰는 frontmatter 다섯 개를 host별로 나눠 보면 다음과 같다. **두 host의 지원 여부는 별개의 축이며 한쪽 근거를 다른 쪽에 전용할 수 없다.**


| frontmatter                | Claude                            | Codex                                        | 조치                                      |
| -------------------------- | --------------------------------- | -------------------------------------------- | --------------------------------------- |
| `argument-hint`            | 지원                                | 직접 대응 없음                                     | Claude 전용 UI 힌트로 유지                     |
| `allowed-tools`            | 지원 — 도구 permission 제어             | strict allowlist 미지원, prompt guidance만 가능    | Codex에서 도구 제한 수단으로 **의존 금지**            |
| `disable-model-invocation` | 지원                                | 직접 대응 없음 — `allow_implicit_invocation`이 유사 기능 | Codex는 해당 skill의 `agents/openai.yaml`에 별도로 선언 |
| `model`                    | 지원 — skill 활성 turn의 모델 override   | skill-level override 미지원                     | Claude는 그대로 유지, Codex는 부모 세션 모델          |
| `effort`                   | 지원 — session effort override      | skill-level override 미지원                     | Claude는 그대로 유지, Codex는 부모 세션 설정          |


**두 열의 근거가 서로 다르다.** Claude 열은 Claude Code 공식 skills 문서의 frontmatter 정의가 근거이고, Codex 열은 OpenAI의 Claude→Codex migration 자료가 근거다. 어느 쪽이든 **설치된 플러그인에서 각 키가 몇 번 쓰이는지는 근거가 되지 못한다.** 실제로 로컬 `SKILL.md` 168개에서 `model`과 `effort`는 사용 0건이지만 둘 다 공식 지원 필드다. 사용 빈도는 지원 여부와 무관하며, 이 문서는 그 둘을 섞지 않는다.

**구조를 한 줄로 요약하면** Codex가 Skills를 지원하지 않는 게 아니다. Claude Code는 [Agent Skills](https://agentskills.io) 표준을 구현한 뒤 그 위에 자체 확장을 얹었고, Codex에는 표준 부분만 있다. 표준이 정의하는 portable core는 여섯 개다.

```text
name  description  license  compatibility  metadata  allowed-tools
```

이 구분이 §7.1 결정의 근거다. **공유할 수 있는 건 표준 core이고, 나머지는 host별 파일로 내린다.** 필드별 전체 대조는 [SKILL.md Frontmatter 호환성 대조표](./skill-frontmatter-compat.md)에 있다 — 공통 / 유사 대응 / Claude 전용 / Codex 전용 4분류와 각 항목의 출처를 담았다.

`list`와 `delete`의 현재 설정(`model: haiku`, `effort: low`)은 Claude에서 그대로 `SKILL.md`로 옮기면 된다. Codex에서는 skill-level override가 없으므로 두 skill이 부모 세션 모델로 실행되며, 이는 §8.1의 기본 원칙과 어긋나지 않는다.

#### 이름 충돌 규칙

같은 플러그인에 `commands/x.md`와 `skills/x/SKILL.md`가 동시에 존재하면 **command가 skill을 가린다.** 근거는 `pm-execution` 플러그인이다. `commands/` 11개와 `skills/` 16개를 가지고 있고 `pre-mortem`, `stakeholder-map`, `test-scenarios` 세 이름이 양쪽에 있는데, 실제로 노출되는 건 command 쪽 하나뿐이고 같은 이름의 skill은 목록에 나타나지 않는다.

따라서 전환 중 두 디렉토리를 함께 두면 새 `SKILL.md`는 실행되지 않는다. 이 사실이 §12 단계 2의 검증 순서를 결정한다.

#### Codex와의 공유: 본문은 하나, 실행 계약은 분리

Codex는 알 수 없는 frontmatter 키를 대체로 조용히 무시한다. 따라서 **단일 `SKILL.md`를 두 host가 공유하는 구조는 성립한다.** Claude 전용 키가 Codex 로드를 깨뜨리지 않는다.

**이 절은 이제 추론이 아니라 실측이다 (2026-08-27, `codex-cli 0.150.0`).** `commands/`를 제거하고 `skills/`·`.codex-plugin/plugin.json`·`list`와 `delete`의 `agents/openai.yaml`을 갖춘 이 브랜치의 빌드를 실제로 로컬 marketplace에 등록해 `codex plugin add`로 설치했다. 결과: `model`, `effort`, `disable-model-invocation: true`, `allowed-tools`가 그대로 남은 `list/SKILL.md`가 경고 없이 설치됐고(`installed, enabled`), `codex doctor`에도 관련 항목이 없었다. `.codex-plugin/migrated-command-skills`(§1의 손실 압축 변환)도 생성되지 않았다 — `commands/`가 없으니 애초에 그 경로를 타지 않는다.

한 가지 예외에 주의한다. Codex CLI 번들 `plugin-creator` skill의 `scripts/validate_plugin.py`(스캐폴딩 저작 도구가 자체 점검용으로 쓰는 별도 린터)는 `disable-model-invocation: true`를 **에러로 판정한다** ("must be false"). 이건 실제 설치 경로의 동작이 아니라 그 도구의 저작 규약일 뿐이지만, 이 린터를 신뢰해 `disable-model-invocation`을 지워야 한다고 오판하지 않도록 기록해 둔다. 실제로 설치를 막는 건 없다.

다만 `SKILL.md`에 Claude 전용 키를 적어두는 것과 Codex에서 같은 효과가 나는 것은 다른 문제다. 위 표의 Codex 열이 전부 미지원이라는 건, **Codex의 동작 계약을 `agents/openai.yaml`과 Codex 설정으로 옮겨야 한다**는 뜻이다.

**번복 (2026-08-27, 실측 근거로 이전 결정을 뒤집음).** 초안은 자동 호출 차단을 위해 다음 설정을 `list`·`delete`의 `agents/openai.yaml`에 넣는 방안을 제시했었다.

```yaml
# skills/list/agents/openai.yaml  (delete도 동일하게, 더 이상 쓰지 않음)
policy:
  allow_implicit_invocation: false
```

당시 근거는 "이렇게 하면 프롬프트 기반 자동 선택은 막히고 `$skill-name` 형태의 명시적 호출은 유지된다"였다. **`codex exec`로 직접 실측한 결과 이 전제가 틀렸다.** `allow_implicit_invocation: false`는 자연어 자동 호출뿐 아니라 `$list`/`$delete` 명시 호출까지 함께 막아서, 이 설정이 있는 한 Codex에서 `list`와 `delete`는 **어떤 방식으로도 호출할 수 없었다.** 대조군으로 이 설정이 없는 `save`는 저장소 밖에서 `$save`가 정상 작동했고, `list`에서 이 설정만 빼자 즉시 `$list`가 정상 작동했다 — 근거는 §12 단계 2 "설치 레벨 발견 2"에 있다.

그래서 **`list`·`delete`의 `agents/openai.yaml`에서 `policy` 블록을 뺐다** (`interface`만 남긴다). 트레이드오프는 이렇다 — Codex에서는 `list`/`delete`도 `save`/`resume`처럼 자연어로 자동 활성화될 수 있다. `list`는 읽기 전용이라 이 정도는 감수할 만하다. `delete`는 §6.4의 확인 절차(삭제 전 slug·Goal 표시 후 승인)가 skill 활성화 여부와 무관하게 실제 `rm` 앞을 막고 있으므로, skill이 의도치 않게 켜지더라도 파일이 지워지지는 않는다. 결과적으로 **Codex에서 삭제 오남용을 막는 건 처음부터 frontmatter/policy가 아니라 §6.4의 확인 절차였다** — 이번 실측은 그 사실을 명확히 했을 뿐이다.

참고로 이 `policy` 필드가 애초에 `disable-model-invocation`의 공식 대응은 아니었다. OpenAI의 매핑표는 `disable-model-invocation`을 "직접 대응 없음, 수동 재작성 필요"로 분류하고, `allow_implicit_invocation`에 대응시키는 건 다른 필드인 `user-invocable`이며 그마저 "semantics가 다르므로 수동 검토 필요"라고 단서를 단다. 공식 등가 매핑이 아닌 대체 결정을 썼다가, 그 대체 결정 자체가 실측에서 깨진 셈이다.

`model`과 `effort`는 `SKILL.md`가 아니라 Codex 설정이나 custom agent 정의에서 `model`, `model_reasoning_effort`로 지정한다. 다만 §8.1의 기본 원칙에 따라 Codex에서는 부모 세션 모델을 그대로 쓰므로 초기 범위에서는 지정하지 않는다.

`allowed-tools`는 Claude에서 실제 permission 제어 기능이지만, Codex에는 대응하는 strict allowlist가 없다. `agents/openai.yaml`이 도구 의존성을 선언할 수는 있어도 그것은 permission boundary가 아니며, OpenAI의 migration 스크립트도 Claude의 `allowed-tools`를 frontmatter로 옮기지 않고 본문의 prompt guidance로 변환한다. 따라서 **Codex에서 `list`와 `resume`의 읽기 전용성을 `allowed-tools`로 보장하려 해서는 안 된다.** §11의 읽기 전용 규칙은 skill 본문의 동작 규칙과 §6.2·§6.3의 계약으로 지킨다.

#### 공통 본문 규칙

- 네 skill은 host 중립적인 용어를 사용한다.
- `AskUserQuestion`, `Bash`, `${CLAUDE_PLUGIN_ROOT}` 같은 host 전용 표현을 공통 본문에 직접 넣지 않는다.
- 경로 계산, 스캔, slug 검증 등 결정론적 처리는 `scripts/`가 담당한다.
- Claude 전용 frontmatter는 Codex의 핵심 동작에 영향을 주지 않는 선택적 metadata로만 사용한다.

### 7.2 Claude 어댑터

- 기존 `/handoff:*` UX를 유지한다.
- `skills/*/SKILL.md`를 직접 로드하므로 별도 command shim을 두지 않는다.
- Claude 전용 모델, effort, tool 및 invocation metadata는 각 `SKILL.md` frontmatter에 둔다.
- Claude transcript 파싱은 Claude adapter 내부에 둔다.

### 7.3 Codex 어댑터

- `.codex-plugin/plugin.json`에서 `skills/`와 `hooks/`를 명시한다.
- 네 skill 모두 Codex에서 기본값(자동 활성화 허용)을 쓴다. `list`·`delete`의 `agents/openai.yaml`은 `interface`(표시 이름) 용도로만 남기고 `policy.allow_implicit_invocation: false`는 넣지 않는다 — 이 필드가 `$` 명시 호출까지 막는다는 게 실측으로 확인됐기 때문이다 (§7.1 "번복" 참고). Codex에서 `delete` 오남용을 막는 건 이 policy가 아니라 §6.4의 확인 절차다.
- `SKILL.md`에서 Codex가 계약으로 보장하는 것은 Agent Skills 표준 6개 필드와 본문 instructions뿐이라고 가정한다. 그중에서도 `allowed-tools`는 Codex에서 permission boundary가 아니다.
- 자동 command migration에 의존하지 않는다.
- Codex의 skill 호출 방식과 자연어 활성화를 지원한다.
- Codex hook payload와 rollout transcript는 Codex adapter에서만 해석한다.
- Codex sandbox와 approval 정책을 정상적인 실행 조건으로 취급한다.

Anthropic은 새 플러그인에 `skills/` 사용을 권장하며, OpenAI의 공식 전환 가이드도 Claude의 재사용 가능한 command를 skill로 변환하고 hook을 Codex 런타임에 맞게 조정하도록 안내한다.

### 7.4 커맨드 표기: 호출 접두사 (결정, 2026-08-30)

같은 skill을 호출하는 문법이 host마다 다르다. Claude Code는 `/handoff:list`, Codex는 `$handoff:list`다. 그런데 skill이 사용자에게 **되돌려 출력하는** 안내 문구에는 접두사가 `/`로 하드코딩돼 있었다 — Codex에서 `$handoff:list`로 호출했는데 결과 하단 안내는 "이어서 작업하려면 `/handoff:resume <slug>`"로 나오는, 그 host에서는 실행되지 않는 명령을 안내하는 버그였다.

**결정: 접두사를 문서에 박지 않고, skill instruction에서 host의 표기를 따르게 한다.** 각 SKILL.md 끝에 동일한 `## Command notation` 문단을 두고 두 단계 규칙을 준다.

1. 사용자가 명시 호출을 타이핑했다면 **그 호출의 접두사를 그대로 복사한다.** 이게 가장 강한 신호이고, 두 host 모두 그 입력이 transcript에 남는다.
2. 자연어로 활성화돼 복사할 접두사가 없으면 현재 host의 표기를 쓴다 (Claude Code `/`, Codex `$`).

**대안으로 검토했다가 채택하지 않은 것: 환경변수 기반 host 감지.** `handoffs.sh`에 `prefix` 서브커맨드를 두고 `CLAUDECODE`(Claude Code가 모든 tool shell에 넣는 것을 실측 확인)와 `CODEX_*`로 판별하는 안이었다. 채택하지 않은 이유는 두 가지다 — (a) Codex 쪽 신호는 실측하지 못했다. 바이너리(`codex 0.151.0`)에 `CODEX_SANDBOX`, `CODEX_SANDBOX_NETWORK_DISABLED`, `CODEX_THREAD_ID` 문자열이 존재하는 것까지만 확인했고, 이 중 무엇이 **모든 실행 모드에서** skill의 shell에 실제로 주입되는지는 확인하지 못했다. (b) 감지에 성공하더라도 "출력할 때 이 값을 치환하라"는 지시 이행 문제는 그대로 남으므로, shell 왕복 한 번을 더 들이고 미검증 감지를 넣는 대가에 비해 얻는 게 작다.

**hook 메시지는 예외적으로 기본값 `/`를 유지한다.** ~~`context-check`가 출력하는 배너·additionalContext는 지금 `hooks/hooks.json`(Claude adapter)에서만 등록되므로 `/`가 정확한 값이다.~~ **정정 (2026-08-31):** 이 전제가 틀렸다. 실제 Codex 설치의 `config.toml`에 `hooks.state."handoff@gilbert9172:hooks/hooks.json:user_prompt_submit:0:0"` 항목이 있고, 해당 세션의 rollout에도 이 hook의 `additionalContext`가 `/handoff:save`를 하드코딩한 채로 주입된 것이 실측됐다 — 즉 Codex도 같은 `hooks/hooks.json`을 그대로 등록해서 쓰고 있었고, 고정 기본값 `/`가 Codex 세션에도 새어 들어가 모델이 잘못된 표기를 그대로 옮기는 사례(사용자 리포트, 2026-08-31)로 이어졌다. `context-check`는 이미 컨텍스트 한도 계산을 위해 transcript에 `model_context_window` 필드가 있는지로 Codex/Claude를 구분하고 있었으므로(§9.4), 같은 판별을 재사용해 `HANDOFF_CMD_PREFIX`의 기본값 자체를 Codex transcript면 `$`, Claude transcript면 `/`로 자동 결정하도록 바꿨다. 환경변수 override는 이 자동 감지가 통하지 않는 host를 위한 escape hatch로 그대로 남긴다(기존 `HANDOFF_BAND_*`, `HANDOFF_CONTEXT_LIMIT`와 같은 성격).

## 8. 모델 정책

### 8.1 기본 원칙

Codex에서는 handoff skill이 현재 부모 세션의 모델을 그대로 사용한다.

이유는 다음과 같다.

- `save`는 현재 대화의 전체 맥락을 가장 잘 보존한 부모 모델이 수행해야 한다.
- `resume`은 handoff를 읽은 뒤 같은 부모 세션에서 작업을 계속해야 한다.
- `list`와 경로 계산은 대부분 결정론적 스크립트로 처리할 수 있다.
- `delete`는 모델 성능보다 정확한 대상 확인과 승인 절차가 중요하다.
- 단순 작업을 별도 저비용 subagent로 넘기면 컨텍스트 전달과 orchestration 비용이 추가된다.

### 8.2 선택적 최적화

실제 평가에서 비용이나 지연 문제가 확인되는 경우에만 경량 custom agent를 선택 기능으로 검토한다. 플러그인의 핵심 동작은 custom agent 설치 여부에 의존하지 않아야 한다.

`SKILL.md`의 `model`과 `effort`는 Claude 전용 최적화 힌트이며 공통 계약에 포함하지 않는다.

- **Claude**: 공식 지원 필드다. skill이 활성인 동안에만 세션 설정을 덮어쓰고 다음 사용자 prompt부터 원래 모델로 돌아간다. `list`와 `delete`의 `model: haiku`, `effort: low`를 그대로 유지한다.
- **Codex**: skill-level override가 없다. Codex 설정이나 custom agent 정의의 `model`, `model_reasoning_effort`로 지정할 수는 있으나, §8.1 원칙에 따라 초기 범위에서는 지정하지 않고 부모 세션 모델을 그대로 쓴다.

결과적으로 같은 skill이 Claude에서는 저비용으로, Codex에서는 부모 모델로 실행된다. **이 비대칭은 허용한다.** §13의 마지막 항목이 요구하는 건 핵심 기능이 특정 모델에 의존하지 않는 것이지, 두 host의 실행 비용이 같은 것이 아니다.

## 9. 컨텍스트 압력 감지

컨텍스트 알림은 핵심 기능이 아니라 선택적 보조 기능으로 정의한다.

### 9.1 공통 정책

- 자동으로 handoff를 저장하지 않는다.
- 임계치 도달 시 저장을 제안하기만 한다.
- 각 알림 단계는 세션당 한 번만 표시한다.
- 사용량을 신뢰할 수 없으면 경고 없이 종료한다.
- parser 오류가 일반 사용자 요청을 막아서는 안 된다.

### 9.2 Claude adapter

진입점은 `UserPromptSubmit` hook이다. hook payload의 `transcript_path`로 transcript를 열고 마지막 usage 기록을 해석한다.

```text
(input_tokens + cache_read_input_tokens + cache_creation_input_tokens) / limit
```

Claude transcript에는 컨텍스트 한도가 없으므로 마지막 assistant message의 `message.model`을 읽는다. 별도 `claude_model_context_map`에는 컨텍스트가 1M으로 고정된 모델만 명시하고, 맵에 없는 모델은 표준 200K로 계산한다. 사용자가 `HANDOFF_CONTEXT_LIMIT`를 지정한 경우에는 자동 감지값보다 우선한다.

### 9.3 Codex adapter

진입점은 Codex에서 `UserPromptSubmit`에 대응하는 prompt 단계 hook이다. **이벤트 이름은 확정됐다** — Claude와 동일하게 `hooks/hooks.json`의 `"UserPromptSubmit"` 키를 그대로 쓴다. 근거: `codex-cli 0.150.0`에 우리 plugin의 `hooks/hooks.json`을 설치한 뒤 `~/.codex/config.toml`의 `[hooks.state]`에 `"<plugin>@<marketplace>:hooks/hooks.json:user_prompt_submit:0:0"` 형태의 trust 키가 기록되는 것을 확인했다 (다른 설치된 plugin들의 `session_start`/`session_end`/`stop`도 같은 snake_case 패턴). 현재 로컬 Codex rollout에서는 `token_count` 이벤트가 다음 값을 제공한다.

- `last_token_usage.input_tokens`
- `model_context_window`

Codex 사용률은 가능한 경우 다음처럼 계산한다.

```text
last_token_usage.input_tokens / model_context_window
```

누적 세션 사용량인 `total_token_usage`를 현재 컨텍스트 사용량으로 오인해서는 안 된다. 또한 `cached_input_tokens`는 `input_tokens`에 다시 더하지 않는다.

다만 공식 문서는 `transcript_path`는 제공하지만 transcript 포맷 자체는 안정적인 hook 인터페이스가 아니라고 명시한다. 따라서 Codex parser는 버전별 fixture로 검증하고, 예상 schema가 없으면 조용히 비활성화해야 한다.

**전제 조건 — hook trust.** Codex는 플러그인 번들 hook을 사용자가 최소 한 번 신뢰(trust)하기 전까지 실행하지 않는다 (2026-08-27 실측, `codex-cli 0.150.0`). `codex exec`처럼 승인 프롬프트가 없는 자동화 실행에서는 신뢰되지 않은 hook이 **에러 없이 조용히 스킵**된다 — `--dangerously-bypass-hook-trust` 플래그가 정확히 이 상황을 위해 존재한다는 것으로 메커니즘은 확인했지만, 실제 payload 내용(위 `token_count` 필드가 hook stdin에 직접 오는지, rollout 파일을 열어야 하는지)은 신뢰 게이트 때문에 이번 라운드에 실측하지 못했다. 사용자가 대화형 세션에서 이 플러그인의 hook을 처음 만났을 때 신뢰 승인을 하기 전까지는 context-check가 계속 무반응일 수 있다는 뜻이므로, §11(권한과 안전)이나 README에 "처음 설치 후 hook 승인이 필요할 수 있다"는 안내를 추가해야 한다.

### 9.4 두 계산식의 등가성

§9.2와 §9.3의 식은 형태가 다르지만 **같은 값을 뜻한다.** 두 식 모두 "현재 컨텍스트에 올라와 있는 전체 토큰"을 구한다.

- Claude transcript의 `input_tokens`는 캐시 토큰을 포함하지 않으므로 캐시 항목 두 개를 더해야 전체가 된다.
- Codex의 `last_token_usage.input_tokens`는 이미 캐시분을 포함하므로 `cached_input_tokens`를 더하면 이중 계산이 된다.

두 host가 같은 임계 밴드를 공유할 수 있는 근거가 이 등가성이다. 나중에 한쪽을 버그로 오해하고 "고치는" 일이 없도록 구현 코드에도 같은 주석을 남긴다.

### 9.5 Lifecycle fallback

Codex의 `PreCompact`와 `PostCompact` 이벤트는 토큰 비율을 대신하는 보조 신호로 사용할 수 있다. 단, compaction을 차단하거나 사용자의 동의 없이 저장하는 방식은 기본값으로 사용하지 않는다.

## 10. 저장 위치와 마이그레이션

### 10.1 저장 위치 (결정, 2026-08-29 구현)

host 중립적인 사용자 데이터 경로를 확정하고 구현했다.

```text
~/.handoffs/<project-slug>/HANDOFF-<task-slug>.md
```

초안(`~/.handoff/projects/<project-id>/handoffs/...`)에서 두 가지를 바꿨다.

- `.handoff`(단수) 대신 `.handoffs`(복수)를 쓴다. `~/.claude`·`~/.codex`처럼 홈 직하 디렉토리 관례를 따르는 것은 같지만, 이름 자체가 이 도구의 명령 이름(`save`/`list`/`resume`/`delete`가 다루는 대상)과 그대로 대응해 더 직관적이다.
- `projects/<id>/handoffs/` 두 겹 중첩을 없애고 `<project-slug>/`로 한 단계 평탄화했다. 최상위가 이미 `.handoffs`이므로 그 아래에 다시 `handoffs/`를 두는 건 중복이었다.

`<project-slug>`는 §10.3의 기존 알고리즘(git root 절대경로의 `/`→`-`)을 그대로 쓴다 — 새 알고리즘이 아니라 저장 위치만 옮긴 것이다. 이 알고리즘은 Claude가 자체적으로 `~/.claude/projects/`를 만들 때 쓰는 것과 우연히 같지만, `~/.handoffs/`는 그 디렉토리 아래에 있지 않다 — 완전히 분리된 host 중립 최상위 경로다. **Codex는 프로젝트별 디렉토리 관례가 아예 없다** (`~/.codex/sessions/<year>/<month>/<day>/rollout-*.jsonl`처럼 날짜로만 분리하고, 프로젝트 식별자는 각 rollout의 `session_meta.payload.cwd`에만 존재 — 2026-08-29 실측). 그래서 "Codex 방식에 맞춘다"는 선택지 자체가 없고, 이 slug 계산은 두 host 중 어느 쪽 관례도 아닌 **plugin 자체의 계산**이다. Claude와 Codex가 같은 git 저장소에서 이 스크립트를 호출하면 같은 절대경로 → 같은 slug → 같은 디렉토리로 수렴하므로, 어느 host에서 저장했는지는 조회 결과에 영향을 주지 않는다.

사용자가 다른 위치를 원하면 `HANDOFF_HOME` 환경변수로 덮어쓸 수 있다(계획, 미구현). XDG data directory를 쓰는 사용자는 이 환경변수로 흡수되므로 별도 규격을 따르지 않는다.

플러그인별 `PLUGIN_DATA`는 host 및 설치별로 분리될 수 있으므로 Claude와 Codex가 공유하는 영구 저장소로 사용하지 않는다.

**받아들인 한계.** slug가 프로젝트명이 아니라 전체 절대경로이므로 이름 충돌은 없지만, 같은 프로젝트를 다른 절대경로(이동, worktree, 다른 위치의 clone)에서 열면 다른 slug로 갈라진다. 이 저장소 자체가 실례다 — `~/.claude/projects/`에 `-Users-giljun-ai-zone-handoff`와 `-Users-giljun-repository-ai-zone-handoff`가 별도로 존재한다(같은 논리적 프로젝트, 사용자가 폴더를 옮긴 결과). 이 분기를 자동으로 병합하는 로직은 두지 않는다 — 사용자가 스스로 만든 경로 변경이므로 사용자가 수동으로 정리하는 것이 맞다는 판단이다(§14에 반영).

### 10.2 호환 전략 (수정, 2026-08-29 — dual-read 대신 명시적 `migrate`; `migrate` skill 구현 완료)

기존 문서는 이전 위치에 남아 있다.

```text
~/.claude/projects/<project-slug>/handoffs/
```

초안은 "새 경로와 기존 경로를 함께 탐색"하는 dual-read 기간을 두는 계획이었다. 이를 뒤집는다 — `dir`/`scan`은 `context-check` 훅과 함께 매 프롬프트·매 커맨드마다 도는 hot path이므로, 여기에 두 경로를 매번 스캔하는 로직을 영구히 심는 비용이, 한 번의 명시적 이동보다 크다고 판단했다. 대신:

1. §10.1의 새 경로(`~/.handoffs/<project-slug>/`)로 **즉시 전환**한다. dual-read 기간을 두지 않는다.
2. 기존 `~/.claude/projects/<project-slug>/handoffs/` 문서는 이 전환만으로는 보이지 않는다. 별도의 `migrate` 동작이 명시적으로 옮긴다. — **구현 완료 (2026-08-29).** `skills/migrate/SKILL.md`, `scripts/handoffs.sh`의 `dir legacy`·`scan legacy` 인자.
3. `migrate`는 자연어 자동 호출을 막고 명시 호출만 허용한다(여러 파일을 이동하는 구조적 작업이라 `delete`보다 보수적으로 다룬다). Claude는 `disable-model-invocation: true`로 보장하고, Codex는 §7.1의 실측대로 이 필드에 대응하는 안전한 수단이 없으므로 자연어 활성화 가능성을 그대로 받아들인다 — 실제 안전장치는 이 정책이 아니라 아래 5번의 확인 절차다.
4. `migrate`는 **같은 slug 1:1**만 옮긴다. slug가 다른 "사실은 같은 프로젝트"(§10.1의 받아들인 한계 참고)를 찾아 병합하는 로직은 두지 않는다 — 사용자가 만든 경로 변경이므로 사용자가 수동으로 처리한다. (구조적으로 자동 보장됨: `dir`과 `dir legacy`는 같은 `$slug` 변수를 공유하므로 애초에 다른 slug를 볼 수 없다.)
5. 이동하려는 slug가 새 경로에 이미 존재하면 자동 병합하지 않는다. 두 문서의 `updated`(없으면 파일 수정 시각)와 Goal 첫 문단을 나란히 보여주고, 슬러그별로 "새 것 유지 / 옛 것으로 교체 / 둘 다 보존(`HANDOFF-<slug>-legacy.md`)" 중 사용자가 고르게 한다.
6. `mv`는 사용자가 확인한 파일만, 확인한 목적지로만 실행한다. 이동은 대상 파일을 옛 위치에서 제거하는 부수효과를 가지므로(=`mv`의 기본 동작) 별도의 삭제 단계를 두지 않는다. 디렉토리 자체는 지우지 않는다.
7. `migrate`는 임시 기능이다. 옛 위치에 아무것도 없으면 조용히 "옮길 게 없다"고 보고하고 종료하므로(no-op), 설치돼 있는 채로 방치해도 위험하지 않다. 실제 삭제 시점은 §14 참고.

### 10.3 프로젝트 ID (결정, 2026-08-29)

기존과 동일하게 git root의 절대 경로를 정규화한 값(`/`→`-`)을 그대로 쓴다. git remote나 별도 repository ID로 바꾸지 않는다 — 이름 충돌이 없다는 게 이 방식의 핵심 장점이고, 두 host 중 어느 쪽도 강제하는 관례가 없어(§10.1) 바꿀 압력도 없다.

저장소 이동, worktree, 동일 remote의 다른 clone은 **의도적으로 하나의 프로젝트로 통합하지 않는다.** 절대 경로가 다르면 다른 slug다. 자동 통합 로직(예: remote URL로 동일성 판단)은 오탐 시 서로 무관한 두 작업의 handoff를 한 폴더에 섞는 대가가, 미탐 시 이미 있는 수동 정리 부담보다 크다고 판단해 두지 않기로 했다. 사용자가 프로젝트를 옮겨서 slug가 갈라진 경우는 §10.1의 "받아들인 한계"이며, 필요하면 사용자가 파일을 직접 옮긴다.

## 11. 권한과 안전

- handoff 문서는 저장소 밖의 사용자 데이터이므로 쓰기 권한이 필요하다.
- Codex sandbox에서 홈 경로 쓰기가 허용되지 않으면 정상적인 approval 흐름을 사용한다.
- 권한 우회를 시도하지 않는다. 승인이 거부되면 §6.1 4단계의 실패 처리로 넘어간다.
- `list`와 `resume`의 문서 읽기는 가능한 한 읽기 전용으로 유지한다.
- `delete`는 정확한 파일 경로를 먼저 해석한 뒤 확인된 단일 파일만 대상으로 한다.
- hook은 사용자의 일반 prompt를 차단하지 않는다.
- transcript 원문이나 민감한 내용을 hook 출력에 포함하지 않는다.
- **Codex에서는 이 plugin의 hook을 사용자가 최초 1회 신뢰(trust) 승인해야 `context-check`가 동작한다.** 승인 전에는 조용히 무반응이며, 이는 §9.1 "사용량을 신뢰할 수 없으면 경고 없이 종료한다" 원칙과 일관되게 동작하는 것이지 오류가 아니다. 최초 설치 안내(README/QUICKSTART)에 이 사실을 명시해야 한다 (2026-08-27 실측).
- `list`·`delete`의 `agents/openai.yaml`에는 `policy.allow_implicit_invocation: false`를 넣지 않는다(§7.1 "번복" 참고 — 이 필드가 `$` 명시 호출까지 막는 것을 실측했다). 따라서 Codex에서 삭제 오남용을 막는 건 frontmatter/policy가 아니라 §6.4의 확인 절차(삭제 전 slug·Goal 표시 후 승인)뿐이라는 점을 항상 전제한다.

## 12. 배포 전략

### 단계 1: 공통 계약 정립

- 네 동작의 입력, 출력, 병합, 대상 판정, 실패 처리 규칙을 고정한다.
- 기존 스크립트의 경로 및 스캔 로직을 공통 코어로 정의한다.
- 현재 Claude 동작에 대한 회귀 테스트 기준을 만든다.

### 단계 2: `skills/` 전환과 Codex packaging

검증 순서가 중요하다. `commands/`와 `skills/`를 함께 둔 채로 확인하면 §7.1의 이름 충돌 규칙에 따라 command가 skill을 가려서, 통과하더라도 실제로 실행된 건 옛 파일이다. 그런 검증은 false green이다.

1. ✅ 기존 `commands/*.md`의 내용을 `skills/*/SKILL.md`로 옮긴다. (`provider-neutral-migration` 브랜치, `commands/` 삭제 완료)
2. ✅ **`commands/`를 삭제한 상태**로 별도 브랜치에서 로컬 설치한다. Claude 쪽은 이 세션에서 직접 재기동해 재확인하지 못했으므로 **다음 Claude Code 세션에서** `/handoff:save` 등이 여전히 뜨는지 재확인한다.
3. ⬜ `/handoff:save`, `/handoff:list`, `/handoff:resume`, `/handoff:delete` 직접 호출과 자연어 활성화를 검증한다. (Claude 쪽 미검증 — 항목 2와 같은 이유)
4. ⬜ `list`와 `delete`에 `disable-model-invocation`이 실제로 적용되어 모델 자동 호출이 차단되는지 확인한다. (Claude 쪽 미검증)
5. ⬜ `list`와 `delete`의 `model`, `effort`가 Claude에서 그대로 적용되는지 확인한다. (Claude 쪽 미검증)
6. ✅ `.codex-plugin/plugin.json`과 `list`·`delete`의 `agents/openai.yaml`을 추가하고, Claude command 자동 변환 없이 네 skill이 모두 발견되는지 검증한다. `codex-cli 0.150.0`에 로컬 marketplace로 실제 설치해 확인 — `installed, enabled`, `.codex-plugin/migrated-command-skills` 미생성.
7. ✅ Claude 전용 frontmatter가 포함된 `SKILL.md`가 Codex에서 경고 없이 로드되는지 확인한다. 위와 같은 설치에서 `list/SKILL.md`의 `model`·`effort`·`disable-model-invocation`·`allowed-tools`가 그대로 남은 채 경고 없이 설치됨을 확인.
8. ✅ (수정됨) 원래 목표였던 "`allow_implicit_invocation: false`로 자동 선택 차단 + `$` 명시 호출 유지"는 성립하지 않음을 실측으로 확인했다 (아래 "설치 레벨 발견 2"). 그래서 `list`·`delete`에서 이 정책 자체를 뺐고, 뺀 뒤 `$list`·`$delete`·`$save`·`$resume` 네 skill 모두 저장소 밖에서 정상 호출됨을 재확인했다 (2026-08-27). Codex에서 `delete` 오남용을 막는 건 이제 §6.4의 확인 절차뿐이라는 걸 전제로 한다.
9. ⬜ 위 항목이 모두 통과한 뒤에 main에서 `commands/` 삭제를 확정한다. (이미 이 브랜치에서는 삭제했지만 항목 3·4·5·8이 남아 있어 main 병합 전 재확인 필요)

#### 설치 레벨 발견 (2026-08-27, `codex-cli 0.150.0`)

**발견 1 — 플러그인 이름 충돌.** 서로 다른 marketplace가 같은 이름(`"handoff"`)의 플러그인을 제공하면, `$list` 같은 명시적 호출이 새로 설치한 쪽이 아니라 **먼저 설치돼 있던 쪽**으로 갔다. 재현: git marketplace `gilbert9172`(구버전, `commands/` 자동변환)와 로컬 테스트 marketplace `handoff-neutral-test`(이 브랜치의 `skills/` 빌드)를 동시에 설치한 상태에서 `$list`를 실행하니 `gilbert9172`의 `source-command-list`(구버전)가 실행됐다. `commands/`와 `skills/`가 같은 플러그인 안에서 이름이 겹칠 때 command가 이긴다는 §7.1의 규칙과 같은 종류의 문제가, 이번엔 **서로 다른 marketplace의 설치 레벨**에서도 재현된다. 실무적 함의: 실사용자가 git marketplace로 이미 설치해 둔 상태에서 로컬 개발 빌드를 나란히 테스트하면 안 되고, 실제 배포 시에도 같은 이름의 구버전이 남아있으면 새 버전이 조용히 가려질 수 있다.

**발견 2 — `policy.allow_implicit_invocation: false`가 `$` 명시 호출까지 막는다 (원인 특정 완료).** `gilbert9172`를 잠시 내리고 테스트 빌드만 남긴 뒤 단계적으로 격리했다.

1. handoff 저장소 안(cwd가 이 프로젝트)에서 `$list`는 실행됐지만, 모델이 "the repository's local `skills/list` implementation ... as the fallback"라고 표현한 것으로 보아 실제 Codex skill 등록 메커니즘이 아니라 **프로젝트 파일을 직접 찾아 읽은 것**이었다 — 이 결과는 무효로 취급한다.
2. handoff 저장소 밖(무관한 다른 프로젝트 디렉터리)에서는 `$list`가 전혀 인식되지 않고 "뭘 나열할지" 되묻는 일반 대화로 빠졌다.
3. 같은 저장소 밖 위치에서 `$save`를 실행하니 — `save`는 `agents/openai.yaml`이 없다 — **정상적으로 설치된 캐시 경로의 `SKILL.md`를 찾아 실행됐다.** 이걸로 "`$` 명시 호출 자체가 `codex exec`에서 안 되는 것"이라는 가설은 기각된다.
4. `list`의 `agents/openai.yaml`에서 `policy` 블록만 제거하고(=`interface`만 남기고 implicit 허용 기본값으로 되돌리고) 재설치한 뒤 저장소 밖에서 다시 `$list`를 실행하니 — **정상적으로 설치된 캐시 경로를 찾아 스캔 스크립트를 실행하고 "핸드오프가 없다"고 정확히 답했다.**

3번과 4번을 대조하면 결론은 하나다. **`policy.allow_implicit_invocation: false`는 문서(§7.1 인용, `skill-creator/references/openai_yaml.md`)가 말하는 것과 달리 이 Codex 버전(`codex-cli 0.150.0`)의 `codex exec`에서는 자연어 주입뿐 아니라 `$skill` 명시 호출까지 함께 막는다.** 대조군(`visualize`, 자연어 성공)과 `save`(`$` 성공)가 각각 "일반적으로 discoverability는 정상"이라는 것과 "`$` 문법 자체는 동작한다"는 것을 보여주므로, 남은 변수는 이 정책 필드 하나뿐이다.

**실무적 결론 (뒤이은 라운드에서 재검토 후 확정).** 처음에는 "이 필드를 빼는 게 답은 아니다 — `$` 호출이 안 된다는 걸 알고 확인 절차에 의존하면 된다"는 쪽으로 결론 내렸었다. 하지만 그건 "명시 호출이 안 될 수도 있으니 감안해서 쓰라"는 반쪽짜리 완화책이었고, 실제로는 **자연어도 `$`도 둘 다 안 되면 그 skill은 Codex에서 그냥 죽은 기능이다.** 그래서 결론을 뒤집었다 — `list`·`delete`의 `agents/openai.yaml`에서 `policy` 블록을 완전히 뺐다(§7.1 "번복"). 뺀 뒤 네 skill 모두 `$` 명시 호출이 저장소 밖에서 정상 작동함을 재확인했다 (§12 단계 2 항목 8). Codex에서 `delete` 오남용을 막는 방어선은 이제 §6.4의 확인 절차 하나뿐이라는 걸 명시적으로 받아들인다. 이 발견들은 `codex exec` 한정이며, 대화형 TUI가 다른 경로를 타는지는 확인하지 못했다 — 다만 정책 필드 자체를 빼버렸으므로 TUI 쪽 차이 여부는 더 이상 우리 구현에 영향을 주지 않는다.

**발견 3 — 플러그인 번들 hook은 사용자가 신뢰(trust)하기 전까지 아예 실행되지 않는다.** `hooks/hooks.json`의 `UserPromptSubmit`에 아무 조건 없이 파일을 쓰는 최소 명령을 넣고 재설치해도 실행되지 않았다. `~/.codex/config.toml`을 보면 `[hooks.state]` 테이블에 플러그인별 hook마다 `"<plugin>@<marketplace>:hooks/hooks.json:<event_snake_case>:0:0"` 키로 `trusted_hash`를 기록해 두는데, 우리 플러그인 항목은 없었다 — 즉 **한 번도 신뢰 승인을 받지 못한 hook은 자동화 실행(`codex exec`)에서 조용히 스킵된다.** `codex exec --help`에 정확히 이 상황을 위한 `--dangerously-bypass-hook-trust`("Run enabled hooks without requiring persisted hook trust... DANGEROUS")가 있어 메커니즘 자체는 확정됐지만, 이 플래그로 직접 재현하는 시도는 세션의 자동 승인 classifier가 막았다 — 이름에 "dangerously bypass ... trust"가 들어간 플래그라 위험 신호로 분류된 것으로 보인다. 그래서 우리 `context-check` hook이 신뢰된 뒤 Codex의 실제 `UserPromptSubmit` payload 모양(§9.3이 가정한 `token_count`/`last_token_usage`/`model_context_window` 필드가 hook stdin에 그대로 오는지, 아니면 다른 경로로 와서 우리가 rollout 파일을 별도로 열어야 하는지)은 **여전히 실측하지 못했다.** 이건 우리 구현의 결함이 아니라 Codex의 신뢰 게이트 때문이며, 실제 사용자는 대화형 세션에서 hook이 처음 실행될 때 뜨는 승인 프롬프트를 한 번 수락하면 이후에는 정상 작동할 것으로 보이지만 확인은 못 했다.

### 단계 3: Host adapter 분리

- plugin root, hook payload 및 사용자 입력 수단을 host별로 해석한다.
- 공통 skill 본문에서는 provider-neutral 용어만 사용한다.
- host별 차이는 hook과 runtime adapter에만 두고 command shim을 다시 만들지 않는다.

### 단계 4: Context hook

- ⬜ Claude와 Codex parser를 `scripts/context-pressure.sh` 안의 별도 함수로 분리한다. **미착수.** 대신 기존 `scripts/handoffs.sh`의 `context-check` 케이스 안에 Codex 분기를 추가하는 방식으로 구현했다(파일을 나누는 리팩터는 후속 작업으로 남긴다).
- ✅ Codex 쪽 파싱 로직을 구현하고 **실제 rollout 파일로 검증했다** (2026-08-27). `last_token_usage.input_tokens`/`model_context_window`를 실제 세션 rollout(`~/.codex/sessions/.../rollout-*.jsonl`)에서 확인한 뒤, 그 파일을 직접 hook payload처럼 스크립트에 흘려 넣어 사용량 계산·band 판정·marker 중복 방지가 모두 정확함을 확인했다. `total_token_usage`(누적)와 `last_token_usage`(현재 턴)를 혼동하지 않는지도 실제 데이터로 확인했다 — 두 값이 달라서(20017 vs 59147) 잘못 짚었으면 바로 드러났을 것이다.
- ✅ Claude 경로 회귀 테스트: 합성 Claude 스타일 transcript로 기존 계산(700000/1000000 → 70%)이 그대로 나옴을 확인해, Codex 분기 추가가 기존 동작을 깨지 않았음을 검증했다.
- ⬜ Codex schema 실패(예상 밖 payload) 테스트는 아직 정식 fixture로 추가하지 않았다 — 수동으로 "transcript_path 없음", "파일 없음", "빈 파일"만 확인했고(모두 조용히 exit 0), 정식 테스트 스위트로 옮기는 건 남아 있다.
- ⬜ **hook 자체가 실제로 이 payload를 받는지는 여전히 미검증.** hook trust 게이트 때문에 `codex exec`로 신뢰되지 않은 plugin hook을 실행할 수 없었다 (§14 참고). 파싱 로직은 검증됐지만 "hook이 호출되고 → stdin으로 transcript_path가 오고 → 이 스크립트가 그걸 받는" 전체 배선은 사용자의 대화형 세션에서 최초 신뢰 승인 후 재확인이 필요하다.

### 단계 5: 중립 저장 위치

- dual-read 정책과 `HANDOFF_HOME` override를 추가한다.
- 새로 쓰는 문서에 §5.2 frontmatter를 붙인다.
- 명시적 마이그레이션 경로를 제공한다.
- 충돌 및 권한 UX를 검증한 뒤 기본 쓰기 위치를 변경한다.

## 13. 완료 기준

다음 조건을 만족하면 Claude/Codex 공통 지원의 첫 버전을 완료한 것으로 본다.

1. Claude와 Codex에서 네 동작이 모두 네이티브하게 발견된다. — **Codex 쪽 완료.** `$save`·`$list`·`$resume`·`$delete` 네 skill 모두 프로젝트 밖에서 정상 호출됨을 실측했다 (2026-08-27, §12 단계 2 항목 8). Claude 쪽은 항목 2·3에서 재확인 필요.
2. Claude 전용 frontmatter가 포함된 `SKILL.md`가 Codex에서 경고 없이 로드된다. — §12 단계 2 항목 7에서 확인 완료.
3. ~~`list`와 `delete`의 자동 호출이 두 host 모두에서 차단된다.~~ **완료 기준을 수정한다 (2026-08-27).** Codex의 `allow_implicit_invocation: false`는 자동 호출뿐 아니라 `$` 명시 호출까지 막는 게 실측으로 확인돼 채택하지 않기로 했다(§7.1 "번복"). 그래서 이 항목은 "두 host 모두 frontmatter로 차단"이 아니라 다음으로 대체한다 — **Claude는 `disable-model-invocation`으로 자동 호출을 차단하고, Codex는 §6.4의 확인 절차만으로 오남용을 막는다.** 두 host의 방어 수단이 다르다는 걸 명시적으로 받아들인다.
4. 한 host에서 저장한 handoff를 다른 host가 목록 조회하고 재개할 수 있다.
5. frontmatter가 없는 기존 Claude handoff를 수정 없이 읽을 수 있다.
6. `save`가 §6.1의 대상 판정 순서를 따르고, 대상이 불확실하면 새 파일을 만드는 대신 사용자에게 묻는다.
7. `save` 업데이트가 섹션별 병합 규칙을 지킨다.
8. `save`가 쓰기에 실패하면 실패 사실과 작성하려던 문서 전문을 사용자에게 보여준다.
9. `list`는 완전히 읽기 전용이다. 이 성질은 `allowed-tools`가 아니라 skill 본문의 동작 규칙으로 보장한다.
10. `resume`은 실행 전에 사용자 확인을 받는다.
11. `delete`는 확인되지 않은 파일을 삭제하지 않는다.
12. Codex transcript schema를 알 수 없을 때 hook이 조용히 종료된다.
13. 잘못된 토큰 경고가 일반 대화를 방해하지 않는다.
14. 플러그인의 핵심 기능이 특정 모델이나 custom subagent에 의존하지 않는다.

## 14. 미결정 사항

- **Codex `UserPromptSubmit` hook의 실제 payload/응답 스키마 (신규, 2026-08-27, 부분 검증).** hook trust 게이트 때문에 `codex exec`로는 신뢰되지 않은 plugin hook이 실행되지 않아 두 가지를 실측하지 못했다.
  1. hook stdin에 `transcript_path`가 실제로 오는지 (§9.3 가정). — **rollout 파일 자체의 `token_count` 이벤트 형태(`last_token_usage.input_tokens`, `model_context_window`)는 실제 세션 rollout에서 직접 읽어 확인했고, `scripts/handoffs.sh`도 그 형태를 정확히 파싱하도록 구현·검증했다** (아래 §12 단계 4 참고). 남은 건 hook이 그 파일 경로를 stdin으로 넘겨주는지뿐이다.
  2. Codex가 hook 응답 JSON에서 Claude와 같은 `hookSpecificOutput.additionalContext` 키를 해석하는지, 아니면 다른 키를 기대하는지. 현재 스크립트는 Claude와 동일한 출력 형식을 그대로 재사용한다 — Codex가 이걸 무시하더라도 에러 없이 조용히 배너가 안 뜨는 정도로 저하될 것으로 예상하지만(SKILL.md frontmatter에서 확인한 것과 같은 "모르는 키는 조용히 무시" 패턴), 실측은 아니다.

  사용자가 대화형 세션에서 이 plugin의 hook을 한 번 신뢰 승인한 뒤 재확인이 필요하다.
- ~~Codex 대화형 TUI에서 `$skill` 명시 호출이 `allow_implicit_invocation: false`를 우회하는지~~ — **더는 의사결정에 영향을 주지 않는 질문이 됐다.** `list`·`delete`에서 이 policy 필드 자체를 뺐기 때문이다(§7.1 "번복"). `codex exec`와 TUI가 이 필드를 다르게 처리하는지는 여전히 미확인이지만, 우리가 그 필드를 안 쓰기로 한 이상 조사할 이유가 없다.
- Codex 컨텍스트 임계치 알림을 기본 활성화할지 opt-in으로 둘지
- §5.4의 누적 섹션에서 중복을 판정하는 구체적 기준
- **`migrate` skill을 실제로 제거할 시점 (신규, 2026-08-29).** "충분한 사용자가 전환했을 때"는 이 플러그인에 사용량 텔레메트리가 없어 데이터로 판단할 수 없다. 날짜나 버전을 미리 못박지 않기로 했다 — 정해두면 그때까지 마이그레이션을 못 한 사용자의 옛 handoff가 조용히 고아가 된다. 대신 `migrate`는 옛 위치에 아무것도 없으면 조용히 no-op하도록 만들어(§10.2 7번) 무기한 설치돼 있어도 해롭지 않게 했다. 실제 파일 삭제 시점은 유지자가 본인이 쓰는 프로젝트들에서 옛 경로가 비어있음을 직접 확인한 뒤로 남겨둔다 — 사용량 기반이 아니라 유지자가 확인 가능한 신호 기반이라는 것만 정해졌고, 정확한 트리거는 미정이다.

### 해결됨

- ~~절대 경로, git remote, repository ID 중 무엇으로 프로젝트를 식별할지~~ — **절대 경로 유지 (2026-08-29).** 이름 충돌 없음이 핵심 장점이고, Codex가 프로젝트 디렉토리 관례 자체가 없어(§10.1 실측) 다른 host 관례에 맞출 이유도 없었다. 저장소 이동으로 slug가 갈라지는 경우는 자동 통합하지 않고 사용자가 수동 처리한다(§10.3).
- ~~기존 Claude 경로에서 새 경로로의 기본 전환 시점~~ — **즉시 전환 (2026-08-29).** dual-read 기간을 두지 않기로 뒤집었다. `dir`/`scan`이 매 프롬프트·매 커맨드마다 도는 hot path라 두 경로를 영구히 함께 스캔하는 비용이 크다고 판단했고, 대신 한 번의 명시적 `migrate` 동작으로 옮긴다(§10.2, 구현 완료).
- ~~`agents/openai.yaml`과 `.codex-plugin/plugin.json`의 역할 경계~~ — 경쟁 관계가 아니었다. `.codex-plugin/plugin.json`은 플러그인 매니페스트(skill 목록의 원본은 여전히 `skills/` 디렉토리 스캔)이고, `agents/openai.yaml`은 **skill 하나에 스코프된** 부속 파일이다. 로컬 Codex CLI(`codex-cli 0.150.0`)의 `skill-creator` 참조 문서로 확인.
- ~~`policy.allow_implicit_invocation`의 선언 위치~~ — `skills/<name>/agents/openai.yaml` (플러그인 루트가 아니라 해당 skill 디렉토리 안). 근거는 위와 동일. §7 아키텍처 트리에 반영함.
- ~~Codex의 `policy.allow_implicit_invocation: false`가 `disable-model-invocation`과 실제로 같은 범위를 막는지~~ — **같은 범위를 막지 않는다. 더 넓게 막는다.** `disable-model-invocation`(Claude)은 자연어 자동 호출만 막고 명시 호출(`/handoff:list`)은 그대로 둔다. `allow_implicit_invocation: false`(Codex, `codex exec` 기준)는 자연어와 `$list` 명시 호출을 **둘 다** 막는다. §12 단계 2 "설치 레벨 발견 2"에서 `save`(정책 없음, `$` 성공) vs `list`(정책 있음, `$` 실패)를 대조해 실측했다. §7.1·§13 항목 3에 반영.
- ~~Codex에서 우리 플러그인의 skill이 project 밖에서 discoverable한지~~ — discoverability 자체는 정상이다(대조군 `visualize`가 자연어만으로 정상 로드됨). 안 잡힌 건 `list`/`delete`의 `allow_implicit_invocation: false` 때문이었다 — 바로 위 항목과 같은 원인.

## 15. 참고 자료

- [Submit your Claude Code plugin to OpenAI](https://developers.openai.com/plugins/guides/submit-claude-plugin)
- [Package your plugin](https://developers.openai.com/plugins/build/plugins)
- [Build skills](https://developers.openai.com/plugins/build/skills)
- [Codex Hooks](https://learn.chatgpt.com/docs/hooks)
- [Codex Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Codex Build skills](https://learn.chatgpt.com/docs/build-skills)
- [Codex Configuration Reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- [openai/skills — migrate-to-codex: Claude/Codex frontmatter 차이](https://github.com/openai/skills/blob/main/skills/.curated/migrate-to-codex/references/differences.md)
- 로컬 Codex CLI(`codex-cli 0.150.0`) 번들 skill-creator — `~/.codex/skills/.system/skill-creator/SKILL.md`, `references/openai_yaml.md`. `agents/openai.yaml`의 위치와 스키마 근거 (위 differences.md보다 최신)
- [Extend Claude with skills](https://code.claude.com/docs/en/skills) — frontmatter reference
- [Agent Skills 표준](https://agentskills.io)
- [SKILL.md Frontmatter 호환성 대조표](./skill-frontmatter-compat.md) — 이 저장소의 부속 문서
- [Slash commands](https://code.claude.com/docs/en/slash-commands)
- [Create Claude Code plugins](https://code.claude.com/docs/en/plugins)
