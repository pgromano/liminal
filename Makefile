LIMINAL_DIR  = $(HOME)/.liminal
LIMINAL_SCRIPT = $(LIMINAL_DIR)/liminal.sh

# ---------------------------------------------------------------------------
# _find-profile-file
#   Resolves which login/profile file to write to, following this logic:
#     1. ~/.profile exists           → use it (shell-neutral, highest priority)
#     2. ~/.profile absent, bash     → ~/.bash_profile → error
#     2. ~/.profile absent, zsh      → ~/.zprofile     → error
#
#   Exports: LIMINAL_PROFILE_FILE
# ---------------------------------------------------------------------------
define _find-profile-file
	SHELL_NAME=$$(basename "$$SHELL"); \
	if [ -f "$(HOME)/.profile" ]; then \
		LIMINAL_PROFILE_FILE="$(HOME)/.profile"; \
	elif [ "$$SHELL_NAME" = "bash" ]; then \
		if [ -f "$(HOME)/.bash_profile" ]; then \
			LIMINAL_PROFILE_FILE="$(HOME)/.bash_profile"; \
		else \
			echo "Error: No profile file found for bash."; \
			echo "  Expected ~/.profile or ~/.bash_profile."; \
			echo "  Create one of these files and re-run: make install"; \
			exit 1; \
		fi; \
	elif [ "$$SHELL_NAME" = "zsh" ]; then \
		if [ -f "$(HOME)/.zprofile" ]; then \
			LIMINAL_PROFILE_FILE="$(HOME)/.zprofile"; \
		else \
			echo "Error: No profile file found for zsh."; \
			echo "  Expected ~/.profile or ~/.zprofile."; \
			echo "  Create one of these files and re-run: make install"; \
			exit 1; \
		fi; \
	else \
		echo "Error: Unrecognised shell '$$SHELL_NAME'."; \
		echo "  Create ~/.profile manually and re-run: make install"; \
		exit 1; \
	fi
endef

# ---------------------------------------------------------------------------
# _find-rc-file
#   Resolves which interactive rc file to write to:
#     bash → ~/.bashrc → error
#     zsh  → ~/.zshrc  → error
#
#   Exports: LIMINAL_RC_FILE
# ---------------------------------------------------------------------------
define _find-rc-file
	SHELL_NAME=$$(basename "$$SHELL"); \
	if [ "$$SHELL_NAME" = "bash" ]; then \
		if [ -f "$(HOME)/.bashrc" ]; then \
			LIMINAL_RC_FILE="$(HOME)/.bashrc"; \
		else \
			echo "Error: No rc file found for bash."; \
			echo "  Expected ~/.bashrc."; \
			echo "  Create ~/.bashrc and re-run: make install"; \
			exit 1; \
		fi; \
	elif [ "$$SHELL_NAME" = "zsh" ]; then \
		if [ -f "$(HOME)/.zshrc" ]; then \
			LIMINAL_RC_FILE="$(HOME)/.zshrc"; \
		else \
			echo "Error: No rc file found for zsh."; \
			echo "  Expected ~/.zshrc."; \
			echo "  Create ~/.zshrc and re-run: make install"; \
			exit 1; \
		fi; \
	else \
		echo "Error: Unrecognised shell '$$SHELL_NAME'."; \
		echo "  Create ~/.bashrc or ~/.zshrc manually and re-run: make install"; \
		exit 1; \
	fi
endef

# ---------------------------------------------------------------------------
# test
#   Runs the plain-shell test suite in tests/test_liminal.sh.
#   Optional filter: make test FILTER=create
# ---------------------------------------------------------------------------
.PHONY: test
test:
	@$$SHELL tests/test_liminal.sh $(FILTER)

# ---------------------------------------------------------------------------
# precheck
#   Verifies Homebrew, installs pyenv if missing, checks python3 is available.
#   Does NOT write to any shell files — that is install's job.
# ---------------------------------------------------------------------------
.PHONY: precheck
precheck:
	@echo "Running pre-install checks..."
	@command -v brew >/dev/null 2>&1 || { \
		echo "Error: Homebrew is not installed."; \
		echo "  Visit https://brew.sh for installation instructions."; \
		exit 1; \
	}
	@command -v pyenv >/dev/null 2>&1 || { \
		echo "pyenv not found — installing via Homebrew..."; \
		brew install pyenv; \
	}
	@command -v python3 >/dev/null 2>&1 || { \
		echo "Error: python3 not found after pyenv install."; \
		echo "  Run: pyenv install <version>  e.g. pyenv install 3.12.0"; \
		exit 1; \
	}
	@echo "Pre-checks passed."

# ---------------------------------------------------------------------------
# install
#   1. Runs precheck
#   2. Creates ~/.liminal/envs and copies liminal.sh
#   3. Writes pyenv PATH hook to the resolved profile file (login-time PATH)
#   4. Writes pyenv init + liminal source to the resolved rc file (interactive)
# ---------------------------------------------------------------------------
.PHONY: install
install: precheck
	@echo "Installing liminal..."
	@mkdir -p $(LIMINAL_DIR)/envs
	@cp $(CURDIR)/liminal.sh $(LIMINAL_SCRIPT)
	@chmod +x $(LIMINAL_SCRIPT)

	@# --- Profile file: pyenv PATH hook ---
	@$(call _find-profile-file); \
	echo "  Writing pyenv PATH hook to $$LIMINAL_PROFILE_FILE"; \
	grep -qx '# pyenv PATH (liminal)' "$$LIMINAL_PROFILE_FILE" 2>/dev/null || \
		printf '\n# pyenv PATH (liminal)\nexport PYENV_ROOT="$$HOME/.pyenv"\nexport PATH="$$PYENV_ROOT/bin:$$PATH"\nif command -v pyenv >/dev/null 2>&1; then\n    eval "$$(pyenv init --path)"\nfi\n# end pyenv PATH (liminal)\n' \
		>> "$$LIMINAL_PROFILE_FILE"

	@# --- RC file: pyenv init (shims/completions) + liminal source ---
	@$(call _find-rc-file); \
	echo "  Writing pyenv init + liminal source to $$LIMINAL_RC_FILE"; \
	grep -qx '# pyenv init (liminal)' "$$LIMINAL_RC_FILE" 2>/dev/null || \
		printf '\n# pyenv init (liminal)\nif command -v pyenv >/dev/null 2>&1; then\n    eval "$$(pyenv init -)"\nfi\n# end pyenv init (liminal)\n' \
		>> "$$LIMINAL_RC_FILE"; \
	grep -qx '# Load liminal' "$$LIMINAL_RC_FILE" 2>/dev/null || \
		printf '\n# Load liminal\nif [ -f "$$HOME/.liminal/liminal.sh" ]; then\n    . "$$HOME/.liminal/liminal.sh"\nfi\n# end Load liminal\n' \
		>> "$$LIMINAL_RC_FILE"

	@echo "Done. Restart your shell or run: source ~/<your rc file>"

# ---------------------------------------------------------------------------
# reinstall — wipe and reinstall without touching envs
# ---------------------------------------------------------------------------
.PHONY: reinstall
reinstall: _soft_uninstall install

# ---------------------------------------------------------------------------
# _soft_uninstall — removes only liminal.sh, preserving envs
# ---------------------------------------------------------------------------
.PHONY: _soft_uninstall
_soft_uninstall:
	@if [ -f $(LIMINAL_SCRIPT) ]; then \
		echo "Removing $(LIMINAL_SCRIPT)..."; \
		rm -f $(LIMINAL_SCRIPT); \
	fi

# ---------------------------------------------------------------------------
# uninstall — full removal: ~/.liminal dir + all hooks from shell files
#   WARNING: this removes all environments under ~/.liminal/envs.
#   To keep your environments, back up ~/.liminal/envs before running.
#   Cleans all candidate files so no orphaned blocks remain regardless of
#   which file was originally written to.
# ---------------------------------------------------------------------------
.PHONY: uninstall
uninstall: _soft_uninstall
	@if [ -d $(LIMINAL_DIR)/envs ] && [ -n "$$(ls $(LIMINAL_DIR)/envs 2>/dev/null)" ]; then \
		echo "Warning: the following environments will be permanently removed:"; \
		for e in $(LIMINAL_DIR)/envs/*/; do echo "  - $$(basename $$e)"; done; \
		printf "Continue? [y/N] "; \
		read confirm; \
		[ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || { echo "Aborted."; exit 1; }; \
	fi
	@if [ -d $(LIMINAL_DIR) ]; then \
		echo "Removing $(LIMINAL_DIR)..."; \
		rm -rf $(LIMINAL_DIR); \
	fi
	@echo "Removing shell hooks..."
	@for f in \
		$(HOME)/.profile \
		$(HOME)/.bash_profile \
		$(HOME)/.zprofile \
		$(HOME)/.bashrc \
		$(HOME)/.zshrc; do \
		if [ -f "$$f" ]; then \
			if grep -qF '# pyenv PATH (liminal)' "$$f" 2>/dev/null || \
			   grep -qF '# pyenv init (liminal)' "$$f" 2>/dev/null || \
			   grep -qF '# Load liminal' "$$f" 2>/dev/null; then \
				cp "$$f" "$$f.bak"; \
				awk ' \
					/^# pyenv PATH \(liminal\)/  { skip=1; next } \
					/^# pyenv init \(liminal\)/  { skip=1; next } \
					/^# Load liminal/            { skip=1; next } \
					/^# end pyenv PATH \(liminal\)/ { skip=0; next } \
					/^# end pyenv init \(liminal\)/ { skip=0; next } \
					/^# end Load liminal/           { skip=0; next } \
					!skip { print } \
				' "$$f.bak" > "$$f" && \
				echo "  Cleaned $$f (backup: $$f.bak)"; \
			fi; \
		fi; \
	done
	@unset _LIMINAL_RESET _LIMINAL_BOLD _LIMINAL_MUTED _LIMINAL_BLUE _LIMINAL_YELLOW _LIMINAL_TEAL 2>/dev/null || true
	@echo "Uninstall complete."
