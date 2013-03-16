# I use this in my .bashrc to have nice VCS stuff.
# Tim Felgentreff (09/20/01): Simplify for speedup, use the git-completion script for git

source ~/bin/git-completion.sh

_bold=
_normal=

__prompt_command() {
   if [ -z $NOPROMPT ]; then

	local vcs base_dir sub_dir ref last_command
	sub_dir() {
		local sub_dir
		sub_dir=$(stat --printf="%n" "${PWD}")
		sub_dir=${sub_dir#$1}
		echo ${sub_dir#/}
	}

	git_dir() {
	        # Old version at bottom. New one doesn't spawn a new process
                p="."
                for i in ${PWD//\// }; do
                    if [ -d "${p}/.git" ]; then
			vcs="git"
			alias pull="git pull"
			alias commit="git commit -v -a"
			alias push="commit ; git push"
			alias revert="git checkout"
			ref=$(echo -e $(__git_ps1))
			break
		    fi
		    p="${p}/.."
		done
		unset p
		if [ -z "$ref" ]; then return 1; fi
	}

	hg_dir() {
                p="."
                for i in ${PWD//\// }; do
                    if [ -d "${p}/.hg" ]; then
			vcs="hg"
			alias pull="hg pull -u"
			alias commit="hg commit"
			alias push="commit ; hg push"
			alias revert="hg revert"
			__info="$(hg sum)"
			tip="${info%tip*}"
			__info="${__info##*branch:}"
			branch="${__info%commit*}"
			__info="${__info##*commit:}"
			status="${__info%update*}"
			status="${status/unknown/}"
			status="${status/(clean)/}"
			ref="$branch $status"
			break
		    fi
		    p="${p}/.."
		done
		unset p
		if [ -z "$ref" ]; then return 1; fi
	}

	svn_dir() {
		[ -d ".svn" ] || return 1
		ref=$(svn info "$base_dir" | awk '/^URL/ { sub(".*/","",$0); r=$0 } /^Revision/ { sub("[^0-9]*","",$0); print $0 }')		
		# this is too slow...
		#if [ -n $(svn status -q) ]; then
		#   ref="\e[0;31m$ref\e[m"
		#fi 
		ref="[$ref]"
		vcs="svn"
		alias pull="svn up"
		alias commit="svn commit"
		alias push="svn ci"
		alias revert="svn revert"
	}
	
	
	cvs_dir() {
		[ -d "CVS" ] || return 1
		vcs="cvs"
		alias pull="cvs update"
		alias commit="cvs commit"
		alias push="cvs commit"
	}

	bzr_dir() {
		base_dir=$(bzr root 2>/dev/null) || return 1
		ref=$(bzr revno 2>/dev/null)
		vcs="bzr"
		alias pull="bzr pull"
		alias commit="bzr commit"
		alias push="bzr push"
		alias revert="bzr revert"
	}
	

	git_dir || hg_dir || svn_dir || cvs_dir

	if [ -n "$vcs" ]; then
		alias st="$vcs status"
		alias d="$vcs diff"
		alias up="pull"
		alias cdb="cd $base_dir"
		__vcs_ref="$vcs:$ref"
		echo " $__vcs_ref"
	fi
   fi
}

#export PROMPT_COMMAND=__prompt_command

# Show the currently running command in the terminal title:
# http://www.davidpashley.com/articles/xterm-titles-with-bash.html
#if [ -z "$TM_SUPPORT_PATH"]; then
#case $TERM in
#  rxvt|*term|xterm-color)
#    trap 'echo -e "\e]1;$working_on>$BASH_COMMAND<\007\c"' DEBUG
#  ;;
#esac
#fi
