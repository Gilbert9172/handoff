# handoff — 빠른 시작 (5분)

여러 작업을 오가도 **어디까지 했는지 놓치지 않게** 해주는 플러그인입니다. 전체 설명은 [README.md](./README.md) 참고.

---

## 1️⃣ 설치 (1분)

### 기본: main 브랜치에서 설치

```shell
/plugin marketplace add https://github.com/Gilbert9172/handoff.git
/plugin install handoff@gilbert9172
/reload-plugins
```

### 확인

```shell
/handoff:list      # "아직 handoff가 없습니다" → 정상
```

---

## 2️⃣ 첫 사용 (3분)

```shell
# 작업을 좀 하다가, 마무리하며 저장
/handoff:save my-first-task

# 저장된 목록 확인
/handoff:list

# 나중에 새 대화에서 그대로 이어받기
/handoff:resume my-first-task
```

---

## 3️⃣ 일일 패턴

🌅 **시작할 때** — `/handoff:list`로 어떤 작업이 어디까지 왔는지 한눈에 봅니다.

| Slug | Updated | Goal |
|------|---------|------|
| auction-state-machine | 2026-06-11 | 낙찰→납부 상태 전이 설계 |
| batch-php-migration | 2026-06-13 | 레거시 PHP 배치를 신규 런타임으로 이관 |

```shell
/handoff:resume batch-php-migration   # 오늘은 이거 이어서

# 🌙 끝낼 때
/handoff:save              # 제목 없이 저장하면 알아서 같은 노트 갱신/새 노트 생성

# ✨ 완료되면
/handoff:delete batch-php-migration   # 정리
```

---

## 4️⃣ 커맨드 한눈에

| 커맨드 | 용도 | 예시 |
|--------|------|------|
| `/handoff:save [제목]` | 현재 작업 저장/갱신 | `/handoff:save api-docs` |
| `/handoff:list` | 목록 보기 | `/handoff:list` |
| `/handoff:resume [슬러그]` | 작업 재개 | `/handoff:resume api-docs` |
| `/handoff:delete [슬러그]` | 노트 삭제 | `/handoff:delete api-docs` |

---

## 5️⃣ 노트 구조 (저장 시 채워지는 섹션)

```markdown
# Goal            ← 목표 (한두 문장)
# Current Progress ← 지금까지 한 일
# What Worked      ← 잘된 접근
# What Didn't Work ← 실패한 접근 + 이유 (반복 방지)
# Next Steps       ← 다음에 할 구체적 작업
```

> 업데이트하면 **Progress·Next Steps는 최신으로 새로 쓰고**, **What Worked/Didn't Work는 누적**됩니다.

---

## 6️⃣ 저장 위치

```
~/.claude/projects/<프로젝트-슬러그>/handoffs/HANDOFF-<슬러그>.md
```

`<프로젝트-슬러그>`는 git 루트 경로의 `/`를 `-`로 바꾼 값. 프로젝트마다 자동으로 분리됩니다. 파일을 직접 열어 수정해도 됩니다.

---

## 7️⃣ FAQ

**Q. 제목을 안 주면?**
A. 기존 노트 중 같은 작업이면 갱신, 새 작업이면 Goal에서 슬러그를 뽑아 새로 만듭니다. 애매하면 물어봅니다.

**Q. 같은 제목으로 다시 저장하면?**
A. 그 파일이 업데이트됩니다(Progress·Next Steps는 갱신, What Worked/Didn't Work는 누적).

**Q. 프로젝트를 바꾸면?**
A. git 루트가 다르면 슬러그도 달라져, 프로젝트별로 노트가 따로 관리됩니다.

**Q. 삭제하면 복구되나요?**
A. 안 됩니다. 삭제 전 확인을 받지만 신중히 고르세요.

**Q. 커맨드가 안 보여요.**
A. `/reload-plugins` → 그래도 없으면 `/plugin list`로 설치 여부, `/plugin marketplace list`로 마켓플레이스 등록 여부 확인.

---

## 💡 팁

- **Next Steps는 구체적으로.** "테스트 더 하기"보다 "`tests/auth.test.ts`의 POST 케이스 작성"처럼 — 미래의 나(또는 동료)가 바로 시작할 수 있게.
- **실패는 이유까지.** What Didn't Work가 다음 세션의 삽질을 막아줍니다.
- **병렬 작업은 노트를 나눠서.** `/handoff:save auction-state-machine`, `/handoff:save batch-php-migration`처럼 작업별로.

---

🚀 **습관 하나만: 세션 끝에 `/handoff:save`.**
