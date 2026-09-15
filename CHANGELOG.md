# Changelog

이 저장소의 주요 변경 사항을 버전별로 기록합니다. [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 형식을 따르며, `scripts/changelog.sh`가 커밋 로그에서 자동 생성합니다 — 이 파일을 직접 고치지 말고 스크립트를 다시 실행하세요.

## [2.2.1] - 2026-09-15

### Added
- add a changelog script and generate CHANGELOG.md (`9b64880`)

### Fixed
- **hooks:** default new Claude models to 1M context (`73e08a0`)

## [2.2.0] - 2026-09-04

### Added
- **finish:** refresh and auto-compact the record before sealing (`fb446a3`)

### Fixed
- **list,delete:** drop model:haiku override, keep effort:low (`0ec175b`)

## [2.1.0] - 2026-09-03

### Added
- **finish:** add a lifecycle boundary so handoffs can end (`1982643`)

## [2.0.2] - 2026-08-31

### Fixed
- **hooks:** auto-detect command prefix instead of assuming Claude-only (`ec89e5d`)

## [2.0.1] - 2026-08-30

### Fixed
- **skills:** print commands with the host's own invocation prefix (`b06dc8e`)

## [2.0.0] - 2026-08-29

### Added
- **migrate:** add one-time skill to move handoffs off the old storage path (`5184f40`)

### Changed
- **storage:** move handoff storage to host-neutral ~/.handoffs/ (`7190e24`)

## [1.4.0] - 2026-08-28

### Added
- **hook:** detect the context window instead of assuming 1M (`2568875`)
- **codex:** add the Codex plugin manifest (`a8702ce`)

### Changed
- **skills:** make skills/ the only source for the four entry points (`ba6e117`)

### Documentation
- add design, internals, and frontmatter compatibility notes (`388b672`)

### Tests
- cover context-check window detection across transcript formats (`e6ebb8c`)

## [1.3.2] - 2026-08-01

### Fixed
- /handoff:delete 자동 호출 차단 (`a3eb7dd`)
- HANDOFF_CONTEXT_LIMIT 기본값을 1M 컨텍스트 기준으로 변경 (`f257d56`)

## [1.3.1] - 2026-08-01

### Added
- 컨텍스트 사용량 기반 handoff 저장 제안 훅 추가 (v1.3.0) (`e344ce9`)

### Fixed
- 밴드 테스트값 원복, context-check tail 최적화 및 안내 문구 정리 (`0de71f4`)
- /handoff:list 자동 호출 차단 및 출력 지시 보강 (`dce16fb`)

### Documentation
- reposition handoff around parallel task switching (`641d678`)
- save 완료 후 가이드 메시지 제안 (`0aafa86`)
- HANDOFF_CONTEXT_LIMIT 설명 명확화 (`b21848d`)

### Chores
- captures/ 를 gitignore 처리 (`5d50d06`)

## [1.2.0] - 2026-06-13

### Documentation
- add English translations of README and QUICKSTART (`41e110a`)

## [1.1.0] - 2026-06-13

### Added
- auto-surface handoffs on SessionStart and nudge save on Stop (`3e67d65`)
- remove SessionStart/Stop hooks, revert to manual commands (`8db740e`)

### Documentation
- add "원본 대비 개선점" section to README (`69088d0`)

### Other
- Initial commit: handoff plugin for personal marketplace (`e2ed4bb`)
- list, delete 호출시 haiku(effort: low) 사용 (`3536417`)
