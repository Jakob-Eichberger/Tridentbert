#!/bin/bash

#######################################################################
## NOTE: This script originates from here but I tweaked the pull     ##
## command, changed default location for backup, and added a comment ##
## for reference later.                                              ##
#######################################################################

#####################################################################
### Please set the paths accordingly. In case you don't have all  ###
### the listed folders, just keep that line commented out.        ###
#####################################################################
### Path to your config folder you want to backup
config_folder=~/printer_data/config

# NOTE: The above should work for just about everyone, but a somewhat
# recent update to moonraker changed paths, etc. You can run the 
# provided moonraker script 'data-path-fix.sh' to fix/update
# older installs

### Path to your Klipper folder, by default that is '~/klipper'
klipper_folder=~/klipper

### Path to your Moonraker folder, by default that is '~/moonraker'
moonraker_folder=~/moonraker

### Path to your Mainsail folder, by default that is '~/mainsail'
mainsail_folder=~/mainsail

### Path to your Fluidd folder, by default that is '~/fluidd'
#fluidd_folder=~/fluidd

### The branch of the repository that you want to save your config
### By default that is 'main'
branch=ConfigBackup

db_file=~/printer_data/database/moonraker-sql.db

#####################################################################
#####################################################################



#####################################################################
################ !!! DO NOT EDIT BELOW THIS LINE !!! ################
#####################################################################

scan_git_repos() {
  git_info=""

  # Ignore only irrelevant large dirs
  ignore_dirs=(
   "$HOME/.cache"
    "$HOME/.local"
  )

  ignore_args=()
  for d in "${ignore_dirs[@]}"; do
    ignore_args+=(-path "$d" -prune -o)
  done

  # Find all .git directories
  mapfile -t repos < <(
    find "$HOME" \
      "${ignore_args[@]}" \
      -type d -name ".git" -print
  )

  for gitdir in "${repos[@]}"; do
    repo_path=$(dirname "$gitdir")

    # Extract remote URL (origin)
    remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null)

    # Extract branch name (works even if HEAD is detached)
    branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)

    # Extract commit hash
    commit_hash=$(git -C "$repo_path" rev-parse --short HEAD 2>/dev/null)

    # Only add if repo is valid
    if [ ! -z "$commit_hash" ] && [ ! -z "$remote_url" ]; then
      git_info+="'$remote_url' - '$branch' - $commit_hash"$'\n'
    fi
  done
}


grab_version(){
  if [ ! -z "$klipper_folder" ]; then
    klipper_commit=$(git -C $klipper_folder describe --always --tags --long | awk '{gsub(/^ +| +$/,"")} {print $0}')
    m1="Klipper version: $klipper_commit"
  fi
  if [ ! -z "$moonraker_folder" ]; then
    moonraker_commit=$(git -C $moonraker_folder describe --always --tags --long | awk '{gsub(/^ +| +$/,"")} {print $0}')
    m2="Moonraker version: $moonraker_commit"
  fi
  if [ ! -z "$mainsail_folder" ]; then
    mainsail_ver=$(head -n 1 $mainsail_folder/.version)
    m3="Mainsail version: $mainsail_ver"
  fi
  if [ ! -z "$fluidd_folder" ]; then
    fluidd_ver=$(head -n 1 $fluidd_folder/.version)
    m4="Fluidd version: $fluidd_ver"
  fi
}

# Here we copy the sqlite database for backup
# To RESTORE the database, stop moonraker, then use the following command:
# cp ~/printer_data/config/moonraker-sql.db ~/printer_data/database/
# Finally, restart moonraker

if [ -f $db_file ]; then
   echo "sqlite based history database found! Copying..."
   cp ~/printer_data/database/moonraker-sql.db ~/printer_data/config/
else
   echo "sqlite based history database not found"
fi

# To fully automate this and not have to deal with auth issues, generate a legacy token on Github
# then update the command below to use the token. Run the command in your base directory and it will
# handle auth. This should just be executed in your shell and not committed to any files or
# Github will revoke the token. =)
# git remote set-url origin https://XXXXXXXXXXX@github.com/EricZimmerman/Voron24Configs.git/
# Note that that format is for changing things after the repository is in use, vs initially

push_config(){
  cd $config_folder
  git pull origin $branch --no-rebase
  git add .

  current_date=$(date +"%Y-%m-%d %T")

  # Add repo scan info
  scan_git_repos

  git commit -m "Autocommit from $current_date" \
             -m "$m1" -m "$m2" -m "$m3" -m "$m4" \
             -m "Git repositories under ~:" \
             -m "$git_info"

  git push origin $branch
}


cleanup_database(){
  cd $config_folder
  rm moonraker-sql.db
}

grab_version
push_config
cleanup_database
