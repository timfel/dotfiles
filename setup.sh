which dnf

if [ $? -eq 0 ]; then
    DEB=0
else
    DEB=1
fi

set -ex

if [ $DEB -eq 1 ]; then
    sudo apt install git build-essential zip unzip python3 curl htop tmux wl-clipboard
else
    sudo dnf install /usr/bin/zip /usr/bin/unzip /usr/bin/python3 /usr/bin/git curl /usr/bin/htop /usr/bin/tmux /usr/bin/wl-copy
fi

git clone https://github.com/timfel/dotfiles ~/dotfiles
git clone https://github.com/timfel/my_emacs_for_rails ~/.emacs.d

pushd ~/dotfiles
python3 install.py
popd

git clone --depth 1 https://github.com/pyenv/pyenv.git ~/.pyenv
export PYENV_ROOT="$HOME"/.pyenv
export PATH="$PYENV_ROOT"/bin:"$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
pyenv install graalpy

git clone --depth 1 https://github.com/sstephenson/rbenv.git ~/.rbenv
git clone --depth 1 https://github.com/sstephenson/ruby-build.git ~/.ruby-build

git clone https://github.com/nvm-sh/nvm ~/.nvm
pushd ~/.nvm
git checkout `git describe --abbrev=0 --tags`
popd
export NVM_DIR="/home/tim/.nvm"
source "$NVM_DIR/nvm.sh"
nvm install node
nvm install-latest-npm

curl -s "https://get.sdkman.io?rcupdate=false" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java
sdk install maven
sdk install gradle
sdk install ant

curl https://sh.rustup.rs -sSf | sh

git clone https://github.com/emacs-mirror/emacs.git ~/emacs
pushd ~/emacs
if [ $DEB -eq 1 ]; then
    sudo apt install autoconf fonts-dejavu-mono texinfo libxpm-dev libxft-dev libjpeg-dev libwebp-dev libgif-dev libpng-dev libmagickcore-dev libgccjit-13-dev libtree-sitter-dev libjansson-dev libmagickwand-dev libxaw7-dev libgnutls28-dev libncurses-dev libharfbuzz-dev libxaw3dxft8-dev libsqlite3-dev libgpm-dev libdbus-1-dev libotf-dev libm17n-dev
else
    error
fi
./autogen.sh
./configure --enable-link-time-optimization --with-sound=yes --with-x-toolkit=lucid --with-imagemagick --with-tree-sitter --with-native-compilation=yes
make -j
make install
