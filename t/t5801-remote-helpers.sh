#!/bin/sh
#
# Copyright (c) 2010 Sverre Rabbelier
#

test_description='Test remote-helper import and export commands'

. ./test-lib.sh

if ! type "${BASH-bash}" >/dev/null 2>&1; then
	skip_all='skipping remote-testgit tests, bash not available'
	test_done
fi

compare_refs() {
	git --git-dir="$1/.git" rev-parse --verify $2 >expect &&
	git --git-dir="$3/.git" rev-parse --verify $4 >actual &&
	test_cmp expect actual
}

test_expect_success 'setup repository' '
	git init server &&
	(cd server &&
	 echo content >file &&
	 git add file &&
	 git commit -m one)
'

test_expect_success 'cloning from local repo' '
	git clone "testgit::${PWD}/server" local &&
	test_cmp server/file local/file
'

test_expect_success 'create new commit on remote' '
	(cd server &&
	 echo content >>file &&
	 git commit -a -m two)
'

test_expect_success 'pulling from local repo' '
	(cd local && git pull) &&
	test_cmp server/file local/file
'

test_expect_success 'pushing to local repo' '
	(cd local &&
	echo content >>file &&
	git commit -a -m three &&
	git push) &&
	compare_refs local HEAD server HEAD
'

test_expect_success 'fetch new branch' '
	(cd server &&
	 git reset --hard &&
	 git checkout -b new &&
	 echo content >>file &&
	 git commit -a -m five
	) &&
	(cd local &&
	 git fetch origin new
	) &&
	compare_refs server HEAD local FETCH_HEAD
'

test_expect_success 'fetch multiple branches' '
	(cd local &&
	 git fetch
	) &&
	compare_refs server master local refs/remotes/origin/master &&
	compare_refs server new local refs/remotes/origin/new
'

test_expect_success 'push when remote has extra refs' '
	(cd local &&
	 git reset --hard origin/master &&
	 echo content >>file &&
	 git commit -a -m six &&
	 git push
	) &&
	compare_refs local master server master
'

test_expect_success 'push new branch by name' '
	(cd local &&
	 git checkout -b new-name  &&
	 echo content >>file &&
	 git commit -a -m seven &&
	 git push origin new-name
	) &&
	compare_refs local HEAD server refs/heads/new-name
'

test_expect_failure 'push new branch with old:new refspec' '
	(cd local &&
	 git push origin new-name:new-refspec
	) &&
	compare_refs local HEAD server refs/heads/new-refspec
'

test_expect_success 'cloning without refspec' '
	GIT_REMOTE_TESTGIT_REFSPEC="" \
	git clone "testgit::${PWD}/server" local2 &&
	compare_refs local2 HEAD server HEAD
'

test_expect_success 'pulling without refspecs' '
	(cd local2 &&
	git reset --hard &&
	GIT_REMOTE_TESTGIT_REFSPEC="" git pull) &&
	compare_refs local2 HEAD server HEAD
'

test_expect_failure 'pushing without refspecs' '
	test_when_finished "(cd local2 && git reset --hard origin)" &&
	(cd local2 &&
	echo content >>file &&
	git commit -a -m ten &&
	GIT_REMOTE_TESTGIT_REFSPEC="" git push) &&
	compare_refs local2 HEAD server HEAD
'

test_expect_success 'pulling with straight refspec' '
	(cd local2 &&
	GIT_REMOTE_TESTGIT_REFSPEC="*:*" git pull) &&
	compare_refs local2 HEAD server HEAD
'

test_expect_failure 'pushing with straight refspec' '
	test_when_finished "(cd local2 && git reset --hard origin)" &&
	(cd local2 &&
	echo content >>file &&
	git commit -a -m eleven &&
	GIT_REMOTE_TESTGIT_REFSPEC="*:*" git push) &&
	compare_refs local2 HEAD server HEAD
'

test_expect_success 'pulling without marks' '
	(cd local2 &&
	GIT_REMOTE_TESTGIT_NO_MARKS=1 git pull) &&
	compare_refs local2 HEAD server HEAD
'

test_expect_failure 'pushing without marks' '
	test_when_finished "(cd local2 && git reset --hard origin)" &&
	(cd local2 &&
	echo content >>file &&
	git commit -a -m twelve &&
	GIT_REMOTE_TESTGIT_NO_MARKS=1 git push) &&
	compare_refs local2 HEAD server HEAD
'

test_expect_success 'push all with existing object' '
	(cd local &&
	git branch dup2 master &&
	git push origin --all
	) &&
	compare_refs local dup2 server dup2
'

test_expect_success 'push ref with existing object' '
	(cd local &&
	git branch dup master &&
	git push origin dup
	) &&
	compare_refs local dup server dup
'

test_done
