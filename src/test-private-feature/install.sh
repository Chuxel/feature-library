#!/bin/bash
echo 'echo "Yep, I executed!"' >> /etc/bash.bashrc
if [ -e /etc/zsh ]; then
    echo 'echo "Yep, I executed!"' >> /etc/zsh/zshenv
fi