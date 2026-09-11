# Groups a `git log --reverse --date=short --pretty=format:'%H%x09%ad%x09%s'`
# stream into a Keep a Changelog-style CHANGELOG.md body. Invoked by changelog.sh.
#
# A commit is a version *boundary* — closing out the version it names — when its
# subject is either the current convention "chore: bump version to X.Y.Z" or the
# old pre-1.2.0 style "vX.Y.Z - ...". Everything between two boundaries belongs to
# the version the later boundary names. Non-boundary commits are grouped by their
# conventional-commit type (feat/fix/docs/refactor/perf/test/chore/build/ci); a
# subject without a recognized prefix lands under "Other". Commits after the last
# boundary (if any) print as "## [Unreleased]".
BEGIN {
  FS = "\t"
  ncat = split("Added Fixed Changed Documentation Tests Build Chores Other", catlist, " ")
  secn = 0
}

{
  hash = $1; date = $2; subject = $3
  is_boundary = 0; ver = ""; rest = ""

  if (match(subject, /^chore(\([^)]*\))?:[ \t]*[Bb]ump version to[ \t]*v?[0-9][0-9A-Za-z.+_-]*/)) {
    is_boundary = 1
    m = substr(subject, RSTART, RLENGTH)
    rest = substr(subject, RSTART + RLENGTH)
    ver = m
    sub(/^.*[Bb]ump version to[ \t]*v?/, "", ver)
  } else if (match(subject, /^v[0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.+_-]*/)) {
    is_boundary = 1
    m = substr(subject, RSTART, RLENGTH)
    ver = substr(m, 2)
    rest = substr(subject, RSTART + RLENGTH)
  }

  if (is_boundary) {
    sub(/^[ \t]*[:,-]+[ \t]*/, "", rest)
    secn++
    ver_arr[secn] = ver
    date_arr[secn] = date
    flush_buf_to(secn)
    if (rest != "") {
      classify(rest)
      seccount[secn, CL_CAT]++
      sectext[secn, CL_CAT, seccount[secn, CL_CAT]] = mkbullet(CL_SCOPE, CL_DESC, hash)
    }
  } else {
    classify(subject)
    bufcount[CL_CAT]++
    buf[CL_CAT, bufcount[CL_CAT]] = mkbullet(CL_SCOPE, CL_DESC, hash)
  }
}

END {
  flush_buf_to(0)
  print "# Changelog"
  print ""
  print "이 저장소의 주요 변경 사항을 버전별로 기록합니다. [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 형식을 따르며, `scripts/changelog.sh`가 커밋 로그에서 자동 생성합니다 — 이 파일을 직접 고치지 말고 스크립트를 다시 실행하세요."
  print ""
  if (has_any(0)) {
    print "## [Unreleased]"
    print ""
    print_section(0)
  }
  for (s = secn; s >= 1; s--) {
    print "## [" ver_arr[s] "] - " date_arr[s]
    print ""
    print_section(s)
  }
}

function flush_buf_to(sec,    c, n, cnt) {
  for (c = 1; c <= ncat; c++) {
    cnt = bufcount[catlist[c]] + 0
    seccount[sec, catlist[c]] = cnt
    for (n = 1; n <= cnt; n++) sectext[sec, catlist[c], n] = buf[catlist[c], n]
    bufcount[catlist[c]] = 0
  }
}

function has_any(sec,    c) {
  for (c = 1; c <= ncat; c++) if (seccount[sec, catlist[c]] + 0 > 0) return 1
  return 0
}

function print_section(sec,    c, n, cnt) {
  for (c = 1; c <= ncat; c++) {
    cnt = seccount[sec, catlist[c]] + 0
    if (cnt > 0) {
      print "### " catlist[c]
      for (n = 1; n <= cnt; n++) print sectext[sec, catlist[c], n]
      print ""
    }
  }
}

# Splits a conventional-commit subject into CL_CAT/CL_SCOPE/CL_DESC globals.
# Tolerates a stray space before the colon ("docs :"), seen once in this repo's
# early history.
function classify(line,    prefix, t) {
  if (match(line, /^(feat|fix|docs|refactor|perf|test|chore|build|ci)(\([a-zA-Z0-9_,.\/ -]*\))?!?[ \t]*:/)) {
    prefix = substr(line, RSTART, RLENGTH)
    CL_DESC = substr(line, RSTART + RLENGTH)
    sub(/^[ \t]+/, "", CL_DESC)
    t = prefix
    sub(/[ \t]*:[ \t]*$/, "", t)
    sub(/!$/, "", t)
    if (match(t, /\(/)) {
      CL_SCOPE = substr(t, RSTART + 1)
      sub(/\)[ \t]*$/, "", CL_SCOPE)
      t = substr(t, 1, RSTART - 1)
    } else {
      CL_SCOPE = ""
    }
    if (t == "feat") CL_CAT = "Added"
    else if (t == "fix") CL_CAT = "Fixed"
    else if (t == "refactor" || t == "perf") CL_CAT = "Changed"
    else if (t == "docs") CL_CAT = "Documentation"
    else if (t == "test") CL_CAT = "Tests"
    else if (t == "build" || t == "ci") CL_CAT = "Build"
    else if (t == "chore") CL_CAT = "Chores"
    else CL_CAT = "Other"
  } else {
    CL_CAT = "Other"; CL_SCOPE = ""; CL_DESC = line
  }
}

function mkbullet(scope, desc, hash,    short) {
  short = substr(hash, 1, 7)
  if (scope != "") return "- **" scope ":** " desc " (`" short "`)"
  return "- " desc " (`" short "`)"
}
