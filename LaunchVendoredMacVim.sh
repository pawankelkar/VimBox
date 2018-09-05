#! /bin/bash

VIM_BOX_VERSION="0.1"
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
# Creates a *sub* VimBox.app! The one you clicked on was just a facade.
function fail {
  osascript -e "tell app \"System Events\" to display dialog \"Problem initializing VimBox. $1\""
  exit 1
}
if [ -d "${DIR}/.git" ]; then
  true
else
  osascript -e 'display notification "Cloning support from jordwalke/VimBox" with title "Initializing VimBox"'
  pushd "${DIR}" || exit 1
  FAILMSG=""
  git init || FAILMSG="Could not initialize git repo. Do you not have git installed?"
  git remote add origin git@github.com:jordwalke/VimBox.git || FAILMSG="Could not find jordwalke/VimBox"
  git fetch --all || FAILMSG="Could not fetch jordwalke/VimBox"
  git checkout -b userVersion origin/json || FAILMSG="Could not checkout jordwalke/VimBox(branch json)"
  if [ "${FAILMSG}" == "" ]; then
    true
  else
    fail "$FAILMSG"
  fi
fi

if [ -e "${DIR}/VimBox.app" ]; then
  true
else
  if [ -e "/Applications/MacVim.app" ]; then
    osascript -e 'display notification "Installing VimBox from system MacVim" with title "Initializing VimBox"'
    cp -rp "/Applications/MacVim.app" "${DIR}/VimBox.app" || FAILMSG="Could not copy system MacVim.app into vendored MacVim"
    # cp -p so it preserves permissions.
    cp -p "${DIR}/VimBox.app/Contents/MacOS/Vim" "${DIR}/VimBox.app/Contents/MacOS/VimOrig" || FAILMSG="Failed copying Vim to VimOrig"
    cp -p "${DIR}/VimBox.app/Contents/MacOS/MacVim" "${DIR}/VimBox.app/Contents/MacOS/VimBox" || FAILMSG="Failed copying MacVim to VimBox"
    # Will call out to the orig vim, but wrap to set the initial vimrc/gvimrc
    cat "${DIR}/VimBoxInitWrapper.sh" > "${DIR}/VimBox.app/Contents/MacOS/Vim" || FAILMSG="Failed creating Vim wrapper script. Does ${DIR}/VimBoxInitWrapper.sh exist?"
    # File permissions of icons must be exactly right:
    # https://superuser.com/questions/618501/changing-an-applications-icon-from-the-terminal-osx
    # Since git doesn't handle ownership correctly reuse the existing file node, and cat to it.
    cp -p "${DIR}/VimBox.app/Contents/Resources/MacVim.icns" "${DIR}/VimBox.app/Contents/Resources/VimBox.icns" || FAILMSG="Could not copy system MacVim.app into vendored MacVim"
    rm "${DIR}/VimBox.app/Contents/Resources/MacVim.icns"
    cat "${DIR}/dotVim/images/ApplicationIcon.icns" > "${DIR}/VimBox.app/Contents/Resources/VimBox.icns" || FAILMSG="Failed setting the icon to the rad VimBox icon."
    sed -i.bak 's;<string>MacVim</string>;<string>VimBox</string>;g' "${DIR}/VimBox.app/Contents/Info.plist" || FAILMSG="Failed running sed on plist."
    sed -i.bak 's;<string>org.vim.MacVim</string>;<string>org.vim.VimBox</string>;g' "${DIR}/VimBox.app/Contents/Info.plist" || FAILMSG="Failed running sed on plist 2."
    if [ "${FAILMSG}" == "" ]; then
      true
    else
      fail "$FAILMSG"
    fi
  else
    osascript -e 'tell app "System Events" to display dialog "You do not have MacVim.app installed in /Applications. VimBox initializes from an existing MacVim installation. First install MacVim from http://macvim-dev.github.io/macvim/"'
    exit 1
  fi
fi
open "${DIR}/VimBox.app" --args "$@"
# open "${DIR}/VimBox.app" "$@"


# VimBox.sh and box attempted to be a way to not use the user .vimrc/.gvimrc
# instead using the one built in VimBox.
# That didn't work because.
#
# How you would normally do it is make the box script wrapper that has:
#
#
# And make the .vimrc have:
# let g:vimBoxInitialVimRcPath = resolve(expand('<sfile>:p'))
# let g:vimBoxInstallationRoot = fnamemodify(g:vimBoxInitialVimRcPath, ':h')
#
# exec "source " . g:vimBoxInstallationRoot . "/VimBox.app/Contents/Resources/vim/vimrc"
#
