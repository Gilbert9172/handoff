# SKILL.md Frontmatter 호환성 대조표

> 상태: Reference
> 작성일: 2026-08-27
> 관련: [provider-neutral-handoff-design.md](./provider-neutral-handoff-design.md) §7.1

`handoff`가 단일 `SKILL.md`를 Claude Code와 Codex가 공유하는 구조([설계 문서 §7.1](./provider-neutral-handoff-design.md))를 택했으므로, 어떤 frontmatter 필드를 공통 본문에 둘 수 있고 어떤 것을 host별 파일로 내려야 하는지 판단할 기준이 필요하다. 이 문서가 그 기준이다. 필드를 새로 쓰려 할 때마다 재조사하지 않도록 근거와 출처를 함께 남긴다.

## 판단의 기준선

Claude Code는 [Agent Skills](https://agentskills.io) 표준을 구현한 뒤 그 위에 자체 확장을 얹었다. **Codex가 Skills를 지원하지 않는 게 아니라, 표준 부분은 지원하고 Claude의 확장이 대부분 없는 구조다.** 따라서 호환성 질문은 항상 "이 필드가 표준인가, Claude 확장인가"로 환원된다.

Agent Skills 표준이 정의하는 portable core는 여섯 개다.

```text
name  description  license  compatibility  metadata  allowed-tools
```

Claude Code 공식 문서도 이 여섯 개를 "Claude Code 밖에서 쓸 수 있는 필드"로 명시한다. claude.ai 업로드나 Skills API로 패키징할 때 나머지 필드를 넣으면 무시가 아니라 **hard error**가 난다.

```text
Unexpected key(s) in SKILL.md frontmatter: argument-hint.
Allowed properties are: allowed-tools, compatibility, description, license, metadata, name
```

Codex는 이와 달리 모르는 키를 대체로 조용히 무시한다. 그래서 단일 `SKILL.md` 공유가 성립한다 — 다만 **무시된다는 것과 효과가 난다는 것은 다르다.** 아래 분류의 핵심이 그 구분이다.

## 1. 공통 — 두 host 모두 계약으로 지원

Agent Skills 표준 필드이므로 공통 `SKILL.md` 본문에 그대로 둘 수 있다.

| 필드 | Claude | Codex | 비고 |
|---|---|---|---|
| `name` | 표시 이름. 플러그인 skill에서는 커맨드 마지막 세그먼트를 결정 | 지원 | 플러그인에서는 `name`이 디렉토리 이름을 대체한다 |
| `description` | 자동 호출 판단의 근거. 권장 필드 | 지원 | 생략하면 본문 첫 문단이 쓰인다 |
| `license` | 수용하되 동작하지 않음 | 표준 필드 | 두 host 모두 메타데이터로만 취급 |
| `compatibility` | 수용하되 동작하지 않음. 최대 500자 | 표준 필드 | 환경 요구사항 서술 |
| `metadata` | 자유 형식 map. Claude Code는 내용에 관여하지 않음 | 표준 필드 | 자체 도구가 읽는 용도 |

`handoff` 적용: 네 skill 모두 `name`과 `description`만 쓰면 된다. 나머지 셋은 현재 필요 없다.

## 2. 유사 대응 — 필드는 있으나 semantics가 다름

**가장 위험한 분류다.** 문법이 통과하고 에러도 안 나지만 보장 수준이 달라서, 한 host에서 확인한 결과를 다른 host의 근거로 쓰면 안 된다.

| Claude 필드 | Codex 대응 | 차이 |
|---|---|---|
| `allowed-tools` | strict allowlist 없음 | Claude에서는 **permission 제어**다 — 해당 turn 동안 도구를 프롬프트 없이 쓰게 허용한다. Codex에는 대응하는 강제 수단이 없고, OpenAI migration 스크립트는 이 값을 본문 prompt guidance로 변환한다. `agents/openai.yaml`이 도구 의존성을 선언할 수 있지만 그것은 permission boundary가 아니다 |
| `user-invocable` | `policy.allow_implicit_invocation` | OpenAI가 공식 매핑표에서 대응시키는 유일한 쌍이지만 **"Manual review required; semantics differ"**로 명시한다. `user-invocable: false`는 "Claude만 호출 가능"이고 `allow_implicit_invocation: false`는 "모델 자동 선택 불가"라 방향이 반대에 가깝다 |
| `disable-model-invocation` | 공식적으로는 **직접 대응 없음** | OpenAI 표는 "Unsupported; requires manual rewrite"로 분류한다. 실무적으로 `allow_implicit_invocation: false`가 의도를 근사하지만, 이는 공식 매핑이 아니라 **우리 쪽 대체 결정**이다 |

**`handoff` 적용 — 두 가지를 반드시 지킨다.**

첫째, `list`와 `resume`의 읽기 전용성을 `allowed-tools`로 보장하려 하지 말 것. Codex에서 강제되지 않는다. skill 본문의 동작 규칙으로 지킨다.

둘째, `list`와 `delete`의 자동 호출 차단은 두 host에서 **각각** 확인할 것. Claude는 `disable-model-invocation: true`, Codex는 `allow_implicit_invocation: false`이고, 위 표대로 이 둘은 등가가 아니다.

## 3. Claude 전용 — Codex 대응 없음

`SKILL.md`에 남겨도 Codex 로드를 깨뜨리지는 않지만 **아무 효과가 없다.** Codex에서 같은 결과가 필요하면 `agents/openai.yaml`이나 Codex 설정으로 따로 구현해야 한다.

| 필드 | 용도 | OpenAI 분류 |
|---|---|---|
| `argument-hint` | 자동완성에 예상 인자 표시 | Unsupported; guidance로 재작성 가능할 때만 유지 |
| `model` | skill 활성 turn 동안 모델 override. 다음 prompt에 세션 모델 복귀 | No skill-level model pin — 모델 선택은 session/agent 범위 |
| `effort` | 세션 effort override. `low`/`medium`/`high`/`xhigh`/`max` | 위와 동일 |
| `context: fork` | forked subagent에서 실행 | Unsupported; skill-local context 매핑 없음 |
| `agent` | `context: fork`일 때 subagent 종류 | Unsupported in skill metadata layer |
| `hooks` | skill 호출 시 hook 등록, 세션 끝까지 유지 | Unsupported; manifest가 아니라 config에서 발견 |
| `paths` | glob으로 자동 활성화 조건 제한 | Unsupported routing mechanism |
| `shell` | 인라인 명령 실행 셸. `bash` 또는 `powershell` | Unsupported shell expansion mode |

### 3.1 OpenAI 자료에 언급이 없는 Claude 필드

아래는 Claude Code 공식 문서에는 있지만 OpenAI 매핑표에 항목이 없다. **표에 없다는 것은 미지원의 근거가 아니라 확인되지 않았다는 뜻이다.** 쓰려면 그때 확인한다.

| 필드 | 용도 |
|---|---|
| `when_to_use` | 트리거 문구 등 추가 호출 근거. `description`에 이어 붙고 1,536자 상한에 포함 |
| `arguments` | `$name` 치환용 명명 위치 인자 |
| `disallowed-tools` | skill 활성 동안 도구를 사용 풀에서 제거 |
| `background` | `context: fork`일 때 결과를 기다릴지 여부 |

## 4. Codex 전용 — Claude 대응 없음

| 항목 | 설명 |
|---|---|
| `policy.allow_implicit_invocation` | 사용자의 명시적 요청 없이 skill이 실행될 수 있는지 제어. `skills/<name>/agents/openai.yaml`에 선언하며 기본값은 `true` |
| skill 번들 자산 디렉토리 | skill root 아래 `scripts/`, `references/`, `assets/`, `agents/`가 있으면 함께 복사된다 |

Claude에서 번들 파일은 `${CLAUDE_SKILL_DIR}`, 플러그인이면 `${CLAUDE_PLUGIN_ROOT}` 치환으로 참조한다. 디렉토리 이름 관례가 계약이 아니므로, `handoff`의 `scripts/`는 두 host에서 참조 방식이 다르다 — 이 차이는 host adapter가 흡수한다.

### 해결됨: `allow_implicit_invocation`의 선언 위치

`skills/<skill-name>/agents/openai.yaml`의 `policy` 블록 — **플러그인 루트가 아니라 skill 디렉토리 안**이다. `scripts/`·`references/`·`assets/`와 같은 층위의 skill 부속 파일이며, `scripts/`처럼 skill마다 있을 수도 없을 수도 있다.

근거는 로컬에 설치된 Codex CLI(`codex-cli 0.150.0`)가 스킬을 만들 때 자신이 참조하는 `skill-creator` 번들 스킬이다 (`~/.codex/skills/.system/skill-creator/SKILL.md`, `references/openai_yaml.md`). OpenAI의 `migrate-to-codex` 자료(`references/differences.md`, "Docs last checked: 2026-04-20")는 이 필드가 존재한다고만 말하고 위치를 밝히지 않았는데, `skill-creator`는 그보다 최신이고 Codex CLI의 실제 스캐폴딩 스크립트(`scripts/generate_openai_yaml.py`)와 직접 일치하므로 이쪽을 채택한다.

## `commands/`와의 관계

Claude Code 공식 문서는 **custom command가 skill로 병합됐다**고 명시한다. `.claude/commands/deploy.md`와 `.claude/skills/deploy/SKILL.md`는 둘 다 `/deploy`를 만들고 동일하게 동작하며, command 파일도 `name`과 `paths`를 뺀 같은 frontmatter를 지원한다. 기존 `commands/`는 계속 동작하지만 skill이 권장 경로다.

이것이 설계 문서 §7.1의 `skills/` 단일화 결정을 뒷받침한다. 다만 **같은 이름이 양쪽에 있을 때의 우선순위는 문서에 명시되어 있지 않다.** 실측으로는 command가 skill을 가린다(설계 문서 §7.1 "이름 충돌 규칙"). 전환 검증을 `commands/` 삭제 후에 해야 하는 이유다.

## 출처

- [Extend Claude with skills](https://code.claude.com/docs/en/skills) — Frontmatter reference 표 20개 필드, Agent Skills 표준 6개 필드, command/skill 병합
- [openai/skills — migrate-to-codex: differences.md](https://github.com/openai/skills/blob/main/skills/.curated/migrate-to-codex/references/differences.md) — Claude→Codex 필드 매핑표, Codex 전용 항목
- [Agent Skills](https://agentskills.io) — 표준 정의
- [Codex Build skills](https://learn.chatgpt.com/docs/build-skills)
- [Codex Configuration Reference](https://learn.chatgpt.com/docs/config-file/config-reference)
