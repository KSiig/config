# set -e

# Get username
printf 'Enter username: '
read user
printf 'Enter GitHub username: '
read githubUser

# Check if user exists
userExists=$(getent passwd | grep -c "^$user:")

# If user does not exists, create it and add to sudoers
if [ $userExists -eq 0 ]; then
  adduser $user
  usermod -aG sudo ksi
fi

# Add SSH key

mkdir -p /home/$user/.ssh
wget https://github.com/$githubUser.keys -O /home/$user/.ssh/authorized_keys
