LIMINAL_DIR = $(HOME)/.liminal
LIMINAL_SCRIPT = $(LIMINAL_DIR)/liminal.sh

precheck:
	# check homebrew is installed
	@command -v brew >/dev/null 2>&1 || { \
		echo "Error: Homebrew is not installed. Visit https://brew.sh for installation instructions."; \
		exit 1; \
	}
	# install pyenv via homebrew if not already installed
	@command -v pyenv >/dev/null 2>&1 || brew install pyenv
	# make sure that pyenv is properly set up for shell
	eval "$$(pyenv init --path)"
	# check python3 is available
	@command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found. Run: pyenv install 3.x.x"; exit 1; }

install: precheck
	# create .liminal dir and copy script
	if ! [ -d $(LIMINAL_DIR) ]; then \
		echo "Installing..."; \
		mkdir -p $(LIMINAL_DIR)/envs; \
	fi
	cp $(CURDIR)/liminal.sh $(LIMINAL_SCRIPT)
	# add liminal.sh sourcing to .profile if not already present
	@grep -qF '# Load liminal functions' $(HOME)/.profile 2>/dev/null || \
		printf '\n# Load liminal functions\nif [ -f "$$HOME/.liminal/liminal.sh" ]; then\n    . "$$HOME/.liminal/liminal.sh"\nfi\n' >> $(HOME)/.profile

reinstall: uninstall install

uninstall:
	# remove .liminal directory if it exists
	if [ -d $(LIMINAL_DIR) ]; then \
		echo "Uninstalling..."; \
		rm -rf $(LIMINAL_DIR); \
	fi
	# remove liminal sourcing block from .profile if present
	@sed -i '' '/# Load liminal functions/{N;N;N;N;d}' $(HOME)/.profile 2>/dev/null || true
