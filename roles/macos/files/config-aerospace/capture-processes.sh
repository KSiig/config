BASELINE=~/.config/aerospace/baseline-processes.txt

ps -e -o comm= | sed 's|.*/||' | sort -u | grep -v '^com\.apple\.' > $BASELINE
