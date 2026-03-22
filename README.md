# liminal

> a tool for things inbetween the things inbetween

liminal is a shell utility for managing Python virtual environments. It wraps `pyenv` and `venv` into a single ergonomic interface, and automatically registers each environment as a Jupyter kernel so it's available in notebooks without any extra setup.

## Requirements

- macOS or Linux
- bash or zsh
- [Homebrew](https://brew.sh) (used to install pyenv if not already present)

## Installation

```sh
make install
```

This copies `liminal.sh` to `~/.liminal/liminal.sh` and prints a one-liner to add to your shell config.

Add the following to your `~/.profile`, `~/.bashrc`, or `~/.zshrc`:

```sh
[ -f "$HOME/.liminal/liminal.sh" ] && . "$HOME/.liminal/liminal.sh"
```

Then reload your shell:

```sh
source ~/.profile   # or ~/.bashrc / ~/.zshrc
```

## Uninstallation

```sh
make uninstall
```

Removes `~/.liminal` and all environments within it (you'll be prompted to confirm if environments exist). Afterwards, remove the source line you added to your shell config manually.

To reinstall without touching your environments:

```sh
make reinstall
```

## Usage

```sh
liminal <command> [options]
```

### Environment commands

| Command | Description |
|---|---|
| `liminal list` | List all environments |
| `liminal status` | Show current Python version and active environment |
| `liminal create <name>` | Create a new environment |
| `liminal activate <name>` | Activate an environment |
| `liminal deactivate` | Deactivate the current environment |
| `liminal remove <name>` | Remove an environment |

### Python version commands

| Command | Description |
|---|---|
| `liminal search [filter]` | List available Python versions |
| `liminal install <version>` | Install a Python version via pyenv |
| `liminal uninstall <version>` | Uninstall a Python version |
| `liminal switch <version>` | Temporarily use a Python version (current shell) |
| `liminal set <version>` | Set the global default Python version |

### Creating environments

```sh
# Create with the current Python version
liminal create myenv

# Create with a specific Python version
liminal create myenv -v 3.12.0

# Create and install from a requirements file
liminal create myenv -r requirements.txt

# Both
liminal create myenv -v 3.12.0 -r requirements.txt
```

The environment is automatically activated after creation, and registered as a Jupyter kernel with the name `myenv (3.12.0)`.

### Example workflow

```sh
# See what Python versions are available
liminal search 3.12

# Install one
liminal install 3.12.1

# Create an environment using it
liminal create myproject -v 3.12.1

# Check what's active
liminal status

# Later, switch to a different environment
liminal activate otheraproject

# Deactivate when done
liminal deactivate
```

## How environments are stored

All environments live under `~/.liminal/envs/<name>/`. Each environment stores its Python version in a `.python-version` file, which liminal uses to restore the correct pyenv shell version on activation.

## Tab completion

liminal includes tab completion for both bash and zsh — no extra setup needed beyond sourcing the script.

- Commands complete after `liminal <TAB>`
- Environment names complete after `liminal activate <TAB>` and `liminal remove <TAB>`
- Installed Python versions complete after `liminal switch <TAB>`, `liminal set <TAB>`, and `liminal uninstall <TAB>`

## Development

Run the test suite:

```sh
make test
```

Run a subset of tests by name:

```sh
make test FILTER=create
```
