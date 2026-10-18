#!/bin/sh
# Iceberg owns the commits in this repository.
#
# A shell `git commit` advances git HEAD while the Pharo image keeps its old reference commit, and
# IceAttachedSingleVersionWorkingCopy >> isDetached is exactly `referenceCommit ~= repository head
# commit`, so the working copy drops into Detached mode and has to be resynced by hand.
#
# Stage with `git add` instead, then commit from the image:
#
#   repo := IceRepository registry detect: [ :e | e name = 'PharoVulkan' ].
#   repo workingCopy commitWithMessage: 'Message'.
#
#   "documentation only, where Iceberg's own diff is empty"
#   repo workingCopy commitChanges: repo workingCopyDiff withMessage: 'Message' force: true.
#
# Iceberg commits through libgit2, which runs no hooks, so this hook never blocks it.
#
# If a shell commit is genuinely wanted, set the variable and re-attach afterwards with
# `repo workingCopy adoptCommit: repo headCommit`.

if [ "${ICEBERG_ALLOW_GIT_COMMIT}" = "1" ]; then
	exit 0
fi

cat >&2 <<'MSG'
pre-commit: blocked. Iceberg owns the commits in this repository.

A shell commit detaches the Pharo working copy, because git HEAD moves and the image's
reference commit does not.

Stage the files, then commit from the image:

  repo := IceRepository registry detect: [ :e | e name = 'PharoVulkan' ].
  repo workingCopy commitWithMessage: 'Message'.

Documentation-only change, where Iceberg's own diff is empty:

  repo workingCopy commitChanges: repo workingCopyDiff withMessage: 'Message' force: true.

To override once:

  ICEBERG_ALLOW_GIT_COMMIT=1 git commit ...

then re-attach with:

  repo workingCopy adoptCommit: repo headCommit.
MSG
exit 1
