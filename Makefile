LIMINAL_DIR    = $(HOME)/.liminal
LIMINAL_SCRIPT = $(LIMINAL_DIR)/liminal.sh

# ---------------------------------------------------------------------------
# test
# ---------------------------------------------------------------------------
.PHONY: test
test:
	@$$SHELL tests/test_liminal.sh $(FILTER)

# ---------------------------------------------------------------------------
# precheck
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
# ---------------------------------------------------------------------------
.PHONY: install
install: precheck
	@echo "Installing liminal..."
	@mkdir -p $(LIMINAL_DIR)/envs
	@cp $(CURDIR)/liminal.sh $(LIMINAL_SCRIPT)
	@chmod +x $(LIMINAL_SCRIPT)
	@echo ""
	@echo "  Done. Add the following line to your ~/.profile, ~/.bashrc, or ~/.zshrc:"
	@echo ""
	@echo "    [ -f \"\$$HOME/.liminal/liminal.sh\" ] && . \"\$$HOME/.liminal/liminal.sh\""
	@echo ""
	@echo "  Then restart your shell or run: source <your rc file>"

# ---------------------------------------------------------------------------
# reinstall — replaces liminal.sh only, preserves envs
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
# uninstall — removes ~/.liminal dir
#   WARNING: removes all environments. Back up ~/.liminal/envs first.
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
	@echo "Uninstall complete."
	@echo ""
	@echo "  Remember to remove the liminal source line from your shell config."
	@echo ""
