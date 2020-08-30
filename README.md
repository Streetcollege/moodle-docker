## About

A Docker environment. Used for hosting https://github.com/flocko-motion/street-college-moodle-core but should be suitable for development and deployment of standard Moodle code. Forked from https://github.com/leoauri/street-college-moodle-core

## Install

- `git clone https://github.com/leoauri/moodle-docker` or via SSH
- `cd moodle-docker`
- `git clone https://github.com/leoauri/street-college-moodle-core moodle` or via SSH
- `cp .config-dist .config`
- Setup environment variables:  
`vi .config`
- `cd moodle`
- Load plugins from submodules:  
  - `git submodule init`
  - `git submodule update`
- run `bin/moodle-docker-compose up -d` to start the docker environment.

Visit the front-facing site to trigger Moodle's database init, or use `bin/moodle-docker-compose exec webserver php admin/cli/install_database.php --agree-license --fullname="Docker moodle" --shortname="docker_moodle" --adminpass="admin" --adminemail="admin@e.mail"` to set up for manual testing.

## Restore from a backup

Run `bin/moodle-restore path/to/backup`.
The directory provided should contain a pgsql dump named db_backup.sql and a moodledata directory.  

## Backup

Run `bin/moodle-backup`.  
This creates a timestamped folder in `~/backups` containing pgsql dump and moodledata directory.

## Activate maintenance mode

There are various maintenance modes in Moodle, the "CLI maintenance mode" actually disables access to the webserver. 

Run `docker exec -it moodle_webserver php admin/cli/maintenance.php --enable` from the docker host environment, or `docker exec -it moodle_webserver php admin/cli/maintenance.php --enablelater=5` to schedule maintenance mode 5 minutes from now.

`docker exec -it moodle_webserver php admin/cli/maintenance.php --disable` brings the site back up.

## Update

### Updating production server

- activate Moodle's maintenance mode
- backup production server (see above) and probably locally backup the backup
- take the server down with `bin/moodle-docker-compose down` if you need to restart metal or rebuild the container
- apply updates to metal, docker environment, Moodle code, whatever you need to do
- update `.env` if necessary.
- probably run `git submodule update` (tell git to check out the submodules' commits specified in the codebase) and maybe `git submodule init` before that
- if you took the server down, bring back up with `bin/moodle-docker-compose up -d` or `bin/moodle-docker-compose up -d --build` if the docker compose has changed any container builds
- if you took the server down, restore the backup you made
- run `docker exec -it moodle_webserver php admin/cli/upgrade.php` to trigger any database upgrades 
- if you didn't upgrade database and only added code, it may be necessary to purge caches: `docker exec -it moodle_webserver php admin/cli/purge_caches.php`.  Otherwise new classes may not be found and you get errors on your production site...
- check things look OK
- deactivate maintenance mode

### Staging

Before updating production you should probably apply updates in a staging environment, to check that nothing breaks:

- put production server in maintenance mode, make a backup
- take production server out of maintenance mode
- set up a staging environment in your desired upgrade state (`.env`, `git submodule update`, ...?)  
  Probably use SSH because you will log in with real passwords.  Just be aware that if you repeatedly restart the environment you could hit Let's Encrypt's rate limits.
- start the server (with `--build` if necessary)
- restore the backup of the production server
- run `docker exec -it moodle_webserver php admin/cli/upgrade.php` to trigger any database upgrades
- visit front page, check everything

### Updating moodle core

Core is almost untouched, so rebasing should be trivial.
* Check out the branch to which you wish to apply updates from upstream.
* Use `git log` to find the last commit from upstream and copy the identifier.  This will serve as the `cut_point`.
* Choose the upstream branch you wish to take updates from, probably of the form `upstream/MOODLE_39_STABLE`.
* Use the command `git rebase --onto <upstream_branch> <cut_point>` to replay local commits onto the newer upstream branch.

### Upgrade metal

This is only relevant to running in an Ubuntu/docker environment:

Upgrade metal:
  - `apt update`
  - `apt upgrade -y`
  - maybe `apt full-upgrade -y`

### Update git repo

Good summary of deploying codebase with git from [grimoire.ca](https://grimoire.ca/git/stop-using-git-pull-to-deploy):

`cd` into the working tree
```
git fetch --all
git checkout --force "${TARGET}"

git submodule sync
git submodule update --init --recursive
```
Where `${TARGET}` is the git object you wish to checkout (branch, tag, commit...)

## Run tests

### Acceptance tests

`bin/moodle-docker-compose exec webserver php admin/tool/behat/cli/init.php` to initialise behat environment.

`bin/moodle-docker-compose exec webserver php admin/tool/behat/cli/run.php --tags=@street_college` runs all tests for [street-college-moodle-core](https://github.com/leoauri/street-college-moodle-core) codebase.  

### Unit tests

`bin/moodle-docker-compose exec webserver php admin/tool/phpunit/cli/init.php` to initialise phpunit environment.

Unit tests use the non-standard suffix "test.php", so option `--test-suffix='test.php'` has to be included in the test command.  This runs tests from the `theme/street_college/tests` directory:  
`bin/moodle-docker-compose exec webserver vendor/bin/phpunit --test-suffix='test.php' theme/street_college/tests`

Tests for custom Street College code can be run with these commands:  
- `bin/moodle-docker-compose exec webserver vendor/bin/phpunit --test-suffix='test.php' theme/street_college/tests`
- `bin/moodle-docker-compose exec webserver vendor/bin/phpunit --test-suffix='test.php' blocks/course_participants/tests`

## Stop

Use `bin/moodle-docker-compose stop` to stop the environment and `bin/moodle-docker-compose down` to pull it down (destroy data).

Use `bin/moodle-docker-compose up -d --build` to rebuild the webserver if you are making changes to the docker machine.  
